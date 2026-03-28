import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../models/server_setup_config.dart';
import '../models/setup_step.dart';
import 'config_service.dart';

class ServerSetupService extends ChangeNotifier {
  SetupStep _currentStep = SetupStep.idle;
  final List<String> _logs = [];
  String? _errorMessage;
  SSHClient? _client;
  bool _alreadyInstalled = false;
  ServerSetupConfig? _lastConfig;

  SetupStep get currentStep => _currentStep;
  List<String> get logs => List.unmodifiable(_logs);
  String? get errorMessage => _errorMessage;
  bool get alreadyInstalled => _alreadyInstalled;

  void clearLogs() {
    _logs.clear();
    _errorMessage = null;
    _currentStep = SetupStep.idle;
    notifyListeners();
  }

  Future<void> installAndRemember(ServerSetupConfig config) async {
    _lastConfig = config;
    await installServer(config);
  }

  Future<void> installServer(ServerSetupConfig config) async {
    _logs.clear();
    _errorMessage = null;
    _alreadyInstalled = false;
    notifyListeners();

    try {
      await _stepConnect(config);
      await _stepCheckSystem();
      await _stepInstall();
      await _stepConfigure(config);
      await _stepCertificate(config);
      await _stepStartService();
      await _stepVerify();
      _setStep(SetupStep.completed);
      _addLog('Installation completed successfully.');
    } catch (e) {
      _errorMessage = e.toString();
      _setStep(SetupStep.failed);
      _addLog('Error: $e');
    }
  }

  Future<void> applyToClientConfig(ConfigService configService) async {
    final existingConfig = await configService.loadConfig();
    final source = _lastConfig;
    if (source == null) {
      throw Exception('No installed server configuration available yet.');
    }

    final updatedConfig = existingConfig.copyWith(
      hostname: source.domain,
      address: source.host,
      port: source.listenPort,
      username: source.vpnUsername,
      password: source.vpnPassword,
    );
    await configService.saveConfig(updatedConfig);
  }

  void disconnect() {
    _client?.close();
    _client = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }

  void _setStep(SetupStep step) {
    _currentStep = step;
    notifyListeners();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$timestamp] $message');
    if (_logs.length > 1000) {
      _logs.removeRange(0, _logs.length - 1000);
    }
    notifyListeners();
  }

  void _addLogRaw(String message) {
    _logs.add(message);
    if (_logs.length > 1000) {
      _logs.removeRange(0, _logs.length - 1000);
    }
    notifyListeners();
  }

  Future<void> _stepConnect(ServerSetupConfig config) async {
    _setStep(SetupStep.connecting);
    _addLog('Connecting to ${config.host}:${config.sshPort}...');

    final socket = await SSHSocket.connect(
      config.host,
      config.sshPort,
      timeout: const Duration(seconds: 15),
    );

    _client = SSHClient(
      socket,
      username: config.sshUsername,
      onPasswordRequest: () => config.sshPassword,
    );

    _addLog('SSH connection established.');
  }

  Future<void> _stepCheckSystem() async {
    _setStep(SetupStep.checkingSystem);

    final arch = await _runCommand('uname -m');
    _addLog('Architecture: $arch');
    if (arch != 'x86_64' && arch != 'aarch64') {
      throw Exception(
        'Unsupported architecture: $arch. Requires x86_64 or aarch64.',
      );
    }

    final osInfo = await _runCommand('cat /etc/os-release | head -5');
    _addLog('OS: ${osInfo.split('\n').first}');

    try {
      await _runCommand('test -f /opt/trusttunnel/trusttunnel_endpoint');
      _alreadyInstalled = true;
      _addLog('TrustTunnel is already installed on this server.');
      notifyListeners();
    } catch (_) {
      _alreadyInstalled = false;
      _addLog('TrustTunnel is not installed yet.');
    }

    try {
      await _runCommand('which curl');
    } catch (_) {
      _addLog('Installing curl...');
      await _runCommand('apt-get update -qq && apt-get install -y -qq curl');
    }
  }

  Future<void> _stepInstall() async {
    _setStep(SetupStep.installing);
    _addLog('Downloading and installing TrustTunnel...');

    await _runCommand(
      'curl -fsSL https://raw.githubusercontent.com/TrustTunnel/TrustTunnel/refs/heads/master/scripts/install.sh | sh -s -',
    );
    await _runCommand('test -f /opt/trusttunnel/trusttunnel_endpoint');
    _addLog('TrustTunnel installed to /opt/trusttunnel/.');
  }

  Future<void> _stepConfigure(ServerSetupConfig config) async {
    _setStep(SetupStep.configuringServer);

    if (_alreadyInstalled) {
      _addLog('Stopping existing service...');
      try {
        await _runCommand('systemctl stop trusttunnel 2>/dev/null || true');
      } catch (_) {}
    }

    await _uploadFile('/opt/trusttunnel/vpn.toml', config.generateVpnToml());
    _addLog('vpn.toml uploaded.');

    await _uploadFile(
      '/opt/trusttunnel/credentials.toml',
      config.generateCredentialsToml(),
    );
    _addLog('credentials.toml uploaded.');

    await _uploadFile('/opt/trusttunnel/hosts.toml', config.generateHostsToml());
    _addLog('hosts.toml uploaded.');

    await _runCommand('chmod 600 /opt/trusttunnel/credentials.toml');
    _addLog('Server configuration is ready.');
  }

  Future<void> _stepCertificate(ServerSetupConfig config) async {
    _setStep(SetupStep.obtainingCertificate);

    try {
      await _runCommand(
        'test -f /etc/letsencrypt/live/${config.domain}/fullchain.pem',
      );
      _addLog('Certificate for ${config.domain} already exists.');
      return;
    } catch (_) {
      _addLog('Certificate not found, requesting via Let\'s Encrypt...');
    }

    try {
      await _runCommand('which certbot');
    } catch (_) {
      _addLog('Installing certbot...');
      await _runCommand(
        'apt-get update -qq && apt-get install -y -qq certbot',
      );
    }

    try {
      await _runCommand('fuser -k 80/tcp 2>/dev/null || true');
    } catch (_) {}

    await _runCommand(
      'certbot certonly --non-interactive --standalone '
      '--agree-tos -m ${config.email} -d ${config.domain}',
    );
    await _runCommand(
      'test -f /etc/letsencrypt/live/${config.domain}/fullchain.pem',
    );
    _addLog('Certificate obtained.');
  }

  Future<void> _stepStartService() async {
    _setStep(SetupStep.startingService);
    _addLog('Configuring systemd service...');

    await _runCommand(
      'cp /opt/trusttunnel/trusttunnel.service.template '
      '/etc/systemd/system/trusttunnel.service',
    );
    await _runCommand('systemctl daemon-reload');
    await _runCommand('systemctl enable trusttunnel');
    await _runCommand('systemctl start trusttunnel');
    _addLog('Service started.');
  }

  Future<void> _stepVerify() async {
    _setStep(SetupStep.verifying);
    _addLog('Waiting for service to start...');

    await Future<void>.delayed(const Duration(seconds: 3));
    final status = await _runCommand('systemctl is-active trusttunnel');
    if (status.trim() == 'active') {
      _addLog('TrustTunnel service is active.');
      return;
    }

    final journal = await _runCommand(
      'journalctl -u trusttunnel --no-pager -n 20 2>/dev/null || true',
    );
    throw Exception(
      'Service failed to start (status: $status)\n\nLogs:\n$journal',
    );
  }

  Future<String> _runCommand(String command) async {
    if (_client == null) {
      throw Exception('SSH is not connected.');
    }

    _addLog('\$ $command');

    final session = await _client!.execute(command);
    final stdout = await utf8.decodeStream(session.stdout);
    final stderr = await utf8.decodeStream(session.stderr);
    final exitCode = session.exitCode;

    if (stdout.trim().isNotEmpty) {
      for (final line in stdout.trim().split('\n')) {
        _addLogRaw('  $line');
      }
    }
    if (stderr.trim().isNotEmpty) {
      for (final line in stderr.trim().split('\n')) {
        _addLogRaw('  [stderr] $line');
      }
    }

    session.close();

    if (exitCode != null && exitCode != 0) {
      throw Exception(
        'Command failed (exit code $exitCode): $command\n$stderr',
      );
    }

    return stdout.trim();
  }

  Future<void> _uploadFile(String remotePath, String content) async {
    if (_client == null) {
      throw Exception('SSH is not connected.');
    }

    _addLog('Uploading file: $remotePath');

    final sftp = await _client!.sftp();
    final file = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    await file.write(Stream.value(utf8.encode(content)));
    await file.close();
    sftp.close();
  }
}

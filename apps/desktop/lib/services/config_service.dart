import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../models/server_config.dart';
import '../utils/localization_helper.dart';
import '../models/domain_group.dart';

/// Service for managing application configuration
class ConfigService {
  static const String _configKey = 'server_config';
  static const String _domainGroupsKey = 'domain_groups';
  static const String _localeKey = 'preferred_locale';
  static const String _configFileName = 'trusttunnel_client.toml';
  static const String _windowsRunKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _windowsRunValueName = 'Trusty VPN';

  /// Load server configuration from local storage
  Future<ServerConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_configKey);

      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return ServerConfig.fromJson(json);
      }
    } catch (e) {
      print('Error loading config: $e');
    }

    // Return default config if loading fails
    return ServerConfig.defaultConfig();
  }

  /// Save server configuration to local storage
  Future<void> saveConfig(ServerConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = config.toJson();
      print('Saving config - vpnMode: ${json['vpnMode']}, domains: ${json['splitTunnelDomains']}, apps: ${json['splitTunnelApps']}');
      final jsonString = jsonEncode(json);
      await prefs.setString(_configKey, jsonString);
    } catch (e) {
      print('Error saving config: $e');
      rethrow;
    }
  }

  Future<void> syncAutoStart(ServerConfig config) async {
    if (!Platform.isWindows) {
      return;
    }

    final launchCommand = await _buildWindowsAutoStartCommand();

    if (config.autoStartWithWindows) {
      final result = await Process.run('reg', [
        'add',
        _windowsRunKey,
        '/v',
        _windowsRunValueName,
        '/t',
        'REG_SZ',
        '/d',
        launchCommand,
        '/f',
      ]);

      if (result.exitCode != 0) {
        throw Exception('Failed to enable Windows auto-start: ${result.stderr}'.trim());
      }
      return;
    }

    final result = await Process.run('reg', [
      'delete',
      _windowsRunKey,
      '/v',
      _windowsRunValueName,
      '/f',
    ]);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().toLowerCase();
      if (!stderr.contains('unable to find') && !stderr.contains('cannot find')) {
        throw Exception('Failed to disable Windows auto-start: ${result.stderr}'.trim());
      }
    }
  }

  Future<String> _buildWindowsAutoStartCommand() async {
    final resolved = Platform.resolvedExecutable;
    if (resolved.toLowerCase().endsWith('.exe')) {
      return '"$resolved"';
    }

    final fallback = p.join(Directory.current.path, 'Trusty.exe');
    return '"$fallback"';
  }

  Future<String> loadPreferredLocaleCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);
      if (localeCode == 'ru') {
        return 'ru';
      }
      if (localeCode == 'en') {
        return 'en';
      }
    } catch (e) {
      print('Error loading preferred locale: $e');
    }

    return 'ru';
  }

  Future<void> savePreferredLocaleCode(String localeCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, localeCode);
    } catch (e) {
      print('Error saving preferred locale: $e');
      rethrow;
    }
  }

  /// Get path to client directory
  Future<String> getClientDirectory() async {
    String baseDir;

    if (Platform.isMacOS) {
      // On macOS, the executable is inside .app/Contents/MacOS/
      // We need to go up to the directory containing the .app bundle
      final exePath = Platform.resolvedExecutable;
      var dir = File(exePath).parent;
      // Walk up until we exit the .app bundle
      while (dir.path.contains('.app')) {
        dir = dir.parent;
      }
      baseDir = dir.path;
    } else if (Platform.isLinux) {
      final appImagePath = Platform.environment['APPIMAGE'];
      if (appImagePath != null && appImagePath.isNotEmpty) {
        baseDir = File(appImagePath).parent.path;
      } else {
        baseDir = File(Platform.resolvedExecutable).parent.path;
      }
    } else {
      baseDir = Directory.current.path;
    }

    final clientDir = p.join(baseDir, 'client');

    // Create directory if it doesn't exist
    final dir = Directory(clientDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return clientDir;
  }

  /// Get path to Trusty client executable
  Future<String> getTrustTunnelExecutable() async {
    final clientDir = await getClientDirectory();

    if (Platform.isWindows) {
      final clientExe = p.join(clientDir, 'trusttunnel_client.exe');
      if (await File(clientExe).exists()) return clientExe;
      return p.join(clientDir, 'trusttunnel.exe');
    } else {
      final clientBin = p.join(clientDir, 'trusttunnel_client');
      if (await File(clientBin).exists()) return clientBin;
      return p.join(clientDir, 'trusttunnel');
    }
  }

  /// Check if Trusty client binary exists
  Future<bool> isTrustTunnelInstalled() async {
    final exePath = await getTrustTunnelExecutable();
    return File(exePath).exists();
  }

  /// Get path to config.toml file
  Future<String> getConfigFilePath() async {
    final clientDir = await getClientDirectory();
    return p.join(clientDir, _configFileName);
  }

  /// Write TOML config file for Trusty client
  Future<void> writeConfigFile(ServerConfig config) async {
    try {
      final configPath = await getConfigFilePath();
      final file = File(configPath);

      print('Config validation: hostname=${config.hostname}, address=${config.address}, username=${config.username}');
      print('Writing TOML - vpnMode: ${config.vpnMode}, domains: ${config.splitTunnelDomains}, apps: ${config.splitTunnelApps}');

      // Validate config before generating TOML
      if (config.hostname.isEmpty) {
        throw Exception(L10n.tr.configErrorHostnameEmpty);
      }
      if (config.address.isEmpty) {
        throw Exception(L10n.tr.configErrorAddressEmpty);
      }
      if (config.username.isEmpty) {
        throw Exception(L10n.tr.configErrorUsernameEmpty);
      }

      final toml = config.toToml();
      await file.writeAsString(toml);

      print('Config file written successfully to: $configPath');
    } catch (e, stackTrace) {
      print('Error writing config file: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete TOML config file
  Future<void> deleteConfigFile() async {
    try {
      final configPath = await getConfigFilePath();
      final file = File(configPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting config file: $e');
    }
  }

  /// Export configuration to JSON file
  Future<void> exportConfig(ServerConfig config, String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = jsonEncode(config.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error exporting config: $e');
      rethrow;
    }
  }

  /// Import configuration from JSON file
  Future<ServerConfig> importConfig(String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ServerConfig.fromJson(json);
    } catch (e) {
      print('Error importing config: $e');
      rethrow;
    }
  }

  /// Load domain groups from local storage
  Future<DomainGroupsData> loadDomainGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_domainGroupsKey);

      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return DomainGroupsData.fromJson(json);
      }
    } catch (e) {
      print('Error loading domain groups: $e');
    }

    return DomainGroupsData();
  }

  /// Save domain groups to local storage
  Future<void> saveDomainGroups(DomainGroupsData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data.toJson());
      await prefs.setString(_domainGroupsKey, jsonString);
    } catch (e) {
      print('Error saving domain groups: $e');
      rethrow;
    }
  }

  /// Migrate flat splitTunnelDomains to domain groups (one-time)
  Future<DomainGroupsData> migrateFlatDomainsToGroups() async {
    final prefs = await SharedPreferences.getInstance();

    // If groups already exist, no migration needed
    if (prefs.containsKey(_domainGroupsKey)) {
      return loadDomainGroups();
    }

    // Load existing config to get flat domains
    final config = await loadConfig();
    final flatDomains = config.splitTunnelDomains;

    // Move all flat domains to standalone
    final data = DomainGroupsData(
      standaloneDomains: List.from(flatDomains),
    );

    if (flatDomains.isNotEmpty) {
      await saveDomainGroups(data);
    }

    return data;
  }
}

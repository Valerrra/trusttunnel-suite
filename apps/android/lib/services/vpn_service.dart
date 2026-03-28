import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vpn_plugin/platform_api.g.dart';

import '../models/server_config.dart';
import '../models/vpn_status.dart';

class VpnService extends ChangeNotifier {
  static const EventChannel _stateChannel = EventChannel(
    'vpn_plugin_event_channel',
  );
  static const EventChannel _queryLogChannel = EventChannel(
    'vpn_plugin_event_channel_query_log',
  );

  final IVpnManager _api = IVpnManager();
  VpnStatus _status = VpnStatus.disconnected;
  final List<String> _logs = [];
  String? _errorMessage;
  StreamSubscription<dynamic>? _stateSubscription;
  StreamSubscription<dynamic>? _queryLogSubscription;
  bool _disconnectRequested = false;

  VpnService() {
    _initialize();
  }

  VpnStatus get status => _status;
  List<String> get logs => List.unmodifiable(_logs);
  String? get errorMessage => _errorMessage;

  Future<void> connect(ServerConfig config) async {
    if (_status.isActive) {
      return;
    }

    _errorMessage = null;
    _disconnectRequested = false;
    _setStatus(VpnStatus.connecting);
    _addLog(
      'Preparing Android VPN session for ${config.hostname}:${config.port}',
    );

    try {
      await _api.start(serverName: config.hostname, config: config.toToml());
      _addLog('Native backend start requested.');
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? e.code;
      _addLog(
        'Failed to start native backend: ${e.code} ${e.message ?? ""}'.trim(),
      );
      _setStatus(VpnStatus.error);
    } catch (e) {
      _errorMessage = e.toString();
      _addLog('Failed to start native backend: $e');
      _setStatus(VpnStatus.error);
    }
  }

  Future<void> disconnect() async {
    _errorMessage = null;
    _disconnectRequested = true;
    _setStatus(VpnStatus.disconnecting);
    _addLog('Stopping Android VPN session.');

    try {
      await _api.stop();
    } on PlatformException catch (e) {
      _errorMessage = e.message ?? e.code;
      _addLog(
        'Failed to stop native backend: ${e.code} ${e.message ?? ""}'.trim(),
      );
      _setStatus(VpnStatus.error);
    } catch (e) {
      _errorMessage = e.toString();
      _addLog('Failed to stop native backend: $e');
      _setStatus(VpnStatus.error);
    }
  }

  Future<void> clearLogs() async {
    _logs.clear();
    notifyListeners();
  }

  Future<void> _initialize() async {
    _stateSubscription = _stateChannel.receiveBroadcastStream().listen(
      _handleNativeState,
      onError: (Object error, StackTrace stackTrace) {
        _addLog('State stream error: $error');
      },
    );

    _queryLogSubscription = _queryLogChannel.receiveBroadcastStream().listen(
      _handleQueryLog,
      onError: (Object error, StackTrace stackTrace) {
        _addLog('Query log stream error: $error');
      },
    );

    try {
      final nativeState = await _api.getCurrentState();
      _applyNativeState(nativeState);
    } catch (e) {
      _addLog('Native backend is not ready yet: $e');
    }
  }

  void _handleNativeState(dynamic rawState) {
    final nativeState = switch (rawState) {
      int() when rawState >= 0 && rawState < VpnManagerState.values.length =>
        VpnManagerState.values[rawState],
      VpnManagerState() => rawState,
      _ => VpnManagerState.disconnected,
    };

    _applyNativeState(nativeState);
  }

  void _applyNativeState(VpnManagerState nativeState) {
    _addLog('Native state: ${nativeState.name}');

    switch (nativeState) {
      case VpnManagerState.disconnected:
        _errorMessage = null;
        _disconnectRequested = false;
        _setStatus(VpnStatus.disconnected);
        return;
      case VpnManagerState.connecting:
      case VpnManagerState.waitingForRecovery:
      case VpnManagerState.recovering:
      case VpnManagerState.waitingForNetwork:
        _setStatus(
          _disconnectRequested ? VpnStatus.disconnecting : VpnStatus.connecting,
        );
        return;
      case VpnManagerState.connected:
        _errorMessage = null;
        _disconnectRequested = false;
        _setStatus(VpnStatus.connected);
        return;
    }
  }

  void _handleQueryLog(dynamic event) {
    if (event == null) {
      return;
    }
    _addLog(event.toString());
  }

  void _setStatus(VpnStatus status) {
    _status = status;
    notifyListeners();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    _logs.add('[$timestamp] $message');
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _queryLogSubscription?.cancel();
    super.dispose();
  }
}

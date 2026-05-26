import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vpn_client/models/proxy_node.dart';
import 'package:vpn_client/models/app_config.dart';
import 'package:vpn_client/services/storage_service.dart';
import 'package:vpn_client/utils/constants.dart';

enum VpnState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class VpnService {
  final StorageService _storage;

  VpnState _state = VpnState.disconnected;
  String? _errorMessage;
  int _uploadBytes = 0;
  int _downloadBytes = 0;
  Timer? _statsTimer;

  final _stateController = StreamController<VpnState>.broadcast();
  final _statsController =
      StreamController<({int upload, int download})>.broadcast();

  // Method channel to Android native
  static const _channel = MethodChannel(AppConstants.vpnChannel);

  VpnService(this._storage) {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  VpnState get state => _state;
  String? get errorMessage => _errorMessage;
  Stream<VpnState> get stateStream => _stateController.stream;
  Stream<({int upload, int download})> get statsStream =>
      _statsController.stream;

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onStateChanged':
        final stateStr = call.arguments as String;
        _updateState(_parseState(stateStr));
        break;
      case 'onStatsUpdate':
        final args = call.arguments as Map<dynamic, dynamic>;
        _uploadBytes = (args['upload'] as num).toInt();
        _downloadBytes = (args['download'] as num).toInt();
        _statsController
            .add((upload: _uploadBytes, download: _downloadBytes));
        break;
      case 'onError':
        _errorMessage = call.arguments as String?;
        _updateState(VpnState.error);
        break;
    }
  }

  VpnState _parseState(String state) {
    switch (state) {
      case 'CONNECTING':
        return VpnState.connecting;
      case 'CONNECTED':
        return VpnState.connected;
      case 'DISCONNECTING':
        return VpnState.disconnecting;
      case 'DISCONNECTED':
        return VpnState.disconnected;
      case 'ERROR':
        return VpnState.error;
      default:
        return VpnState.disconnected;
    }
  }

  Future<void> connect(ProxyNode node, AppConfig config) async {
    if (_state == VpnState.connecting || _state == VpnState.connected) return;

    _updateState(VpnState.connecting);
    _errorMessage = null;

    try {
      final v2rayConfig = node.toV2RayConfig(
        config.socksPort,
        config.httpPort,
      );

      await _channel.invokeMethod('startVpn', {
        'config': v2rayConfig,
        'socksPort': config.socksPort,
        'httpPort': config.httpPort,
        'bypassLan': config.bypassLan,
      });

      _startStatsPolling();
      _updateState(VpnState.connected);
    } catch (e) {
      _errorMessage = e.toString();
      _updateState(VpnState.error);
    }
  }

  Future<void> disconnect() async {
    if (_state == VpnState.disconnected) return;

    _updateState(VpnState.disconnecting);
    _stopStatsPolling();

    try {
      await _channel.invokeMethod('stopVpn');
    } catch (_) {}
    _updateState(VpnState.disconnected);
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final stats = await _channel
            .invokeMethod('getStats') as Map<dynamic, dynamic>?;
        if (stats != null) {
          _uploadBytes = (stats['upload'] as num).toInt();
          _downloadBytes = (stats['download'] as num).toInt();
          _statsController
              .add((upload: _uploadBytes, download: _downloadBytes));
        }
      } catch (_) {}
    });
  }

  void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  void _updateState(VpnState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  void dispose() {
    _stopStatsPolling();
    _stateController.close();
    _statsController.close();
  }
}

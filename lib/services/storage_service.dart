import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vpn_client/models/proxy_node.dart';
import 'package:vpn_client/models/subscription.dart';
import 'package:vpn_client/models/app_config.dart';
import 'package:vpn_client/utils/constants.dart';

class StorageService {
  late Box<String> _nodesBox;
  late Box<String> _subscriptionsBox;
  late Box<String> _configBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _nodesBox = await Hive.openBox<String>(AppConstants.nodesBox);
    _subscriptionsBox =
        await Hive.openBox<String>(AppConstants.subscriptionsBox);
    _configBox = await Hive.openBox<String>(AppConstants.configBox);
  }

  // --- Nodes ---
  List<ProxyNode> getNodes() {
    return _nodesBox.values
        .map((v) => ProxyNode.fromJson(jsonDecode(v) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveNode(ProxyNode node) {
    return _nodesBox.put(node.id, jsonEncode(node.toJson()));
  }

  Future<void> saveNodes(List<ProxyNode> nodes) {
    final map = <String, String>{};
    for (final node in nodes) {
      map[node.id] = jsonEncode(node.toJson());
    }
    return _nodesBox.putAll(map);
  }

  Future<void> deleteNode(String id) {
    return _nodesBox.delete(id);
  }

  Future<void> clearNodes() {
    return _nodesBox.clear();
  }

  // --- Subscriptions ---
  List<Subscription> getSubscriptions() {
    return _subscriptionsBox.values
        .map((v) =>
            Subscription.fromJson(jsonDecode(v) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSubscription(Subscription sub) {
    return _subscriptionsBox.put(sub.id, jsonEncode(sub.toJson()));
  }

  Future<void> deleteSubscription(String id) {
    return _subscriptionsBox.delete(id);
  }

  // --- Config ---
  AppConfig getConfig() {
    final raw = _configBox.get('app_config');
    if (raw == null) return AppConfig();
    try {
      return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppConfig();
    }
  }

  Future<void> saveConfig(AppConfig config) {
    return _configBox.put('app_config', jsonEncode(config.toJson()));
  }
}

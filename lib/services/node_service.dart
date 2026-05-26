import 'dart:io';
import 'package:vpn_client/models/proxy_node.dart';
import 'package:vpn_client/services/storage_service.dart';

class NodeService {
  final StorageService _storage;

  NodeService(this._storage);

  List<ProxyNode> getNodes() => _storage.getNodes();

  ProxyNode? getCurrentNode() {
    final nodes = getNodes();
    if (nodes.isEmpty) return null;
    // Return last used or first node
    final sorted = List<ProxyNode>.from(nodes)
      ..sort((a, b) {
        if (a.lastUsedAt == null && b.lastUsedAt == null) return 0;
        if (a.lastUsedAt == null) return 1;
        if (b.lastUsedAt == null) return -1;
        return b.lastUsedAt!.compareTo(a.lastUsedAt!);
      });
    return sorted.first;
  }

  Future<void> addNode(ProxyNode node) async {
    // Check for duplicate
    final existing = getNodes();
    final dup = existing.any((n) =>
        n.address == node.address && n.port == node.port && n.type == node.type);
    if (dup) return;
    await _storage.saveNode(node);
  }

  Future<void> addNodes(List<ProxyNode> nodes) async {
    await _storage.saveNodes(nodes);
  }

  Future<void> removeNode(String id) async {
    await _storage.deleteNode(id);
  }

  Future<void> clearNodes() async {
    await _storage.clearNodes();
  }

  Future<void> markUsed(ProxyNode node) async {
    final updated = node.copyWith(lastUsedAt: DateTime.now());
    await _storage.saveNode(updated);
  }

  Future<void> toggleFavorite(ProxyNode node) async {
    final updated = node.copyWith(isFavorite: !node.isFavorite);
    await _storage.saveNode(updated);
  }

  /// Test node latency via TCP connection
  Future<int> testLatency(ProxyNode node, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        node.address,
        node.port,
        timeout: timeout,
      );
      socket.destroy();
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  Future<void> updateLatency(ProxyNode node) async {
    final latency = await testLatency(node);
    final updated = node.copyWith(
      latency: latency,
      status: latency < 0
          ? NodeStatus.timeout
          : latency < 300
              ? NodeStatus.ok
              : NodeStatus.slow,
    );
    await _storage.saveNode(updated);
  }
}

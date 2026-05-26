import 'package:dio/dio.dart';
import 'package:vpn_client/models/subscription.dart';
import 'package:vpn_client/models/proxy_node.dart';
import 'package:vpn_client/services/storage_service.dart';
import 'package:vpn_client/utils/link_parser.dart';

class SubscriptionService {
  final StorageService _storage;
  final Dio _dio;

  SubscriptionService(this._storage)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ));

  List<Subscription> getSubscriptions() => _storage.getSubscriptions();

  Future<void> addSubscription(Subscription sub) async {
    await _storage.saveSubscription(sub);
  }

  Future<void> removeSubscription(String id) async {
    await _storage.deleteSubscription(id);
  }

  /// Fetch and parse nodes from a subscription URL
  Future<List<ProxyNode>> fetchNodes(Subscription sub) async {
    final response = await _dio.get(sub.url);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch subscription: HTTP ${response.statusCode}');
    }

    final body = response.data is String
        ? response.data as String
        : response.data.toString();

    final nodes = LinkParser.parseSubscription(body);

    // Update subscription metadata
    final updated = sub.copyWith(
      nodeCount: nodes.length,
      lastUpdated: DateTime.now(),
    );
    await _storage.saveSubscription(updated);

    return nodes;
  }

  /// Update all subscriptions and return all nodes
  Future<List<ProxyNode>> updateAll() async {
    final subs = _storage.getSubscriptions();
    final allNodes = <ProxyNode>[];

    for (final sub in subs) {
      try {
        final nodes = await fetchNodes(sub);
        allNodes.addAll(nodes);
      } catch (_) {
        // Skip failed subscriptions
      }
    }

    if (allNodes.isNotEmpty) {
      await _storage.saveNodes(allNodes);
    }

    return allNodes;
  }
}

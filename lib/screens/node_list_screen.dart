import 'package:flutter/material.dart';
import 'package:vpn_client/models/proxy_node.dart';
import 'package:vpn_client/models/app_config.dart';
import 'package:vpn_client/services/node_service.dart';
import 'package:vpn_client/services/vpn_service.dart';
import 'package:vpn_client/screens/add_node_screen.dart';
import 'package:vpn_client/widgets/node_card.dart';

class NodeListScreen extends StatefulWidget {
  final NodeService nodeService;
  final VpnService vpnService;
  final AppConfig config;
  final ProxyNode? currentNode;
  final ValueChanged<ProxyNode> onNodeSelected;

  const NodeListScreen({
    super.key,
    required this.nodeService,
    required this.vpnService,
    required this.config,
    this.currentNode,
    required this.onNodeSelected,
  });

  @override
  State<NodeListScreen> createState() => _NodeListScreenState();
}

class _NodeListScreenState extends State<NodeListScreen> {
  List<ProxyNode> _nodes = [];
  String _searchQuery = '';
  bool _testingAll = false;
  bool _sortByLatency = false;

  @override
  void initState() {
    super.initState();
    _nodes = widget.nodeService.getNodes();
    // Auto sort favorites first
    _nodes.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return 0;
    });
  }

  List<ProxyNode> get _filteredNodes {
    if (_searchQuery.isEmpty) return _nodes;
    final q = _searchQuery.toLowerCase();
    return _nodes.where((n) {
      return n.name.toLowerCase().contains(q) ||
          n.address.toLowerCase().contains(q) ||
          (n.remarks?.toLowerCase().contains(q) ?? false) ||
          n.type.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNodes;
    final isConnected = widget.vpnService.state == VpnState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('节点列表', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Sort button
          IconButton(
            icon: Icon(
              _sortByLatency ? Icons.sort : Icons.sort_by_alpha,
              color: _sortByLatency
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: '按延迟排序',
            onPressed: () {
              setState(() {
                _sortByLatency = !_sortByLatency;
                if (_sortByLatency) {
                  _nodes.sort((a, b) => a.latency.compareTo(b.latency));
                } else {
                  _nodes.sort((a, b) => a.name.compareTo(b.name));
                }
              });
            },
          ),
          // Test all latency
          IconButton(
            icon: _testingAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed),
            tooltip: '测试全部延迟',
            onPressed: _testingAll ? null : _testAllLatency,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加节点',
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索节点...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Node count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '共 ${filtered.length} 个节点',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const Spacer(),
                if (isConnected)
                  const Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'VPN 已连接',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Node list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dns_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty ? '无匹配节点' : '暂无节点',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final node = filtered[index];
                      final isSelected =
                          widget.currentNode?.id == node.id;
                      return NodeCard(
                        node: node,
                        isSelected: isSelected,
                        onTap: () {
                          // Long press = select, short tap = connect
                          widget.onNodeSelected(node);
                          if (isConnected) {
                            widget.vpnService.disconnect().then((_) async {
                              await widget.nodeService.markUsed(node);
                              widget.vpnService.connect(
                                  node, widget.config);
                            });
                          } else {
                            widget.nodeService.markUsed(node).then((_) {
                              widget.vpnService.connect(
                                  node, widget.config);
                            });
                          }
                          Navigator.pop(context);
                        },
                        onFavorite: () {
                          widget.nodeService.toggleFavorite(node);
                          setState(() {
                            _nodes = widget.nodeService.getNodes();
                          });
                        },
                        onDelete: () => _confirmDelete(node),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNodeScreen(
          onSaved: (node) async {
            await widget.nodeService.addNode(node);
            setState(() {
              _nodes = widget.nodeService.getNodes();
            });
          },
        ),
      ),
    );
  }

  void _confirmDelete(ProxyNode node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除节点'),
        content: Text('确定删除 "${node.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              widget.nodeService.removeNode(node.id);
              setState(() => _nodes = widget.nodeService.getNodes());
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAllLatency() async {
    setState(() => _testingAll = true);
    for (final node in _nodes) {
      await widget.nodeService.updateLatency(node);
    }
    setState(() {
      _testingAll = false;
      _nodes = widget.nodeService.getNodes();
      if (_sortByLatency) {
        _nodes.sort((a, b) => a.latency.compareTo(b.latency));
      }
    });
  }
}

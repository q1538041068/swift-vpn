import 'package:flutter/material.dart';
import 'package:vpn_client/models/subscription.dart';
import 'package:vpn_client/services/subscription_service.dart';
import 'package:vpn_client/services/node_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final SubscriptionService subService;
  final NodeService nodeService;

  const SubscriptionScreen({
    super.key,
    required this.subService,
    required this.nodeService,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  List<Subscription> _subs = [];
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _subs = widget.subService.getSubscriptions();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('订阅管理', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _updating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '更新全部订阅',
            onPressed: _updating ? null : _updateAll,
          ),
        ],
      ),
      body: _subs.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _subs.length + 1, // +1 for add button
              itemBuilder: (context, index) {
                if (index == _subs.length) {
                  return _buildAddCard();
                }
                return _buildSubscriptionCard(_subs[index]);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rss_feed, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '暂无订阅',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加机场订阅链接，自动导入节点',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddDialog(),
            icon: const Icon(Icons.add),
            label: const Text('添加订阅'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(Subscription sub) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.rss_feed, color: Colors.deepPurple),
        ),
        title: Text(
          sub.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${sub.nodeCount} 个节点',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (sub.lastUpdated != null)
              Text(
                '更新于 ${_formatDate(sub.lastUpdated!)}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'update') _updateSub(sub);
            if (action == 'delete') _deleteSub(sub);
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'update', child: Text('更新')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCard() {
    return OutlinedButton.icon(
      onPressed: () => _showAddDialog(),
      icon: const Icon(Icons.add),
      label: const Text('添加订阅'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAddDialog() {
    _urlController.clear();
    _nameController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加订阅'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '如: 机场A',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '订阅链接',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              final url = _urlController.text.trim();
              if (name.isEmpty || url.isEmpty) return;

              Navigator.pop(ctx);

              final sub = Subscription(
                id: 'sub_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
                name: name,
                url: url,
              );

              await widget.subService.addSubscription(sub);

              setState(() {
                _subs = widget.subService.getSubscriptions();
              });

              // Fetch nodes immediately
              _updateSub(sub);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSub(Subscription sub) async {
    setState(() => _updating = true);
    try {
      final nodes = await widget.subService.fetchNodes(sub);
      // Save fetched nodes via NodeService
      await widget.nodeService.addNodes(nodes);
      // We need access to the actual StorageService to save nodes
      // In production, this would be properly wired via DI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新成功: 获取到 ${nodes.length} 个节点')),
        );
      }
      setState(() {
        _subs = widget.subService.getSubscriptions();
        _updating = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
      setState(() => _updating = false);
    }
  }

  Future<void> _updateAll() async {
    setState(() => _updating = true);
    try {
      final nodes = await widget.subService.updateAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('全部更新完成: 共 ${nodes.length} 个节点')),
        );
      }
    } catch (_) {}
    setState(() {
      _subs = widget.subService.getSubscriptions();
      _updating = false;
    });
  }

  void _deleteSub(Subscription sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除订阅'),
        content: Text('确定删除 "${sub.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await widget.subService.removeSubscription(sub.id);
              setState(() => _subs = widget.subService.getSubscriptions());
              if (mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import 'package:vpn_client/models/proxy_node.dart';
import 'package:vpn_client/services/vpn_service.dart';
import 'package:vpn_client/services/node_service.dart';
import 'package:vpn_client/services/subscription_service.dart';
import 'package:vpn_client/models/app_config.dart';
import 'package:vpn_client/widgets/connect_button.dart';
import 'package:vpn_client/widgets/traffic_chart.dart';
import 'package:vpn_client/screens/node_list_screen.dart';
import 'package:vpn_client/screens/subscription_screen.dart';
import 'package:vpn_client/screens/settings_screen.dart';
import 'package:vpn_client/screens/scan_screen.dart';

class HomeScreen extends StatefulWidget {
  final VpnService vpnService;
  final NodeService nodeService;
  final SubscriptionService subscriptionService;
  final AppConfig config;

  const HomeScreen({
    super.key,
    required this.vpnService,
    required this.nodeService,
    required this.subscriptionService,
    required this.config,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VpnState _vpnState = VpnState.disconnected;
  ProxyNode? _currentNode;

  @override
  void initState() {
    super.initState();
    _vpnState = widget.vpnService.state;
    _currentNode = widget.nodeService.getCurrentNode();
    widget.vpnService.stateStream.listen((state) {
      setState(() => _vpnState = state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              title: const Text(
                'SwiftVPN',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: '扫描二维码',
                  onPressed: () => _openScanner(context),
                ),
              ],
            ),
            // Connection status
            SliverToBoxAdapter(
              child: _buildConnectionSection(),
            ),
            // Current node info
            SliverToBoxAdapter(
              child: _buildCurrentNodeInfo(),
            ),
            // Traffic stats
            if (_vpnState == VpnState.connected)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TrafficChart(
                    statsStream: widget.vpnService.statsStream,
                  ),
                ),
              ),
            // Quick actions
            SliverToBoxAdapter(
              child: _buildQuickActions(),
            ),
            // Node count summary
            SliverToBoxAdapter(
              child: _buildStatsRow(),
            ),
            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection() {
    final statusText = switch (_vpnState) {
      VpnState.disconnected => '未连接',
      VpnState.connecting => '连接中...',
      VpnState.connected => '已连接',
      VpnState.disconnecting => '断开中...',
      VpnState.error => '连接失败',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          ConnectButton(
            state: _vpnState,
            onConnect: () async {
              if (_currentNode != null) {
                await widget.vpnService.connect(_currentNode!, widget.config);
                await widget.nodeService.markUsed(_currentNode!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先添加代理节点')),
                );
              }
            },
            onDisconnect: () => widget.vpnService.disconnect(),
          ),
          const SizedBox(height: 16),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _statusColor,
            ),
          ),
          if (_vpnState == VpnState.error && widget.vpnService.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.vpnService.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentNodeInfo() {
    if (_currentNode == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.cloud_off, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  '暂无节点',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '添加订阅或手动添加节点开始使用',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isConnected = _vpnState == VpnState.connected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isConnected ? Colors.green : Colors.grey)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isConnected ? Icons.shield : Icons.language,
                  color: isConnected ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentNode!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currentNode!.address}:${_currentNode!.port}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _currentNode!.displayLatency,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _latencyColor(_currentNode!.status),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _ActionCard(
              icon: Icons.dns,
              label: '节点列表',
              subtitle: '${widget.nodeService.getNodes().length} 个节点',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NodeListScreen(
                    nodeService: widget.nodeService,
                    vpnService: widget.vpnService,
                    config: widget.config,
                    currentNode: _currentNode,
                    onNodeSelected: (node) {
                      setState(() => _currentNode = node);
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.sync,
              label: '订阅管理',
              subtitle: '导入订阅链接',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubscriptionScreen(
                    subService: widget.subscriptionService,
                    nodeService: widget.nodeService,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              icon: Icons.settings,
              label: '设置',
              subtitle: '路由 · DNS',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(config: widget.config),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final nodes = widget.nodeService.getNodes();
    final onlineCount = nodes.where((n) => n.status == NodeStatus.ok).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatChip(label: '节点', value: '${nodes.length}'),
          const SizedBox(width: 16),
          _StatChip(label: '可用', value: '$onlineCount'),
          const SizedBox(width: 16),
          _StatChip(label: '延迟', value: _currentNode?.displayLatency ?? '--'),
        ],
      ),
    );
  }

  void _openScanner(BuildContext context) async {
    final node = await Navigator.push<ProxyNode>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          onScanned: (node) {
            widget.nodeService.addNode(node);
          },
        ),
      ),
    );
    if (node != null && mounted) {
      setState(() => _currentNode = node);
      // Auto-connect after scanning
      if (_vpnState == VpnState.connected) {
        await widget.vpnService.disconnect();
      }
      await widget.nodeService.markUsed(node);
      await widget.vpnService.connect(node, widget.config);
    }
  }

  Color get _statusColor {
    return switch (_vpnState) {
      VpnState.connected => const Color(0xFF4CAF50),
      VpnState.connecting => const Color(0xFFFFA726),
      VpnState.disconnecting => Colors.orange,
      VpnState.error => const Color(0xFFEF5350),
      VpnState.disconnected => Colors.grey,
    };
  }

  Color _latencyColor(NodeStatus status) {
    return switch (status) {
      NodeStatus.ok => const Color(0xFF4CAF50),
      NodeStatus.slow => const Color(0xFFFFA726),
      NodeStatus.timeout => const Color(0xFFEF5350),
      NodeStatus.unknown => Colors.grey,
    };
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

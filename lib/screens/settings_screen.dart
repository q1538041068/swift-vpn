import 'package:flutter/material.dart';
import 'package:vpn_client/models/app_config.dart';

class SettingsScreen extends StatefulWidget {
  final AppConfig config;

  const SettingsScreen({super.key, required this.config});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection settings
          _SectionHeader(title: '连接设置'),
          SwitchListTile(
            title: const Text('自动连接'),
            subtitle: const Text('应用启动时自动连接到上次使用的节点'),
            value: _config.autoConnect,
            onChanged: (v) => setState(() => _config = _config.copyWith(autoConnect: v)),
            secondary: const Icon(Icons.power),
          ),
          SwitchListTile(
            title: const Text('绕过局域网'),
            subtitle: const Text('VPN 不代理局域网流量'),
            value: _config.bypassLan,
            onChanged: (v) => setState(() => _config = _config.copyWith(bypassLan: v)),
            secondary: const Icon(Icons.router),
          ),
          SwitchListTile(
            title: const Text('连接通知'),
            subtitle: const Text('连接/断开时显示通知'),
            value: _config.notifyOnConnect,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(notifyOnConnect: v)),
            secondary: const Icon(Icons.notifications_outlined),
          ),
          const Divider(height: 32),

          // Routing
          _SectionHeader(title: '路由设置'),
          RadioListTile<String>(
            title: const Text('全局模式'),
            subtitle: const Text('所有流量通过代理'),
            value: 'global',
            groupValue: _config.routingMode,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(routingMode: v)),
            secondary: const Icon(Icons.public),
          ),
          RadioListTile<String>(
            title: const Text('代理模式（推荐）'),
            subtitle: const Text('仅代理被墙网站，国内直连'),
            value: 'proxy',
            groupValue: _config.routingMode,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(routingMode: v)),
            secondary: Icon(Icons.rule, color: Theme.of(context).colorScheme.primary),
          ),
          RadioListTile<String>(
            title: const Text('直连模式'),
            subtitle: const Text('所有流量直连，不通过代理'),
            value: 'direct',
            groupValue: _config.routingMode,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(routingMode: v)),
            secondary: const Icon(Icons.cable),
          ),
          const Divider(height: 32),

          // Port settings
          _SectionHeader(title: '端口设置'),
          ListTile(
            leading: const Icon(Icons.settings_ethernet),
            title: const Text('SOCKS5 端口'),
            subtitle: Text('${_config.socksPort}'),
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editPort(true),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.http),
            title: const Text('HTTP 代理端口'),
            subtitle: Text('${_config.httpPort}'),
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editPort(false),
            ),
          ),
          const Divider(height: 32),

          // Appearance
          _SectionHeader(title: '外观'),
          SwitchListTile(
            title: const Text('深色模式'),
            value: _config.darkMode,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(darkMode: v)),
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(height: 32),

          // About
          _SectionHeader(title: '关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('SwiftVPN'),
            subtitle: Text('版本 1.0.0'),
          ),
        ],
      ),
    );
  }

  void _editPort(bool isSocks) {
    final controller = TextEditingController(
      text: (isSocks ? _config.socksPort : _config.httpPort).toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改${isSocks ? "SOCKS5" : "HTTP"}端口'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '1024-65535',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final port = int.tryParse(controller.text);
              if (port != null && port >= 1024 && port <= 65535) {
                setState(() {
                  _config = isSocks
                      ? _config.copyWith(socksPort: port)
                      : _config.copyWith(httpPort: port);
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

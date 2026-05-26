import 'package:flutter/material.dart';
import 'package:vpn_client/models/proxy_node.dart';
import 'package:vpn_client/utils/link_parser.dart';

class AddNodeScreen extends StatefulWidget {
  final ValueChanged<ProxyNode> onSaved;

  const AddNodeScreen({super.key, required this.onSaved});

  @override
  State<AddNodeScreen> createState() => _AddNodeScreenState();
}

class _AddNodeScreenState extends State<AddNodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _portController = TextEditingController(text: '443');
  final _uuidController = TextEditingController();
  final _passwordController = TextEditingController();

  ProxyType _type = ProxyType.vmess;
  String _ssMethod = 'aes-256-gcm';
  String _vmessNetwork = 'tcp';
  String _vmessSecurity = 'auto';
  String _vmessTls = 'none';
  String _vmessPath = '/';
  String _vmessHost = '';
  int _alterId = 0;

  bool _showManual = false;

  final _ssMethods = [
    'aes-256-gcm', 'aes-128-gcm', 'chacha20-ietf-poly1305',
    'aes-256-cfb', 'aes-128-cfb', 'chacha20', 'rc4-md5',
  ];

  @override
  void dispose() {
    _linkController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _uuidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加节点', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick import via link
              TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  labelText: '快速导入',
                  hintText: '粘贴 ss:// 或 vmess:// 链接...',
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _parseLink,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('或手动填写', style: TextStyle(color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              // Protocol type selector
              SegmentedButton<ProxyType>(
                segments: const [
                  ButtonSegment(
                    value: ProxyType.vmess,
                    label: Text('VMess'),
                    icon: Icon(Icons.flash_on, size: 18),
                  ),
                  ButtonSegment(
                    value: ProxyType.shadowsocks,
                    label: Text('Shadowsocks'),
                    icon: Icon(Icons.cloud, size: 18),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() => _type = v.first),
              ),
              const SizedBox(height: 16),
              // Common fields
              TextFormField(
                controller: _nameController,
                decoration: _inputDeco('节点名称', Icons.label_outline),
                validator: (v) => v?.isEmpty == true ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _addressController,
                      decoration: _inputDeco('服务器地址', Icons.computer),
                      validator: (v) =>
                          v?.isEmpty == true ? '请输入地址' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _portController,
                      decoration: _inputDeco('端口', null),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? '端口' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Protocol-specific fields
              if (_type == ProxyType.vmess) ..._buildVMessFields(),
              if (_type == ProxyType.shadowsocks) ..._buildSSFields(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('保存节点'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildVMessFields() => [
        TextFormField(
          controller: _uuidController,
          decoration: _inputDeco('UUID (用户ID)', Icons.vpn_key),
          validator: (v) => v?.isEmpty == true ? '请输入UUID' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _vmessNetwork,
                decoration: _inputDeco('传输协议', Icons.settings_ethernet),
                items: ['tcp', 'ws', 'kcp', 'h2', 'quic', 'grpc']
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (v) => setState(() => _vmessNetwork = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _vmessSecurity,
                decoration: _inputDeco('加密', Icons.lock_outline),
                items: ['auto', 'aes-128-gcm', 'chacha20-poly1305', 'none']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _vmessSecurity = v!),
              ),
            ),
          ],
        ),
        if (_vmessNetwork == 'ws') ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _vmessPath,
            decoration: _inputDeco('路径 (path)', Icons.route),
            onChanged: (v) => _vmessPath = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _vmessHost,
            decoration: _inputDeco('Host (伪装域名)', Icons.dns),
            onChanged: (v) => _vmessHost = v,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _vmessTls,
                decoration: _inputDeco('TLS', Icons.security),
                items: ['none', 'tls']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _vmessTls = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: _alterId.toString(),
                decoration: _inputDeco('Alter ID', null),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    _alterId = int.tryParse(v) ?? 0,
              ),
            ),
          ],
        ),
      ];

  List<Widget> _buildSSFields() => [
        DropdownButtonFormField<String>(
          value: _ssMethod,
          decoration: _inputDeco('加密方式', Icons.lock_outline),
          items: _ssMethods
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) => setState(() => _ssMethod = v!),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          decoration: _inputDeco('密码', Icons.password),
          obscureText: true,
          validator: (v) => v?.isEmpty == true ? '请输入密码' : null,
        ),
      ];

  InputDecoration _inputDeco(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  void _parseLink() {
    final link = _linkController.text.trim();
    if (link.isEmpty) return;
    final node = LinkParser.parse(link);
    if (node == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法解析链接，请检查格式')),
      );
      return;
    }
    setState(() {
      _nameController.text = node.name;
      _addressController.text = node.address;
      _portController.text = node.port.toString();
      _type = node.type;
      if (node.type == ProxyType.vmess) {
        _uuidController.text = node.vmessUuid ?? '';
        _vmessNetwork = node.vmessNetwork ?? 'tcp';
        _vmessSecurity = node.vmessSecurity ?? 'auto';
        _vmessTls = node.vmessTls ?? 'none';
        _vmessPath = node.vmessPath ?? '/';
        _vmessHost = node.vmessHost ?? '';
        _alterId = node.vmessAlterId ?? 0;
      } else if (node.type == ProxyType.shadowsocks) {
        _passwordController.text = node.ssPassword ?? '';
        _ssMethod = node.ssMethod ?? 'aes-256-gcm';
      }
      _showManual = true;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final id = 'node_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final node = ProxyNode(
      id: id,
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 0,
      type: _type,
      ssMethod: _type == ProxyType.shadowsocks ? _ssMethod : null,
      ssPassword: _type == ProxyType.shadowsocks ? _passwordController.text : null,
      vmessUuid: _type == ProxyType.vmess ? _uuidController.text : null,
      vmessAlterId: _type == ProxyType.vmess ? _alterId : null,
      vmessSecurity: _type == ProxyType.vmess ? _vmessSecurity : null,
      vmessNetwork: _type == ProxyType.vmess ? _vmessNetwork : null,
      vmessPath: _type == ProxyType.vmess ? _vmessPath : null,
      vmessHost: _type == ProxyType.vmess ? _vmessHost : null,
      vmessTls: _type == ProxyType.vmess ? _vmessTls : null,
    );

    widget.onSaved(node);
    Navigator.pop(context);
  }
}

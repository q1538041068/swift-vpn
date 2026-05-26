import 'dart:convert';
import 'package:vpn_client/models/proxy_node.dart';

/// Parse ss://, ssr://, vmess://, trojan:// links into ProxyNode objects
class LinkParser {
  /// Try to parse any proxy link
  static ProxyNode? parse(String link) {
    link = link.trim();
    if (link.startsWith('ss://')) return _parseSS(link);
    if (link.startsWith('vmess://')) return _parseVMess(link);
    if (link.startsWith('trojan://')) return _parseTrojan(link);
    return null;
  }

  /// Parse all links from a base64-encoded subscription body or plain text
  static List<ProxyNode> parseSubscription(String body) {
    final nodes = <ProxyNode>[];
    // Try base64 decode first
    String decoded = body;
    try {
      decoded = utf8.decode(base64.decode(body.trim()));
    } catch (_) {
      decoded = body;
    }
    for (final line in decoded.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final node = parse(trimmed);
      if (node != null) nodes.add(node);
    }
    return nodes;
  }

  static ProxyNode? _parseSS(String link) {
    try {
      // Format: ss://base64(method:password)@host:port#name
      // or: ss://base64(method:password@host:port)#name
      final uri = Uri.tryParse(link);
      if (uri == null) return null;

      final name =
          uri.fragment.isNotEmpty ? Uri.decodeFull(uri.fragment) : 'SS Node';

      String host = '';
      int port = 0;
      String method = '';
      String password = '';

      // Decode userinfo
      if (uri.userInfo.isNotEmpty) {
        // SIP002 format: method:password@host:port
        final decoded = _safeBase64Decode(uri.userInfo);
        final parts = decoded.split(':');
        if (parts.length >= 2) {
          method = parts[0];
          password = parts.sublist(1).join(':');
        }
        host = uri.host;
        port = uri.port;
      } else {
        // Legacy format: entire authority is base64 encoded
        final decoded =
            _safeBase64Decode('${uri.host}${uri.hasPort ? ':${uri.port}' : ''}');
        final atIndex = decoded.lastIndexOf('@');
        if (atIndex == -1) return null;
        final userInfo = decoded.substring(0, atIndex);
        final serverInfo = decoded.substring(atIndex + 1);
        final userParts = userInfo.split(':');
        if (userParts.length < 2) return null;
        method = userParts[0];
        password = userParts.sublist(1).join(':');
        final serverParts = serverInfo.split(':');
        host = serverParts[0];
        port = serverParts.length > 1 ? int.tryParse(serverParts[1]) ?? 8388 : 8388;
      }

      return ProxyNode(
        id: _generateId(),
        name: name,
        address: host,
        port: port,
        type: ProxyType.shadowsocks,
        ssMethod: method,
        ssPassword: password,
      );
    } catch (_) {
      return null;
    }
  }

  static ProxyNode? _parseVMess(String link) {
    try {
      // Format: vmess://base64(json)
      final b64 = link.substring(8);
      final json = jsonDecode(_safeBase64Decode(b64)) as Map<String, dynamic>;

      return ProxyNode(
        id: _generateId(),
        name: json['ps'] as String? ?? 'VMess Node',
        address: json['add'] as String? ?? '',
        port: int.tryParse(json['port']?.toString() ?? '0') ?? 0,
        type: ProxyType.vmess,
        vmessUuid: json['id'] as String? ?? '',
        vmessAlterId: int.tryParse(json['aid']?.toString() ?? '0') ?? 0,
        vmessSecurity: json['scy'] as String? ?? 'auto',
        vmessNetwork: json['net'] as String? ?? 'tcp',
        vmessPath: json['path'] as String? ?? '/',
        vmessHost: json['host'] as String? ?? '',
        vmessTls: json['tls'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static ProxyNode? _parseTrojan(String link) {
    try {
      final uri = Uri.tryParse(link);
      if (uri == null) return null;

      final name =
          uri.fragment.isNotEmpty ? Uri.decodeFull(uri.fragment) : 'Trojan Node';

      return ProxyNode(
        id: _generateId(),
        name: name,
        address: uri.host,
        port: uri.port,
        type: ProxyType.trojan,
        ssPassword: uri.userInfo, // trojan password in userinfo
      );
    } catch (_) {
      return null;
    }
  }

  static String _safeBase64Decode(String input) {
    try {
      // Add padding if needed
      String padded = input;
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      return utf8.decode(base64.decode(padded));
    } catch (_) {
      return input;
    }
  }

  static String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final hash = now.toRadixString(36);
    return 'node_$hash';
  }
}

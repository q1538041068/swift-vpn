import 'dart:convert';

enum ProxyType { vmess, shadowsocks, socks, http, trojan }

enum NodeStatus { unknown, ok, slow, timeout }

class ProxyNode {
  final String id;
  String name;
  String address;
  int port;
  ProxyType type;

  // Shadowsocks fields
  String? ssMethod;
  String? ssPassword;

  // VMess fields
  String? vmessUuid;
  int? vmessAlterId;
  String? vmessSecurity;
  String? vmessNetwork;
  String? vmessPath;
  String? vmessHost;
  String? vmessTls;

  // Common
  String? remarks;
  int latency;
  NodeStatus status;
  bool isFavorite;
  DateTime createdAt;
  DateTime? lastUsedAt;

  ProxyNode({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.type,
    this.ssMethod,
    this.ssPassword,
    this.vmessUuid,
    this.vmessAlterId,
    this.vmessSecurity,
    this.vmessNetwork,
    this.vmessPath,
    this.vmessHost,
    this.vmessTls,
    this.remarks,
    this.latency = -1,
    this.status = NodeStatus.unknown,
    this.isFavorite = false,
    DateTime? createdAt,
    this.lastUsedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayLatency {
    if (latency < 0) return '--';
    if (latency >= 1000) return '${(latency / 1000).toStringAsFixed(1)}s';
    return '${latency}ms';
  }

  String get location {
    final lower = name.toLowerCase();
    for (final entry in _countryPatterns.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return '';
  }

  /// Build V2Ray JSON config string from this node
  String toV2RayConfig(int socksPort, int httpPort) {
    switch (type) {
      case ProxyType.vmess:
        return jsonEncode({
          'inbounds': [
            {
              'port': socksPort,
              'protocol': 'socks',
              'settings': {'auth': 'noauth', 'udp': true}
            },
            {
              'port': httpPort,
              'protocol': 'http',
              'settings': {'timeout': 360}
            }
          ],
          'outbounds': [
            {
              'protocol': 'vmess',
              'settings': {
                'vnext': [
                  {
                    'address': address,
                    'port': port,
                    'users': [
                      {
                        'id': vmessUuid ?? '',
                        'alterId': vmessAlterId ?? 0,
                        'security': vmessSecurity ?? 'auto'
                      }
                    ]
                  }
                ]
              },
              'streamSettings': {
                'network': vmessNetwork ?? 'tcp',
                if (vmessNetwork == 'ws') ...{
                  'wsSettings': {
                    'path': vmessPath ?? '/',
                    'headers': {'Host': vmessHost ?? address}
                  }
                },
                'security': (vmessTls == 'tls') ? 'tls' : 'none',
                if (vmessTls == 'tls') ...{
                  'tlsSettings': {'serverName': vmessHost ?? address}
                }
              }
            }
          ]
        });
      case ProxyType.shadowsocks:
        return jsonEncode({
          'inbounds': [
            {
              'port': socksPort,
              'protocol': 'socks',
              'settings': {'auth': 'noauth', 'udp': true}
            },
            {
              'port': httpPort,
              'protocol': 'http',
              'settings': {'timeout': 360}
            }
          ],
          'outbounds': [
            {
              'protocol': 'shadowsocks',
              'settings': {
                'servers': [
                  {
                    'address': address,
                    'port': port,
                    'method': ssMethod ?? 'aes-256-gcm',
                    'password': ssPassword ?? ''
                  }
                ]
              }
            }
          ]
        });
      default:
        return '{}';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'port': port,
        'type': type.name,
        'ssMethod': ssMethod,
        'ssPassword': ssPassword,
        'vmessUuid': vmessUuid,
        'vmessAlterId': vmessAlterId,
        'vmessSecurity': vmessSecurity,
        'vmessNetwork': vmessNetwork,
        'vmessPath': vmessPath,
        'vmessHost': vmessHost,
        'vmessTls': vmessTls,
        'remarks': remarks,
        'latency': latency,
        'isFavorite': isFavorite,
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  factory ProxyNode.fromJson(Map<String, dynamic> json) => ProxyNode(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        port: json['port'] as int,
        type: ProxyType.values.byName(json['type'] as String),
        ssMethod: json['ssMethod'] as String?,
        ssPassword: json['ssPassword'] as String?,
        vmessUuid: json['vmessUuid'] as String?,
        vmessAlterId: json['vmessAlterId'] as int?,
        vmessSecurity: json['vmessSecurity'] as String?,
        vmessNetwork: json['vmessNetwork'] as String?,
        vmessPath: json['vmessPath'] as String?,
        vmessHost: json['vmessHost'] as String?,
        vmessTls: json['vmessTls'] as String?,
        remarks: json['remarks'] as String?,
        latency: json['latency'] as int? ?? -1,
        isFavorite: json['isFavorite'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? ''),
      );

  ProxyNode copyWith({
    String? id,
    String? name,
    String? address,
    int? port,
    ProxyType? type,
    String? ssMethod,
    String? ssPassword,
    String? vmessUuid,
    int? vmessAlterId,
    String? vmessSecurity,
    String? vmessNetwork,
    String? vmessPath,
    String? vmessHost,
    String? vmessTls,
    String? remarks,
    int? latency,
    NodeStatus? status,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) =>
      ProxyNode(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        port: port ?? this.port,
        type: type ?? this.type,
        ssMethod: ssMethod ?? this.ssMethod,
        ssPassword: ssPassword ?? this.ssPassword,
        vmessUuid: vmessUuid ?? this.vmessUuid,
        vmessAlterId: vmessAlterId ?? this.vmessAlterId,
        vmessSecurity: vmessSecurity ?? this.vmessSecurity,
        vmessNetwork: vmessNetwork ?? this.vmessNetwork,
        vmessPath: vmessPath ?? this.vmessPath,
        vmessHost: vmessHost ?? this.vmessHost,
        vmessTls: vmessTls ?? this.vmessTls,
        remarks: remarks ?? this.remarks,
        latency: latency ?? this.latency,
        status: status ?? this.status,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );
}

const _countryPatterns = {
  '香港': 'HK',
  'hongkong': 'HK',
  'hk': 'HK',
  '台湾': 'TW',
  'taiwan': 'TW',
  'tw': 'TW',
  '日本': 'JP',
  'japan': 'JP',
  'jp': 'JP',
  '新加坡': 'SG',
  'singapore': 'SG',
  'sg': 'SG',
  '美国': 'US',
  'us': 'US',
  'usa': 'US',
  'united states': 'US',
  '韩国': 'KR',
  'korea': 'KR',
  'kr': 'KR',
  '德国': 'DE',
  'germany': 'DE',
  'de': 'DE',
  '英国': 'GB',
  'uk': 'GB',
  'gb': 'GB',
  'united kingdom': 'GB',
  '加拿大': 'CA',
  'canada': 'CA',
  'ca': 'CA',
  '澳大利亚': 'AU',
  'australia': 'AU',
  'au': 'AU',
};

class Subscription {
  final String id;
  String name;
  String url;
  int nodeCount;
  DateTime? lastUpdated;
  DateTime createdAt;
  bool autoUpdate;

  Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.nodeCount = 0,
    this.lastUpdated,
    DateTime? createdAt,
    this.autoUpdate = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'nodeCount': nodeCount,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'autoUpdate': autoUpdate,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        nodeCount: json['nodeCount'] as int? ?? 0,
        lastUpdated:
            DateTime.tryParse(json['lastUpdated'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        autoUpdate: json['autoUpdate'] as bool? ?? false,
      );

  Subscription copyWith({
    String? id,
    String? name,
    String? url,
    int? nodeCount,
    DateTime? lastUpdated,
    DateTime? createdAt,
    bool? autoUpdate,
  }) =>
      Subscription(
        id: id ?? this.id,
        name: name ?? this.name,
        url: url ?? this.url,
        nodeCount: nodeCount ?? this.nodeCount,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        createdAt: createdAt ?? this.createdAt,
        autoUpdate: autoUpdate ?? this.autoUpdate,
      );
}

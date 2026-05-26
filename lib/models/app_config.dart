class AppConfig {
  bool autoConnect;
  bool darkMode;
  bool bypassLan;
  bool notifyOnConnect;
  int socksPort;
  int httpPort;
  String routingMode; // 'global', 'proxy', 'direct'

  AppConfig({
    this.autoConnect = false,
    this.darkMode = true,
    this.bypassLan = true,
    this.notifyOnConnect = true,
    this.socksPort = 10808,
    this.httpPort = 10809,
    this.routingMode = 'proxy',
  });

  Map<String, dynamic> toJson() => {
        'autoConnect': autoConnect,
        'darkMode': darkMode,
        'bypassLan': bypassLan,
        'notifyOnConnect': notifyOnConnect,
        'socksPort': socksPort,
        'httpPort': httpPort,
        'routingMode': routingMode,
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        autoConnect: json['autoConnect'] as bool? ?? false,
        darkMode: json['darkMode'] as bool? ?? true,
        bypassLan: json['bypassLan'] as bool? ?? true,
        notifyOnConnect: json['notifyOnConnect'] as bool? ?? true,
        socksPort: json['socksPort'] as int? ?? 10808,
        httpPort: json['httpPort'] as int? ?? 10809,
        routingMode: json['routingMode'] as String? ?? 'proxy',
      );

  AppConfig copyWith({
    bool? autoConnect,
    bool? darkMode,
    bool? bypassLan,
    bool? notifyOnConnect,
    int? socksPort,
    int? httpPort,
    String? routingMode,
  }) =>
      AppConfig(
        autoConnect: autoConnect ?? this.autoConnect,
        darkMode: darkMode ?? this.darkMode,
        bypassLan: bypassLan ?? this.bypassLan,
        notifyOnConnect: notifyOnConnect ?? this.notifyOnConnect,
        socksPort: socksPort ?? this.socksPort,
        httpPort: httpPort ?? this.httpPort,
        routingMode: routingMode ?? this.routingMode,
      );
}

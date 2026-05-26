class AppConstants {
  AppConstants._();

  static const String appName = 'SwiftVPN';
  static const String appVersion = '1.0.0';

  // Storage keys
  static const String nodesBox = 'nodes';
  static const String subscriptionsBox = 'subscriptions';
  static const String configBox = 'config';
  static const String nodeKey = 'current_node';
  static const String autoConnectKey = 'auto_connect';
  static const String darkModeKey = 'dark_mode';

  // VPN
  static const String vpnChannel = 'com.vpnclient.app/vpn';
  static const int vpnIdleTimeout = 300;
  static const Duration connectTimeout = Duration(seconds: 15);

  // Default ports
  static const int defaultSocksPort = 10808;
  static const int defaultHttpPort = 10809;
}

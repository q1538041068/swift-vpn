import 'package:flutter/material.dart';
import 'package:vpn_client/services/storage_service.dart';
import 'package:vpn_client/services/node_service.dart';
import 'package:vpn_client/services/subscription_service.dart';
import 'package:vpn_client/services/vpn_service.dart';
import 'package:vpn_client/models/app_config.dart';
import 'package:vpn_client/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  final config = storage.getConfig();
  final nodeService = NodeService(storage);
  final subscriptionService = SubscriptionService(storage);
  final vpnService = VpnService(storage);

  runApp(SwiftVPNApp(
    storage: storage,
    nodeService: nodeService,
    subscriptionService: subscriptionService,
    vpnService: vpnService,
    config: config,
  ));
}

class SwiftVPNApp extends StatelessWidget {
  final StorageService storage;
  final NodeService nodeService;
  final SubscriptionService subscriptionService;
  final VpnService vpnService;
  final AppConfig config;

  const SwiftVPNApp({
    super.key,
    required this.storage,
    required this.nodeService,
    required this.subscriptionService,
    required this.vpnService,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwiftVPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6750A4),
        brightness: config.darkMode ? Brightness.dark : Brightness.light,
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          scrolledUnderElevation: 1,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6750A4),
        brightness: Brightness.dark,
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          scrolledUnderElevation: 1,
        ),
      ),
      themeMode: config.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        vpnService: vpnService,
        nodeService: nodeService,
        subscriptionService: subscriptionService,
        config: config,
      ),
    );
  }
}

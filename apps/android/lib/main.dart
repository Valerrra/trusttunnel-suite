import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/server_setup_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/split_tunnel_screen.dart';
import 'services/config_service.dart';
import 'services/locale_service.dart';
import 'services/server_setup_service.dart';
import 'services/vpn_service.dart';
import 'utils/localization_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrustyAndroidApp());
}

class TrustyAndroidApp extends StatelessWidget {
  const TrustyAndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ConfigService>(create: (_) => ConfigService()),
        ChangeNotifierProvider<LocaleService>(
          create: (context) => LocaleService(context.read<ConfigService>()),
        ),
        ChangeNotifierProvider<VpnService>(create: (_) => VpnService()),
        ChangeNotifierProvider<ServerSetupService>(
          create: (_) => ServerSetupService(),
        ),
      ],
      child: Consumer<LocaleService>(
        builder: (context, localeService, child) {
          return MaterialApp(
            title: 'Trusty Android',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: localeService.locale,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D6E6E),
                brightness: Brightness.light,
              ),
              appBarTheme: const AppBarTheme(centerTitle: false),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D6E6E),
                brightness: Brightness.dark,
              ),
              appBarTheme: const AppBarTheme(centerTitle: false),
            ),
            themeMode: ThemeMode.system,
            builder: (context, child) {
              L10n.init(AppLocalizations.of(context)!);
              return child!;
            },
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    SettingsScreen(),
    SplitTunnelScreen(),
    ServerSetupScreen(),
    LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final labels = [
      tr.navHome,
      tr.navSettings,
      tr.navSplitTunnel,
      tr.navServer,
      tr.navLogs,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(labels[_selectedIndex])),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: tr.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: tr.navSettings,
          ),
          NavigationDestination(
            icon: const Icon(Icons.route_outlined),
            selectedIcon: const Icon(Icons.route),
            label: tr.navSplitTunnel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.dns_outlined),
            selectedIcon: const Icon(Icons.dns),
            label: tr.navServer,
          ),
          NavigationDestination(
            icon: const Icon(Icons.article_outlined),
            selectedIcon: const Icon(Icons.article),
            label: tr.navLogs,
          ),
        ],
      ),
    );
  }
}

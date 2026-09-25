import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/app_provider.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'account_screen.dart';
import '../widgets/widgets.dart';

/// الهيكل الرئيسي — تنقل سفلي: الرئيسية · البحث · حسابي
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _watchConnectivity();
  }

  void _watchConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      final online = result.any((r) => r != ConnectivityResult.none);
      context.read<AppProvider>().setOnline(
            online ? OnlineStatus.online : OnlineStatus.offline,
          );
    });
  }

  final List<Widget> _pages = const [
    HomeScreen(),
    SearchScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _pages),
          // شريط التنبيه بعدم الاتصال
          if (app.isOffline)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: OfflineBanner(
                  lastSync: app.lastSync,
                  onRetry: () => app.sync(force: true),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.home),
            selectedIcon: Icon(LucideIcons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.search),
            selectedIcon: Icon(LucideIcons.search),
            label: 'البحث',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.user),
            selectedIcon: Icon(LucideIcons.user),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'config/theme.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // شريط الحالة بلون فاتح (التصميم أبيض)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // الاتجاه العمودي فقط
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const DalelApp());
}

class DalelApp extends StatelessWidget {
  const DalelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'دليل الدير',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),

        // ═══════════════ الاتجاه من اليمين لليسار ═══════════════
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        builder: (context, child) {
          // منع تكبير الخط من إعدادات الجهاز
          final mq = MediaQuery.of(context);
          final child2 = MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.noScaling),
            child: child!,
          );
          // فرض الاتجاه صراحةً — لا نعتمد على استنتاج الحزمة
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child2,
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}

/// مراقب الاتصال — يحدّث حالة التطبيق عند تبدّل الشبكة
class ConnectivityWatcher extends StatefulWidget {
  final Widget child;
  const ConnectivityWatcher({super.key, required this.child});

  @override
  State<ConnectivityWatcher> createState() => _ConnectivityWatcherState();
}

class _ConnectivityWatcherState extends State<ConnectivityWatcher> {
  @override
  void initState() {
    super.initState();
    _check();
    Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      final app = context.read<AppProvider>();
      final online = result.any((r) => r != ConnectivityResult.none);
      app.setOnline(online ? OnlineStatus.online : OnlineStatus.offline);
    });
  }

  Future<void> _check() async {
    final result = await Connectivity().checkConnectivity();
    if (!mounted) return;
    final online = result.any((r) => r != ConnectivityResult.none);
    context.read<AppProvider>().setOnline(
          online ? OnlineStatus.online : OnlineStatus.offline,
        );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

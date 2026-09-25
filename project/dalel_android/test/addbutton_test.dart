import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:lucide_icons/lucide_icons.dart';
import 'package:dalel/config/theme.dart';
import 'package:dalel/providers/app_provider.dart';
import 'package:dalel/providers/auth_provider.dart';
import 'package:dalel/screens/home_screen.dart';

/* ══════════════════════════════════════════════════════════════
 *  اختبارات زر «أضف خدمة» في الشريط العلوي
 * ══════════════════════════════════════════════════════════════ */

/// يبني التطبيق داخل بيئة RTL
Widget _shell() => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: HomeScreen(),
        ),
      ),
    );

void main() {
  testWidgets('زر «أضف خدمة» يظهر في الشريط العلوي للرئيسية',
      (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.text('أضف خدمة'), findsOneWidget,
        reason: 'يجب أن يظهر زر «أضف خدمة» في الشريط العلوي');
  });

  testWidgets('الزر يقع في منتصف الشريط عرضياً', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    final btn = tester.getCenter(find.text('أضف خدمة'));
    // مركز شاشة بعرض ٤٠٠ = ٢٠٠
    expect((btn.dx - 200).abs(), lessThan(60),
        reason: 'زر الإضافة يجب أن يكون قريباً من منتصف الشاشة (dx=${btn.dx})');
  });

  testWidgets('النقر على الزر يفتح نموذج إضافة خدمة', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('أضف خدمة'));
    await tester.pumpAndSettle();

    expect(find.text('أضف خدمة للدليل'), findsOneWidget,
        reason: 'النقر يجب أن يفتح شاشة طلب إضافة خدمة');
  });

  testWidgets('الشريط يحتوي زر التحديث أيضاً', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.refreshCw), findsOneWidget,
        reason: 'زر التحديث يجب أن يبقى في الشريط');
  });
}

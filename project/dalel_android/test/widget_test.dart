import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:dalel/main.dart';
import 'package:dalel/config/theme.dart';
import 'package:dalel/providers/app_provider.dart';
import 'package:dalel/providers/auth_provider.dart';

void main() {
  testWidgets('التطبيق يُقلع ويعرض شاشة البداية', (WidgetTester tester) async {
    await tester.pumpWidget(const DalelApp());
    await tester.pump();

    expect(find.text('دليل الدير'), findsOneWidget);
    expect(find.text('دليل الخدمات اليومية'), findsOneWidget);
  });

  testWidgets('عناصر الواجهة تُرسم باتجاه RTL فعلياً',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DalelApp());
    await tester.pump();

    // خذ سياق أي عنصر مرئي داخل المحتوى (وليس MaterialApp نفسه)
    final text = find.text('دليل الخدمات اليومية');
    expect(text, findsOneWidget);

    final ctx = tester.element(text);
    final dir = Directionality.of(ctx);

    // الاتجاه الفعلي الساري على المحتوى يجب أن يكون RTL
    expect(dir, TextDirection.rtl,
        reason: 'المحتوى يجب أن يُرسم من اليمين لليسار');
  });

  testWidgets('اللغة العربية والتوطين مضبوطان', (WidgetTester tester) async {
    await tester.pumpWidget(const DalelApp());
    await tester.pump();

    final ctx = tester.element(find.text('دليل الخدمات اليومية'));
    final locale = Localizations.maybeLocaleOf(ctx);

    expect(locale?.languageCode, 'ar');
  });

  testWidgets('ترتيب عناصر Row ينعكس: الأول يظهر على اليمين',
      (WidgetTester tester) async {
    // نبني صفاً داخل نفس بيئة التطبيق (RTL) ونقيس المواضع الفعلية
    await tester.pumpWidget(
      MultiProvider(
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
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Row(
                children: const [
                  SizedBox(key: Key('first'), width: 100, height: 20),
                  SizedBox(key: Key('second'), width: 100, height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final first = tester.getTopLeft(find.byKey(const Key('first')));
    final second = tester.getTopLeft(find.byKey(const Key('second')));

    // في RTL: العنصر الأول يبدأ من اليمين، أي إحداثياته أكبر من الثاني
    expect(first.dx > second.dx, isTrue,
        reason: 'في RTL يجب أن يكون العنصر الأول على يمين الثاني');
  });
}

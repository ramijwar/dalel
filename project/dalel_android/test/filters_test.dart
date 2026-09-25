import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:dalel/config/theme.dart';
import 'package:dalel/models/models.dart';
import 'package:dalel/providers/app_provider.dart';
import 'package:dalel/providers/auth_provider.dart';
import 'package:dalel/screens/section_screen.dart';

/* ══════════════════════════════════════════════════════════════
 *  اختبارات فلاتر شاشة القسم
 *
 *  الخللان المُصلَحان:
 *   ١) شريط النطاق (مدينة/ريف) كان يقارن _status ولا يضبط أي حالة
 *   ٢) عدّاد المحافظة كان يستخدم servicesCount العام (كل الخدمات)
 * ══════════════════════════════════════════════════════════════
 *
 *  البيانات: ٦ أطباء
 *    حلب    → ٣ مدينة (١،٢،٣) + ٢ ريف (٤،٥)  = ٥
 *    ريف حلب → ١ ريف (٦)                      = ١
 *
 *  ملاحظة: قسم الأطباء يعرض بطاقات تجميع بالاختصاص أولاً،
 *  وكل الخدمات بلا اختصاص تتجمّع في بطاقة «عام» بعدّادها.
 */

Service svc({
  required int id,
  required String name,
  int gov = 1,
  String zone = 'city',
}) =>
    Service.fromJson({
      'id': id,
      'name': name,
      'category_id': 38,
      'governorate_id': gov,
      'region_id': 700 + id,
      'region_name': 'منطقة $id',
      'region_zone': zone,
      'status': 'open',
      'status_label': 'تعمل الآن',
    });

Widget harness({
  required List<Service> services,
  required List<Governorate> governorates,
  required List<Category> categories,
}) {
  return MultiProvider(
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
        child: _Harness(
          services: services,
          governorates: governorates,
          categories: categories,
        ),
      ),
    ),
  );
}

class _Harness extends StatefulWidget {
  final List<Service> services;
  final List<Governorate> governorates;
  final List<Category> categories;

  const _Harness({
    required this.services,
    required this.governorates,
    required this.categories,
  });

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().debugInject(
          services: widget.services,
          governorates: widget.governorates,
          categories: widget.categories,
        );
  }

  @override
  Widget build(BuildContext context) => SectionScreen(
        category: widget.categories.firstWhere((c) => c.slug == 'doctors'),
      );
}

/// كل النصوص الظاهرة على الشاشة
List<String> texts(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data)
    .whereType<String>()
    .toList();

void main() {
  final governorates = [
    Governorate.fromJson({
      'id': 1,
      'name': 'حلب',
      'slug': 'aleppo',
      // العدّاد العام من الخادم — لا يخصّ الأطباء (هذا هو مصدر الخلل)
      'services_count': 489,
    }),
    Governorate.fromJson({
      'id': 2,
      'name': 'ريف حلب',
      'slug': 'aleppo-rural',
      'services_count': 34,
    }),
  ];

  final categories = [
    Category.fromJson({
      'id': 38,
      'slug': 'doctors',
      'name': 'أطباء مختصون',
      'layout': 'mini',
      'features': {'duty': false, 'schedule': true, 'status': true},
    }),
  ];

  final services = [
    svc(id: 1, name: 'د. الأول', gov: 1, zone: 'city'),
    svc(id: 2, name: 'د. الثاني', gov: 1, zone: 'city'),
    svc(id: 3, name: 'د. الثالث', gov: 1, zone: 'city'),
    svc(id: 4, name: 'د. الرابع', gov: 1, zone: 'rural'),
    svc(id: 5, name: 'د. الخامس', gov: 1, zone: 'rural'),
    svc(id: 6, name: 'د. السادس', gov: 2, zone: 'rural'),
  ];

  testWidgets('الشاشة تُقلع وتعرض كل أطباء القسم', (tester) async {
    await tester.pumpWidget(harness(
      services: services,
      governorates: governorates,
      categories: categories,
    ));
    await tester.pumpAndSettle();

    expect(find.text('أطباء مختصون'), findsWidgets);
    expect(find.text('الاختصاصات'), findsOneWidget);
    // بطاقة التجميع «عام» بعدّاد ٦
    expect(texts(tester), contains('6'));
  });

  testWidgets('شريط النطاق يظهر بعد اختيار محافظة', (tester) async {
    await tester.pumpWidget(harness(
      services: services,
      governorates: governorates,
      categories: categories,
    ));
    await tester.pumpAndSettle();

    // قبل اختيار محافظة: لا شريط نطاق
    expect(find.text('كل المناطق'), findsNothing);

    await tester.tap(find.text('حلب'));
    await tester.pumpAndSettle();

    // بعد الاختيار: يظهر شريط النطاق
    expect(find.text('كل المناطق'), findsOneWidget);
    expect(find.text('مدينة'), findsOneWidget);
    expect(find.text('ريف'), findsOneWidget);
  });

  testWidgets('الخلل ١: «ريف» يفلتر النتائج فعلياً', (tester) async {
    await tester.pumpWidget(harness(
      services: services,
      governorates: governorates,
      categories: categories,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حلب'));
    await tester.pumpAndSettle();
    // حلب = ٥ أطباء (٣ مدينة + ٢ ريف)
    expect(texts(tester), contains('5'));

    // اضغط «ريف»
    await tester.tap(find.text('ريف'));
    await tester.pumpAndSettle();

    // شريط الأدوات يجب أن يعرض ٢ (الرابع والخامس فقط)
    expect(find.text('2 تعمل الآن'), findsOneWidget,
        reason: 'ريف حلب يجب أن يعطي طبيبَين لا خمسة');
    // شريحة «حلب» تتقلّص من ٥ إلى ٢
    expect(find.text('5 تعمل الآن'), findsNothing,
        reason: 'العدّاد ٥ يجب أن يختفي بعد فلترة الريف');
  });

  testWidgets('الخلل ١: «مدينة» تعطي الثلاثة الآخرين', (tester) async {
    await tester.pumpWidget(harness(
      services: services,
      governorates: governorates,
      categories: categories,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حلب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مدينة'));
    await tester.pumpAndSettle();

    expect(find.text('3 تعمل الآن'), findsOneWidget,
        reason: 'مدينة حلب يجب أن تعطي ثلاثة أطباء');
  });

  testWidgets('الخلل ١: النقر مرة أخرى يلغي الفلتر', (tester) async {
    await tester.pumpWidget(harness(
      services: services,
      governorates: governorates,
      categories: categories,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حلب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ريف'));
    await tester.pumpAndSettle();
    expect(find.text('2 تعمل الآن'), findsOneWidget);

    // أعد النقر لإلغاء التحديد
    await tester.tap(find.text('ريف'));
    await tester.pumpAndSettle();

    expect(find.text('5 تعمل الآن'), findsOneWidget,
        reason: 'إلغاء فلتر الريف يعيد كل أطباء حلب (٥)');
  });

  testWidgets('الخلل ٢: عدّاد المحافظة يخصّ القسم لا كل الخدمات',
      (tester) async {
    await tester.pumpWidget(harness(
      services: services,
      governorates: governorates,
      categories: categories,
    ));
    await tester.pumpAndSettle();

    final t = texts(tester);

    expect(t, contains('5'),
        reason: 'شريحة حلب يجب أن تُظهر ٥ (أطباء حلب فقط)');
    expect(t, contains('1'),
        reason: 'شريحة ريف حلب يجب أن تُظهر ١ (طبيب واحد)');

    // العدّاد العام القديم يجب ألا يظهر
    expect(t, isNot(contains('489')),
        reason: 'يجب ألا يظهر ٤٨٩ (كل خدمات حلب) — هذا هو الخلل المُصلَح');
    expect(t, isNot(contains('34')),
        reason: 'يجب ألا يظهر ٣٤ (كل خدمات ريف حلب)');
  });

  testWidgets('الخلل ٢: العدّاد يتغيّر مع النطاق المختار', (tester) async {
    await tester.pumpWidget(harness(
      services: services,
      governorates: governorates,
      categories: categories,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حلب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ريف'));
    await tester.pumpAndSettle();

    // بعد اختيار الريف: شريحة «مدينة» تعرض ٣ و«ريف» تعرض ٢
    // (العدّادان محسوبان ضمن المحافظة المختارة)
    final t = texts(tester);
    expect(t, contains('2'));
    expect(t, contains('3'));
    expect(t, isNot(contains('489')));
  });

  test('نموذج الخدمة يحمل نطاق المنطقة', () {
    expect(svc(id: 9, name: 'x', zone: 'rural').regionZone, 'rural');
    expect(svc(id: 9, name: 'x', zone: 'city').regionZone, 'city');
  });

  test('المحافظة تحتفظ بعدّادها العام لكن الواجهة لا تستخدمه', () {
    final g = Governorate.fromJson({
      'id': 1,
      'name': 'حلب',
      'services_count': 489,
    });
    expect(g.servicesCount, 489);
  });
}

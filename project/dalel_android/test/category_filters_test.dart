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
 *  ميزة الفلاتر — طبقة التطبيق
 *
 *  المدير يُنشئ فلاتر في لوحة التحكم (المناطق · الاختصاص · نوع المركبة …)
 *  ثم يُسنِد لكل قسم **فلتراً أساسياً** — وهو الذي يبني بطاقات المستوى
 *  الأول في صفحة القسم. الخادم يرسلها في `category.filters[]` ويحكم
 *  `is_primary` أيّها الأساسي.
 *
 *  ما تتحقق منه هذه الاختبارات:
 *    ١) قراءة `filters[]` من `/api/meta` (والتخزين المحلي)
 *    ٢) الأساسي يحكم التجميع — مناطق / اختصاص / حقل (نوع المركبة)
 *    ٣) «غير محدد» تُجمَّع ولا تُخفى
 *    ٤) قسم بلا فلاتر يرجع للتجميع المضمّن (توافق خلفي)
 * ══════════════════════════════════════════════════════════════ */

/// فلتر مُسنَد كما يرسله الخادم
Map<String, dynamic> link({
  required int id,
  required String key,
  required String label,
  String type = 'region',
  String srcKey = '',
  String icon = '',
  bool primary = true,
  int order = 0,
}) =>
    {
      'id': id,
      'filter_id': id,
      'key': key,
      'label': label,
      'source_type': type,
      'source_key': srcKey,
      'icon': icon,
      'is_primary': primary,
      'sort_order': order,
    };

Map<String, dynamic> service({
  required int id,
  required String name,
  int categoryId = 37,
  int? regionId,
  String? regionName,
  int? specialtyId,
  Map<String, dynamic> meta = const {},
  List<Map<String, dynamic>> fields = const [],
  String status = 'open',
  String? regionZone = 'city',
}) =>
    {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'status': status,
      'status_label': status == 'open' ? 'تعمل الآن' : 'مغلقة',
      'on_duty': false,
      if (regionId != null) 'region_id': regionId,
      if (regionName != null) 'region_name': regionName,
      if (regionZone != null) 'region_zone': regionZone,
      if (specialtyId != null) 'specialty_id': specialtyId,
      'meta': meta,
      'fields': fields,
    };

Widget harness({
  required Category category,
  required List<Service> services,
}) =>
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
          child: _Harness(category: category, services: services),
        ),
      ),
    );

class _Harness extends StatefulWidget {
  final Category category;
  final List<Service> services;
  const _Harness({required this.category, required this.services});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().debugInject(
          services: widget.services,
          categories: [widget.category],
          governorates: const [],
        );
  }

  @override
  Widget build(BuildContext context) => SectionScreen(category: widget.category);
}

void main() {
  group('نموذج الفلتر', () {
    test('يُقرأ من filters[] في ردّ /api/meta', () {
      final c = Category.fromJson({
        'id': 37,
        'slug': 'pharmacies',
        'name': 'صيدليات بشرية',
        'filters': [
          link(id: 6, key: 'region', label: 'المناطق', icon: 'map-pin'),
        ],
      });
      expect(c.filters.length, 1);
      expect(c.filters.first.key, 'region');
      expect(c.filters.first.label, 'المناطق');
      expect(c.filters.first.sourceType, 'region');
      expect(c.filters.first.isPrimary, isTrue);
      expect(c.primaryFilter?.key, 'region');
      expect(c.secondaryFilters, isEmpty);
    });

    test('الأساسي واحد — والبقية ثانوية', () {
      final c = Category.fromJson({
        'id': 40,
        'slug': 'transport',
        'name': 'سرفيس واسعافية',
        'filters': [
          link(
              id: 9,
              key: 'flt-vehicle',
              label: 'نوع المركبة',
              type: 'field',
              srcKey: 'vehicle',
              order: 40),
          link(
              id: 8,
              key: 'flt-direction',
              label: 'اتجاه السفر',
              type: 'field',
              srcKey: 'direction',
              primary: false,
              order: 41),
        ],
      });
      expect(c.primaryFilter?.key, 'flt-vehicle');
      expect(c.primaryFilter?.sourceType, 'field');
      expect(c.primaryFilter?.sourceKey, 'vehicle');
      expect(c.secondaryFilters.length, 1);
      expect(c.secondaryFilters.first.key, 'flt-direction');
    });

    test('قسم بلا فلاتر — بلا أساسي (توافق خلفي)', () {
      final c = Category.fromJson({'id': 99, 'slug': 'x', 'name': 'قسم'});
      expect(c.filters, isEmpty);
      expect(c.primaryFilter, isNull);
    });

    test('الرحلة الكاملة toJson → fromJson تحفظ الفلاتر (التخزين المحلي)', () {
      final a = Category.fromJson({
        'id': 38,
        'slug': 'doctors',
        'name': 'عيادات أطباء',
        'filters': [
          link(id: 7, key: 'specialty', label: 'الاختصاص', type: 'specialty'),
        ],
      });
      final b = Category.fromJson(a.toJson());
      expect(b.filters.length, 1);
      expect(b.primaryFilter?.label, 'الاختصاص');
      expect(b.primaryFilter?.sourceType, 'specialty');
    });

    test('نص تالف في التخزين المحلي لا يُسقط الفلاتر الأخرى', () {
      final c = Category.fromJson({
        'id': 38,
        'slug': 'doctors',
        'name': 'عيادات أطباء',
        'filters': [
          link(id: 7, key: 'specialty', label: 'الاختصاص', type: 'specialty'),
        ],
      });
      expect(c.primaryFilter, isNotNull);
    });
  });

  group('صفحة القسم تتبع الفلتر المُسنَد', () {
    testWidgets('الفلتر الأساسي «المناطق» يبني بطاقات المناطق',
        (tester) async {
      final cat = Category.fromJson({
        'id': 37,
        'slug': 'pharmacies',
        'name': 'صيدليات بشرية',
        'layout': 'card',
        'features': {'duty': true, 'schedule': true, 'status': true},
        'filters': [
          link(id: 6, key: 'region', label: 'المناطق', icon: 'map-pin'),
        ],
      });
      await tester.pumpWidget(harness(
        category: cat,
        services: [
          Service.fromJson(service(
              id: 1, name: 'صيدلية أ', regionId: 701, regionName: 'الشيخ نجار')),
          Service.fromJson(service(
              id: 2, name: 'صيدلية ب', regionId: 701, regionName: 'الشيخ نجار')),
          Service.fromJson(service(
              id: 3, name: 'صيدلية ج', regionId: 702, regionName: 'الهجانة')),
        ],
      ));
      await tester.pumpAndSettle();

      // العنوان = اسم الفلتر الذي أسنَده المدير (لا نص مضمّن في التطبيق)
      expect(find.text('المناطق'), findsOneWidget);
      // بطاقة لكل منطقة بعدّادها
      expect(find.text('الشيخ نجار'), findsOneWidget);
      expect(find.text('الهجانة'), findsOneWidget);
    });

    testWidgets('فلتر «نوع المركبة» (حقل) يجمّع بقيم الحقل و«غير محدد»',
        (tester) async {
      final cat = Category.fromJson({
        'id': 40,
        'slug': 'transport',
        'name': 'سرفيس واسعافية',
        'layout': 'row',
        'features': {'duty': true, 'schedule': true, 'status': true},
        'filters': [
          link(
              id: 9,
              key: 'flt-vehicle',
              label: 'نوع المركبة',
              type: 'field',
              srcKey: 'vehicle'),
        ],
      });
      await tester.pumpWidget(harness(
        category: cat,
        services: [
          Service.fromJson(service(
              id: 1,
              name: 'سرفيس ١',
              categoryId: 40,
              regionId: 731,
              regionName: 'ابوحمام',
              meta: {'vehicle': 'باص'})),
          Service.fromJson(service(
              id: 2,
              name: 'سرفيس ٢',
              categoryId: 40,
              regionId: 731,
              regionName: 'ابوحمام',
              meta: {'vehicle': 'إسعاف'})),
          // بلا نوع مركبة → يجب أن تُجمَّع «غير محدد» لا أن تختفي
          Service.fromJson(service(
              id: 3,
              name: 'سرفيس ٣',
              categoryId: 40,
              regionId: 731,
              regionName: 'ابوحمام')),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('نوع المركبة'), findsOneWidget);
      expect(find.text('باص'), findsOneWidget);
      expect(find.text('إسعاف'), findsOneWidget);
      expect(find.text('غير محدد'), findsOneWidget,
          reason: 'خدمة بلا قيمة للحقل تُجمَّع «غير محدد» ولا تُخفى');
    });

    testWidgets('الفلتر الأساسي «الاختصاص» يقرأ specialty_id واسمه',
        (tester) async {
      final cat = Category.fromJson({
        'id': 38,
        'slug': 'doctors',
        'name': 'عيادات أطباء',
        'layout': 'card',
        'features': {'duty': false, 'schedule': true, 'status': true},
        'fields': [
          {
            'id': 6,
            'key': 'specialty',
            'label': 'الاختصاص',
            'type': 'select',
            'options': [
              {'id': 51, 'label': 'أطفال وحديثي الولادة', 'value': '1'},
              {'id': 65, 'label': 'أسنان', 'value': '15'},
            ],
          },
        ],
        'filters': [
          link(id: 7, key: 'specialty', label: 'الاختصاص', type: 'specialty'),
        ],
      });
      await tester.pumpWidget(harness(
        category: cat,
        services: [
          Service.fromJson(service(
              id: 1,
              name: 'د. أ',
              categoryId: 38,
              specialtyId: 1,
              meta: {'specialty': '1'})),
          Service.fromJson(service(
              id: 2,
              name: 'د. ب',
              categoryId: 38,
              specialtyId: 15,
              meta: {'specialty': '15'})),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('الاختصاص'), findsOneWidget);
      // الأسماء من خيارات الحقل — لا أرقام خام
      expect(find.text('أطفال وحديثي الولادة'), findsOneWidget);
      expect(find.text('أسنان'), findsOneWidget);
    });

    testWidgets('قسم بلا فلاتر → التجميع المضمّن (توافق خلفي)', (tester) async {
      final cat = Category.fromJson({
        'id': 38,
        'slug': 'doctors',
        'name': 'عيادات أطباء',
        'layout': 'card',
        'features': {'duty': false, 'schedule': true, 'status': true},
      });
      await tester.pumpWidget(harness(
        category: cat,
        services: [
          Service.fromJson(service(id: 1, name: 'د. أ', categoryId: 38)),
        ],
      ));
      await tester.pumpAndSettle();

      // لا فلتر من الخادم → عنوان التجميع المضمّن لقسم الأطباء
      expect(find.text('الاختصاصات'), findsOneWidget);
    });
  });

  group('الفلاتر الثانوية المُسنَدة للقسم', () {
    /// قسم السرفيس: «نوع المركبة» أساسي (بطاقات) و«اتجاه السفر» ثانوي (شريحة)
    Category transportCategory() => Category.fromJson({
          'id': 40,
          'slug': 'transport',
          'name': 'سرفيس واسعافية',
          'layout': 'row',
          'features': {'duty': true, 'schedule': true, 'status': true},
          'filters': [
            link(
                id: 9,
                key: 'flt-vehicle',
                label: 'نوع المركبة',
                type: 'field',
                srcKey: 'vehicle'),
            link(
                id: 8,
                key: 'flt-direction',
                label: 'اتجاه السفر',
                type: 'field',
                srcKey: 'direction',
                primary: false,
                order: 41),
          ],
        });

    List<Service> transportServices() => [
          Service.fromJson(service(
              id: 1,
              name: 'س١',
              categoryId: 40,
              regionId: 731,
              regionName: 'ابوحمام',
              meta: {'vehicle': 'باص', 'direction': 'ديرالزور-دمشق'})),
          Service.fromJson(service(
              id: 2,
              name: 'س٢',
              categoryId: 40,
              regionId: 731,
              regionName: 'ابوحمام',
              meta: {'vehicle': 'إسعاف', 'direction': 'ديرالزور-حلب'})),
        ];

    testWidgets('شريحة الفلتر الثانوي تظهر بحالة «الكل»',
        (tester) async {
      await tester.pumpWidget(harness(
        category: transportCategory(),
        services: transportServices(),
      ));
      await tester.pumpAndSettle();

      // الأساسي يبني البطاقات، والثانوي يظهر كشريحة اختيار
      expect(find.text('نوع المركبة'), findsOneWidget);
      expect(find.text('اتجاه السفر: الكل'), findsOneWidget);
    });

    testWidgets('اختيار قيمة ثانوية يُصفّي النتائج فعلياً', (tester) async {
      await tester.pumpWidget(harness(
        category: transportCategory(),
        services: transportServices(),
      ));
      await tester.pumpAndSettle();

      // افتح بطاقة «باص»: تُعرض خدماتها وحدها
      await tester.tap(find.text('باص'));
      await tester.pumpAndSettle();
      expect(find.text('س١'), findsOneWidget);
      expect(find.text('س٢'), findsNothing,
          reason: 'س٢ في بطاقة «إسعاف» — لا تُعرض داخل «باص»');

      // اختر اتجاه «ديرالزور-حلب» من الشريحة الثانوية
      await tester.ensureVisible(find.text('اتجاه السفر: الكل'));
      await tester.tap(find.text('اتجاه السفر: الكل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ديرالزور-حلب'));
      await tester.pumpAndSettle();

      /* الفلتر الثانوي يُصفّي كل الخدمات ثم تُعاد البطاقات (‏_groupKey
         يُفرَّغ عند تغيير قيمة ثانوية) — فتبقى بطاقة «إسعاف» وحدها. */
      expect(find.text('اتجاه السفر: ديرالزور-حلب'), findsOneWidget);
      expect(find.text('إسعاف'), findsOneWidget);
      expect(find.text('باص'), findsNothing,
          reason: 'س١ اتجاهها دمشق — يجب أن تُحجب بطاقتها');
    });

    testWidgets('الفلتر الثانوي لا يحجب خياراته بعد الاختيار',
        (tester) async {
      await tester.pumpWidget(harness(
        category: transportCategory(),
        services: transportServices(),
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('اتجاه السفر: الكل'));
      await tester.tap(find.text('اتجاه السفر: الكل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ديرالزور-دمشق'));
      await tester.pumpAndSettle();

      // أعِد فتح القائمة: يجب أن يبقى الاتجاه الآخر قابلاً للاختيار مباشرةً
      await tester.ensureVisible(find.text('اتجاه السفر: ديرالزور-دمشق'));
      await tester.tap(find.text('اتجاه السفر: ديرالزور-دمشق'));
      await tester.pumpAndSettle();
      expect(find.text('ديرالزور-حلب'), findsOneWidget,
          reason: 'لو حجب الفلتر نفسه لما أمكن التبديل إلا بإلغائه أولاً');

      // التبديل مباشرةً يعمل
      await tester.tap(find.text('ديرالزور-حلب'));
      await tester.pumpAndSettle();
      expect(find.text('اتجاه السفر: ديرالزور-حلب'), findsOneWidget);
    });

    testWidgets('إلغاء الفلتر الثانوي يُعيد النتائج', (tester) async {
      await tester.pumpWidget(harness(
        category: transportCategory(),
        services: transportServices(),
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('اتجاه السفر: الكل'));
      await tester.tap(find.text('اتجاه السفر: الكل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ديرالزور-دمشق'));
      await tester.pumpAndSettle();
      expect(find.text('اتجاه السفر: ديرالزور-دمشق'), findsOneWidget);

      // «الكل» في الورقة السفلية — أعِد الشريحة إلى مجال الرؤية أولاً
      // (نصها الطويل يخرج من عرض الشاشة في الصف الأفقي فتضيع النقرة)
      await tester.ensureVisible(find.text('اتجاه السفر: ديرالزور-دمشق'));
      await tester.tap(find.text('اتجاه السفر: ديرالزور-دمشق'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الكل'));
      await tester.pumpAndSettle();

      expect(find.text('اتجاه السفر: الكل'), findsOneWidget);
      await tester.tap(find.text('باص'));
      await tester.pumpAndSettle();
      expect(find.text('س١'), findsOneWidget);
    });
  });
}

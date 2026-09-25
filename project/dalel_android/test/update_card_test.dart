import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalel/config/theme.dart';
import 'package:dalel/models/models.dart';
import 'package:dalel/services/update_service.dart';
import 'package:dalel/widgets/update_card.dart';

/* ══════════════════════════════════════════════════════════════
 *  شريط تحديث التطبيق — الشكل والمنطق
 *
 *  الشكوى: «ظهرت بطاقة طلب التحديث لكن لا يوجد زر تنزيل، والبطاقة
 *  كبيرة جداً». السبب: البطاقة كانت رأسية (ترويسة + صندوق «ما الجديد»
 *  بعدة أسطر + زرّان بعرض الشاشة) فتشغل نصف الشاشة وتدفع زر التنزيل
 *  إلى ما تحت مجال الرؤية.
 *
 *  هذه الاختبارات تثبّت المطلوب:
 *    ١) الشريط قصير وبارتفاع ثابت (لا «مربّع كبير»)
 *    ٢) زر الإجراء حاضر دائماً في مكانه — في كل مرحلة
 *    ٣) الضغط على «تنزيل» موصول فعلاً بالخدمة (لا زر صامت)
 *    ٤) «ما الجديد» في ورقة سفلية، فلا يُطيل الشريط
 *    ٥) «لاحقاً» تُخفي الشريط، والتحديث الإلزامي لا يُخفى
 * ══════════════════════════════════════════════════════════════ */

const int _mb = 1024 * 1024;

AppUpdate _update({
  String name = '1.3.0',
  int code = 5,
  String notes = '',
  bool force = false,
  String url = 'https://example.com/dalel.apk',
  int size = 12 * _mb,
}) =>
    AppUpdate(
      versionName: name,
      versionCode: code,
      notes: notes,
      force: force,
      url: url,
      size: size,
      sha256: '',
      publishedAt: DateTime(2026, 9, 25),
    );

/// سطح هاتف حقيقي (٣٦٠×٨٠٠ نقطة منطقية) — نفس ما يراه المستخدم،
/// فقياسات الشريط والمعروض من النص تُقاس على العرض الفعلي لا على سطح الاختبار.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// هيئة الاختبار: نفس سياق التطبيق (RTL + ثيم دليل الدير) داخل تمرير عمودي.
Widget _host(UpdateService s) => MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          body: SingleChildScrollView(
            child: UpdateCard(service: s),
          ),
        ),
      ),
    );

/// ارتفاع الشريط الفعلي — مقياس «كبيرة جداً» مقابل «شريط».
double _h(WidgetTester t) => t.getSize(find.byType(UpdateCard)).height;

/// زرٌّ بنصّه — `find.byType(FilledButton)` لا يكفي: `FilledButton.icon`
/// يُنشئ صنفاً فرعياً (`_FilledButtonWithIcon`)، والمطابقة بالنوع دقيقة.
Finder _button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );

void main() {
  group('شكل الشريط', () {
    testWidgets('متاح: قصير، وزر «تنزيل» ظاهر فيه', (tester) async {
      final s = UpdateService.forTest()
        ..debugSet(update: _update(), phase: UpdatePhase.available);
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();

      expect(find.text('يتوفر إصدار جديد 1.3.0'), findsOneWidget);
      // الإجراء الأساسي موجود — هذه بالضبط الشكوى التي أُصلحت
      expect(_button('تنزيل'), findsOneWidget,
          reason: 'زر التنزيل يجب أن يكون ظاهراً في الشريط نفسه');
      // ومعه تفاصيل الإصدار في سطر ثانٍ
      expect(find.textContaining('12.0 ميغا'), findsOneWidget);

      expect(_h(tester), lessThanOrEqualTo(72),
          reason: 'الشريط لا يتجاوز ~٧٢ نقطة — لا مربّعاً كبيراً');
    });

    testWidgets('يُعرض في صفٍّ واحد بعرض الشاشة كاملاً', (tester) async {
      final s = UpdateService.forTest()
        ..debugSet(update: _update(), phase: UpdatePhase.available);
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();

      final w = tester.getSize(find.byType(UpdateCard)).width;
      expect(w, lessThanOrEqualTo(360.0));
      // زر التنزيل وترويسة الشريط على السطر نفسه (فرق المراكز أقل من ارتفاع سطر)
      final btn = tester.getCenter(_button('تنزيل'));
      final title = tester.getCenter(find.text('يتوفر إصدار جديد 1.3.0'));
      expect((btn.dy - title.dy).abs(), lessThan(24),
          reason: 'الزر والعنوان في صفٍّ واحد — لا زر تحت المحتوى');
    });

    testWidgets('لا تحديث → لا شريط إطلاقاً', (tester) async {
      final s = UpdateService.forTest()..debugSet(clearUpdate: true);
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.getSize(find.byType(UpdateCard)).height, 0);
    });
  });

  group('زر الإجراء يتبع المرحلة في مكانه', () {
    testWidgets('أثناء التنزيل: نسبة + إلغاء + شريط تقدّم رقيق', (tester) async {
      final s = UpdateService.forTest()
        ..debugSet(
          update: _update(),
          phase: UpdatePhase.downloading,
          progress: 0.42,
          received: 5 * _mb,
          total: 12 * _mb,
          speed: 1.5 * _mb,
        );
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();

      expect(find.text('يُنزَّل التحديث 42%'), findsOneWidget);
      expect(_button('إلغاء'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('م.ب/ث'), findsOneWidget);
      // يبقى شريطاً رفيعاً أثناء التنزيل أيضاً
      expect(_h(tester), lessThanOrEqualTo(80));
    });

    testWidgets('بعد اكتمال التنزيل: زر «تثبيت»', (tester) async {
      final s = UpdateService.forTest()
        ..debugSet(
          update: _update(),
          phase: UpdatePhase.downloaded,
          progress: 1,
          received: 12 * _mb,
          total: 12 * _mb,
        );
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();

      expect(find.text('التحديث جاهز للتثبيت'), findsOneWidget);
      expect(_button('تثبيت'), findsOneWidget);
      expect(_h(tester), lessThanOrEqualTo(72));
    });

    testWidgets('فشل: السبب في السطر الثاني وزر «إعادة»', (tester) async {
      final s = UpdateService.forTest()
        ..debugSet(
          update: _update(),
          phase: UpdatePhase.failed,
          error: 'تعذّر التنزيل (رمز 404)',
        );
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();

      expect(find.text('تعذّر التحديث'), findsOneWidget);
      expect(find.textContaining('تعذّر التنزيل (رمز 404)'), findsOneWidget);
      expect(_button('إعادة'), findsOneWidget);
    });
  });

  group('المنطق', () {
    testWidgets('الضغط على «تنزيل» موصول بالخدمة فعلاً', (tester) async {
      final s = UpdateService.forTest()
        ..debugSet(update: _update(), phase: UpdatePhase.available);
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();

      await tester.tap(_button('تنزيل'));
      // تنتقل الحالة فوراً إلى «يُنزَّل» — دليل أن الزر ليس صامتاً
      await tester.pump();
      expect(s.phase, UpdatePhase.downloading);

      // ثم تفشل محاولة الشبكة في بيئة الاختبار (لا تخزين مؤقّت/لا شبكة)
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(s.phase, UpdatePhase.failed);
      expect(_button('إعادة'), findsOneWidget,
          reason: 'بعد الفشل يعرض الشريط «إعادة» بدل أن يبقى بلا إجراء');
    });

    testWidgets('«لاحقاً» تُخفي الشريط في التحديث الاختياري', (tester) async {
      final s = UpdateService.forTest()
        ..debugSet(update: _update(), phase: UpdatePhase.available);
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();

      await tester.tap(find.byTooltip('لاحقاً'));
      await tester.pumpAndSettle();
      expect(s.hasUpdate, isFalse);
      expect(tester.getSize(find.byType(UpdateCard)).height, 0);
    });

    testWidgets('التحديث الإلزامي: شارة «إلزامي» ولا زر إخفاء', (tester) async {
      final s = UpdateService.forTest()
        ..debugSet(update: _update(force: true), phase: UpdatePhase.available);
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();

      expect(find.text('إلزامي'), findsOneWidget);
      expect(find.byTooltip('لاحقاً'), findsNothing,
          reason: 'التحديث الإلزامي لا يُخفى بزر');
      // ومع ذلك زر التنزيل حاضر
      expect(_button('تنزيل'), findsOneWidget);
    });
  });

  group('«ما الجديد» — ورقة سفلية لا صندوق في الشريط', () {
    testWidgets('الشريط يبقى قصيراً ولو طالت الملاحظات', (tester) async {
      final s = UpdateService.forTest()
        ..debugSet(
          update: _update(notes: List.generate(8, (i) => 'إصلاح رقم ${i + 1}').join('\n')),
          phase: UpdatePhase.available,
        );
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();

      expect(_h(tester), lessThanOrEqualTo(72),
          reason: 'الملاحظات لا تُطيل الشريط — مكانها الورقة السفلية');
      // ولا سطر منها ظاهر في الشريط
      expect(find.textContaining('إصلاح رقم 1'), findsNothing);
      // لكن زر الاطلاع عليها موجود قبل التنزيل أيضاً
      expect(find.byTooltip('تفاصيل التحديث'), findsOneWidget);
    });

    testWidgets('زر التفاصيل يفتح الورقة بالسطور', (tester) async {
      final s = UpdateService.forTest()
        ..debugSet(
          update: _update(notes: 'إصلاح التنزيل\nتحسين الشكل'),
          phase: UpdatePhase.downloaded,
          progress: 1,
        );
      _phone(tester);
      await tester.pumpWidget(_host(s));
      await tester.pump();

      await tester.tap(find.byTooltip('تفاصيل التحديث'));
      await tester.pumpAndSettle();

      expect(find.text('ما الجديد'), findsOneWidget);
      expect(find.textContaining('إصلاح التنزيل'), findsOneWidget);
      expect(find.textContaining('تحسين الشكل'), findsOneWidget);
      expect(_button('تثبيت التحديث'), findsOneWidget);
    });
  });
}

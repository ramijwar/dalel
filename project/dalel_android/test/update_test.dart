import 'package:flutter_test/flutter_test.dart';
import 'package:dalel/models/models.dart';

/* ══════════════════════════════════════════════════════════════
 *  تحديث التطبيق من داخل التطبيق
 *
 *  المدير يرفع ملف APK من لوحة التحكم، فيقرأ الخادم الإصدار من داخل
 *  الملف وينشره على `GET /api/app-update`. التطبيق يقارن رقم بنائه
 *  بالمثبَّت على الجهاز، فإن كان الخادم أحدث ظهرت البطاقة في «حسابي».
 *
 *  ما تتحقق منه هذه الاختبارات:
 *   • قراءة حمولة الخادم بمفاتيحها المختلفة (ونصّاً تالفاً)
 *   • قرار «هل هناك تحديث؟» — وهو أهم ما هنا: لا تحديث وهمي ولا مفوَّت
 *   • تنسيق الحجم والسرعة والمتبقّي (المعروض على المستخدم)
 *   • سطور «ما الجديد» — التنظيف من الشرطات والفراغات
 * ══════════════════════════════════════════════════════════════ */

/// حمولة نموذجية كما تُرسلها نقطة `/api/app-update`
Map<String, dynamic> payload({
  Object? name = '1.2.0',
  Object? code = 5,
  Object? notes = '• إصلاح مشكلة الفلاتر\n• سرعة أعلى في التحميل\n\n',
  Object? force = false,
  Object? size = 25165824,
  Object? sha = 'abc123',
  Object? url = 'https://example.com/dalel-1.2.0.apk',
  Object? published = '2026-09-25T12:00:00+03:00',
}) =>
    {
      'available': true,
      'version_name': name,
      'version_code': code,
      'notes': notes,
      'force': force,
      'size': size,
      'sha256': sha,
      'url': url,
      'published_at': published,
    };

void main() {
  group('قراءة حمولة الخادم', () {
    test('١) حمولة كاملة → كل الحقول صحيحة', () {
      final u = AppUpdate.fromJson(payload());

      expect(u.versionName, '1.2.0');
      expect(u.versionCode, 5);
      expect(u.force, isFalse);
      expect(u.size, 25165824);
      expect(u.sha256, 'abc123');
      expect(u.hasUrl, isTrue);
      expect(u.publishedAt, isNotNull);
    });

    test('٢) حمولة فارغة → قيم افتراضية بلا انهيار', () {
      final u = AppUpdate.fromJson(const {});

      expect(u.versionName, '');
      expect(u.versionCode, 0);
      expect(u.force, isFalse);
      expect(u.hasUrl, isFalse);
      expect(u.hasNotes, isFalse);
      expect(u.publishedAt, isNull);
    });

    test('٣) قيم بنوع مغاير (نصّ بدل رقم · 1 بدل true)', () {
      final u = AppUpdate.fromJson({
        'version_code': '7',
        'size': '1024',
        'force': 1,
      });

      expect(u.versionCode, 7);
      expect(u.size, 1024);
      expect(u.force, isTrue);
    });

    test('٤) تاريخ تالف → null بلا استثناء', () {
      final u = AppUpdate.fromJson(payload(published: 'ليس تاريخاً'));
      expect(u.publishedAt, isNull);
      expect(u.publishedLabel, '');
    });
  });

  group('قرار «هل هناك تحديث؟» — المعيار رقم البناء', () {
    test('٥) الخادم أحدث → نعم', () {
      final u = AppUpdate.fromJson(payload(code: 5, name: '1.2.0'));
      expect(u.isNewerThan(installedCode: 2, installedName: '1.1.0'), isTrue);
    });

    test('٦) الخادم أقدم → لا (لا تُنزَّل نسخة قديمة فوق أحدث)', () {
      final u = AppUpdate.fromJson(payload(code: 1, name: '1.0.0'));
      expect(u.isNewerThan(installedCode: 5, installedName: '1.2.0'), isFalse);
    });

    test('٧) الرقمان متساويان → لا تحديث (ولو اختلف الاسم)', () {
      final u = AppUpdate.fromJson(payload(code: 5, name: '1.2.0'));
      expect(u.isNewerThan(installedCode: 5, installedName: '1.2.0'), isFalse);
    });

    test('٨) رقم الخادم صفر → لا تحديث بناءً على الرقم', () {
      final u = AppUpdate.fromJson(payload(code: 0, name: '1.2.0'));
      // الرقم صفر غير صالح → نرتد إلى مقارنة الاسم
      expect(u.isNewerThan(installedCode: 5, installedName: '1.2.0'), isFalse);
      expect(u.isNewerThan(installedCode: 5, installedName: '1.0.0'), isTrue);
    });

    test('٩) رقم الجهاز مجهول (0) واختلف الاسم → نعم', () {
      final u = AppUpdate.fromJson(payload(code: 5, name: '1.2.0'));
      expect(u.isNewerThan(installedCode: 0, installedName: '1.1.0'), isTrue);
    });

    test('١٠) رقم الجهاز مجهول والاسم نفسه → لا تحديث وهمي', () {
      final u = AppUpdate.fromJson(payload(code: 5, name: '1.2.0'));
      expect(u.isNewerThan(installedCode: 0, installedName: '1.2.0'), isFalse);
    });

    test('١١) لا اسم ولا رقم على الخادم → لا تحديث', () {
      final u = AppUpdate.fromJson(payload(name: '', code: 0));
      expect(u.isNewerThan(installedCode: 3, installedName: '1.1.0'), isFalse);
    });
  });

  group('سطور «ما الجديد»', () {
    test('١٢) تُنظَّف من الشرطات والفراغات والأسطر الفارغة', () {
      final u = AppUpdate.fromJson(payload(
        notes: '• الأول\n- الثاني\n* الثالث\n\n   \n· الرابع\n',
      ));

      expect(u.noteLines, ['الأول', 'الثاني', 'الثالث', 'الرابع']);
      expect(u.hasNotes, isTrue);
    });

    test('١٣) ملاحظات فارغة → لا سطور', () {
      expect(AppUpdate.fromJson(payload(notes: '')).hasNotes, isFalse);
      expect(AppUpdate.fromJson(payload(notes: '   \n  ')).hasNotes, isFalse);
    });

    test('١٤) نص بلا شرطات يبقى كما هو', () {
      final u = AppUpdate.fromJson(payload(notes: 'إصلاحات عامة\nتحسين الأداء'));
      expect(u.noteLines, ['إصلاحات عامة', 'تحسين الأداء']);
    });
  });

  group('التنسيق المعروض للمستخدم', () {
    test('١٥) الأحجام', () {
      expect(formatBytes(0), '—');
      expect(formatBytes(512), '512 بايت');
      expect(formatBytes(2048), '2 ك.ب');
      expect(formatBytes(1048576), '1.0 ميغا');
      expect(formatBytes(25165824), '24.0 ميغا');
      expect(formatBytes(1073741824), '1.00 غيغا');
    });

    test('١٦) السرعات', () {
      expect(formatSpeed(0), '—');
      expect(formatSpeed(512), '512 بايت/ث');
      expect(formatSpeed(20480), '20 ك.ب/ث');
      expect(formatSpeed(2516582), '2.4 م.ب/ث');
    });

    test('١٧) الزمن المتبقّي — ويُخفى إن كان غير منطقي', () {
      expect(formatEta(0), '');
      expect(formatEta(-5), '');
      expect(formatEta(99999), '');
      expect(formatEta(45), '45 ث');
      expect(formatEta(125), '2:05 د');
      expect(formatEta(3600), '60:00 د');
    });

    test('١٨) حجم الإصدار المعروض في البطاقة', () {
      expect(AppUpdate.fromJson(payload(size: 25165824)).sizeLabel, '24.0 ميغا');
      expect(AppUpdate.fromJson(payload(size: 0)).sizeLabel, '—');
    });

    test('١٩) تاريخ النشر بصيغة مختصرة', () {
      final u = AppUpdate.fromJson(payload(published: '2026-09-25T12:00:00+03:00'));
      expect(u.publishedLabel, '25/9/2026');
    });

    test('٢٠) رابط فارغ أو مسافات → لا ملف للتنزيل', () {
      expect(AppUpdate.fromJson(payload(url: '')).hasUrl, isFalse);
      expect(AppUpdate.fromJson(payload(url: '   ')).hasUrl, isFalse);
      expect(AppUpdate.fromJson(payload(url: 'https://x/y.apk')).hasUrl, isTrue);
    });
  });
}

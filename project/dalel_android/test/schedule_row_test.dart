import 'package:flutter_test/flutter_test.dart';
import 'package:dalel/models/models.dart';

/* ══════════════════════════════════════════════════════════════
 *  جدول الدوام — عقد التطبيق مع الخادم
 *
 *  العطل الذي أبلغ عنه المالك: «أوقات الدوام تظهر مغلقة» في شاشة
 *  تفاصيل الخدمة. السبب: الخادم يرسل المفاتيح `day` · `opens` ·
 *  `closes` · `is_24h` (انظر `schedules_map()` في api.php)، بينما
 *  كان التطبيق يقرأ `is_open` · `from` · `to` ⇒ تُقرأ فارغة فيصير
 *  isOpen = false لكل يوم.
 *
 *  وبالاتجاه المعاكس كان `toJson()` يرسل المفاتيح القديمة نفسها،
 *  فجدولٌ يُحفظ من «لوحة صاحب الخدمة» في التطبيق لا يقرأه الخادم.
 *  هذه الاختبارات تثبّت العقد في الاتجاهين.
 * ══════════════════════════════════════════════════════════════ */

void main() {
  group('جدول الدوام — القراءة من الخادم', () {
    test('مفاتيح الخادم (opens/closes) تُقرأ مفتوحة لا مغلقة', () {
      final r = ScheduleRow.fromJson(
          {'day': 1, 'opens': '10:00', 'closes': '13:00', 'is_24h': false});

      expect(r.day, 1);
      expect(r.isOpen, isTrue, reason: 'يوم مُدرَج في الجدول = مفتوح');
      expect(r.from, '10:00');
      expect(r.to, '13:00');
      expect(r.is24, isFalse);
    });

    test('فترتان في اليوم نفسه', () {
      final a = ScheduleRow.fromJson(
          {'day': 0, 'opens': '10:00', 'closes': '13:00', 'is_24h': false});
      final b = ScheduleRow.fromJson(
          {'day': 0, 'opens': '17:00', 'closes': '21:00', 'is_24h': false});

      expect(a.day, b.day);
      expect([a.from, a.to, b.from, b.to],
          ['10:00', '13:00', '17:00', '21:00']);
    });

    test('الدوام المتواصل ٢٤ ساعة', () {
      final r = ScheduleRow.fromJson(
          {'day': 2, 'opens': '00:00', 'closes': '23:59', 'is_24h': true});

      expect(r.is24, isTrue);
      expect(r.isOpen, isTrue);
    });

    test('مفاتيح قديمة (is_open/from/to) تبقى مقروءة — توافق خلفي', () {
      final r = ScheduleRow.fromJson(
          {'day': 3, 'is_open': 1, 'from': '08:30', 'to': '14:00'});

      expect(r.isOpen, isTrue);
      expect(r.from, '08:30');
      expect(r.to, '14:00');
    });

    test('يوم مغلق صراحةً يُقرأ مغلقاً', () {
      final r = ScheduleRow.fromJson(
          {'day': 4, 'is_open': 0, 'opens': '09:00', 'closes': '12:00'});

      expect(r.isOpen, isFalse);
    });

    test('تسميات الأيام: ٠ الأحد … ٦ السبت', () {
      expect(ScheduleRow.dayNames.length, 7);
      expect(ScheduleRow(day: 0).dayName, 'الأحد');
      expect(ScheduleRow(day: 6).dayName, 'السبت');
    });
  });

  group('جدول الدوام — الكتابة إلى الخادم', () {
    test('toJson يرسل مفاتيح الخادم لا المفاتيح القديمة', () {
      final j = ScheduleRow(day: 1, from: '10:00', to: '13:00').toJson();

      expect(j['day'], 1);
      expect(j['opens'], '10:00');
      expect(j['closes'], '13:00');
      expect(j['is_24h'], isFalse);
      // المفاتيح القديمة لا تُرسل — الخادم يتجاهلها
      expect(j.containsKey('is_open'), isFalse);
      expect(j.containsKey('from'), isFalse);
    });

    test('اليوم المغلق يُرسل بأوقات فارغة فيتجاهله الخادم', () {
      final j = ScheduleRow(day: 5, isOpen: false).toJson();

      expect(j['day'], 5);
      expect(j['opens'], '');
      expect(j['closes'], '');
      expect(j['is_24h'], isFalse);
    });

    test('الدوام المتواصل يُرسل بـ is_24h', () {
      final j = ScheduleRow(day: 2, is24: true).toJson();

      expect(j['is_24h'], isTrue);
      expect(j['opens'], '00:00');
      expect(j['closes'], '23:59');
    });

    test('رحلة كاملة: قراءة من الخادم ثم إعادة الإرسال لا تفقد البيانات', () {
      final src = {'day': 0, 'opens': '17:00', 'closes': '21:00', 'is_24h': false};
      final back = ScheduleRow.fromJson(src).toJson();

      expect(back['day'], src['day']);
      expect(back['opens'], src['opens']);
      expect(back['closes'], src['closes']);
      expect(back['is_24h'], src['is_24h']);
    });
  });
}

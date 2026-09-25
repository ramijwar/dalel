import 'package:flutter_test/flutter_test.dart';

import 'package:dalel/models/models.dart';

/* ══════════════════════════════════════════════════════════════
 *  اختبارات قسم «طلبات بانتظار موافقة المدير» (عرض فقط)
 *  يتحقق من تحليل حمولة مسار /admin/requests كما يعيدها الخادم
 * ══════════════════════════════════════════════════════════════ */

void main() {
  group('طلبات الإدارة — تحليل حمولة admin/requests', () {
    test('حقل كامل كما يعيده الخادم', () {
      final r = ServiceRequest.fromJson({
        'id': 35,
        'name': 'خط هنانو - الجامعة',
        'category_id': 40,
        'category_name': 'سرفيس واسعافية',
        'region_id': 699,
        'region_name': 'السابعة',
        'governorate_id': 10,
        'governorate_name': 'ديرالزور',
        'address': 'شارع الجامعة',
        'phone': '0936651837',
        'note': 'خط جديد ينتظر الاعتماد',
        'status': 'pending',
        'want_to_manage': 0,
        'user_id': 40,
        'user_name': 'اياد العبد الكريم',
        'created_at': '2026-09-23 16:52:06',
      });

      expect(r.id, 35);
      expect(r.name, 'خط هنانو - الجامعة');
      expect(r.categoryName, 'سرفيس واسعافية');
      expect(r.regionName, 'السابعة');
      expect(r.governorateName, 'ديرالزور');
      expect(r.status, 'pending');
      expect(r.userName, 'اياد العبد الكريم');
      expect(r.wantToManage, isFalse);
      expect(r.createdAt, '2026-09-23 16:52:06');
      expect(r.statusLabel, 'قيد المراجعة');
    });

    test('طلب زائر بلا حساب يرغب بإدارة خدمته', () {
      final r = ServiceRequest.fromJson({
        'id': 34,
        'name': 'كازية الراموسة الجديدة',
        'category_name': 'كازيات',
        'status': 'pending',
        'want_to_manage': 1,
        'user_name': null,
      });

      expect(r.wantToManage, isTrue);
      expect(r.userName, isNull);
      expect(r.regionName, isNull); // بلا منطقة — يجب ألا ينهار العرض
      expect(r.statusLabel, 'قيد المراجعة');
    });

    test('want_to_manage كقيمة منطقية true (توافق)', () {
      final r = ServiceRequest.fromJson({
        'id': 1,
        'name': 'خدمة',
        'want_to_manage': true,
      });
      expect(r.wantToManage, isTrue);
    });

    test('حمولة ناقصة جداً لا تكسر النموذج', () {
      final r = ServiceRequest.fromJson({'id': 9, 'name': 'طلب مجهول'});
      expect(r.name, 'طلب مجهول');
      expect(r.status, 'pending');
      expect(r.address, '');
      expect(r.categoryName, isNull);
      expect(r.wantToManage, isFalse);
    });
  });
}

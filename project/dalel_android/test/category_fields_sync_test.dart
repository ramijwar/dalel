import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dalel/models/models.dart';
import 'package:dalel/services/database_service.dart';

/* ══════════════════════════════════════════════════════════════
 *  حقول الأقسام الديناميكية — انعكاس تعديلات لوحة الويب
 *
 *  السيناريو: مدير أضاف حقلاً ثم أزاله من لوحة الويب.
 *  كان saveCategories يحفظ الأقسام فقط دون حقولها، ولم تكن
 *  القاعدة المحلية تُمسّ إطلاقاً — فبقي الحقل المحذوف يظهر
 *  في نموذج «أضف خدمة» في التطبيق بلا نهاية.
 * ══════════════════════════════════════════════════════════════ */

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseService.testPath = inMemoryDatabasePath;
  tearDownAll(() => DatabaseService.testPath = null);

  FieldOption opt(String label, String value) =>
      FieldOption(id: 0, label: label, value: value, icon: '');

  test('المزامنة تحفظ حقول الأقسام وخياراتها', () async {
    final svc = DatabaseService.instance;

    final cat = Category(
      id: 37,
      slug: 'pharmacies',
      name: 'صيدليات',
      fields: [
        const CategoryField(
            id: 11, key: 'price', label: 'سعر المعاينة', type: 'number'),
        CategoryField(
          id: 12,
          key: 'delivery',
          label: 'توصيل',
          type: 'select',
          options: [opt('نعم', '1'), opt('لا', '0')],
        ),
      ],
    );
    await svc.saveCategories([cat]);

    final cats = await svc.getCategories();
    expect(cats, isNotEmpty);
    expect(cats.first.fields.length, 2, reason: 'الحقلان محفوظان محلياً');
    expect(cats.first.fields[1].key, 'delivery');
    expect(cats.first.fields[1].options.length, 2, reason: 'الخيارات محفوظة');
    expect(cats.first.fields[1].options.first.label, 'نعم');
  });

  test('إزالة حقل من لوحة الويب يزيله محلياً في المزامنة التالية', () async {
    final svc = DatabaseService.instance;

    // المزامنة الثانية: حقل «توصيل» حُذف من اللوحة
    final cat = Category(
      id: 37,
      slug: 'pharmacies',
      name: 'صيدليات',
      fields: [
        const CategoryField(
            id: 11, key: 'price', label: 'سعر المعاينة', type: 'number'),
      ],
    );
    await svc.saveCategories([cat]);

    final cats = await svc.getCategories();
    expect(cats.first.fields.length, 1,
        reason: 'الحقل المحذوف لا يبقى عالقاً محلياً');
    expect(cats.first.fields.single.key, 'price');
  });

  test('الوحدة وإخفاء «لا» يُحفظان ويعودان من القاعدة المحلية', () async {
    final svc = DatabaseService.instance;

    final cat = Category(
      id: 37,
      slug: 'pharmacies',
      name: 'صيدليات',
      fields: const [
        CategoryField(
            id: 21,
            key: 'consult_fee',
            label: 'سعر المعاينة',
            type: 'number',
            suffix: 'ل.س'),
        CategoryField(
            id: 22,
            key: 'delivery',
            label: 'خدمة التوصيل',
            type: 'boolean',
            hideWhenFalse: true),
      ],
    );

    await svc.saveCategories([cat]);

    final cats = await svc.getCategories();
    final fee = cats.first.fields.firstWhere((f) => f.key == 'consult_fee');
    final del = cats.first.fields.firstWhere((f) => f.key == 'delivery');

    expect(fee.suffix, 'ل.س', reason: 'الوحدة محفوظة ومقروءة');
    expect(del.hideWhenFalse, isTrue, reason: 'إخفاء «لا» محفوظ ومقروء');
    expect(fee.hideWhenFalse, isFalse);
  });
}

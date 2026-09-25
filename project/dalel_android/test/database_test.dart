import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dalel/config/constants.dart';
import 'package:dalel/models/models.dart';
import 'package:dalel/services/database_service.dart';

/* ══════════════════════════════════════════════════════════════
 *  اختبارات قاعدة البيانات المحلية
 *  تتحقق من توافق المخطط مع بيانات الخادم:
 *    • جداول الحقول الخاصة بالأقسام
 *    • الحقول المحلولة للخدمات (تعمل بدون إنترنت)
 * ══════════════════════════════════════════════════════════════ */

/// `:memory:` في sqflite_common_ffi قاعدة **مشتركة** بين الاتصالات
/// (file::memory:?cache=shared)، فكانت قواعد الاختبارات تتلوّث ببعضها
/// وتظهر أعطال متذبذبة. نستخدم ملفاً مؤقتاً فريداً لكل قاعدة.
int _dbSeq = 0;
final List<String> _tmpFiles = [];

String _tmpDbPath() {
  _dbSeq++;
  final path = p.join(Directory.systemTemp.path,
      'dalel_test_${DateTime.now().microsecondsSinceEpoch}_$_dbSeq.sqlite');
  _tmpFiles.add(path);
  return path;
}

void main() {
  sqfliteFfiInit();

  tearDownAll(() async {
    await DatabaseService.resetForTests();
    for (final f in _tmpFiles) {
      try {
        await File(f).delete();
      } catch (_) {}
    }
  });

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      _tmpDbPath(),
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (d, v) => DatabaseService.instance.createSchema(d),
        onUpgrade: (d, o, n) => DatabaseService.instance.upgradeSchema(d, o, n),
      ),
    );
  });

  tearDown(() async => db.close());

  test('المخطط يحتوي جداول الحقول الخاصة', () async {
    final tables = await db.query(
      'sqlite_master',
      where: 'type = ?',
      whereArgs: ['table'],
    );
    final names = tables.map((t) => t['name'].toString()).toSet();

    for (final t in [
      'categories',
      'services',
      'schedules',
      'category_fields',
      'category_field_options',
      'service_fields',
    ]) {
      expect(names.contains(t), isTrue, reason: 'جدول $t يجب أن يكون موجوداً');
    }
  });

  test('ترقية من إصدار ١ تُنشئ جداول الحقول', () async {
    // أنشئ قاعدة بإصدار ١ (بلا جداول الحقول)
    final path1 = _tmpDbPath();
    final old = await databaseFactoryFfi.openDatabase(
      path1,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''CREATE TABLE categories (
            id INTEGER PRIMARY KEY, slug TEXT, name TEXT)''');
        },
      ),
    );

    // أغلق وأعد الفتح بالإصدار ٢ لتشغيل الترقية
    await old.close();
    final upgraded = await databaseFactoryFfi.openDatabase(
      path1,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (d, v) => DatabaseService.instance.createSchema(d),
        onUpgrade: (d, o, n) => DatabaseService.instance.upgradeSchema(d, o, n),
      ),
    );

    // افتح من نفس المسار — نحتاج قاعدة جديدة للتحقق
    // (الذاكرة تُنشئ قاعدة جديدة، لذا نتحقق من _upgrade مباشرة)
    final d2 = await databaseFactoryFfi.openDatabase(_tmpDbPath());
    await DatabaseService.instance.upgradeSchema(d2, 1, 2);

    final names = (await d2.query('sqlite_master', where: 'type = ?', whereArgs: ['table']))
        .map((t) => t['name'].toString())
        .toSet();

    expect(names.contains('category_fields'), isTrue);
    expect(names.contains('category_field_options'), isTrue);
    expect(names.contains('service_fields'), isTrue);


    await d2.close();
    await upgraded.close();
  });

  test('ترقية من إصدار ٢ تضيف عمودَي الوحدة وإخفاء «لا»', () async {
    // قاعدة بإصدار ٢: جدول category_fields بالمخطط القديم (بلا العمودين)
    final d = await databaseFactoryFfi.openDatabase(_tmpDbPath());
    await d.execute('''CREATE TABLE category_fields (
      id INTEGER PRIMARY KEY,
      category_id INTEGER NOT NULL,
      field_key TEXT NOT NULL,
      label TEXT NOT NULL,
      type TEXT DEFAULT 'select',
      required INTEGER DEFAULT 0,
      placeholder TEXT,
      help TEXT,
      show_in_card INTEGER DEFAULT 1,
      filterable INTEGER DEFAULT 0,
      sort_order INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1
    )''');

    // الترقية إلى الإصدار ٣ — يجب أن تُضيف العمودين لا أن تفشل
    await DatabaseService.instance.upgradeSchema(d, 2, 3);

    final cols = (await d.rawQuery('PRAGMA table_info(category_fields)'))
        .map((r) => r['name'].toString())
        .toSet();

    expect(cols.contains('suffix'), isTrue, reason: 'عمود الوحدة مضاف');
    expect(cols.contains('hide_when_false'), isTrue, reason: 'عمود إخفاء «لا» مضاف');

    // تشغيلها مرة ثانية لا يجب أن يرمي (آمنة للتكرار)
    await DatabaseService.instance.upgradeSchema(d, 2, 3);

    await d.close();
  });

  test('حفظ وقراءة حقل قائمة مع خياراته', () async {
    final cat = Category.fromJson({
      'id': 38,
      'slug': 'doctors',
      'name': 'أطباء',
      'fields': [
        {
          'id': 6,
          'key': 'specialty',
          'label': 'الاختصاص',
          'type': 'select',
          'required': true,
          'options': [
            {'id': 1, 'label': 'أطفال', 'value': '1', 'icon': 'baby'},
            {'id': 2, 'label': 'قلبية', 'value': '2', 'icon': 'heart'},
          ],
        },
      ],
    });

    await db.insert('categories', cat.toJson());
    await db.insert('category_fields', {
      'id': 6,
      'category_id': 38,
      'field_key': 'specialty',
      'label': 'الاختصاص',
      'type': 'select',
      'required': 1,
      'sort_order': 0,
      'is_active': 1,
    });
    await db.insert('category_field_options', {
      'id': 1, 'field_id': 6, 'label': 'أطفال', 'value': '1',
      'icon': 'baby', 'sort_order': 0, 'is_active': 1,
    });
    await db.insert('category_field_options', {
      'id': 2, 'field_id': 6, 'label': 'قلبية', 'value': '2',
      'icon': 'heart', 'sort_order': 1, 'is_active': 1,
    });

    // نتحقق من البنية عبر القراءة المباشرة
    final fRows = await db.query('category_fields', where: 'category_id = ?', whereArgs: [38]);
    expect(fRows.length, 1);
    expect(fRows.first['field_key'], 'specialty');

    final oRows = await db.query('category_field_options', where: 'field_id = ?', whereArgs: [6]);
    expect(oRows.length, 2);
    expect(oRows.first['label'], 'أطفال');
  });

  test('حفظ الحقول المحلولة لخدمة وقراءتها', () async {
    await db.insert('services', {
      'id': 100,
      'name': 'د. أحمد',
      'category_id': 38,
      'meta': '{}',
    });

    // نحاكي ما تفعله saveServices
    final batch = db.batch();
    batch.delete('service_fields', where: 'service_id = ?', whereArgs: [100]);
    batch.insert('service_fields', {
      'service_id': 100,
      'field_key': 'specialty',
      'label': 'الاختصاص',
      'type': 'select',
      'value': '2',
      'display': 'أمراض قلبية',
      'icon': 'heart',
      'sort': 0,
    });
    await batch.commit(noResult: true);

    final rows = await db.query('service_fields', where: 'service_id = ?', whereArgs: [100]);
    expect(rows.length, 1);
    expect(rows.first['display'], 'أمراض قلبية');
    expect(rows.first['icon'], 'heart');
  });

  test('الفهارس موجودة لتسريع الاستعلامات', () async {
    final idx = (await db.query('sqlite_master', where: 'type = ?', whereArgs: ['index']))
        .map((t) => t['name'].toString())
        .where((n) => n.startsWith('idx_'))
        .toSet();

    for (final i in [
      'idx_services_cat',
      'idx_services_gov',
      'idx_services_zone',
      'idx_services_cat_gov',
      'idx_cf_cat',
      'idx_sf_service',
    ]) {
      expect(idx.contains(i), isTrue, reason: 'الفهرس $i يجب أن يكون موجوداً');
    }
  });

  test('استعلام الحقول بالجملة يرجع تجميعاً صحيحاً', () async {
    // خدمتان، لكل منهما حقل
    await db.insert('service_fields', {
      'service_id': 1, 'field_key': 'specialty', 'label': 'الاختصاص',
      'value': '1', 'display': 'أطفال', 'sort': 0,
    });
    await db.insert('service_fields', {
      'service_id': 2, 'field_key': 'specialty', 'label': 'الاختصاص',
      'value': '2', 'display': 'قلبية', 'sort': 0,
    });

    final placeholders = '?,?';
    final rows = await db.query(
      'service_fields',
      where: 'service_id IN ($placeholders)',
      whereArgs: [1, 2],
      orderBy: 'service_id, sort',
    );

    final map = <int, List<ResolvedField>>{};
    for (final r in rows) {
      map.putIfAbsent(r['service_id'] as int, () => []).add(ResolvedField(
            key: r['field_key'].toString(),
            label: r['label'].toString(),
            type: (r['type'] ?? 'text').toString(),
            value: (r['value'] ?? '').toString(),
            display: (r['display'] ?? '').toString(),
            icon: (r['icon'] ?? '').toString(),
          ));
    }

    expect(map.length, 2);
    expect(map[1]!.single.display, 'أطفال');
    expect(map[2]!.single.display, 'قلبية');
  });

  test('قراءة كل خدمات القسم من المحلي — بلا قصّ عند 200 (انحدار)', () async {
    // الخطأ: الخادم يقص الصفحة إلى 200، و«servicesAll» طلبت 500 فرأت
    // الصفحة الأولى (200) أخيرة فحفظت 200 فقط، ثم كان العرض المحلي
    // يُقص هو الآخر بـ limit=200 — فتظهر ٢٠٠ من أصل ٢٤٢.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.testPath = _tmpDbPath();
    addTearDown(DatabaseService.resetForTests);
    final svc = DatabaseService.instance;
    final d = await svc.db;

    for (var i = 1; i <= 250; i++) {
      await d.insert('services', {
        'id': 1000 + i,
        'name': 'صيدلية $i',
        'category_id': 37,
        'meta': '{}',
      });
    }

    // بالحد الجديد: كل الصفوف تُقرأ من المحلي
    final all = await svc.queryServices(categoryId: 37, limit: AppConfig.localQueryLimit);
    expect(all.length, 250);

    // وللتوثيق: الحد القديم (pageSize=200) كان يقص فعلاً
    final capped = await svc.queryServices(categoryId: 37, limit: AppConfig.pageSize);
    expect(capped.length, 200);
  });
}

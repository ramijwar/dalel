import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

/// ══════════════════════════════════════════════════════════════
/// قاعدة البيانات المحلية SQLite
/// تخزّن بيانات الخادم ليعمل التطبيق بدون إنترنت
/// ══════════════════════════════════════════════════════════════
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String _dbName = 'dalel.db';
  static const int _version = 3;

  Database? _db;

  /// مسار مخصّص للاختبارات (قاعدة بيانات في الذاكرة)
  static String? testPath;

  Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  /// يفتح قاعدة بيانات في الذاكرة للاختبارات
  static Future<Database> openTestDb() => openDatabase(
        inMemoryDatabasePath,
        version: _version,
        onCreate: (d, v) => DatabaseService.instance._create(d, v),
        onUpgrade: (d, o, n) => DatabaseService.instance._upgrade(d, o, n),
      );

  Future<Database> _init() async {
    if (testPath != null) {
      return openDatabase(
        testPath!,
        version: _version,
        onCreate: _create,
        onUpgrade: _upgrade,
      );
    }
    final dir = await getDatabasesPath();
    final path = join(dir, _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  /// مغلّف عام — للاختبارات (قاعدة بيانات في الذاكرة)
  Future<void> createSchema(Database d, [int v = _version]) => _create(d, v);

  /// مغلّف عام — للاختبارات (ترقية المخطط)
  Future<void> upgradeSchema(Database d, int oldV, int newV) =>
      _upgrade(d, oldV, newV);

  /// مغلّف عام لحفظ خدمة واحدة مع حقولها وجدولها
  Future<void> saveServiceFull(Service s) => saveService(s);

  Future<void> _create(Database db, int v) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        slug TEXT NOT NULL,
        name TEXT NOT NULL,
        singular TEXT,
        icon TEXT,
        color TEXT,
        description TEXT,
        route TEXT,
        sort_order INTEGER DEFAULT 0,
        layout TEXT DEFAULT 'card',
        features TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE governorates (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT,
        zone TEXT,
        sort_order INTEGER DEFAULT 0,
        services_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE regions (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        zone TEXT,
        sort_order INTEGER DEFAULT 0,
        governorate_id INTEGER,
        parent_id INTEGER,
        level TEXT DEFAULT 'city',
        services_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE specialties (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT,
        icon TEXT,
        services_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE services (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        category_slug TEXT,
        category_name TEXT,
        category_icon TEXT,
        region_id INTEGER,
        region_name TEXT,
        region_zone TEXT,
        region_level TEXT,
        city_name TEXT,
        governorate_id INTEGER,
        governorate_name TEXT,
        governorate_slug TEXT,
        specialty_id INTEGER,
        address TEXT,
        phone TEXT,
        phone_intl TEXT,
        whatsapp TEXT,
        whatsapp_number TEXT,
        note TEXT,
        photo TEXT,
        meta TEXT,
        is_verified INTEGER DEFAULT 0,
        owner_id INTEGER,
        owner_name TEXT,
        status TEXT,
        status_label TEXT,
        status_sublabel TEXT,
        status_source TEXT,
        closes_at TEXT,
        on_duty INTEGER DEFAULT 0,
        duty_from TEXT,
        duty_to TEXT,
        updated_at TEXT,
        created_at TEXT,
        schedule_count INTEGER DEFAULT 0,
        cached_at INTEGER
      )
    ''');

    await db.execute('CREATE INDEX idx_services_cat ON services(category_id)');
    await db
        .execute('CREATE INDEX idx_services_gov ON services(governorate_id)');
    await db.execute('CREATE INDEX idx_services_region ON services(region_id)');
    await db.execute('CREATE INDEX idx_services_status ON services(status)');
    await db
        .execute('CREATE INDEX idx_services_zone ON services(region_zone)');
    await db.execute(
        'CREATE INDEX idx_services_cat_gov ON services(category_id, governorate_id)');

    // ─── الحقول الخاصة بالأقسام ───
    await db.execute('''
      CREATE TABLE category_fields (
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
        is_active INTEGER DEFAULT 1,
        suffix TEXT DEFAULT '',
        hide_when_false INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE category_field_options (
        id INTEGER PRIMARY KEY,
        field_id INTEGER NOT NULL,
        label TEXT NOT NULL,
        value TEXT NOT NULL,
        icon TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // الحقول المحلولة لكل خدمة — ليعمل العرض بدون إنترنت
    await db.execute('''
      CREATE TABLE service_fields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_id INTEGER NOT NULL,
        field_key TEXT NOT NULL,
        label TEXT NOT NULL,
        type TEXT,
        value TEXT,
        display TEXT,
        icon TEXT,
        sort INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_cf_cat ON category_fields(category_id)');
    await db.execute(
        'CREATE INDEX idx_cfo_field ON category_field_options(field_id)');
    await db.execute(
        'CREATE INDEX idx_sf_service ON service_fields(service_id)');

    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_id INTEGER NOT NULL,
        day INTEGER NOT NULL,
        is_open INTEGER DEFAULT 1,
        time_from TEXT,
        time_to TEXT,
        UNIQUE(service_id, day)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // المفضلة محلياً
    await db.execute('''
      CREATE TABLE favorites (
        service_id INTEGER PRIMARY KEY,
        added_at INTEGER
      )
    ''');

    // آخر عمليات بحث
    await db.execute('''
      CREATE TABLE recent_searches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL UNIQUE,
        searched_at INTEGER
      )
    ''');
  }

  /// ══════════════════════════════════════════════════════════
  /// الترقية من إصدار إلى آخر
  ///   ١ → ٢: الحقول الخاصة بالأقسام + الحقول المحلولة للخدمات
  /// ══════════════════════════════════════════════════════════
  Future<void> _upgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS category_fields (
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
          is_active INTEGER DEFAULT 1,
          suffix TEXT DEFAULT '',
          hide_when_false INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS category_field_options (
          id INTEGER PRIMARY KEY,
          field_id INTEGER NOT NULL,
          label TEXT NOT NULL,
          value TEXT NOT NULL,
          icon TEXT,
          sort_order INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1
        )
      ''');
      // الحقول المحلولة لكل خدمة — ليعمل العرض بدون إنترنت
      await db.execute('''
        CREATE TABLE IF NOT EXISTS service_fields (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          service_id INTEGER NOT NULL,
          field_key TEXT NOT NULL,
          label TEXT NOT NULL,
          type TEXT,
          value TEXT,
          display TEXT,
          icon TEXT,
          sort INTEGER DEFAULT 0
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_cf_cat ON category_fields(category_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_cfo_field ON category_field_options(field_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sf_service ON service_fields(service_id)');
      // فهارس إضافية لتسريع الاستعلامات
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_services_zone ON services(region_zone)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_services_cat_gov ON services(category_id, governorate_id)');
    }

    //   ٢ → ٣: وحدة الحقل الرقمي + إخفاء القيمة المنطقية عند «لا»
    //   CREATE TABLE أعلاه لا يُضيف أعمدة إلى جدول موجود، فمن ثبّت الإصدار
    //   السابق يحتاج هذا الـ ALTER وإلا بقي بلا العمودين وانهارت قراءتهما.
    if (oldV < 3) {
      await _addColumnIfMissing(db, 'category_fields', 'suffix', "TEXT DEFAULT ''");
      await _addColumnIfMissing(
          db, 'category_fields', 'hide_when_false', 'INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// إضافة عمود إن لم يكن موجوداً (SQLite لا يدعم ADD COLUMN IF NOT EXISTS)
  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final exists = cols.any((r) => r['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  // ══════════════════════════════════════════════════════════
  // حفظ البيانات من الخادم
  // ══════════════════════════════════════════════════════════

  /// حفظ الأقسام (يستبدل الكل)
  Future<void> saveCategories(List<Category> list) async {
    final d = await db;
    await d.transaction((txn) async {
      // ── الحقول الديناميكية تُستبدل كاملةً في كل مزامنة ──
      // بدون هذا: حقل أُضيف ثم أُزيل من لوحة الويب يبقى عالقاً
      // في القاعدة المحلية ويظهر في نموذج إضافة خدمة بلا نهاية.
      await txn.delete('category_field_options');
      await txn.delete('category_fields');
      await txn.delete('categories');
      for (final c in list) {
        await txn.insert('categories', c.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        for (var fi = 0; fi < c.fields.length; fi++) {
          final f = c.fields[fi];
          final fid = f.id != 0 ? f.id : fi + 1;
          await txn.insert('category_fields', {
            'id': fid,
            'category_id': c.id,
            'field_key': f.key,
            'label': f.label,
            'type': f.type,
            'required': f.required ? 1 : 0,
            'placeholder': f.placeholder,
            'help': f.help,
            'show_in_card': f.showInCard ? 1 : 0,
            'filterable': f.filterable ? 1 : 0,
            'sort_order': f.sortOrder,
            'is_active': 1,
            'suffix': f.suffix,
            'hide_when_false': f.hideWhenFalse ? 1 : 0,
          });
          for (var oi = 0; oi < f.options.length; oi++) {
            final o = f.options[oi];
            await txn.insert('category_field_options', {
              'id': o.id != 0 ? o.id : fid * 1000 + oi + 1,
              'field_id': fid,
              'label': o.label,
              'value': o.value,
              'icon': o.icon,
              'sort_order': oi,
            });
          }
        }
      }
    });
  }

  Future<void> saveGovernorates(List<Governorate> list) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('governorates');
      for (final g in list) {
        await txn.insert('governorates', g.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveRegions(List<Region> list) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('regions');
      for (final r in list) {
        await txn.insert('regions', r.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveSpecialties(List<Specialty> list) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('specialties');
      for (final s in list) {
        await txn.insert('specialties', s.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// حفظ خدمة واحدة (مع جدولها إن وُجد)
  Future<void> saveService(Service s) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.insert(
        'services',
        {...s.toJson(), 'cached_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (s.schedule.isNotEmpty) await _saveSchedule(txn, s.id, s.schedule);
    });
  }

  /// ══════════════════════════════════════════════════════════
  /// حفظ دفعة خدمات — كل شيء داخل دفعة واحدة
  ///
  /// كان الجدول يُحفظ بانتظار فردي لكل صف داخل الحلقة،
  /// وهو ما يجعل مزامنة ٥٢٣ خدمة (~٣٦٠٠ صف جدول) بطيئة جداً.
  /// الآن: حذف جماعي + إدراج جمعي في دفعة واحدة.
  /// ══════════════════════════════════════════════════════════
  Future<void> saveServices(List<Service> list) async {
    if (list.isEmpty) return;
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    await d.transaction((txn) async {
      final batch = txn.batch();

      for (final s in list) {
        batch.insert(
          'services',
          {...s.toJson(), 'cached_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // الحقول المحلولة (مثل الاختصاص) — تحل محلها كاملةً
        batch.delete('service_fields',
            where: 'service_id = ?', whereArgs: [s.id]);
        if (s.fields.isNotEmpty) {
          for (var i = 0; i < s.fields.length; i++) {
            final f = s.fields[i];
            batch.insert('service_fields', {
              'service_id': s.id,
              'field_key': f.key,
              'label': f.label,
              'type': f.type,
              'value': f.value,
              'display': f.display,
              'icon': f.icon,
              'sort': i,
            });
          }
        }

        // جدول الدوام — داخل نفس الدفعة
        if (s.schedule.isNotEmpty) {
          batch.delete('schedules',
              where: 'service_id = ?', whereArgs: [s.id]);
          for (final r in s.schedule) {
            batch.insert('schedules', {
              'service_id': s.id,
              'day': r.day,
              'is_open': r.isOpen ? 1 : 0,
              'time_from': r.from,
              'time_to': r.to,
            });
          }
        }
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> _saveSchedule(
      DatabaseExecutor txn, int serviceId, List<ScheduleRow> rows) async {
    await txn
        .delete('schedules', where: 'service_id = ?', whereArgs: [serviceId]);
    if (rows.isEmpty) return;
    final batch = txn.batch();
    for (final r in rows) {
      batch.insert('schedules', {
        'service_id': serviceId,
        'day': r.day,
        'is_open': r.isOpen ? 1 : 0,
        'time_from': r.from,
        'time_to': r.to,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveSchedule(int serviceId, List<ScheduleRow> rows) async {
    final d = await db;
    await d.transaction((txn) => _saveSchedule(txn, serviceId, rows));
  }

  Future<void> saveSettings(AppSettings s) async {
    final d = await db;
    await d.insert(
      'settings',
      {'key': 'app', 'value': jsonEncode(s.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ══════════════════════════════════════════════════════════
  // قراءة البيانات (تعمل بدون إنترنت)
  // ══════════════════════════════════════════════════════════

  /// قراءة الأقسام مع حقولها الخاصة (تعمل بدون إنترنت)
  Future<List<Category>> getCategories() async {
    final d = await db;
    final rows = await d.query('categories', orderBy: 'sort_order, name');
    if (rows.isEmpty) return [];

    // اجمع الحقول وخياراتها في استعلامين فقط (لا N+1)
    final fRows = await d.query('category_fields',
        where: 'is_active = 1', orderBy: 'sort_order, id');
    final oRows = await d
        .query('category_field_options', orderBy: 'field_id, sort_order');

    final optionsByField = <int, List<FieldOption>>{};
    for (final o in oRows) {
      optionsByField
          .putIfAbsent(_asInt(o['field_id']), () => [])
          .add(FieldOption(
            id: _asInt(o['id']),
            label: (o['label'] ?? '').toString(),
            value: (o['value'] ?? '').toString(),
            icon: (o['icon'] ?? '').toString(),
          ));
    }

    final fieldsByCat = <int, List<CategoryField>>{};
    for (final f in fRows) {
      final fid = _asInt(f['id']);
      fieldsByCat.putIfAbsent(_asInt(f['category_id']), () => []).add(
            CategoryField(
              id: fid,
              key: (f['field_key'] ?? '').toString(),
              label: (f['label'] ?? '').toString(),
              type: (f['type'] ?? 'select').toString(),
              required: _asInt(f['required']) == 1,
              placeholder: (f['placeholder'] ?? '').toString(),
              help: (f['help'] ?? '').toString(),
              showInCard: f['show_in_card'] == null
                  ? true
                  : _asInt(f['show_in_card']) == 1,
              filterable: _asInt(f['filterable']) == 1,
              sortOrder: _asInt(f['sort_order']),
              suffix: (f['suffix'] ?? '').toString(),
              hideWhenFalse: _asInt(f['hide_when_false']) == 1,
              options: optionsByField[fid] ?? const [],
            ),
          );
    }

    return rows.map((r) {
      final c = Category.fromJson(r);
      return Category(
        id: c.id,
        slug: c.slug,
        name: c.name,
        singular: c.singular,
        icon: c.icon,
        color: c.color,
        description: c.description,
        route: c.route,
        sortOrder: c.sortOrder,
        layout: c.layout,
        features: c.features,
        fields: fieldsByCat[c.id] ?? const [],
        isActive: c.isActive,
      );
    }).toList();
  }

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  Future<List<Governorate>> getGovernorates() async {
    final d = await db;
    final rows = await d.query('governorates', orderBy: 'sort_order, name');
    return rows.map(Governorate.fromJson).toList();
  }

  Future<List<Region>> getRegions({int? governorateId}) async {
    final d = await db;
    final rows = await d.query(
      'regions',
      where: governorateId != null ? 'governorate_id = ?' : null,
      whereArgs: governorateId != null ? [governorateId] : null,
      orderBy: 'sort_order, name',
    );
    return rows.map(Region.fromJson).toList();
  }

  Future<List<Specialty>> getSpecialties() async {
    final d = await db;
    final rows = await d.query('specialties', orderBy: 'name');
    return rows.map(Specialty.fromJson).toList();
  }

  Future<AppSettings?> getSettings() async {
    final d = await db;
    final rows =
        await d.query('settings', where: 'key = ?', whereArgs: ['app']);
    if (rows.isEmpty) return null;
    try {
      return AppSettings.fromJson(jsonDecode(rows.first['value'] as String));
    } catch (_) {
      return null;
    }
  }

  Future<Service?> getService(int id) async {
    final d = await db;
    final rows = await d.query('services', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final s = Service.fromJson(_decodeMeta(rows.first));
    final sched = await getSchedule(id);
    final fields = await getServiceFields(id);
    return s.copyWith(
      schedule: sched.isEmpty ? null : sched,
      fields: fields.isEmpty ? null : fields,
    );
  }

  /// الحقول المحلولة لخدمة واحدة (تعمل بدون إنترنت)
  Future<List<ResolvedField>> getServiceFields(int serviceId) async {
    final d = await db;
    final rows = await d.query(
      'service_fields',
      where: 'service_id = ?',
      whereArgs: [serviceId],
      orderBy: 'sort',
    );
    return rows
        .map((r) => ResolvedField(
              key: (r['field_key'] ?? '').toString(),
              label: (r['label'] ?? '').toString(),
              type: (r['type'] ?? 'text').toString(),
              value: (r['value'] ?? '').toString(),
              display: (r['display'] ?? '').toString(),
              icon: (r['icon'] ?? '').toString(),
            ))
        .toList();
  }

  /// الحقول المحلولة لعدة خدمات دفعةً واحدة (استعلام واحد — لا N+1)
  Future<Map<int, List<ResolvedField>>> getServiceFieldsBulk(
      List<int> ids) async {
    if (ids.isEmpty) return {};
    final d = await db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await d.query(
      'service_fields',
      where: 'service_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'service_id, sort',
    );
    final map = <int, List<ResolvedField>>{};
    for (final r in rows) {
      final sid = _asInt(r['service_id']);
      map.putIfAbsent(sid, () => []).add(ResolvedField(
            key: (r['field_key'] ?? '').toString(),
            label: (r['label'] ?? '').toString(),
            type: (r['type'] ?? 'text').toString(),
            value: (r['value'] ?? '').toString(),
            display: (r['display'] ?? '').toString(),
            icon: (r['icon'] ?? '').toString(),
          ));
    }
    return map;
  }

  Future<List<ScheduleRow>> getSchedule(int serviceId) async {
    final d = await db;
    final rows = await d.query(
      'schedules',
      where: 'service_id = ?',
      whereArgs: [serviceId],
      orderBy: 'day',
    );
    return rows
        .map((r) => ScheduleRow(
              day: r['day'] as int,
              isOpen: (r['is_open'] as int) == 1,
              from: (r['time_from'] as String?) ?? '08:00',
              to: (r['time_to'] as String?) ?? '20:00',
            ))
        .toList();
  }

  /// استعلام الخدمات مع الفلاتر — من قاعدة البيانات المحلية
  Future<List<Service>> queryServices({
    int? categoryId,
    String? categorySlug,
    int? regionId,
    int? governorateId,
    int? specialtyId,
    String? status,
    bool? onDuty,
    String? search,
    int limit = 500,
  }) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];

    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (categorySlug != null) {
      where.add('category_slug = ?');
      args.add(categorySlug);
    }
    if (regionId != null) {
      where.add('region_id = ?');
      args.add(regionId);
    }
    if (governorateId != null) {
      where.add('governorate_id = ?');
      args.add(governorateId);
    }
    if (specialtyId != null) {
      where.add('specialty_id = ?');
      args.add(specialtyId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (onDuty != null) {
      where.add('on_duty = ?');
      args.add(onDuty ? 1 : 0);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(name LIKE ? OR address LIKE ? OR region_name LIKE ?)');
      final q = '%${search.trim()}%';
      args.addAll([q, q, q]);
    }

    final rows = await d.query(
      'services',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name',
      limit: limit,
    );

    final list = rows.map((r) => Service.fromJson(_decodeMeta(r))).toList();
    if (list.isEmpty) return list;

    // ════════════════════════════════════════════════════════
    // كان هنا استعلام لكل خدمة على حدة (N+1) — الآن استعلامان
    // فقط للجداول والحقول مهما بلغ عدد الخدمات.
    // ════════════════════════════════════════════════════════
    final ids = list.map((s) => s.id).toList();
    final inClause = List.filled(ids.length, '?').join(',');

    final sRows = await d.query(
      'schedules',
      where: 'service_id IN ($inClause)',
      whereArgs: ids,
      orderBy: 'service_id, day',
    );
    final schedBySvc = <int, List<ScheduleRow>>{};
    for (final r in sRows) {
      schedBySvc.putIfAbsent(_asInt(r['service_id']), () => []).add(
            ScheduleRow(
              day: _asInt(r['day']),
              isOpen: _asInt(r['is_open']) == 1,
              from: (r['time_from'] as String?) ?? '08:00',
              to: (r['time_to'] as String?) ?? '20:00',
            ),
          );
    }

    final fieldsBySvc = await getServiceFieldsBulk(ids);

    return list.map((s) {
      final sched = schedBySvc[s.id];
      final fields = fieldsBySvc[s.id];
      return s.copyWith(
        schedule: (sched == null || sched.isEmpty) ? null : sched,
        fields: (fields == null || fields.isEmpty) ? null : fields,
      );
    }).toList();
  }

  Map<String, dynamic> _decodeMeta(Map<String, Object?> row) {
    final m = Map<String, dynamic>.from(row);
    final raw = m['meta'];
    if (raw is String && raw.isNotEmpty) {
      try {
        m['meta'] = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        m['meta'] = <String, dynamic>{};
      }
    }
    return m;
  }

  // ══════════════════════════════════════════════════════════
  // المفضلة
  // ══════════════════════════════════════════════════════════

  Future<Set<int>> getFavorites() async {
    final d = await db;
    final rows = await d.query('favorites');
    return rows.map((r) => r['service_id'] as int).toSet();
  }

  Future<bool> isFavorite(int id) async {
    final d = await db;
    final rows =
        await d.query('favorites', where: 'service_id = ?', whereArgs: [id]);
    return rows.isNotEmpty;
  }

  Future<void> toggleFavorite(int id) async {
    final d = await db;
    final exists = await isFavorite(id);
    if (exists) {
      await d.delete('favorites', where: 'service_id = ?', whereArgs: [id]);
    } else {
      await d.insert('favorites', {
        'service_id': id,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  // ══════════════════════════════════════════════════════════
  // عمليات البحث الأخيرة
  // ══════════════════════════════════════════════════════════

  Future<List<String>> getRecentSearches() async {
    final d = await db;
    final rows =
        await d.query('recent_searches', orderBy: 'searched_at DESC', limit: 8);
    return rows.map((r) => r['query'] as String).toList();
  }

  Future<void> addRecentSearch(String q) async {
    if (q.trim().length < 2) return;
    final d = await db;
    await d.insert(
        'recent_searches',
        {
          'query': q.trim(),
          'searched_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    // احتفظ بآخر ١٠ فقط
    final all = await d.query('recent_searches', orderBy: 'searched_at DESC');
    if (all.length > 10) {
      for (final r in all.skip(10)) {
        await d
            .delete('recent_searches', where: 'id = ?', whereArgs: [r['id']]);
      }
    }
  }

  Future<void> clearRecentSearches() async =>
      (await db).delete('recent_searches');

  // ══════════════════════════════════════════════════════════
  // بيانات المزامنة
  // ══════════════════════════════════════════════════════════

  Future<void> setSyncedAt() async {
    final d = await db;
    await d.insert(
      'sync_meta',
      {
        'key': 'last_sync',
        'value': DateTime.now().millisecondsSinceEpoch.toString()
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> getLastSync() async {
    final d = await db;
    final rows =
        await d.query('sync_meta', where: 'key = ?', whereArgs: ['last_sync']);
    if (rows.isEmpty) return null;
    final ms = int.tryParse(rows.first['value']?.toString() ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<int> getServicesCount() async {
    final d = await db;
    final r = await d.rawQuery('SELECT COUNT(*) c FROM services');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// تفريغ كل البيانات المحلية
  Future<void> clearAll() async {
    final d = await db;
    for (final t in [
      'categories',
      'governorates',
      'regions',
      'specialties',
      'services',
      'schedules',
      'settings',
      'sync_meta',
    ]) {
      await d.delete(t);
    }
  }

  Future<void> close() async {
    final d = _db;
    if (d != null) {
      await d.close();
      _db = null;
    }
  }
}

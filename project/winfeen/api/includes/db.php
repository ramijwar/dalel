<?php
/**
 * اتصال قاعدة البيانات (SQLite) + إنشاء الجداول تلقائياً
 */

// ملاحظة: install.php يُعرّف APP_ROOT بنفسه قبل تضمين هذا الملف،
// لذا نتحقق أولاً لتفادي تحذير «الثابت مُعرَّف مسبقاً».
if (!defined('APP_ROOT')) {
    define('APP_ROOT', dirname(__DIR__));
}

function db(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $file = APP_ROOT . '/storage/app.sqlite';
    $dir  = dirname($file);
    if (!is_dir($dir)) {
        mkdir($dir, 0775, true);
    }

    $pdo = new PDO('sqlite:' . $file);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->exec('PRAGMA journal_mode = WAL');
    $pdo->exec('PRAGMA foreign_keys = ON');

    migrate($pdo);

    return $pdo;
}

function migrate(PDO $pdo): void
{
    $pdo->exec("CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        full_name TEXT DEFAULT '',
        birth_date TEXT DEFAULT NULL,
        avatar TEXT DEFAULT NULL,
        bio TEXT DEFAULT '',
        role TEXT NOT NULL DEFAULT 'user',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT
    )");

    $pdo->exec("CREATE TABLE IF NOT EXISTS regions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        zone TEXT NOT NULL DEFAULT 'city',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        UNIQUE(name, zone)
    )");

    $pdo->exec("CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        slug TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        singular TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT '📍',
        color TEXT NOT NULL DEFAULT '#2ec4b6',
        description TEXT DEFAULT '',
        route TEXT DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        layout TEXT NOT NULL DEFAULT 'card',
        features TEXT NOT NULL DEFAULT '{}',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )");

    $pdo->exec("CREATE TABLE IF NOT EXISTS services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        region_id INTEGER REFERENCES regions(id) ON DELETE SET NULL,
        owner_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        address TEXT DEFAULT '',
        phone TEXT DEFAULT '',
        whatsapp TEXT DEFAULT '',
        note TEXT DEFAULT '',
        meta TEXT DEFAULT '{}',
        photo TEXT DEFAULT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        layout TEXT DEFAULT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_verified INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT
    )");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_services_category ON services(category_id)");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_services_region ON services(region_id)");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_services_owner ON services(owner_id)");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_services_active ON services(is_active)");

    // جدول الاختصاصات الطبية
    $pdo->exec("CREATE TABLE IF NOT EXISTS specialties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon TEXT NOT NULL DEFAULT '🩺',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT
    )");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_specialties_active ON specialties(is_active)");

    // ترقية: إضافة عمود specialty_id لجدول services إن لم يكن موجوداً
    $cols = [];
    foreach ($pdo->query("PRAGMA table_info(services)")->fetchAll() as $r) {
        $cols[$r['name']] = true;
    }
    if (!isset($cols['specialty_id'])) {
        $pdo->exec("ALTER TABLE services ADD COLUMN specialty_id INTEGER REFERENCES specialties(id) ON DELETE SET NULL");
    }
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_services_specialty ON services(specialty_id)");

    $pdo->exec("CREATE TABLE IF NOT EXISTS schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_id INTEGER NOT NULL REFERENCES services(id) ON DELETE CASCADE,
        day INTEGER NOT NULL,
        opens TEXT NOT NULL,
        closes TEXT NOT NULL,
        is_24h INTEGER NOT NULL DEFAULT 0
    )");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_schedules_service ON schedules(service_id)");

    $pdo->exec("CREATE TABLE IF NOT EXISTS service_status (
        service_id INTEGER PRIMARY KEY REFERENCES services(id) ON DELETE CASCADE,
        mode TEXT NOT NULL DEFAULT 'auto',
        note TEXT DEFAULT '',
        on_duty INTEGER NOT NULL DEFAULT 0,
        duty_from TEXT DEFAULT NULL,
        duty_to TEXT DEFAULT NULL,
        updated_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
        expires_at TEXT DEFAULT NULL,
        updated_at TEXT
    )");

    $pdo->exec("CREATE TABLE IF NOT EXISTS service_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        region_id INTEGER REFERENCES regions(id) ON DELETE SET NULL,
        name TEXT NOT NULL,
        address TEXT DEFAULT '',
        phone TEXT DEFAULT '',
        whatsapp TEXT DEFAULT '',
        note TEXT DEFAULT '',
        meta TEXT DEFAULT '{}',
        want_to_manage INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        admin_note TEXT DEFAULT '',
        created_service_id INTEGER REFERENCES services(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )");

    $pdo->exec("CREATE TABLE IF NOT EXISTS activity_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        actor TEXT NOT NULL DEFAULT 'system',
        action TEXT NOT NULL,
        entity TEXT NOT NULL DEFAULT '',
        entity_id INTEGER DEFAULT NULL,
        message TEXT DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )");

    $pdo->exec("CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
    )");

    $pdo->exec("CREATE TABLE IF NOT EXISTS login_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ip TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )");

    // ══════════════════════════════════════════════════════════
    // هرمية الموقع: محافظة ← مدينة ← قرية
    // ══════════════════════════════════════════════════════════
    $pdo->exec("CREATE TABLE IF NOT EXISTS governorates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        slug TEXT,
        zone TEXT NOT NULL DEFAULT 'city',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )");

    // أعمدة الهرمية على المناطق (المدن والقرى)
    $rcols = [];
    foreach ($pdo->query("PRAGMA table_info(regions)")->fetchAll() as $r) { $rcols[$r['name']] = true; }
    if (!isset($rcols['governorate_id'])) {
        $pdo->exec("ALTER TABLE regions ADD COLUMN governorate_id INTEGER REFERENCES governorates(id) ON DELETE SET NULL");
    }
    if (!isset($rcols['parent_id'])) {
        $pdo->exec("ALTER TABLE regions ADD COLUMN parent_id INTEGER REFERENCES regions(id) ON DELETE CASCADE");
    }
    if (!isset($rcols['level'])) {
        $pdo->exec("ALTER TABLE regions ADD COLUMN level TEXT NOT NULL DEFAULT 'city'");
    }
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_regions_gov ON regions(governorate_id)");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_regions_parent ON regions(parent_id)");

    // محافظة الخدمة
    $scols2 = [];
    foreach ($pdo->query("PRAGMA table_info(services)")->fetchAll() as $r) { $scols2[$r['name']] = true; }
    if (!isset($scols2['governorate_id'])) {
        $pdo->exec("ALTER TABLE services ADD COLUMN governorate_id INTEGER REFERENCES governorates(id) ON DELETE SET NULL");
    }
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_services_gov ON services(governorate_id)");

    // محافظة الطلب المُقدَّم من المستخدم
    $qrcols = [];
    foreach ($pdo->query("PRAGMA table_info(service_requests)")->fetchAll() as $r) { $qrcols[$r['name']] = true; }
    if (!isset($qrcols['governorate_id'])) {
        $pdo->exec("ALTER TABLE service_requests ADD COLUMN governorate_id INTEGER REFERENCES governorates(id) ON DELETE SET NULL");
    }

    // ══════════════════════════════════════════════════════════════════
    //  الحقول الخاصة بالأقسام (نظام الحقول الديناميكية)
    // ══════════════════════════════════════════════════════════════════
    //  ملاحظة مهمة: كان هذان الجدولان يُنشَآن في install.php و migrate_fields.php
    //  فقط، فلم يكونا يُنشَآن عند نشر الكود على قاعدة بيانات قديمة أو عند استعادة
    //  نسخة احتياطية سابقة — فينهار /api/meta بخطأ SQL. الآن يُنشَآن مع كل طلب
    //  فيُصلح المخطط نفسه بنفسه، تماماً كباقي الجداول في هذه الدالة.
    // ══════════════════════════════════════════════════════════════════
    $pdo->exec("CREATE TABLE IF NOT EXISTS category_fields (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id  INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        field_key    TEXT NOT NULL,
        label        TEXT NOT NULL,
        type         TEXT NOT NULL DEFAULT 'select',
        required     INTEGER NOT NULL DEFAULT 0,
        placeholder  TEXT DEFAULT '',
        help         TEXT DEFAULT '',
        show_in_card INTEGER NOT NULL DEFAULT 1,
        filterable   INTEGER NOT NULL DEFAULT 0,
        sort_order   INTEGER NOT NULL DEFAULT 0,
        is_active    INTEGER NOT NULL DEFAULT 1,
        created_at   TEXT,
        UNIQUE(category_id, field_key)
    )");

    $pdo->exec("CREATE TABLE IF NOT EXISTS category_field_options (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        field_id   INTEGER NOT NULL REFERENCES category_fields(id) ON DELETE CASCADE,
        label      TEXT NOT NULL,
        value      TEXT NOT NULL,
        icon       TEXT DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active  INTEGER NOT NULL DEFAULT 1,
        created_at TEXT
    )");

    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_cf_category ON category_fields(category_id)");
    $pdo->exec("CREATE INDEX IF NOT EXISTS idx_cfo_field ON category_field_options(field_id)");

    // ── ترقية تقدّمية: أعمدة إضافية لحقول الأقسام ──
    $cfcols = [];
    foreach ($pdo->query("PRAGMA table_info(category_fields)")->fetchAll() as $r) { $cfcols[$r['name']] = true; }

    // وحدة تُلحَق بعد الرقم في العرض (ل.س · موقف · كم)
    if (!isset($cfcols['suffix'])) {
        $pdo->exec("ALTER TABLE category_fields ADD COLUMN suffix TEXT DEFAULT ''");
    }
    // للحقول المنطقية: تُخفى القيمة إن كانت «لا» (تمنع شرائح «لا» المتكررة في البطاقات)
    if (!isset($cfcols['hide_when_false'])) {
        $pdo->exec("ALTER TABLE category_fields ADD COLUMN hide_when_false INTEGER NOT NULL DEFAULT 0");
    }
}

/** تسجيل حدث في سجل النشاط */
function log_activity(string $action, string $entity = '', ?int $entityId = null, string $message = '', string $actor = 'system', ?int $userId = null): void
{
    try {
        $st = db()->prepare("INSERT INTO activity_log (user_id, actor, action, entity, entity_id, message) VALUES (?,?,?,?,?,?)");
        $st->execute([$userId, $actor, $action, $entity, $entityId, $message]);
    } catch (\Throwable $e) {
        // لا نوقف الطلب بسبب فشل التسجيل
    }
}

function setting(string $key, ?string $default = null): ?string
{
    static $cache = null;
    if ($cache === null) {
        $cache = [];
        foreach (db()->query("SELECT key, value FROM settings") as $row) {
            $cache[$row['key']] = $row['value'];
        }
    }
    return $cache[$key] ?? $default;
}

function set_setting(string $key, string $value): void
{
    $st = db()->prepare("INSERT INTO settings (key, value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value = excluded.value");
    $st->execute([$key, $value]);
}

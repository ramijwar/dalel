<?php
/**
 * ══════════════════════════════════════════════════════════════════════
 *  مُثبّت قاعدة البيانات — دليل الدير
 * ══════════════════════════════════════════════════════════════════════
 *
 *  يبني قاعدة بيانات جديدة بكامل جداولها، بلا أي بيانات،
 *  ثم ينشئ حساب مدير واحد فقط.
 *
 *  ▸ التشغيل من المتصفح:
 *      https://t3lam.site/dalel/api/install.php?confirm=yes
 *
 *  ▸ التشغيل من الطرفية:
 *      php install.php
 *
 *  ⚠️ يحذف قاعدة البيانات الحالية (مع نسخة احتياطية تلقائية).
 *
 * ══════════════════════════════════════════════════════════════════════
 */

declare(strict_types=1);

// ─── الثوابت ───
define('APP_ROOT', __DIR__);
define('DB_FILE', APP_ROOT . '/storage/app.sqlite');
define('KEY_FILE', APP_ROOT . '/storage/secret.key');

/** حساب المدير الوحيد الذي يُنشأ */
const ADMIN_PHONE    = '0936651837';
const ADMIN_PASSWORD = '123456';
const ADMIN_NAME     = 'مدير النظام';

$isCli = PHP_SAPI === 'cli';

if (!$isCli) {
    header('Content-Type: text/html; charset=utf-8');
}

/* ══════════════════════════════════════════════════════════════════════
 *  🔒 الحماية — يسبق أي عمل مدمّر
 * ══════════════════════════════════════════════════════════════════════
 *  هذا السكربت يحذف قاعدة البيانات. كان يُشغَّل من الويب بمجرد
 *  ?confirm=yes بلا أي مصادقة — أي أن أي زائر يستطيع محو الموقع.
 *
 *  الآن: إن وُجد حساب مدير فلا بد من رمز مدير صالح،
 *        وإن لم يوجد (تثبيت أول) فيبقى مسموحاً فلا شيء لنُفقده.
 * ══════════════════════════════════════════════════════════════════════ */
require_once __DIR__ . '/includes/maintenance.php';
require_maintenance_access('install.php');

/* ══════════════════════════════════════════════════════════════════════
 *  مساعدات العرض
 * ══════════════════════════════════════════════════════════════════════ */

$log = [];

function say(string $msg, string $kind = 'info'): void
{
    global $log, $isCli;
    $log[] = [$kind, $msg];
    if (!$isCli) {
        return;                       // نجمعها ونعرضها في النهاية
    }
    $icon = match ($kind) {
        'ok'   => "\033[32m  ✓\033[0m",
        'warn' => "\033[33m  !\033[0m",
        'err'  => "\033[31m  ✗\033[0m",
        'head' => "\033[36m",
        default => '  ·',
    };
    echo $kind === 'head' ? "\n{$icon}{$msg}\033[0m\n" : "{$icon} {$msg}\n";
}

function h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}

/* ══════════════════════════════════════════════════════════════════════
 *  التأكيد
 * ══════════════════════════════════════════════════════════════════════ */

if (!$isCli && ($_GET['confirm'] ?? '') !== 'yes') {
    $exists = is_file(DB_FILE);
    $size   = $exists ? round(filesize(DB_FILE) / 1024) : 0;
    ?>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>تثبيت قاعدة البيانات — دليل الدير</title>
<style>
  :root{--accent:#3b82f6;--accent-dark:#2563eb;--border:#e2e8f0;--muted:#64748b;--text:#0f172a}
  *{box-sizing:border-box}
  body{margin:0;font-family:"Segoe UI",Tahoma,sans-serif;background:#f8fafc;color:var(--text);
       display:grid;place-items:center;min-height:100vh;padding:24px}
  .box{background:#fff;border:1px solid var(--border);border-radius:14px;padding:28px;max-width:520px;width:100%;
       box-shadow:0 4px 16px rgba(15,23,42,.06)}
  h1{font-size:1.25rem;margin:0 0 6px}
  p{color:var(--muted);font-size:.9rem;line-height:1.8;margin:0 0 14px}
  .warn{background:#fef3c7;border:1px solid #fcd34d;color:#92400e;border-radius:10px;padding:12px 14px;
        font-size:.86rem;line-height:1.8;margin:16px 0}
  .info{background:#f1f5f9;border-radius:10px;padding:12px 14px;font-size:.85rem;line-height:1.9;margin:16px 0}
  .info b{color:var(--text)}
  .btn{display:inline-block;background:linear-gradient(135deg,var(--accent),var(--accent-dark));color:#fff;
       border:none;border-radius:999px;padding:11px 26px;font-size:.92rem;font-weight:700;
       text-decoration:none;cursor:pointer;font-family:inherit}
  .btn:hover{filter:brightness(1.07)}
  .btn--ghost{background:#fff;color:var(--muted);border:1px solid var(--border);margin-right:8px}
  code{background:#f1f5f9;padding:2px 7px;border-radius:5px;direction:ltr;display:inline-block;font-size:.85rem}
</style>
</head>
<body>
<div class="box">
  <h1>🗄️ تثبيت قاعدة بيانات جديدة</h1>
  <p>سيبني هذا المُثبّت كل جداول التطبيق من الصفر، <b>بلا أي بيانات</b>،
     ثم ينشئ حساب مدير واحداً لتتمكن من الدخول.</p>

  <?php if ($exists): ?>
    <div class="warn">
      ⚠️ <b>تحذير:</b> توجد قاعدة بيانات حالية (<?= $size ?> ك.ب).<br>
      سيتم <b>حذفها واستبدالها</b> — مع الاحتفاظ بنسخة احتياطية تلقائية.
    </div>
  <?php endif; ?>

  <div class="info">
    <b>حساب المدير بعد التثبيت:</b><br>
    📱 الهاتف: <code><?= h(ADMIN_PHONE) ?></code><br>
    🔑 كلمة المرور: <code><?= h(ADMIN_PASSWORD) ?></code>
  </div>

  <p style="margin-bottom:18px">متابعة؟</p>
  <a class="btn" href="?confirm=yes">تأكيد التثبيت</a>
  <a class="btn btn--ghost" href="../">إلغاء</a>
</div>
</body>
</html>
    <?php
    exit;
}

/* ══════════════════════════════════════════════════════════════════════
 *  التنفيذ
 * ══════════════════════════════════════════════════════════════════════ */

say('بدء التثبيت', 'head');

try {
    // ─── ١) مجلد التخزين ───
    $dir = dirname(DB_FILE);
    if (!is_dir($dir)) {
        if (!mkdir($dir, 0775, true) && !is_dir($dir)) {
            throw new RuntimeException("تعذّر إنشاء مجلد التخزين: $dir");
        }
        say("أُنشئ مجلد التخزين", 'ok');
    } else {
        say('مجلد التخزين موجود', 'info');
    }

    if (!is_writable($dir)) {
        throw new RuntimeException("مجلد التخزين غير قابل للكتابة: $dir");
    }

    // ─── ٢) نسخة احتياطية من القاعدة الحالية ───
    if (is_file(DB_FILE)) {
        $backup = dirname(DB_FILE) . '/app.backup-' . date('Ymd-His') . '.sqlite';
        if (@copy(DB_FILE, $backup)) {
            say('نسخة احتياطية: ' . basename($backup), 'ok');
        } else {
            say('تعذّر إنشاء نسخة احتياطية — تابع بحذر', 'warn');
        }
        // احذف ملفات WAL/SHM المرافقة حتى لا تلتصق بالقاعدة القديمة
        foreach (['-wal', '-shm'] as $ext) {
            $f = DB_FILE . $ext;
            if (is_file($f)) {
                @unlink($f);
            }
        }
        @unlink(DB_FILE);
        say('حُذفت القاعدة القديمة', 'ok');
    }

    // ─── ٣) أنشئ القاعدة ───
    $pdo = new PDO('sqlite:' . DB_FILE);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->exec('PRAGMA journal_mode = WAL');
    $pdo->exec('PRAGMA foreign_keys = ON');
    say('أُنشئ ملف القاعدة', 'ok');

    // ─── ٤) الجداول (داخل معاملة واحدة) ───
    say('بناء الجداول', 'head');
    $pdo->beginTransaction();

    $tables = [];

    // ═══ المستخدمون ═══
    $tables['users'] = "CREATE TABLE users (
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
    )";

    // ═══ المحافظات ═══
    $tables['governorates'] = "CREATE TABLE governorates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        slug TEXT,
        zone TEXT NOT NULL DEFAULT 'city',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )";

    // ═══ المناطق (مدن وقرى) ═══
    $tables['regions'] = "CREATE TABLE regions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        zone TEXT NOT NULL DEFAULT 'city',
        sort_order INTEGER NOT NULL DEFAULT 0,
        governorate_id INTEGER REFERENCES governorates(id) ON DELETE SET NULL,
        parent_id INTEGER REFERENCES regions(id) ON DELETE CASCADE,
        level TEXT NOT NULL DEFAULT 'city',
        is_active INTEGER NOT NULL DEFAULT 1,
        UNIQUE(name, zone)
    )";

    // ═══ الأقسام ═══
    $tables['categories'] = "CREATE TABLE categories (
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
    )";

    // ═══ الاختصاصات الطبية (قائمة قديمة — احتياط) ═══
    $tables['specialties'] = "CREATE TABLE specialties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon TEXT NOT NULL DEFAULT '🩺',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT
    )";

    // ═══ الحقول الخاصة بالأقسام ═══
    $tables['category_fields'] = "CREATE TABLE category_fields (
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
    )";

    $tables['category_field_options'] = "CREATE TABLE category_field_options (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        field_id   INTEGER NOT NULL REFERENCES category_fields(id) ON DELETE CASCADE,
        label      TEXT NOT NULL,
        value      TEXT NOT NULL,
        icon       TEXT DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active  INTEGER NOT NULL DEFAULT 1,
        created_at TEXT
    )";

    // ═══ الخدمات ═══
    $tables['services'] = "CREATE TABLE services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        region_id INTEGER REFERENCES regions(id) ON DELETE SET NULL,
        governorate_id INTEGER REFERENCES governorates(id) ON DELETE SET NULL,
        specialty_id INTEGER REFERENCES specialties(id) ON DELETE SET NULL,
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
    )";

    // ═══ جداول الدوام ═══
    $tables['schedules'] = "CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_id INTEGER NOT NULL REFERENCES services(id) ON DELETE CASCADE,
        day INTEGER NOT NULL,
        opens TEXT NOT NULL,
        closes TEXT NOT NULL,
        is_24h INTEGER NOT NULL DEFAULT 0
    )";

    // ═══ حالة الخدمة ═══
    $tables['service_status'] = "CREATE TABLE service_status (
        service_id INTEGER PRIMARY KEY REFERENCES services(id) ON DELETE CASCADE,
        mode TEXT NOT NULL DEFAULT 'auto',
        note TEXT DEFAULT '',
        on_duty INTEGER NOT NULL DEFAULT 0,
        duty_from TEXT DEFAULT NULL,
        duty_to TEXT DEFAULT NULL,
        updated_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
        expires_at TEXT DEFAULT NULL,
        updated_at TEXT
    )";

    // ═══ طلبات الإضافة ═══
    $tables['service_requests'] = "CREATE TABLE service_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        region_id INTEGER REFERENCES regions(id) ON DELETE SET NULL,
        governorate_id INTEGER REFERENCES governorates(id) ON DELETE SET NULL,
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
    )";

    // ═══ سجل النشاط ═══
    $tables['activity_log'] = "CREATE TABLE activity_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        actor TEXT NOT NULL DEFAULT 'system',
        action TEXT NOT NULL,
        entity TEXT NOT NULL DEFAULT '',
        entity_id INTEGER DEFAULT NULL,
        message TEXT DEFAULT '',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )";

    // ═══ الإعدادات ═══
    $tables['settings'] = "CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
    )";

    // ═══ محاولات الدخول ═══
    $tables['login_attempts'] = "CREATE TABLE login_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ip TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )";

    foreach ($tables as $name => $sql) {
        $pdo->exec($sql);
        say("جدول {$name}", 'ok');
    }

    // ─── ٥) الفهارس ───
    say('بناء الفهارس', 'head');
    $indexes = [
        'idx_services_category'  => 'CREATE INDEX idx_services_category ON services(category_id)',
        'idx_services_region'    => 'CREATE INDEX idx_services_region ON services(region_id)',
        'idx_services_gov'       => 'CREATE INDEX idx_services_gov ON services(governorate_id)',
        'idx_services_owner'     => 'CREATE INDEX idx_services_owner ON services(owner_id)',
        'idx_services_active'    => 'CREATE INDEX idx_services_active ON services(is_active)',
        'idx_services_specialty' => 'CREATE INDEX idx_services_specialty ON services(specialty_id)',
        'idx_schedules_service'  => 'CREATE INDEX idx_schedules_service ON schedules(service_id)',
        'idx_specialties_active' => 'CREATE INDEX idx_specialties_active ON specialties(is_active)',
        'idx_regions_gov'        => 'CREATE INDEX idx_regions_gov ON regions(governorate_id)',
        'idx_regions_parent'     => 'CREATE INDEX idx_regions_parent ON regions(parent_id)',
        'idx_cf_category'        => 'CREATE INDEX idx_cf_category ON category_fields(category_id)',
        'idx_cfo_field'          => 'CREATE INDEX idx_cfo_field ON category_field_options(field_id)',
    ];
    foreach ($indexes as $name => $sql) {
        $pdo->exec($sql);
    }
    say(count($indexes) . ' فهرساً', 'ok');

    $pdo->commit();

    // ─── ٦) حساب المدير ───
    say('إنشاء حساب المدير', 'head');
    $hash = password_hash(ADMIN_PASSWORD, PASSWORD_BCRYPT, ['cost' => 10]);
    $st = $pdo->prepare(
        "INSERT INTO users (phone, password_hash, full_name, role, is_active, created_at)
         VALUES (?, ?, ?, 'admin', 1, datetime('now'))"
    );
    $st->execute([ADMIN_PHONE, $hash, ADMIN_NAME]);
    $adminId = (int) $pdo->lastInsertId();
    say("المستخدم #{$adminId} — " . ADMIN_PHONE, 'ok');

    // تحقّق فوري
    $check = $pdo->prepare('SELECT password_hash FROM users WHERE id = ?');
    $check->execute([$adminId]);
    if (!password_verify(ADMIN_PASSWORD, $check->fetchColumn())) {
        throw new RuntimeException('فشل التحقق من كلمة مرور المدير');
    }
    say('تحقّق كلمة المرور', 'ok');

    // ─── ٧) إعدادات أساسية (تهيئة، ليست بيانات) ───
    say('الإعدادات الأساسية', 'head');
    $defaults = [
        'site_name'      => 'دليل الدير',
        'tagline'        => 'دليل خدماتك اليومية في مكان واحد',
        'city'           => '',
        'whatsapp_admin' => '',
        'announcements'  => '[]',
        'ad_interval'    => '5',
    ];
    $ins = $pdo->prepare(
        "INSERT INTO settings (key, value) VALUES (?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value"
    );
    foreach ($defaults as $k => $v) {
        $ins->execute([$k, $v]);
    }
    say(count($defaults) . ' إعدادات (بلا بيانات خدمات)', 'ok');

    // ─── ٨) مفتاح توقيع جديد ───
    $secret = bin2hex(random_bytes(32));
    file_put_contents(KEY_FILE, $secret);
    @chmod(KEY_FILE, 0600);
    say('مفتاح جلسات جديد (سيُسجّل خروج الجميع)', 'warn');

    // ─── ٩) سجل التثبيت ───
    $pdo->prepare(
        "INSERT INTO activity_log (user_id, actor, action, entity, message)
         VALUES (?, 'system', 'install', 'database', ?)"
    )->execute([$adminId, 'تثبيت قاعدة بيانات جديدة']);
    say('سُجّل الحدث', 'ok');

    // ─── ١٠) تقرير ───
    $counts = [];
    foreach (array_keys($tables) as $t) {
        $counts[$t] = (int) $pdo->query("SELECT COUNT(*) FROM {$t}")->fetchColumn();
    }

    say('تم', 'head');
    say('قاعدة بيانات جديدة جاهزة — بلا أي بيانات', 'ok');
    say('المدير: ' . ADMIN_PHONE . ' / ' . ADMIN_PASSWORD, 'ok');

    $dbSize = round(filesize(DB_FILE) / 1024, 1);

    if (!$isCli) {
        // ═══ عرض HTML ═══
        ?>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>تم التثبيت — دليل الدير</title>
<style>
  :root{--accent:#3b82f6;--border:#e2e8f0;--muted:#64748b;--text:#0f172a;--ok:#16a34a}
  *{box-sizing:border-box}
  body{margin:0;font-family:"Segoe UI",Tahoma,sans-serif;background:#f8fafc;color:var(--text);
       display:grid;place-items:center;min-height:100vh;padding:24px}
  .box{background:#fff;border:1px solid var(--border);border-radius:14px;padding:28px;max-width:600px;width:100%;
       box-shadow:0 4px 16px rgba(15,23,42,.06)}
  h1{font-size:1.25rem;margin:0 0 4px}
  .sub{color:var(--muted);font-size:.88rem;margin:0 0 18px}
  .creds{background:linear-gradient(135deg,#eff6ff,#dbeafe);border:1px solid #bfdbfe;border-radius:12px;
         padding:16px 18px;margin:16px 0}
  .creds div{font-size:.95rem;line-height:2.1}
  code{background:#fff;padding:3px 10px;border-radius:6px;direction:ltr;display:inline-block;
       font-weight:700;font-size:.95rem;color:var(--accent)}
  table{width:100%;border-collapse:collapse;margin:16px 0;font-size:.86rem}
  th,td{text-align:right;padding:6px 10px;border-bottom:1px solid var(--border)}
  th{color:var(--muted);font-weight:600;font-size:.8rem}
  td:last-child{text-align:left;font-variant-numeric:tabular-nums}
  .warn{background:#fef3c7;border:1px solid #fcd34d;color:#92400e;border-radius:10px;
        padding:11px 14px;font-size:.84rem;line-height:1.8;margin:16px 0}
  .ok{color:var(--ok);font-weight:700}
  .btn{display:inline-block;background:var(--accent);color:#fff;border-radius:999px;
       padding:11px 26px;font-size:.92rem;font-weight:700;text-decoration:none;margin-top:8px}
</style>
</head>
<body>
<div class="box">
  <h1 class="ok">✓ تم بناء قاعدة البيانات</h1>
  <p class="sub">كل الجداول أُنشئت من الصفر — بلا أي بيانات (الحجم: <?= $dbSize ?> ك.ب)</p>

  <div class="creds">
    <div>📱 الهاتف: <code><?= h(ADMIN_PHONE) ?></code></div>
    <div>🔑 كلمة المرور: <code><?= h(ADMIN_PASSWORD) ?></code></div>
  </div>

  <table>
    <tr><th>الجدول</th><th>عدد الصفوف</th></tr>
    <?php foreach ($counts as $t => $c): ?>
      <tr><td><?= h($t) ?></td><td><?= $c ?></td></tr>
    <?php endforeach; ?>
  </table>

  <div class="warn">
    🔐 أُنشئ <b>مفتاح جلسات جديد</b> — سيُسجّل خروج أي مستخدم مسجّل سابقاً.<br>
    🗑️ <b>احذف هذا الملف الآن</b> (<code>api/install.php</code>) حتى لا يتمكن أحد من إعادة تشغيله.
  </div>

  <a class="btn" href="../">الذهاب إلى الموقع</a>
</div>
</body>
</html>
        <?php
    } else {
        echo "\n\033[1mالجداول:\033[0m\n";
        foreach ($counts as $t => $c) {
            printf("  %-26s %d صفاً\n", $t, $c);
        }
        echo "\n\033[1mحجم القاعدة:\033[0m {$dbSize} ك.ب\n";
        echo "\033[33mاحذف هذا الملف بعد الاستعمال.\033[0m\n\n";
    }

} catch (Throwable $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    $msg = $e->getMessage();
    say("فشل: {$msg}", 'err');

    if (!$isCli) {
        echo '<div style="background:#fee2e2;border:1px solid #fca5a5;color:#b91c1c;'
           . 'border-radius:12px;padding:18px;font-family:Tahoma">'
           . '<b>فشل التثبيت</b><br>' . h($msg) . '</div>';
    }
    exit(1);
}

<?php
/**
 * ══════════════════════════════════════════════════════════════
 *  ترحيل: نظام الحقول الخاصة للأقسام
 * ══════════════════════════════════════════════════════════════
 *  ١) ينشئ جدولي category_fields و category_field_options
 *  ٢) ينقل الاختصصاصات العشرين إلى حقل «الاختصاص» لقسم الأطباء
 *  ٣) ينقل قيم specialty_id في الخدمات إلى meta.specialty
 *  آمن للتشغيل أكثر من مرة (idempotent)
 * ══════════════════════════════════════════════════════════════
 */

require_once __DIR__ . '/includes/maintenance.php';

// 🔒 حماية: لا يُشغَّل من الويب بلا صلاحية مدير (يكتب في قاعدة البيانات)
require_maintenance_access('migrate_fields.php');

$dbFile = __DIR__ . '/storage/app.sqlite';
if (!is_file($dbFile)) {
    fwrite(STDERR, "قاعدة البيانات غير موجودة: $dbFile\n");
    exit(1);
}

// نسخة احتياطية قبل أي تعديل
$backup = __DIR__ . '/storage/app.before-fields-' . date('Ymd-His') . '.sqlite';
copy($dbFile, $backup);
echo "✓ نسخة احتياطية: " . basename($backup) . "\n";

$db = new PDO('sqlite:' . $dbFile);
$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$db->exec('PRAGMA foreign_keys = ON');

// ───────────────────────────────────────────
// ١) الجداول
// ───────────────────────────────────────────
$db->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS category_fields (
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
)
SQL);
echo "✓ جدول category_fields\n";

$db->exec(<<<'SQL'
CREATE TABLE IF NOT EXISTS category_field_options (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    field_id   INTEGER NOT NULL REFERENCES category_fields(id) ON DELETE CASCADE,
    label      TEXT NOT NULL,
    value      TEXT NOT NULL,
    icon       TEXT DEFAULT '',
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active  INTEGER NOT NULL DEFAULT 1,
    created_at TEXT
)
SQL);
echo "✓ جدول category_field_options\n";

$db->exec('CREATE INDEX IF NOT EXISTS idx_cf_category ON category_fields(category_id)');
$db->exec('CREATE INDEX IF NOT EXISTS idx_cfo_field ON category_field_options(field_id)');

// ───────────────────────────────────────────
// ٢) نقل الاختصاصات إلى قسم الأطباء
// ───────────────────────────────────────────
$docCat = $db->query("SELECT id FROM categories WHERE slug = 'doctors'")->fetchColumn();

// إن لم يوجد قسم أطباء بالـ slug، جرّب الاسم
if (!$docCat) {
    $docCat = $db->query("SELECT id FROM categories WHERE name LIKE '%أطباء%' OR name LIKE '%طبيب%'")->fetchColumn();
}
if (!$docCat) {
    echo "· لا يوجد قسم أطباء — تخطّي نقل الاختصاصات\n";
} else {
    $docCat = (int) $docCat;
    echo "· قسم الأطباء: #$docCat\n";

    // أنشئ حقل الاختصاص إن لم يكن موجوداً
    $fieldId = (int) ($db->query(
        "SELECT id FROM category_fields WHERE category_id = $docCat AND field_key = 'specialty'"
    )->fetchColumn() ?: 0);

    if (!$fieldId) {
        $st = $db->prepare(
            "INSERT INTO category_fields
             (category_id, field_key, label, type, required, placeholder, show_in_card, filterable, sort_order, is_active, created_at)
             VALUES (?, 'specialty', 'الاختصاص', 'select', 1, 'ابحث عن الاختصاص…', 1, 1, 0, 1, datetime('now'))"
        );
        $st->execute([$docCat]);
        $fieldId = (int) $db->lastInsertId();
        echo "✓ أُنشئ حقل «الاختصاص» #$fieldId\n";
    } else {
        echo "· حقل «الاختصاص» موجود مسبقاً #$fieldId\n";
    }

    // انسخ الاختصاصات كخيارات
    $existing = (int) $db->query("SELECT COUNT(*) FROM category_field_options WHERE field_id = $fieldId")->fetchColumn();
    if ($existing > 0) {
        echo "· الخيارات موجودة مسبقاً ($existing) — تخطّي\n";
    } else {
        $ins = $db->prepare(
            "INSERT INTO category_field_options (field_id, label, value, icon, sort_order, is_active, created_at)
             VALUES (?, ?, ?, ?, ?, 1, datetime('now'))"
        );
        $n = 0;
        foreach ($db->query("SELECT id, name, icon FROM specialties ORDER BY sort_order, id") as $sp) {
            $label = trim($sp['name']);
            if ($label === '') continue;
            // القيمة = مُعرّف الاختصاص — يبقى مستقراً حتى لو تغيّر الاسم
            $ins->execute([$fieldId, $label, (string) $sp['id'], $sp['icon'] ?? '', $n]);
            $n++;
        }
        echo "✓ نُسخت $n اختصاصاً كخيارات\n";
    }

    // ───────────────────────────────────────
    // ٣) انقل قيم specialty_id → meta.specialty
    // ───────────────────────────────────────
    $moved = 0;
    $rows = $db->query("SELECT id, specialty_id, meta FROM services WHERE specialty_id IS NOT NULL")->fetchAll();
    $upd  = $db->prepare("UPDATE services SET meta = ? WHERE id = ?");
    foreach ($rows as $r) {
        $meta = json_decode((string) ($r['meta'] ?: '{}'), true);
        if (!is_array($meta)) $meta = [];
        if (isset($meta['specialty'])) continue;   // منقول سابقاً
        $meta['specialty'] = (string) $r['specialty_id'];
        $upd->execute([json_encode($meta, JSON_UNESCAPED_UNICODE), $r['id']]);
        $moved++;
    }
    echo "✓ نُقلت $moved قيمة اختصاص إلى meta.specialty\n";
}

// ───────────────────────────────────────────
// ملخّص
// ───────────────────────────────────────────
echo "\n══ النتيجة ══\n";
echo "  الحقول:   " . $db->query("SELECT COUNT(*) FROM category_fields")->fetchColumn() . "\n";
echo "  الخيارات: " . $db->query("SELECT COUNT(*) FROM category_field_options")->fetchColumn() . "\n";
echo "  الخدمات:  " . $db->query("SELECT COUNT(*) FROM services")->fetchColumn() . "\n";

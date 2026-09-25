<?php
/**
 * ══════════════════════════════════════════════════════════════════════
 *  ترحيل ٢ — استكمال نظام الحقول الديناميكية
 * ══════════════════════════════════════════════════════════════════════
 *
 *  ما يفعله:
 *    ١) يحذف حقولاً كانت مخلّفات اختبار (حقل «سعر المعاينة» على الصيدليات)
 *    ٢) يُصلح حقولاً مُعرَّفة بشكل خاطئ (خيارات بنزين/مازوت المتشابكة)
 *    ٣) يُعيد تسمية مفتاح مُولَّد آلياً إلى اسم مقروء (f0d00cfdb → direction)
 *    ٤) يُعرّف الحقول الحقيقية لكل قسم، فتظهر بياناتها وتُدار من لوحة الإدارة
 *    ٥) يُصلح قيم meta المشوّهة ([] بدل {})
 *
 *  ✅ آمن للتشغيل أكثر من مرة (idempotent)
 *  ✅ يأخذ نسخة احتياطية تلقائياً قبل أي تعديل
 *  ✅ لا يحذف أي قيمة من خدمات المستخدمين
 *
 *  التشغيل من الطرفية:
 *      php api/migrate_fields_v2.php
 *
 *  ⚠️ لا يُشغَّل من الويب إلا برمز مدير صالح (انظر maintenance.php).
 * ══════════════════════════════════════════════════════════════════════
 */

$isCli = PHP_SAPI === 'cli';

require_once __DIR__ . '/includes/maintenance.php';
require_maintenance_access('migrate_fields_v2.php');

$dbFile = __DIR__ . '/storage/app.sqlite';
if (!is_file($dbFile)) {
    fwrite(STDERR, "✗ قاعدة البيانات غير موجودة: $dbFile\n");
    exit(1);
}

// ─── نسخة احتياطية قبل أي تعديل ───
$backup = __DIR__ . '/storage/app.before-fields-v2-' . date('Ymd-His') . '.sqlite';
copy($dbFile, $backup);

$pdo = new PDO('sqlite:' . $dbFile);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
$pdo->exec('PRAGMA foreign_keys = ON');

// ─── الأعمدة الجديدة (إن لم يكن db.php قد أضافها بعد) ───
$cols = [];
foreach ($pdo->query('PRAGMA table_info(category_fields)') as $r) { $cols[$r['name']] = true; }
if (!isset($cols['suffix'])) {
    $pdo->exec("ALTER TABLE category_fields ADD COLUMN suffix TEXT DEFAULT ''");
}
if (!isset($cols['hide_when_false'])) {
    $pdo->exec("ALTER TABLE category_fields ADD COLUMN hide_when_false INTEGER NOT NULL DEFAULT 0");
}

/* ══════════════════════════════════════════════════════════════
 *  تعريفات الحقول المستهدفة
 *  المفتاح = slug القسم
 * ══════════════════════════════════════════════════════════════ */

/** @var array<string, array{fields: list<array<string,mixed>>, drop: list<string>, rename?: array<string,string>}> */
$SPEC = [

    // ─── صيدليات بشرية ───
    // البيانات الفعلية: pharmacist · is_24h · delivery
    // حقل «سعر المعاينة» كان مخلّف اختبار من نسخ سابق — يُحذف
    'pharmacies' => [
        'drop' => ['price'],
        'fields' => [
            ['key' => 'pharmacist', 'label' => 'الصيدلاني', 'type' => 'text',    'show_in_card' => 1, 'placeholder' => 'اسم الصيدلاني المسؤول'],
            ['key' => 'is_24h',     'label' => 'دوام 24 ساعة', 'type' => 'boolean', 'show_in_card' => 1, 'hide_when_false' => 1],
            ['key' => 'delivery',   'label' => 'خدمة التوصيل',  'type' => 'boolean', 'show_in_card' => 1, 'hide_when_false' => 1],
        ],
    ],

    // ─── عيادات أطباء ───
    // البيانات الفعلية: specialty · specialty_icon · consult_fee · currency · hospital
    'doctors' => [
        'drop' => [],
        'fields' => [
            // specialty موجود مسبقاً بـ ٢٠ خياراً — نحدّث وصفه فقط ولا نمسّ خياراته
            ['key' => 'specialty',    'label' => 'الاختصاص',     'type' => 'select', 'required' => 1, 'show_in_card' => 1, 'filterable' => 1, 'placeholder' => 'ابحث عن الاختصاص…', 'keep_options' => true],
            ['key' => 'consult_fee',  'label' => 'سعر المعاينة', 'type' => 'number', 'show_in_card' => 1, 'suffix' => 'ل.س', 'placeholder' => '15000'],
            ['key' => 'hospital',     'label' => 'المستشفى',     'type' => 'text',   'show_in_card' => 1, 'placeholder' => 'مستشفى الرازي'],
        ],
    ],

    // ─── كازيات ───
    // لا خدمات بعد — نُصلح الحقول التي أُنشئت خطأً في اختبار سابق
    // (كان خيار «غير متوفر» في حقل «بنزين» يحمل قيمة «متوفر مازوت»)
    'stations' => [
        'drop' => [],
        'fields' => [
            ['key' => 'company',    'label' => 'الشركة',     'type' => 'text',    'show_in_card' => 1, 'placeholder' => 'كازية الجلاء'],
            ['key' => 'benzen',     'label' => 'بنزين',      'type' => 'boolean', 'show_in_card' => 1],
            ['key' => 'diesel',     'label' => 'مازوت',      'type' => 'boolean', 'show_in_card' => 1],
            ['key' => 'smart_card', 'label' => 'بطاقة ذكية', 'type' => 'boolean', 'show_in_card' => 0, 'hide_when_false' => 1],
        ],
    ],

    // ─── سرفيس واسعافية ───
    // لا خدمات بعد — نُعيد تسمية المفتاح المُولَّد ونُكمل الحقول
    'transport' => [
        'drop'   => [],
        'rename' => ['f0d00cfdb' => 'direction'],
        'fields' => [
            ['key' => 'direction', 'label' => 'اتجاه السفر',  'type' => 'select', 'show_in_card' => 1, 'filterable' => 1, 'required' => 1, 'keep_options' => true],
            ['key' => 'vehicle',   'label' => 'نوع المركبة',  'type' => 'select', 'show_in_card' => 1, 'filterable' => 1,
             'options' => [
                ['label' => 'سرفيس', 'value' => 'سرفيس', 'icon' => '🚐'],
                ['label' => 'باص',   'value' => 'باص',   'icon' => '🚌'],
                ['label' => 'إسعاف', 'value' => 'إسعاف', 'icon' => '🚑'],
             ]],
            ['key' => 'fare',      'label' => 'الأجرة',       'type' => 'number', 'show_in_card' => 1, 'suffix' => 'ل.س', 'placeholder' => '2000'],
            ['key' => 'frequency', 'label' => 'الانطلاق',     'type' => 'text',   'show_in_card' => 1, 'placeholder' => 'كل ١٥ دقيقة'],
        ],
    ],

    // ─── المخابر ───
    // قسم جديد بلا خدمات وبلا نموذج سابق — لا نخترع حقولاً.
    // يمكن تعريف حقوله من: لوحة الإدارة ← الأقسام ← المخابر ← الحقول الإضافية
    'laboratory' => [
        'drop'   => [],
        'fields' => [],
    ],
];

/* ══════════════════════════════════════════════════════════════
 *  التنفيذ
 * ══════════════════════════════════════════════════════════════ */

$report = ['renamed' => 0, 'dropped' => 0, 'created' => 0, 'updated' => 0, 'options' => 0, 'meta_fixed' => 0];
$say = function (string $icon, string $msg) use ($isCli) {
    if ($isCli) { echo "  $icon $msg\n"; }
    else { echo htmlspecialchars("$icon $msg", ENT_QUOTES, 'UTF-8') . "<br>\n"; }
};

if ($isCli) {
    echo "\n════════ استكمال نظام الحقول الديناميكية ════════\n\n";
    echo "✓ نسخة احتياطية: " . basename($backup) . "\n";
}

$pdo->beginTransaction();

try {
    foreach ($SPEC as $slug => $spec) {
        // ── إيجاد القسم ──
        $st = $pdo->prepare('SELECT id, name FROM categories WHERE slug = ?');
        $st->execute([$slug]);
        $cat = $st->fetch();
        if (!$cat) {
            $say('ⓘ', "القسم «$slug» غير موجود — تخطّي");
            continue;
        }
        $catId = (int) $cat['id'];
        $say('═', "{$cat['name']} (#$catId)");

        // ── ① إعادة تسمية مفاتيح مُولَّدة ──
        foreach (($spec['rename'] ?? []) as $from => $to) {
            $st = $pdo->prepare('SELECT id FROM category_fields WHERE category_id = ? AND field_key = ?');
            $st->execute([$catId, $from]);
            $fid = $st->fetchColumn();
            if (!$fid) { continue; }

            // لا نُعيد التسمية إن كان الاسم الجديد مشغولاً
            $st = $pdo->prepare('SELECT id FROM category_fields WHERE category_id = ? AND field_key = ?');
            $st->execute([$catId, $to]);
            if ($st->fetchColumn()) { continue; }

            $pdo->prepare('UPDATE category_fields SET field_key = ? WHERE id = ?')->execute([$to, $fid]);
            $say('↻', "أُعيد تسمية المفتاح: $from → $to");
            $report['renamed']++;
        }

        // ── ② حذف مخلّفات الاختبار ──
        foreach ($spec['drop'] as $key) {
            $st = $pdo->prepare('SELECT id FROM category_fields WHERE category_id = ? AND field_key = ?');
            $st->execute([$catId, $key]);
            $fid = $st->fetchColumn();
            if (!$fid) { continue; }

            // نتحقق أن لا خدمة تحمل قيمة لهذا المفتاح قبل الحذف
            $used = 0;
            foreach ($pdo->query("SELECT meta FROM services WHERE category_id = $catId AND meta LIKE '%\"$key\"%'") as $r) {
                $m = json_decode($r['meta'] ?: '{}', true);
                if (is_array($m) && array_key_exists($key, $m)) { $used++; }
            }
            if ($used > 0) {
                $say('⚠', "لم يُحذف «$key» — $used خدمة تستخدمه فعلاً");
                continue;
            }
            $pdo->prepare('DELETE FROM category_field_options WHERE field_id = ?')->execute([$fid]);
            $pdo->prepare('DELETE FROM category_fields WHERE id = ?')->execute([$fid]);
            $say('✗', "حُذف حقل مخلّف الاختبار: $key");
            $report['dropped']++;
        }

        // ── ③ تعريف الحقول ──
        $order = 0;
        foreach ($spec['fields'] as $f) {
            $st = $pdo->prepare('SELECT id, type FROM category_fields WHERE category_id = ? AND field_key = ?');
            $st->execute([$catId, $f['key']]);
            $existing = $st->fetch();

            $data = [
                'label'           => $f['label'],
                'type'            => $f['type'],
                'required'        => !empty($f['required']) ? 1 : 0,
                'placeholder'     => $f['placeholder'] ?? '',
                'help'            => $f['help'] ?? '',
                'show_in_card'    => !empty($f['show_in_card']) ? 1 : 0,
                'filterable'      => !empty($f['filterable']) ? 1 : 0,
                'suffix'          => $f['suffix'] ?? '',
                'hide_when_false' => !empty($f['hide_when_false']) ? 1 : 0,
                'sort_order'      => $order,
                'is_active'       => 1,
            ];
            $order++;

            if ($existing) {
                $fid = (int) $existing['id'];
                $typeChanged = ($existing['type'] !== $f['type']);

                $set = implode(', ', array_map(fn($k) => "$k = ?", array_keys($data)));
                $pdo->prepare("UPDATE category_fields SET $set WHERE id = ?")
                    ->execute([...array_values($data), $fid]);
                $say('↻', "حُدِّث الحقل: {$f['key']} ({$f['label']})");
                $report['updated']++;

                // تغيّر النوع (قائمة ← منطقي مثلاً): الخيارات القديمة لم تعد صالحة
                if ($typeChanged && $f['type'] !== 'select') {
                    $n = $pdo->prepare('DELETE FROM category_field_options WHERE field_id = ?');
                    $n->execute([$fid]);
                    if ($n->rowCount() > 0) {
                        $say('✗', 'حُذفت خيارات قديمة (' . $n->rowCount() . ') لتغيّر النوع');
                    }
                }
            } else {
                $data['category_id'] = $catId;
                $data['field_key']   = $f['key'];
                $data['created_at']  = date('c');
                $cols2 = implode(', ', array_keys($data));
                $ph    = implode(', ', array_fill(0, count($data), '?'));
                $pdo->prepare("INSERT INTO category_fields ($cols2) VALUES ($ph)")
                    ->execute(array_values($data));
                $fid = (int) $pdo->lastInsertId();
                $say('+', "أُنشئ الحقل: {$f['key']} ({$f['label']})");
                $report['created']++;
            }

            // ── ④ خيارات القائمة ──
            if ($f['type'] === 'select' && empty($f['keep_options']) && !empty($f['options'])) {
                $pdo->prepare('DELETE FROM category_field_options WHERE field_id = ?')->execute([$fid]);
                $ins = $pdo->prepare(
                    'INSERT INTO category_field_options (field_id, label, value, icon, sort_order, is_active, created_at)
                     VALUES (?,?,?,?,?,1,datetime(\'now\'))'
                );
                $i = 0;
                foreach ($f['options'] as $o) {
                    $ins->execute([$fid, $o['label'], $o['value'] ?? $o['label'], $o['icon'] ?? '', $i]);
                    $i++;
                    $report['options']++;
                }
                $say('+', "أُضيف $i خياراً لـ {$f['key']}");
            }
        }
        echo "\n";
    }

    // ── ⑤ إصلاح قيم meta المشوّهة ([] بدل {}) ──
    $bad = $pdo->query("SELECT id, meta FROM services WHERE meta IS NOT NULL AND meta != '' AND substr(trim(meta),1,1) != '{'")->fetchAll();
    foreach ($bad as $r) {
        $decoded = json_decode($r['meta'], true);
        if (is_array($decoded) && $decoded === []) {
            $pdo->prepare('UPDATE services SET meta = ? WHERE id = ?')->execute(['{}', $r['id']]);
            $report['meta_fixed']++;
        }
    }
    if ($report['meta_fixed'] > 0) {
        $say('✓', "أُصلحت {$report['meta_fixed']} قيمة meta مشوّهة ([] ← {})");
    }

    $pdo->commit();

} catch (\Throwable $e) {
    $pdo->rollBack();
    $say('✗', 'فشل الترحيل — أُعيدت كل التغييرات: ' . $e->getMessage());
    if ($isCli) {
        echo "\n  النسخة الاحتياطية محفوظة في: " . basename($backup) . "\n\n";
    }
    exit(1);
}

if ($isCli) {
    echo "════════════════════════════════════════════════\n";
    echo "  إعادة التسمية : {$report['renamed']}\n";
    echo "  حُذف           : {$report['dropped']}\n";
    echo "  أُنشئ          : {$report['created']}\n";
    echo "  حُدِّث          : {$report['updated']}\n";
    echo "  خيارات         : {$report['options']}\n";
    echo "  meta مُصلَح    : {$report['meta_fixed']}\n";
    echo "════════════════════════════════════════════════\n\n";

    // ── عرض الحالة النهائية ──
    echo "  حالة الحقول الآن:\n\n";
    $sql = "SELECT c.name cat, f.field_key, f.label, f.type, f.required, f.show_in_card,
                   f.filterable, f.suffix, f.hide_when_false,
                   (SELECT COUNT(*) FROM category_field_options o WHERE o.field_id = f.id AND o.is_active = 1) opts,
                   (SELECT COUNT(*) FROM services s WHERE s.category_id = c.id) svc
              FROM category_fields f
              JOIN categories c ON c.id = f.category_id
             WHERE f.is_active = 1
             ORDER BY c.sort_order, c.id, f.sort_order, f.id";
    foreach ($pdo->query($sql) as $r) {
        $flags = [];
        if ((int) $r['required'])     $flags[] = 'إلزامي';
        if ((int) $r['show_in_card']) $flags[] = 'بطاقة';
        if ((int) $r['filterable'])   $flags[] = 'فلتر';
        if ((int) $r['hide_when_false']) $flags[] = 'إخفاء-لا';
        if ($r['suffix'] !== '')      $flags[] = 'وحدة=' . $r['suffix'];
        if ((int) $r['opts'])         $flags[] = $r['opts'] . ' خيار';
        printf("    %-16s %-12s %-14s %-9s %s\n",
            $r['cat'], $r['field_key'], $r['label'], $r['type'],
            implode(' · ', $flags) . ($r['svc'] ? "   [{$r['svc']} خدمة]" : ''));
    }
    echo "\n  ⚠️  احذف هذا الملف بعد التشغيل إن أردت (اختياري).\n\n";
    echo "  للتشغيل عبر الويب يلزم رمز مدير صالح.\n\n";
}

echo $isCli ? '' : '<p>تم الترحيل بنجاح.</p>';
exit(0);

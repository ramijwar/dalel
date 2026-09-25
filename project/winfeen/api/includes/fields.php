<?php
/**
 * ══════════════════════════════════════════════════════════════
 *  محرّك الحقول الخاصة للأقسام
 * ══════════════════════════════════════════════════════════════
 *  كل قسم يمكن أن يمتلك حقولاً إضافية تُعرَّف من لوحة الإدارة.
 *  الأنواع المدعومة: select | text | textarea | number | boolean
 *  قيم الحقول تُحفظ داخل services.meta بمفتاح الحقل (field_key).
 *
 *  حلّ القيم متسامح مع الصيغتين القديمتين:
 *    • قيمة = مُعرّف الخيار   (الصيغة الجديدة، مستقرّة)
 *    • قيمة = نص الخيار       (الصيغة القديمة، بيانات ما قبل الترحيل)
 *  في الحالتين يرجع النظام كائناً جاهزاً للعرض.
 * ══════════════════════════════════════════════════════════════
 */

const FIELD_TYPES = ['select', 'text', 'textarea', 'number', 'boolean'];

function field_types(): array
{
    return FIELD_TYPES;
}

/**
 * حقول قسم واحد، مع خيارات كل حقل من نوع قائمة
 */
function category_fields_list(int $categoryId): array
{
    if ($categoryId <= 0) return [];
    $pdo = db();

    $st = $pdo->prepare(
        "SELECT id, category_id, field_key, label, type, required, placeholder, help,
                show_in_card, filterable, sort_order, is_active, suffix, hide_when_false
           FROM category_fields
          WHERE category_id = ? AND is_active = 1
          ORDER BY sort_order, id"
    );
    $st->execute([$categoryId]);
    $fields = $st->fetchAll();
    if (!$fields) return [];

    // خيارات كل الحقول دفعةً واحدة (تجنّب N+1)
    $ids  = array_map(fn($f) => (int) $f['id'], $fields);
    $in   = implode(',', array_fill(0, count($ids), '?'));
    $os   = $pdo->prepare(
        "SELECT id, field_id, label, value, icon, sort_order, is_active
           FROM category_field_options
          WHERE field_id IN ($in) AND is_active = 1
          ORDER BY sort_order, id"
    );
    $os->execute($ids);

    $byField = [];
    foreach ($os->fetchAll() as $o) {
        $byField[(int) $o['field_id']][] = [
            'id'    => (int) $o['id'],
            'label' => $o['label'],
            'value' => $o['value'],
            'icon'  => $o['icon'] ?? '',
        ];
    }

    $out = [];
    foreach ($fields as $f) {
        $out[] = [
            'id'          => (int) $f['id'],
            'key'         => $f['field_key'],
            'label'       => $f['label'],
            'type'        => $f['type'],
            'required'    => (bool) (int) $f['required'],
            'placeholder' => $f['placeholder'] ?? '',
            'help'        => $f['help'] ?? '',
            'show_in_card' => (bool) (int) $f['show_in_card'],
            'filterable'  => (bool) (int) $f['filterable'],
            'sort_order'  => (int) $f['sort_order'],
            'suffix'      => (string) ($f['suffix'] ?? ''),
            'hide_when_false' => (bool) (int) ($f['hide_when_false'] ?? 0),
            'options'     => $byField[(int) $f['id']] ?? [],
        ];
    }
    return $out;
}

/**
 * حقول عدة أقسام دفعةً واحدة (لـ /meta)
 * يرجع: [ categoryId => [fields…] ]
 */
function category_fields_map(array $categoryIds): array
{
    $ids = array_values(array_filter(array_map('intval', $categoryIds)));
    if (!$ids) return [];

    $pdo  = db();
    $in   = implode(',', array_fill(0, count($ids), '?'));
    $st   = $pdo->prepare(
        "SELECT id, category_id, field_key, label, type, required, placeholder, help,
                show_in_card, filterable, sort_order, suffix, hide_when_false
           FROM category_fields
          WHERE category_id IN ($in) AND is_active = 1
          ORDER BY sort_order, id"
    );
    $st->execute($ids);
    $fields = $st->fetchAll();
    if (!$fields) return [];

    $fIds = array_map(fn($f) => (int) $f['id'], $fields);
    $in2  = implode(',', array_fill(0, count($fIds), '?'));
    $os   = $pdo->prepare(
        "SELECT id, field_id, label, value, icon, sort_order
           FROM category_field_options
          WHERE field_id IN ($in2) AND is_active = 1
          ORDER BY sort_order, id"
    );
    $os->execute($fIds);

    $byField = [];
    foreach ($os->fetchAll() as $o) {
        $byField[(int) $o['field_id']][] = [
            'id'    => (int) $o['id'],
            'label' => $o['label'],
            'value' => $o['value'],
            'icon'  => $o['icon'] ?? '',
        ];
    }

    $map = [];
    foreach ($fields as $f) {
        $cid = (int) $f['category_id'];
        $map[$cid][] = [
            'id'          => (int) $f['id'],
            'key'         => $f['field_key'],
            'label'       => $f['label'],
            'type'        => $f['type'],
            'required'    => (bool) (int) $f['required'],
            'placeholder' => $f['placeholder'] ?? '',
            'help'        => $f['help'] ?? '',
            'show_in_card' => (bool) (int) $f['show_in_card'],
            'filterable'  => (bool) (int) $f['filterable'],
            'sort_order'  => (int) $f['sort_order'],
            'suffix'      => (string) ($f['suffix'] ?? ''),
            'hide_when_false' => (bool) (int) ($f['hide_when_false'] ?? 0),
            'options'     => $byField[(int) $f['id']] ?? [],
        ];
    }
    return $map;
}

/**
 * يحلّ قيم حقول خدمة معيّنة إلى كائنات جاهزة للعرض
 *
 * @param int   $categoryId قسم الخدمة
 * @param array $meta       محتوى services.meta
 * @return array            [{key,label,type,value,display,icon}]
 */
/**
 * هل هذا الحقل «سعر»؟ يقرر أيقونته (💵 لسعر المعاينة · # للأرقام الأخرى).
 *
 * الفحص بالمفتاح الإنجليزي والاسم العربي معاً، فيعمل مع أي قسم يضيف المدير
 * فيه حقلاً اسمه price أو cost أو «تكلفة» أو «أجرة» — بلا قائمة أقسام ثابتة.
 */
function is_price_field(string $key, string $label = ''): bool
{
    $hay = mb_strtolower($key . ' ' . $label, 'UTF-8');
    foreach (['price', 'cost', 'fee', 'fare', 'charge', 'tuition', 'salary'] as $w) {
        if (str_contains($hay, $w)) return true;
    }
    foreach (['سعر', 'أسعار', 'ثمن', 'تكلفة', 'كلفة', 'أجرة', 'اجرة', 'أجور',
              'رسوم', 'رسم', 'مبلغ', 'دفعة', 'اشتراك', 'بدل'] as $w) {
        if (mb_strpos($hay, $w, 0, 'UTF-8') !== false) return true;
    }
    return false;
}

function resolve_service_fields(int $categoryId, array $meta): array
{
    $fields = category_fields_list($categoryId);
    if (!$fields) return [];

    $out = [];
    foreach ($fields as $f) {
        $key = $f['key'];
        if (!array_key_exists($key, $meta)) continue;

        $raw  = $meta[$key];
        $type = $f['type'];

        // ─── حقل منطقي ───
        if ($type === 'boolean') {
            $val = filter_var($raw, FILTER_VALIDATE_BOOLEAN);

            // «إخفاء عند لا»: لا نُخرج الحقل إطلاقاً إن كانت قيمته «لا».
            // يُستخدم في البطاقات لتفادي شرائح «لا» المتكررة
            // (مثال: ٢٠٠ صيدلية بلا توصيل — لا داعي لعرض «التوصيل: لا» لكلٍّ منها).
            if (!$val && !empty($f['hide_when_false'])) {
                continue;
            }

            $out[] = [
                'key'     => $key,
                'label'   => $f['label'],
                'type'    => $type,
                'value'   => $val ? '1' : '0',
                'display' => $val ? 'نعم' : 'لا',
                'icon'    => $val ? 'check' : 'x',
            ];
            continue;
        }

        // ─── قائمة: طابق القيمة مع الخيارات ───
        if ($type === 'select') {
            $rawStr = is_scalar($raw) ? (string) $raw : '';
            if ($rawStr === '') continue;

            $match    = null;
            $fallback = null;

            foreach ($f['options'] as $o) {
                // مطابقة تامة مع المُعرّف (الصيغة الجديدة)
                if ((string) $o['value'] === $rawStr) { $match = $o; break; }
                // مطابقة تامة مع النص — تُحفظ كاحتياط
                if ($fallback === null && mb_strtolower((string) $o['label']) === mb_strtolower($rawStr)) {
                    $fallback = $o;
                }
            }

            // جرّب المُعرّف الرقمي أيضاً (قيمة قديمة = id الاختصاص)
            if (!$match && ctype_digit($rawStr)) {
                foreach ($f['options'] as $o) {
                    if ((string) $o['id'] === $rawStr) { $match = $o; break; }
                }
            }
            $match ??= $fallback;

            // ─── حماية من عرض مُعرّف خام ───
            // إن كان المحفوظ رقماً لا يقابل أي خيار (اختصاص حُذف من القائمة مثلاً)
            // فالقيمة بلا معنى للمستخدم. عرض «9» أسوأ من عدم عرض شيء إطلاقاً.
            // القيم الحرة غير الرقمية تبقى كما هي (بيانات قديمة محفوظة كنص).
            if (!$match && ctype_digit($rawStr)) {
                continue;
            }

            $out[] = [
                'key'     => $key,
                'label'   => $f['label'],
                'type'    => $type,
                'value'   => $rawStr,
                // إن لم يُعثر على خيار مطابق، اعرض القيمة الخام كما هي
                'display' => $match['label'] ?? $rawStr,
                'icon'    => $match['icon'] ?? '',
            ];
            continue;
        }

        // ─── نص / رقم / نص طويل ───
        if (is_bool($raw))      $raw = $raw ? 'نعم' : 'لا';
        elseif (is_array($raw)) $raw = json_encode($raw, JSON_UNESCAPED_UNICODE);
        $rawStr = (string) $raw;
        if ($rawStr === '') continue;

        // الوحدة (ل.س · موقف · كم) تُلحَق بعد الرقم لتظهر «‎15,000 ل.س» كما اعتاد المستخدم
        $suffix = trim((string) ($f['suffix'] ?? ''));
        if ($type === 'number') {
            $display = number_format((float) $rawStr) . ($suffix !== '' ? ' ' . $suffix : '');
        } else {
            $display = $rawStr;
        }

        $out[] = [
            'key'     => $key,
            'label'   => $f['label'],
            'type'    => $type,
            'value'   => $rawStr,
            'display' => $display,
            'icon'    => ($type === 'number' && is_price_field($key, (string) $f['label']))
                ? 'banknote'      // 💵 حقول الأسعار
                : ($type === 'number' ? 'hash' : 'type'),
        ];
    }
    return $out;
}

/**
 * يتحقق من قيم الحقول المُرسالة ويُعيدها مطبَّعة
 * يفشل إن كان حقل إلزامي فارغاً أو خياراً غير موجود
 */
function validate_fields_values(int $categoryId, array $in): array
{
    $fields = category_fields_list($categoryId);
    if (!$fields) return [];

    $out = [];
    foreach ($fields as $f) {
        $key = $f['key'];
        if (!array_key_exists($key, $in)) {
            if ($f['required']) fail("حقل «{$f['label']}» مطلوب", 422);
            continue;
        }
        $raw = $in[$key];

        switch ($f['type']) {
            case 'boolean':
                $out[$key] = filter_var($raw, FILTER_VALIDATE_BOOLEAN) ? 1 : 0;
                break;

            case 'number':
                if ($raw === '' || $raw === null) {
                    if ($f['required']) fail("حقل «{$f['label']}» مطلوب", 422);
                    $out[$key] = null;
                } else {
                    if (!is_numeric($raw)) fail("حقل «{$f['label']}» يجب أن يكون رقماً", 422);
                    $out[$key] = is_float($raw + 0) ? (float) $raw : (int) $raw;
                }
                break;

            case 'select':
                $v = is_scalar($raw) ? (string) $raw : '';
                if ($v === '') {
                    if ($f['required']) fail("حقل «{$f['label']}» مطلوب", 422);
                    $out[$key] = null;
                    break;
                }
                // اقبل المُعرّف أو نص الخيار
                $ok = false;
                foreach ($f['options'] as $o) {
                    if ((string) $o['value'] === $v || (string) $o['id'] === $v) { $ok = true; break; }
                }
                if (!$ok) fail("قيمة حقل «{$f['label']}» غير صالحة", 422);
                $out[$key] = $v;
                break;

            default: // text | textarea
                $v = is_scalar($raw) ? trim((string) $raw) : '';
                if ($v === '' && $f['required']) fail("حقل «{$f['label']}» مطلوب", 422);
                $out[$key] = $v;
        }
    }
    return $out;
}

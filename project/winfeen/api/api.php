<?php
/**
 * واجهة برمجية واحدة (PHP + SQLite) لتطبيق «دليل الدير»
 * جميع المسارات تبدأ بـ /api
 */

require __DIR__ . '/includes/db.php';
require __DIR__ . '/includes/token.php';
require __DIR__ . '/includes/auth.php';
require __DIR__ . '/includes/helpers.php';
require __DIR__ . '/includes/fields.php';

date_default_timezone_set(APP_TIMEZONE);

/**
 * الطابع الزمني الحالي بتوقيت التطبيق (APP_TIMEZONE) بصيغة SQL.
 * ملاحظة: الطابع الزمني الافتراضي في SQLite يكون بتوقيت UTC، بينما
 * الواجهة تقرأ التواريخ بتوقيت التطبيق — لذا نولّد القيمة من PHP للضمان.
 */
function now_sql(): string
{
    return app_now()->format('Y-m-d H:i:s');
}

// هل نُشغَّل مباشرة (وليس عبر router.php)؟
$_wf_direct = str_contains($_SERVER['SCRIPT_NAME'] ?? '', '/api/');

// ---------- CORS ----------
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$_wf_reqPath = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
// إزالة basePath إن وُجد (في حال التشغيل من مجلد فرعي)
$_wf_scriptDir = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME']));
$_wf_base = rtrim($_wf_scriptDir, '/');
if ($_wf_base !== '' && $_wf_base !== '/' && str_starts_with($_wf_reqPath, $_wf_base)) {
    $_wf_reqPath = substr($_wf_reqPath, strlen($_wf_base)) ?: '/';
}
$path   = trim($_wf_reqPath, '/');
// إذا كنا نُشغَّل مباشرة من api/index.php، لا حاجة لإزالة api/ من المسار
if (!$_wf_direct) {
    $path = preg_replace('#^api/?#', '', $path);
}
$path   = rtrim($path, '/');
$seg    = $path === '' ? [] : explode('/', $path);


function seg(int $i): ?string { return $GLOBALS['seg'][$i] ?? null; }
function arg(string $k, $d = null) { return $_GET[$k] ?? $d; }
function body_str(string $k, int $max = 500): string { return str_trim(body()[$k] ?? '', $max); }
function body_int(string $k): ?int { $v = body()[$k] ?? null; return ($v === null || $v === '') ? null : (int) $v; }

try {
    route();
} catch (\Throwable $e) {
    fail('خطأ في الخادم: ' . $e->getMessage(), 500);
}

// =============================================================
function route(): void
{
    $m  = $GLOBALS['method'];
    $s  = $GLOBALS['seg'];
    $r0 = $s[0] ?? '';

    if ($r0 === '' || $r0 === 'health') {
        ok(['app' => 'dalel-api', 'time' => app_now()->format('c'), 'php' => PHP_VERSION]);
    }

    // ---------- بيانات عامة ----------
    if ($r0 === 'meta' && $m === 'GET')       { api_meta(); return; }
    if ($r0 === 'home' && $m === 'GET')       { api_home(); return; }
    if ($r0 === 'stats' && $m === 'GET')      { api_stats(); return; }
    if ($r0 === 'categories' && $m === 'GET') { ok(['items' => categories_list()]); return; }
    if ($r0 === 'regions' && $m === 'GET')    { ok(['items' => regions_list(arg('zone'))]); return; }
    if ($r0 === 'governorates' && $m === 'GET') { ok(['items' => governorates_list()]); return; }
    if ($r0 === 'locations' && $m === 'GET')    { ok(['items' => location_tree()]); return; }
    if ($r0 === 'specialties' && $m === 'GET') {
        specialties_sync();
        ok(['items' => specialties_list()]);
        return;
    }
    if ($r0 === 'services' && $m === 'GET') {
        if (!isset($s[1])) { api_services(); return; }
        if (ctype_digit($s[1])) { api_service_detail((int) $s[1]); return; }
    }
    if ($r0 === 'service-requests' && $m === 'POST') { api_create_request(); return; }

    // ---------- المصادقة ----------
    if ($r0 === 'auth') {
        $a = $s[1] ?? '';
        if ($a === 'register' && $m === 'POST') { api_register(); return; }
        if ($a === 'login' && $m === 'POST')    { api_login(); return; }
        if ($a === 'me' && $m === 'GET') {
            $u = current_user();
            if ($u === null) fail('غير مسجل الدخول', 401);
            ok(['user' => public_user($u)]);
            return;
        }
    }

    // ---------- الملف الشخصي ----------
    if ($r0 === 'profile') {
        $u = require_auth();
        $a = $s[1] ?? '';
        if ($a === 'avatar' && $m === 'POST') { api_upload_avatar($u); return; }
        if ($m === 'PUT' || $m === 'POST')    { api_update_profile($u); return; }
        if ($m === 'GET')                     { ok(['user' => public_user($u)]); return; }
    }

    // ---------- خدماتي (صاحب الخدمة) ----------
    if ($r0 === 'my') {
        $u = require_auth();
        $a = $s[1] ?? '';
        if ($a === 'services' && $m === 'GET') { api_my_services($u); return; }
        if ($a === 'requests' && $m === 'GET') { api_my_requests($u); return; }
        if ($a === 'activity' && $m === 'GET') { api_my_activity($u); return; }
    }

    // ---------- تحكم صاحب الخدمة بخدمته ----------
    if ($r0 === 'owner' && ($s[1] ?? '') === 'services' && isset($s[2]) && ctype_digit($s[2])) {
        $u    = require_auth();
        $svc  = owned_service($u, (int) $s[2]);
        $what = $s[3] ?? '';
        if ($what === 'status' && $m === 'PUT')   { api_owner_status($u, $svc); return; }
        if ($what === 'schedule' && $m === 'PUT') { api_owner_schedule($u, $svc); return; }
        if ($what === '' && $m === 'PUT')         { api_owner_update($u, $svc); return; }
        if ($what === '' && $m === 'GET')         { api_owner_service($svc); return; }
    }

    // ---------- لوحة الإدارة ----------
    if ($r0 === 'admin') {
        require_admin();
        $a  = $s[1] ?? '';
        $id = (isset($s[2]) && ctype_digit($s[2])) ? (int) $s[2] : null;

        if ($a === 'stats' && $m === 'GET') { admin_stats(); return; }

        if ($a === 'services') {
            if ($m === 'GET' && $id === null) { admin_services_list(); return; }
            if ($m === 'GET')                 { admin_service_get((int) $id); return; }
            if ($m === 'POST')                { admin_service_create(); return; }
            if ($m === 'PUT' || $m === 'PATCH') { admin_service_update($id); return; }
            if ($m === 'DELETE')              { admin_service_delete($id); return; }
        }
        if ($a === 'categories') {
            if ($m === 'GET')                 { ok(['items' => categories_list(true)]); return; }
            if ($m === 'POST')                { admin_category_save(null); return; }
            if ($m === 'PUT' || $m === 'PATCH') { admin_category_save($id); return; }
            if ($m === 'DELETE')              { admin_category_delete($id); return; }
        }
        // ─── الحقول الخاصة بالأقسام ───
        if ($a === 'category-fields') {
            // خيارات حقل من نوع قائمة — تُفحص أولاً قبل مسار الحقل نفسه
            // /admin/category-fields/{fieldId}/options[/{optionId}]
            if (($s[3] ?? '') === 'options') {
                $fid = (int) ($id ?? 0);
                if ($m === 'POST')                  { admin_field_option_save($fid, null); return; }
                if ($m === 'PUT' || $m === 'PATCH') { admin_field_option_save($fid, isset($s[4]) ? (int) $s[4] : null); return; }
                if ($m === 'DELETE')                { admin_field_option_delete($fid, isset($s[4]) ? (int) $s[4] : null); return; }
            }
            // /admin/category-fields[/{id}]?category_id=38
            if ($m === 'GET')                   { admin_fields_list((int) (arg('category_id') ?: 0)); return; }
            if ($m === 'POST')                  { admin_field_save(null); return; }
            if ($m === 'PUT' || $m === 'PATCH') { admin_field_save($id); return; }
            if ($m === 'DELETE')                { admin_field_delete($id); return; }
        }

        if ($a === 'governorates') {
            if ($m === 'GET')                 { ok(['items' => governorates_list(true)]); return; }
            if ($m === 'POST')                { admin_governorate_save(null); return; }
            if ($m === 'PUT' || $m === 'PATCH') { admin_governorate_save($id); return; }
            if ($m === 'DELETE')              { admin_governorate_delete($id); return; }
        }
        if ($a === 'regions') {
            if ($m === 'GET')                 { ok(['items' => regions_list(arg('zone'), true)]); return; }
            if ($m === 'POST')                { admin_region_save(null); return; }
            if ($m === 'PUT' || $m === 'PATCH') { admin_region_save($id); return; }
            if ($m === 'DELETE')              { admin_region_delete($id); return; }
        }
        if ($a === 'requests') {
            if ($m === 'GET')                            { admin_requests_list(); return; }
            if (($s[3] ?? '') === 'approve' && $m === 'POST') { admin_request_approve((int) $id); return; }
            if (($s[3] ?? '') === 'reject' && $m === 'POST')  { admin_request_reject((int) $id); return; }
            if ($m === 'DELETE')                         { admin_request_delete((int) $id); return; }
        }
        if ($a === 'users') {
            if ($m === 'GET')                 { admin_users_list(); return; }
            if ($m === 'PUT' || $m === 'PATCH') { admin_user_update($id); return; }
            if ($m === 'DELETE')              { admin_user_delete($id); return; }
        }
        if ($a === 'activity' && $m === 'GET')  { admin_activity(); return; }
        if ($a === 'settings' && $m === 'PUT')  { admin_settings_save(); return; }
        if ($a === 'data' && $m === 'GET')      { admin_data_counts(); return; }
        if ($a === 'data' && $m === 'DELETE')   { admin_data_clear(); return; }
    }

    fail('مسار غير معروف: /api/' . implode('/', $s), 404);
}

// =============================================================
// استعلامات مساعدة
// =============================================================

function base_select(): string
{
    return "SELECT s.*, c.slug AS category_slug, c.name AS category_name, c.icon AS category_icon,
                   r.name AS region_name, r.zone AS region_zone,
                   r.level AS region_level, r.parent_id AS region_parent_id,
                   g.name AS governorate_name, g.slug AS governorate_slug,
                   pc.name AS city_name,
                   u.full_name AS owner_name, u.phone AS owner_phone,
                   ss.mode, ss.note AS status_note, ss.on_duty, ss.duty_from, ss.duty_to, ss.expires_at
            FROM services s
            JOIN categories c ON c.id = s.category_id
            LEFT JOIN regions r ON r.id = s.region_id
            LEFT JOIN governorates g ON g.id = s.governorate_id
            LEFT JOIN regions pc ON pc.id = r.parent_id
            LEFT JOIN users u ON u.id = s.owner_id
            LEFT JOIN service_status ss ON ss.service_id = s.id";
}

/** جلب جداول الدوام لمجموعة خدمات دفعة واحدة */
function schedules_map(array $ids): array
{
    if (!$ids) {
        return [];
    }
    $in = implode(',', array_map('intval', $ids));
    $rows = db()->query("SELECT * FROM schedules WHERE service_id IN ($in) ORDER BY day, opens")->fetchAll();
    $map = [];
    foreach ($rows as $r) {
        $map[(int) $r['service_id']][] = $r;
    }
    return $map;
}

function categories_list(bool $includeInactive = false): array
{
    $sql = "SELECT * FROM categories" . ($includeInactive ? "" : " WHERE is_active = 1") . " ORDER BY sort_order, id";
    $rows = db()->query($sql)->fetchAll();

    // حقول كل الأقسام في استعلام واحد
    $ids = array_map(fn($c) => (int) $c['id'], $rows);
    $fieldsMap = category_fields_map($ids);

    $out = [];
    foreach ($rows as $c) {
        $c['features'] = json_field($c['features']);
        $c['is_active'] = (bool) $c['is_active'];
        // الحقول الخاصة بهذا القسم (مع خياراتها)
        $c['fields'] = $fieldsMap[(int) $c['id']] ?? [];
        $out[] = $c;
    }
    return $out;
}

/** قائمة المحافظات النشطة */
function governorates_list(bool $includeInactive = false): array
{
    $sql = "SELECT g.*, (SELECT COUNT(*) FROM services s
                        WHERE s.governorate_id = g.id AND s.is_active = 1) AS services_count
            FROM governorates g"
         . ($includeInactive ? "" : " WHERE g.is_active = 1")
         . " ORDER BY g.sort_order, g.name";
    return db()->query($sql)->fetchAll();
}

/** شجرة الموقع: محافظات ← مدن ← قرى */
function location_tree(): array
{
    $govs = governorates_list();
    $govIds = array_column($govs, 'id');
    $cities = []; $villages = [];
    if ($govIds) {
        $in = implode(',', array_fill(0, count($govIds), '?'));
        $st = db()->prepare("SELECT id, governorate_id, name, level FROM regions
                             WHERE is_active = 1 AND level = 'city' AND governorate_id IN ($in)
                             ORDER BY name");
        $st->execute($govIds);
        $cities = $st->fetchAll();
        $st = db()->prepare("SELECT id, parent_id, name FROM regions
                             WHERE is_active = 1 AND level = 'village' AND parent_id IS NOT NULL
                             ORDER BY name");
        $st->execute();
        $villages = $st->fetchAll();
    }
    $byGov = [];
    foreach ($cities as $c) $byGov[$c['governorate_id']][] = $c;
    $vilByCity = [];
    foreach ($villages as $v) $vilByCity[$v['parent_id']][] = $v;

    foreach ($govs as &$g) {
        $g['cities'] = array_map(function ($c) use ($vilByCity) {
            $c['villages'] = $vilByCity[$c['id']] ?? [];
            return $c;
        }, $byGov[$g['id']] ?? []);
    }
    return $govs;
}

function regions_list(?string $zone = null, bool $includeInactive = false): array
{
    // نضيف اسم المحافظة واسم المدينة الأم ليظهر التسلسل الهرمي بوضوح
    $sql = "SELECT r.*,
                   g.name  AS governorate_name,
                   pc.name AS parent_name,
                   (SELECT COUNT(*) FROM services s WHERE s.region_id = r.id AND s.is_active = 1) AS services_count
            FROM regions r
            LEFT JOIN governorates g  ON g.id = r.governorate_id
            LEFT JOIN regions pc      ON pc.id = r.parent_id
            WHERE 1=1";
    $args = [];
    if ($zone && in_array($zone, ['city', 'rural'], true)) {
        $sql .= " AND r.zone = ?";
        $args[] = $zone;
    }
    if (!$includeInactive) {
        $sql .= " AND r.is_active = 1";
    }
    $sql .= " ORDER BY r.name COLLATE NOCASE";
    $st = db()->prepare($sql);
    $st->execute($args);
    return $st->fetchAll();
}

/**
 * قائمة الاختصاصات الطبية مع عدد الأطباء النشطين في كل منها.
 * تُستخدم في قسم الأطباء لتصفية النتائج حسب الاختصاص من قاعدة البيانات.
 */
function specialties_list(bool $withCounts = true): array
{
    // ملاحظة: حالة «يعمل الآن» تُحسب في PHP من جدول الدوام، لذا نكتفي هنا
    // بعدّ إجمالي الخدمات، وتحسب الواجهة عدد العاملين من العناصر المُعادة.
    $sql = "SELECT sp.id, sp.name, sp.icon, sp.sort_order";
    if ($withCounts) {
        $sql .= ",
            (SELECT COUNT(*) FROM services s
              WHERE s.specialty_id = sp.id AND s.is_active = 1) AS services_count";
    }
    $sql .= " FROM specialties sp WHERE sp.is_active = 1 ORDER BY sp.sort_order, sp.name COLLATE NOCASE";

    return db()->query($sql)->fetchAll();
}

/**
 * مزامنة الاختصاصات: تنشئ اختصاصاً لكل قيمة specialty موجودة في حقل meta
 * لخدمات قسم الأطباء، ثم تربط الخدمات بالاختصاصات المنشأة.
 * تُستدعى تلقائياً عند طلب قائمة الاختصاصات.
 */
function specialties_sync(): void
{
    $pdo = db();

    // القسم الذي يحمل slug = doctors
    $catId = $pdo->query("SELECT id FROM categories WHERE slug = 'doctors'")->fetchColumn();
    if (!$catId) {
        return;
    }

    // اجمع الاختصاصات الفريدة من meta
    $rows = $pdo->prepare("SELECT id, meta FROM services WHERE category_id = ? AND is_active = 1");
    $rows->execute([$catId]);

    /* ══════════════════════════════════════════════════════════
     * خريطة القيم ← الأسماء من حقول القسم
     *
     * الخدمات القديمة تخزّن meta.specialty باسم الاختصاص
     * («أمراض داخلية»)، أما الجديدة فتخزّن مُعرّف الخيار
     * («5») كما يُرسله منتقي الحقول الديناميكي.
     * بدون هذه الخريطة يُنشأ اختصاص مزيف باسم «5»،
     * فيظهر في القسم كرتان: واحدة برقم وأخرى بالاسم.
     * ══════════════════════════════════════════════════════════ */
    $valueToLabel = [];   // "5" => "أمراض داخلية"
    try {
        $fStmt = $pdo->prepare(
            "SELECT f.id, f.field_key FROM category_fields f
             WHERE f.category_id = ? AND f.is_active = 1"
        );
        $fStmt->execute([$catId]);
        foreach ($fStmt->fetchAll() as $f) {
            if (($f['field_key'] ?? '') !== 'specialty') {
                continue;
            }
            $oStmt = $pdo->prepare(
                "SELECT id, label, value, icon FROM category_field_options
                 WHERE field_id = ? AND is_active = 1"
            );
            $oStmt->execute([$f['id']]);
            foreach ($oStmt->fetchAll() as $o) {
                $lbl = trim((string) ($o['label'] ?? ''));
                if ($lbl === '') {
                    continue;
                }
                $valueToLabel[(string) $o['value']]      = $lbl;
                $valueToLabel[(string) $o['id']]         = $lbl;
                $valueToLabel[mb_strtolower($lbl)]       = $lbl;
            }
        }
    } catch (Throwable $e) {
        // الجداول قد لا تكون موجودة بعد — تابع بالمنطق القديم
    }

    $byName = [];   // name => [serviceIds]
    foreach ($rows->fetchAll() as $r) {
        $meta = json_decode($r['meta'] ?: '{}', true);
        if (!is_array($meta)) {
            continue;
        }
        $raw  = trim((string) ($meta['specialty'] ?? ''));
        if ($raw === '') {
            continue;
        }

        /* حوّل مُعرّف الخيار إلى اسمه المقروء */
        if (isset($valueToLabel[$raw])) {
            $name = $valueToLabel[$raw];
        } else {
            $key = mb_strtolower($raw);
            $name = $valueToLabel[$key] ?? $raw;
        }

        // لا تنشئ اختصاصات بأسماء رقمية — مؤشر على فشل الحلّ
        if ($name !== '' && preg_match('/^\d+$/', $name)) {
            continue;
        }

        $byName[$name]['ids'][]   = (int) $r['id'];
        $byName[$name]['icon']    = trim((string) ($meta['specialty_icon'] ?? '')) ?: '🩺';
    }

    if (!$byName) {
        return;
    }

    $ins = $pdo->prepare(
        "INSERT INTO specialties (name, icon, sort_order, is_active, created_at)
         VALUES (?, ?, ?, 1, ?) ON CONFLICT(name) DO NOTHING"
    );
    $order = 0;
    foreach ($byName as $name => $info) {
        $ins->execute([$name, $info['icon'], $order++, now_sql()]);
    }

    // اربط كل خدمة باختصاصها
    $findId = $pdo->prepare("SELECT id FROM specialties WHERE name = ?");
    $link   = $pdo->prepare("UPDATE services SET specialty_id = ? WHERE id = ? AND (specialty_id IS NULL OR specialty_id <> ?)");
    foreach ($byName as $name => $info) {
        $findId->execute([$name]);
        $sid = $findId->fetchColumn();
        if (!$sid) {
            continue;
        }
        foreach ($info['ids'] as $svcId) {
            $link->execute([$sid, $svcId, $sid]);
        }
    }
}

function owned_service(array $user, int $id): array
{
    $st = db()->prepare(base_select() . " WHERE s.id = ?");
    $st->execute([$id]);
    $row = $st->fetch();
    if (!$row) {
        fail('الخدمة غير موجودة', 404);
    }
    if ($user['role'] !== 'admin' && (int) ($row['owner_id'] ?? 0) !== (int) $user['id']) {
        fail('ليست لديك صلاحية على هذه الخدمة', 403);
    }
    return $row;
}

function schedules_of(int $serviceId): array
{
    $st = db()->prepare("SELECT * FROM schedules WHERE service_id = ? ORDER BY day, opens");
    $st->execute([$serviceId]);
    return $st->fetchAll();
}

function ensure_status_row(int $serviceId): void
{
    db()->prepare("INSERT OR IGNORE INTO service_status (service_id, mode) VALUES (?, 'auto')")->execute([$serviceId]);
}

// =============================================================
// واجهات عامة
// =============================================================

function api_settings(): array
{
    return [
        'site_name'      => setting('site_name', 'دليل الدير'),
        'city'           => setting('city', ''),   // فارغ = غير مقيّد بمحافظة
        // وقت التبديل بين الإعلانات بالثواني (1..60، الافتراضي 5)
        'ad_interval'    => (int) setting('ad_interval', '5') ?: 5,
        'announcements'  => json_field(setting('announcements', '[]')),
        'whatsapp_admin' => setting('whatsapp_admin', ''),
        'service_types'  => json_field(setting('service_types', '[]')),
    ];
}

/**
 * عدد الخدمات النشطة لكل قسم — استعلام تجميعي واحد رخيص.
 * لا يُفشل الطلب إن تعذّر الحساب: يُرجع مصفوفة فارغة.
 */
function counts_by_category(): array
{
    $out = [];
    try {
        foreach (db()->query(
            "SELECT c.slug, COUNT(s.id) AS total
               FROM categories c
               LEFT JOIN services s ON s.category_id = c.id AND s.is_active = 1
              WHERE c.is_active = 1
              GROUP BY c.id"
        )->fetchAll() as $row) {
            $out[$row['slug']] = (int) $row['total'];
        }
    } catch (\Throwable $e) {
        $out = [];
    }
    return $out;
}

function api_meta(): void
{
    ok([
        'categories'   => categories_list(),
        'regions'      => regions_list(),
        'governorates' => governorates_list(),
        'locations'    => location_tree(),
        'counts'       => counts_by_category(),
        'settings'     => api_settings(),
        'time'         => app_now()->format('c'),
    ]);
}

/**
 * نقطة نهاية واحدة للصفحة الرئيسية: التصنيفات + العدادات + الإعدادات
 * في طلب واحد بدل خمسة — أسرع وأكثر موثوقية.
 */
function api_home(): void
{
    ok([
        'categories'   => categories_list(),
        'regions'      => regions_list(),
        'governorates' => governorates_list(),
        'locations'    => location_tree(),
        'counts'       => counts_by_category(),
        'settings'     => api_settings(),
        'time'         => app_now()->format('c'),
    ]);
}

function api_stats(): void
{
    $out = [];
    foreach (db()->query("SELECT c.id, c.slug, c.name, c.icon, c.color, COUNT(s.id) AS total FROM categories c
                          LEFT JOIN services s ON s.category_id = c.id AND s.is_active = 1
                          WHERE c.is_active = 1 GROUP BY c.id ORDER BY c.sort_order")->fetchAll() as $row) {
        $out[$row['slug']] = (int) $row['total'];
    }
    $openTotal = 0;
    foreach (db()->query("SELECT s.id FROM services s WHERE s.is_active = 1")->fetchAll() as $r) {
        $ids[] = (int) $r['id'];
    }
    $ids = $ids ?? [];
    $map = schedules_map($ids);
    $st = db()->query(base_select() . " WHERE s.is_active = 1");
    foreach ($st->fetchAll() as $row) {
        $c = compute_status($row, $map[(int) $row['id']] ?? []);
        if ($c['status'] === 'open') {
            $openTotal++;
        }
    }
    ok(['by_category' => $out, 'open_now' => $openTotal, 'total_services' => count($ids), 'time' => app_now()->format('c')]);
}

function api_services(): void
{
    $pdo = db();
    $where = ["s.is_active = 1"];
    $args  = [];

    if ($cid = arg('category_id')) {
        if (ctype_digit((string) $cid)) { $where[] = "s.category_id = ?"; $args[] = (int) $cid; }
        else { $where[] = "c.slug = ?"; $args[] = $cid; }
    }
    if ($rid = arg('region_id')) { $where[] = "s.region_id = ?"; $args[] = (int) $rid; }
    if ($gid = arg('governorate_id')) { $where[] = "s.governorate_id = ?"; $args[] = (int) $gid; }
    if ($sp = arg('specialty_id')) { $where[] = "s.specialty_id = ?"; $args[] = (int) $sp; }
    if ($zone = arg('zone'))     { $where[] = "r.zone = ?"; $args[] = in_arr($zone, ['city', 'rural'], 'city'); }
    if ($own = arg('owner_id'))  { $where[] = "s.owner_id = ?"; $args[] = (int) $own; }
    if ($q = str_trim((string) arg('q'), 80)) {
        $where[] = "(s.name LIKE ? OR s.address LIKE ? OR s.phone LIKE ? OR r.name LIKE ?)";
        $like = '%' . $q . '%';
        array_push($args, $like, $like, $like, $like);
    }

    $sql = base_select() . " WHERE " . implode(' AND ', $where);
    $st = $pdo->prepare($sql);
    $st->execute($args);
    $rows = $st->fetchAll();

    $map = schedules_map(array_map(fn($r) => (int) $r['id'], $rows));

    $items = [];
    foreach ($rows as $row) {
        $sched = $map[(int) $row['id']] ?? [];
        $item  = shape_service($row, $sched);
        $item['schedule_count'] = count($sched);
        $items[] = $item;
    }

    // فلاتر الحالة (بعد الحساب)
    $status = arg('status');
    if ($status === 'open')      { $items = array_values(array_filter($items, fn($i) => $i['status'] === 'open')); }
    if ($status === 'closed')    { $items = array_values(array_filter($items, fn($i) => $i['status'] === 'closed')); }
    if ($status === 'on_duty')   { $items = array_values(array_filter($items, fn($i) => $i['on_duty'])); }
    if ($status === 'manual')    { $items = array_values(array_filter($items, fn($i) => $i['status_source'] === 'manual')); }
    if ($status === 'verified')  { $items = array_values(array_filter($items, fn($i) => $i['is_verified'])); }
    if ($status === 'unmanaged') { $items = array_values(array_filter($items, fn($i) => $i['owner_id'] === null)); }

    if (arg('opens_day') !== null && ctype_digit((string) arg('opens_day'))) {
        $d = (int) arg('opens_day');
        $items = array_values(array_filter($items, function ($i) use ($d, $map) {
            foreach ($map[$i['id']] ?? [] as $s) {
                if ((int) $s['day'] === $d) { return true; }
            }
            return false;
        }));
    }

    // تجميع حسب المنطقة
    $groups = [];
    foreach ($items as $i) {
        $key = $i['region_name'] ?? 'غير محدد';
        if (!isset($groups[$key])) {
            $groups[$key] = ['region' => $key, 'region_id' => $i['region_id'], 'total' => 0, 'open' => 0, 'on_duty' => 0];
        }
        $groups[$key]['total']++;
        if ($i['status'] === 'open') { $groups[$key]['open']++; }
        if ($i['on_duty']) { $groups[$key]['on_duty']++; }
    }
    $groups = array_values($groups);
    usort($groups, fn($a, $b) => ($b['open'] <=> $a['open']) ?: strcmp($a['region'], $b['region']));

    // ترتيب
    $sort = (string) (arg('sort') ?? 'open_first');
    $nameCmp = function ($a, $b) {
        $an = preg_replace('/^(ال|أل)/u', '', $a['name']);
        $bn = preg_replace('/^(ال|أل)/u', '', $b['name']);
        strcmp($an, $bn); return;
    };
    if ($sort === 'name') {
        usort($items, $nameCmp);
    } elseif ($sort === 'recent') {
        usort($items, fn($a, $b) => strcmp((string) $b['updated_at'], (string) $a['updated_at']));
    } else { // open_first
        usort($items, function ($a, $b) use ($nameCmp) {
            return ($b['status'] === 'open') <=> ($a['status'] === 'open') ?: $nameCmp($a, $b);
        });
    }

    // السقف كان ٢٠٠، وقسم الصيدليات فيه ٢٤٢ خدمة — فأربعون صيدلية كانت
    // محجوبة عن الواجهة تماماً (تُحسب في مجموع «total» وفي بطاقات المناطق
    // ثم لا تظهر عند اختيار المنطقة لأن الشريحة تنتهي قبلها).
    // رفعناه إلى ٥٠٠ مع بقاء الطلب محدوداً، والواجهة تجلب بقية الصفحات إن زاد.
    $limit = max(1, min(500, (int) (arg('limit') ?? 200)));
    $page  = max(1, (int) (arg('page') ?? 1));
    $total = count($items);
    $slice = array_slice($items, ($page - 1) * $limit, $limit);

    ok([
        'items'       => $slice,
        'total'       => $total,
        'page'        => $page,
        'limit'       => $limit,
        'open_now'    => count(array_filter($items, fn($i) => $i['status'] === 'open')),
        'on_duty'     => count(array_filter($items, fn($i) => $i['on_duty'])),
        'regions'     => $groups,
        'time'        => app_now()->format('c'),
    ]);
}

function api_service_detail(int $id): void
{
    $st = db()->prepare(base_select() . " WHERE s.id = ?");
    $st->execute([$id]);
    $row = $st->fetch();
    if (!$row || (int) $row['is_active'] !== 1) {
        fail('الخدمة غير موجودة', 404);
    }
    $sched = schedules_of($id);
    $item  = shape_service($row, $sched);
    $item['schedule'] = array_map(fn($s) => [
        'day' => (int) $s['day'], 'opens' => $s['opens'], 'closes' => $s['closes'], 'is_24h' => (bool) $s['is_24h'],
    ], $sched);
    $item['status_note'] = $row['status_note'] ?? '';
    $item['owner'] = $row['owner_id'] ? ['id' => (int) $row['owner_id'], 'name' => $row['owner_name'] ?: 'المسؤول عن الخدمة'] : null;

    // خدمات مجاورة في نفس المنطقة
    $near = [];
    if ($row['region_id']) {
        $st2 = db()->prepare(base_select() . " WHERE s.is_active = 1 AND s.region_id = ? AND s.id != ? ORDER BY RANDOM() LIMIT 4");
        $st2->execute([(int) $row['region_id'], $id]);
        $map2 = schedules_map(array_map(fn($r) => (int) $r['id'], $st2->fetchAll()));
        $st2->execute([(int) $row['region_id'], $id]);
        foreach ($st2->fetchAll() as $r) {
            $near[] = shape_service($r, $map2[(int) $r['id']] ?? []);
        }
    }
    ok(['service' => $item, 'nearby' => $near]);
}

// =============================================================
// المصادقة
// =============================================================

function api_register(): void
{
    $phone = normalize_phone(body_str('phone', 20));
    $pass  = (string) (body()['password'] ?? '');
    $name  = body_str('full_name', 120);

    if (!preg_match('/^09\d{8}$/', $phone)) fail('رقم هاتف سوري غير صالح (مثال: 0991234567)');
    if (u_len($pass) < 6) fail('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
    if ($name === '') fail('الاسم الثلاثي مطلوب');

    $st = db()->prepare("SELECT id FROM users WHERE phone = ?");
    $st->execute([$phone]);
    if ($st->fetch()) fail('هذا الرقم مسجّل مسبقاً', 409);

    $birth = body_str('birth_date', 10);
    if ($birth !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $birth)) $birth = null;

    $st = db()->prepare("INSERT INTO users (phone, password_hash, full_name, birth_date, role) VALUES (?,?,?,?, 'user')");
    $st->execute([$phone, password_hash($pass, PASSWORD_DEFAULT), $name, $birth ?: null]);
    $uid = (int) db()->lastInsertId();

    log_activity('register', 'user', $uid, 'حساب جديد: ' . $name, 'user', $uid);

    $u = db()->query("SELECT * FROM users WHERE id = $uid")->fetch();
    ok(['token' => issue_token($uid, 'user'), 'user' => public_user($u)]);
}

function api_login(): void
{
    throttle_login();
    $phone = normalize_phone(body_str('phone', 20));
    $pass  = (string) (body()['password'] ?? '');
    if ($phone === '' || $pass === '') fail('أدخل رقم الهاتف وكلمة المرور');

    $st = db()->prepare("SELECT * FROM users WHERE phone = ?");
    $st->execute([$phone]);
    $u = $st->fetch();
    if (!$u || !password_verify($pass, $u['password_hash'])) fail('رقم الهاتف أو كلمة المرور غير صحيحة', 401);
    if ((int) $u['is_active'] !== 1) fail('الحساب موقوف، تواصل مع الإدارة', 403);

    if (password_needs_rehash($u['password_hash'], PASSWORD_DEFAULT)) {
        db()->prepare("UPDATE users SET password_hash = ? WHERE id = ?")->execute([password_hash($pass, PASSWORD_DEFAULT), $u['id']]);
    }
    reset_login_throttle();
    log_activity('login', 'user', (int) $u['id'], 'تسجيل دخول', 'user', (int) $u['id']);
    ok(['token' => issue_token((int) $u['id'], $u['role']), 'user' => public_user($u)]);
}

function api_update_profile(array $u): void
{
    $name  = body_str('full_name', 120);
    $birth = body_str('birth_date', 10);
    $bio   = body_str('bio', 300);
    $pass  = (string) (body()['password'] ?? '');
    $phone = normalize_phone(body_str('phone', 20));
    if ($birth !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $birth)) fail('تاريخ الميلاد غير صالح');

    $sets = [];
    $args = [];
    if (array_key_exists('full_name', body())) { if ($name === '') fail('الاسم مطلوب'); $sets[] = 'full_name = ?'; $args[] = $name; }
    if (array_key_exists('birth_date', body())) { $sets[] = 'birth_date = ?'; $args[] = $birth ?: null; }
    if (array_key_exists('bio', body()))        { $sets[] = 'bio = ?'; $args[] = $bio; }
    if (array_key_exists('phone', body()) && $phone !== '') {
        if (!preg_match('/^09\d{8}$/', $phone)) fail('رقم هاتف سوري غير صالح (مثال: 0991234567)');
        // التحقق من عدم تكرار الرقم
        $chk = db()->prepare("SELECT id FROM users WHERE phone = ? AND id != ?");
        $chk->execute([$phone, (int) $u['id']]);
        if ($chk->fetch()) fail('هذا الرقم مسجّل لحساب آخر', 409);
        $sets[] = 'phone = ?';
        $args[] = $phone;
    }
    if ($pass !== '') {
        if (u_len($pass) < 6) fail('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
        $sets[] = 'password_hash = ?'; $args[] = password_hash($pass, PASSWORD_DEFAULT);
    }
    if (!$sets) fail('لا توجد تغييرات');

    $sets[] = "updated_at = '" . now_sql() . "'";
    $args[] = (int) $u['id'];
    db()->prepare("UPDATE users SET " . implode(', ', $sets) . " WHERE id = ?")->execute($args);

    $fresh = db()->prepare("SELECT * FROM users WHERE id = ?");
    $fresh->execute([(int) $u['id']]);
    ok(['user' => public_user($fresh->fetch()), 'message' => 'تم حفظ البيانات']);
}

function api_upload_avatar(array $u): void
{
    if (empty($_FILES['avatar'])) fail('لم يتم إرسال صورة', 400);
    $f = $_FILES['avatar'];
    if ($f['error'] !== UPLOAD_ERR_OK) fail('فشل رفع الصورة', 400);
    if ($f['size'] > 3 * 1024 * 1024) fail('حجم الصورة يجب أن يكون أقل من 3 ميغا');

    $info = @getimagesize($f['tmp_name']);
    if (!$info) fail('الملف ليس صورة صالحة');
    $ext = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp', 'image/gif' => 'gif'][$info['mime']] ?? null;
    if (!$ext) fail('الصيغ المدعومة: JPG / PNG / WEBP / GIF');

    $dir = APP_ROOT . '/storage/uploads';
    if (!is_dir($dir)) mkdir($dir, 0775, true);

    // تصغير الصورة إلى 512px لتوفير المساحة (إن توفّرت مكتبة GD)
    $src = !function_exists('imagecreatefromjpeg') ? false : match ($info['mime']) {
        'image/jpeg' => @imagecreatefromjpeg($f['tmp_name']),
        'image/png'  => @imagecreatefrompng($f['tmp_name']),
        'image/webp' => @imagecreatefromwebp($f['tmp_name']),
        'image/gif'  => @imagecreatefromgif($f['tmp_name']),
        default      => false,
    };
    $name = 'avatar_' . $u['id'] . '_' . substr(bin2hex(random_bytes(4)), 0, 6) . '.' . $ext;
    $dest = $dir . '/' . $name;

    if ($src) {
        $w = imagesx($src); $h = imagesy($src);
        $size = min($w, $h, 512);
        $dst = imagecreatetruecolor($size, $size);
        imagecopyresampled($dst, $src, 0, 0, (int) (($w - $size) / 2), (int) (($h - $size) / 2), $size, $size, $size, $size);
        if ($ext === 'jpg') imagejpeg($dst, $dest, 88);
        elseif ($ext === 'png') imagepng($dest, $dest);
        elseif ($ext === 'webp') imagewebp($dst, $dest, 88);
        else imagegif($dst, $dest);
        imagedestroy($src); imagedestroy($dst);
    } else {
        move_uploaded_file($f['tmp_name'], $dest);
    }

    // حذف الصورة القديمة
    if (!empty($u['avatar'])) {
        $old = APP_ROOT . '/storage/uploads/' . basename($u['avatar']);
        if (is_file($old)) @unlink($old);
    }

    db()->prepare("UPDATE users SET avatar = ?, updated_at = '" . now_sql() . "' WHERE id = ?")->execute(['/uploads/' . $name, (int) $u['id']]);
    $fresh = db()->prepare("SELECT * FROM users WHERE id = ?");
    $fresh->execute([(int) $u['id']]);
    ok(['user' => public_user($fresh->fetch()), 'message' => 'تم تحديث الصورة الشخصية']);
}

// =============================================================
// قسم "خدماتي" لصاحب الخدمة
// =============================================================

function api_my_services(array $u): void
{
    $st = db()->prepare(base_select() . " WHERE s.owner_id = ? ORDER BY s.name");
    $st->execute([(int) $u['id']]);
    $rows = $st->fetchAll();
    $map = schedules_map(array_map(fn($r) => (int) $r['id'], $rows));
    $items = [];
    foreach ($rows as $row) {
        $i = shape_service($row, $map[(int) $row['id']] ?? []);
        $i['schedule'] = array_map(fn($s) => ['day' => (int) $s['day'], 'opens' => $s['opens'], 'closes' => $s['closes'], 'is_24h' => (bool) $s['is_24h']], schedules_of((int) $row['id']));
        $i['mode'] = $row['mode'] ?? 'auto';
        $i['expires_at'] = $row['expires_at'] ?? null;
        $items[] = $i;
    }
    ok(['items' => $items, 'total' => count($items)]);
}

function api_owner_service(array $svc): void
{
    $sched = schedules_of((int) $svc['id']);
    $item = shape_service($svc, $sched);
    $item['schedule'] = array_map(fn($s) => ['day' => (int) $s['day'], 'opens' => $s['opens'], 'closes' => $s['closes'], 'is_24h' => (bool) $s['is_24h']], $sched);
    $item['mode'] = $svc['mode'] ?? 'auto';
    $item['expires_at'] = $svc['expires_at'] ?? null;
    ok(['service' => $item]);
}

function api_my_requests(array $u): void
{
    $st = db()->prepare("SELECT sr.*, c.name AS category_name, c.icon AS category_icon, r.name AS region_name
                         FROM service_requests sr
                         LEFT JOIN categories c ON c.id = sr.category_id
                         LEFT JOIN regions r ON r.id = sr.region_id
                         WHERE sr.user_id = ? ORDER BY sr.id DESC");
    $st->execute([(int) $u['id']]);
    ok(['items' => $st->fetchAll()]);
}

function api_my_activity(array $u): void
{
    $st = db()->prepare("SELECT action, entity, entity_id, message, created_at FROM activity_log WHERE user_id = ? ORDER BY id DESC LIMIT 40");
    $st->execute([(int) $u['id']]);
    ok(['items' => $st->fetchAll()]);
}

/** تحديث حالة التوفر يدوياً (زر السحب) */
function api_owner_status(array $u, array $svc): void
{
    $b    = body();
    $mode = in_arr($b['mode'] ?? 'auto', ['open', 'closed', 'auto'], 'auto');
    $note = str_trim($b['note'] ?? '', 200);
    $hours = isset($b['hours']) ? max(0, min(72, (float) $b['hours'])) : 6;
    $onDuty = !empty($b['on_duty']) ? 1 : 0;
    $dutyHours = isset($b['duty_hours']) ? max(0, min(72, (float) $b['duty_hours'])) : 12;

    ensure_status_row((int) $svc['id']);
    $expires = $mode === 'auto' ? null : app_now()->add(new DateInterval('PT' . (int) round($hours * 60) . 'M'))->format('Y-m-d H:i:s');
    $dutyTo = $onDuty ? app_now()->add(new DateInterval('PT' . (int) round($dutyHours * 60) . 'M'))->format('Y-m-d H:i:s') : null;

    $st = db()->prepare("UPDATE service_status
        SET mode = ?, note = ?, on_duty = ?, duty_from = ?, duty_to = ?, updated_by = ?, expires_at = ?, updated_at = '" . now_sql() . "'
        WHERE service_id = ?");
    $st->execute([$mode, $note, $onDuty, $onDuty ? app_now()->format('Y-m-d H:i:s') : null, $dutyTo, (int) $u['id'], $expires, (int) $svc['id']]);
    db()->prepare("UPDATE services SET updated_at = '" . now_sql() . "' WHERE id = ?")->execute([(int) $svc['id']]);

    log_activity('status', 'service', (int) $svc['id'], 'غيّر الحالة إلى: ' . $mode . ($onDuty ? ' + مناوب' : ''), 'user', (int) $u['id']);

    $fresh = owned_service($u, (int) $svc['id']);
    $item = shape_service($fresh, schedules_of((int) $svc['id']));
    $item['mode'] = $fresh['mode'];
    $item['expires_at'] = $fresh['expires_at'];
    ok(['service' => $item, 'message' => $mode === 'auto' ? 'عاد التحديث التلقائي حسب جدول الدوام' : 'تم تحديث الحالة']);
}

/** حفظ جدول الدوام */
function api_owner_schedule(array $u, array $svc): void
{
    $b = body();
    $rows = $b['schedule'] ?? null;
    if (!is_array($rows)) fail('جدول الدوام غير صالح');

    $clean = [];
    foreach ($rows as $r) {
        if (!is_array($r)) continue;
        $day = (int) ($r['day'] ?? -1);
        if ($day < 0 || $day > 6) continue;
        $is24 = !empty($r['is_24h']);
        $opens = (string) ($r['opens'] ?? '');
        $closes = (string) ($r['closes'] ?? '');
        if ($is24) {
            $clean[] = [$day, '00:00', '23:59', 1];
            continue;
        }
        if (!valid_time($opens) || !valid_time($closes)) continue;
        if ($opens === $closes) continue;
        $clean[] = [$day, $opens, $closes, 0];
    }

    $pdo = db();
    $pdo->beginTransaction();
    $pdo->prepare("DELETE FROM schedules WHERE service_id = ?")->execute([(int) $svc['id']]);
    $ins = $pdo->prepare("INSERT INTO schedules (service_id, day, opens, closes, is_24h) VALUES (?,?,?,?,?)");
    foreach ($clean as $c) {
        $ins->execute([(int) $svc['id'], $c[0], $c[1], $c[2], $c[3]]);
    }
    // عند تعديل الجدول يعود التحديث للتلقائي ما لم يحدَّد خلاف ذلك
    ensure_status_row((int) $svc['id']);
    if (!array_key_exists('keep_manual', $b) || empty($b['keep_manual'])) {
        $pdo->prepare("UPDATE service_status SET mode = 'auto', expires_at = NULL, updated_by = ?, updated_at = '" . now_sql() . "' WHERE service_id = ?")
            ->execute([(int) $u['id'], (int) $svc['id']]);
    }
    $pdo->prepare("UPDATE services SET updated_at = '" . now_sql() . "' WHERE id = ?")->execute([(int) $svc['id']]);
    $pdo->commit();

    log_activity('schedule', 'service', (int) $svc['id'], 'حدّث جدول الدوام (' . count($clean) . ' فترة)', 'user', (int) $u['id']);
    ok(['schedule' => array_map(fn($c) => ['day' => $c[0], 'opens' => $c[1], 'closes' => $c[2], 'is_24h' => (bool) $c[3]], $clean),
        'message' => 'تم حفظ جدول الدوام']);
}

/** تعديل بيانات الخدمة من قبل صاحبها */
function api_owner_update(array $u, array $svc): void
{
    $name = body_str('name', 160);
    if ($name === '') fail('الاسم مطلوب');

    // ابدأ من meta الحالي، وادمج ما أُرسل، ثم طبّق الأيقونة إن وُجدت
    $meta = json_field($svc['meta'] ?? '{}');
    if (!is_array($meta)) { $meta = []; }
    $sent = json_field(body()['meta'] ?? '{}');
    if (is_array($sent)) { $meta = array_merge($meta, $sent); }

    $icon = trim((string) (body()['icon'] ?? ''));
    if ($icon !== '' && preg_match('/^[a-z0-9\-]{2,30}$/', $icon)) {
        $meta['icon'] = $icon;
    }

    // الموقع: المنطقة + المحافظة (تُشتق من المنطقة إن لم تُرسل)
    $regId = !empty(body()['region_id']) ? (int) body()['region_id'] : null;
    $govId = !empty(body()['governorate_id']) ? (int) body()['governorate_id'] : null;
    if (!$govId && $regId) {
        $st = db()->prepare("SELECT governorate_id FROM regions WHERE id = ?");
        $st->execute([$regId]);
        $govId = (int) ($st->fetchColumn() ?: 0) ?: null;
    }

    db()->prepare("UPDATE services SET name = ?, address = ?, phone = ?, whatsapp = ?, note = ?, meta = ?, region_id = ?, governorate_id = ?, updated_at = '" . now_sql() . "' WHERE id = ?")
        ->execute([
            $name,
            body_str('address', 300),
            normalize_phone(body_str('phone', 25)),
            normalize_phone(body_str('whatsapp', 25)),
            body_str('note', 500),
            json_enc($meta),
            $regId,
            $govId,
            (int) $svc['id'],
        ]);
    log_activity('update', 'service', (int) $svc['id'], 'عدّل بيانات الخدمة', 'user', (int) $u['id']);
    ok(['service' => shape_service(owned_service($u, (int) $svc['id']), schedules_of((int) $svc['id'])), 'message' => 'تم حفظ التعديلات']);
}

// =============================================================
// طلب إضافة خدمة (متاح للجميع)
// =============================================================

function api_create_request(): void
{
    $u = current_user();
    $b = body();
    $name = str_trim($b['name'] ?? '', 160);
    if ($name === '') fail('اسم الخدمة مطلوب');

    $catId = (int) ($b['category_id'] ?? 0);
    $st = db()->prepare("SELECT id FROM categories WHERE id = ? AND is_active = 1");
    $st->execute([$catId]);
    if (!$st->fetch()) fail('اختر نوع الخدمة');

    $regId = !empty($b['region_id']) ? (int) $b['region_id'] : null;
    if ($regId) {
        $st = db()->prepare("SELECT id FROM regions WHERE id = ?");
        $st->execute([$regId]);
        if (!$st->fetch()) fail('المنطقة غير موجودة');
    }

    $phone = normalize_phone(str_trim($b['phone'] ?? '', 25));
    if ($phone !== '' && !preg_match('/^0\d{8,9}$/', $phone)) fail('رقم الهاتف غير صالح');

    $meta = json_field($b['meta'] ?? '{}');

    // الحقول الخاصة بالقسم (مثل الاختصاص) — تُتحقق وتُدمج داخل meta
    $fieldValues = validate_fields_values($catId, $b['fields'] ?? []);
    foreach ($fieldValues as $k => $v) {
        if ($v === null) unset($meta[$k]);
        else $meta[$k] = $v;
    }

    // محافظة الطلب: تُرسل صراحةً، وإلا تُشتق من المنطقة
    $reqGovId = !empty($b['governorate_id']) ? (int) $b['governorate_id'] : null;
    if (!$reqGovId && $regId) {
        $st = db()->prepare("SELECT governorate_id FROM regions WHERE id = ?");
        $st->execute([$regId]);
        $reqGovId = (int) ($st->fetchColumn() ?: 0) ?: null;
    }

    $st = db()->prepare("INSERT INTO service_requests
        (user_id, category_id, region_id, governorate_id, name, address, phone, whatsapp, note, meta, want_to_manage)
        VALUES (?,?,?,?,?,?,?,?,?,?,?)");
    $st->execute([
        $u ? (int) $u['id'] : null,
        $catId,
        $regId,
        $reqGovId,
        $name,
        str_trim($b['address'] ?? '', 300),
        $phone,
        normalize_phone(str_trim($b['whatsapp'] ?? '', 25)),
        str_trim($b['note'] ?? '', 500),
        json_enc($meta),
        !empty($b['want_to_manage']) ? 1 : 0,
    ]);
    $rid = (int) db()->lastInsertId();
    log_activity('request', 'service_request', $rid, 'طلب إضافة: ' . $name, $u ? 'user' : 'guest', $u ? (int) $u['id'] : null);

    ok(['id' => $rid, 'message' => 'تم استلام طلبك، سيتم مراجعته من إدارة الموقع']);
}

// =============================================================
// لوحة الإدارة
// =============================================================

function admin_stats(): void
{
    $pdo = db();
    $cats = [];
    foreach ($pdo->query("SELECT c.id, c.slug, c.name, c.icon, c.color,
                                 (SELECT COUNT(*) FROM services s WHERE s.category_id = c.id AND s.is_active = 1) AS total,
                                 (SELECT COUNT(*) FROM services s WHERE s.category_id = c.id AND s.is_active = 1 AND s.owner_id IS NOT NULL) AS managed
                          FROM categories c ORDER BY c.sort_order")->fetchAll() as $c) {
        $cats[] = $c;
    }
    $openNow = 0; $manual = 0; $duty = 0;
    $rows = $pdo->query(base_select() . " WHERE s.is_active = 1")->fetchAll();
    $map = schedules_map(array_map(fn($r) => (int) $r['id'], $rows));
    foreach ($rows as $row) {
        $c = compute_status($row, $map[(int) $row['id']] ?? []);
        if ($c['status'] === 'open') $openNow++;
        if ($c['source'] === 'manual') $manual++;
        if (on_duty_now($row)) $duty++;
    }
    ok([
        'categories' => $cats,
        'services'   => (int) $pdo->query("SELECT COUNT(*) c FROM services")->fetch()['c'],
        'services_active' => count($rows),
        'regions'    => (int) $pdo->query("SELECT COUNT(*) c FROM regions")->fetch()['c'],
        'users'      => (int) $pdo->query("SELECT COUNT(*) c FROM users")->fetch()['c'],
        'owners'     => (int) $pdo->query("SELECT COUNT(*) c FROM users WHERE id IN (SELECT owner_id FROM services WHERE owner_id IS NOT NULL)")->fetch()['c'],
        'requests_pending' => (int) $pdo->query("SELECT COUNT(*) c FROM service_requests WHERE status = 'pending'")->fetch()['c'],
        'requests_total'   => (int) $pdo->query("SELECT COUNT(*) c FROM service_requests")->fetch()['c'],
        'open_now'   => $openNow,
        'manual_now' => $manual,
        'on_duty'    => $duty,
        'time'       => app_now()->format('c'),
    ]);
}

function admin_services_list(): void
{
    $where = ['1=1']; $args = [];
    if ($c = arg('category_id')) { $where[] = 's.category_id = ?'; $args[] = (int) $c; }
    if ($r = arg('region_id'))   { $where[] = 's.region_id = ?'; $args[] = (int) $r; }
    if ($o = arg('owner_id'))    { $where[] = 's.owner_id = ?'; $args[] = (int) $o; }
    if (arg('only_unmanaged'))   { $where[] = 's.owner_id IS NULL'; }
    if (arg('active') !== null)  { $where[] = 's.is_active = ?'; $args[] = (int) arg('active'); }
    if ($q = str_trim((string) arg('q'), 80)) {
        $where[] = '(s.name LIKE ? OR s.address LIKE ? OR s.phone LIKE ?)';
        array_push($args, "%$q%", "%$q%", "%$q%");
    }
    $sql = base_select() . " WHERE " . implode(' AND ', $where) . " ORDER BY s.id DESC LIMIT 400";
    $st = db()->prepare($sql);
    $st->execute($args);
    $rows = $st->fetchAll();
    $map = schedules_map(array_map(fn($r) => (int) $r['id'], $rows));
    $items = [];
    foreach ($rows as $row) {
        $i = shape_service($row, $map[(int) $row['id']] ?? []);
        $i['is_active'] = (bool) $row['is_active'];
        $i['mode'] = $row['mode'] ?? 'auto';
        $i['layout'] = $row['layout'];
        $i['category_icon'] = $row['category_icon'];
        $items[] = $i;
    }
    ok(['items' => $items, 'total' => count($items)]);
}

function admin_service_get(int $id): void
{
    $st = db()->prepare(base_select() . " WHERE s.id = ?");
    $st->execute([$id]);
    $row = $st->fetch();
    if (!$row) fail('غير موجود', 404);
    $sched = schedules_of($id);
    $item = shape_service($row, $sched);
    $item['schedule'] = array_map(fn($s) => ['day' => (int) $s['day'], 'opens' => $s['opens'], 'closes' => $s['closes'], 'is_24h' => (bool) $s['is_24h']], $sched);
    $item['is_active'] = (bool) $row['is_active'];
    $item['mode'] = $row['mode'] ?? 'auto';
    $item['layout'] = $row['layout'];
    $item['sort_order'] = (int) $row['sort_order'];
    $item['owner_phone'] = $row['owner_phone'] ?? null;
    ok(['service' => $item]);
}

function service_payload(bool $requireCategory = true): array
{
    $b = body();
    $catId = (int) ($b['category_id'] ?? 0);
    if ($requireCategory) {
        $st = db()->prepare("SELECT id FROM categories WHERE id = ?");
        $st->execute([$catId]);
        if (!$st->fetch()) fail('نوع الخدمة غير موجود');
    }
    $regId = !empty($b['region_id']) ? (int) $b['region_id'] : null;
    $ownerId = !empty($b['owner_id']) ? (int) $b['owner_id'] : null;

    // المحافظة: تُرسل صراحةً، وإلا تُشتق من المنطقة (المدينة/القرية)
    $govId = !empty($b['governorate_id']) ? (int) $b['governorate_id'] : null;
    if (!$govId && $regId) {
        $st = db()->prepare("SELECT governorate_id FROM regions WHERE id = ?");
        $st->execute([$regId]);
        $govId = (int) ($st->fetchColumn() ?: 0) ?: null;
    }
    if (!$govId) {
        $st = db()->prepare("SELECT value FROM settings WHERE key = 'default_governorate_id'");
        $st->execute();
        $govId = (int) ($st->fetchColumn() ?: 0) ?: null;
    }
    if ($govId) {
        $st = db()->prepare("SELECT id FROM governorates WHERE id = ?");
        $st->execute([$govId]);
        if (!$st->fetch()) fail('المحافظة المختارة غير موجودة', 422);
    }
    if ($ownerId) {
        $st = db()->prepare("SELECT id FROM users WHERE id = ?");
        $st->execute([$ownerId]);
        if (!$st->fetch()) fail('المستخدم المسؤول غير موجود');
    }
    // ─── الحقول الخاصة بالقسم: تُتحقق وتُدمج داخل meta ───
    $meta = service_meta($b, $catId);

    return [
        'category_id'     => $catId,
        'region_id'       => $regId,
        'governorate_id'  => $govId,
        'owner_id'        => $ownerId,
        'name'        => str_trim($b['name'] ?? '', 160),
        'address'     => str_trim($b['address'] ?? '', 300),
        'phone'       => normalize_phone(str_trim($b['phone'] ?? '', 25)),
        'whatsapp'    => normalize_phone(str_trim($b['whatsapp'] ?? '', 25)),
        'note'        => str_trim($b['note'] ?? '', 500),
        'meta'        => json_enc($meta),
        'photo'       => str_trim($b['photo'] ?? '', 300) ?: null,
        'sort_order'  => (int) ($b['sort_order'] ?? 0),
        'layout'      => in_arr($b['layout'] ?? null, ['card', 'list', 'row', 'wide', 'compact'], null),
        'is_active'   => !array_key_exists('is_active', $b) ? 1 : (int) (!empty($b['is_active'])),
        'is_verified' => !empty($b['is_verified']) ? 1 : 0,
    ];
}

/**
 * يبني حقل meta للخدمة: يبدأ من meta المُرسل ثم يضيف الأيقونة (icon) إن وُجدت.
 * الأيقونة تُطبَّق في الإضافة والتعديل (مسار المدير).
 */
function service_meta(array $b, int $catId = 0): array
{
    $meta = json_field($b['meta'] ?? '{}');
    if (!is_array($meta)) { $meta = []; }

    // تحقّق من الحقول الخاصة بالقسم وأدمج قيمها داخل meta
    if ($catId > 0) {
        $values = validate_fields_values($catId, $b['fields'] ?? $meta);
        foreach ($values as $k => $v) {
            if ($v === null) unset($meta[$k]);
            else $meta[$k] = $v;
        }
    }

    $icon = trim((string) ($b['icon'] ?? ''));
    if ($icon !== '' && preg_match('/^[a-z0-9\-]{2,30}$/', $icon)) {
        $meta['icon'] = $icon;
    }
    return $meta;
}

function admin_service_create(): void
{
    $p = service_payload();
    if ($p['name'] === '') fail('اسم الخدمة مطلوب');
    $st = db()->prepare("INSERT INTO services (category_id, region_id, governorate_id, owner_id, name, address, phone, whatsapp, note, meta, photo, sort_order, layout, is_active, is_verified)
                         VALUES (:category_id,:region_id,:governorate_id,:owner_id,:name,:address,:phone,:whatsapp,:note,:meta,:photo,:sort_order,:layout,:is_active,:is_verified)");
    $st->execute($p);
    $id = (int) db()->lastInsertId();
    ensure_status_row($id);
    if (!empty(body()['schedule']) && is_array(body()['schedule'])) {
        save_schedule($id, body()['schedule']);
    }
    log_activity('create', 'service', $id, 'أضاف خدمة: ' . $p['name'], 'admin', (int) (current_user()['id'] ?? 0));
    ok(['id' => $id, 'message' => 'تمت إضافة الخدمة']);
}

function admin_service_update(?int $id): void
{
    if (!$id) fail('معرف غير صالح');
    $p = service_payload(false);

    // دمج الأيقونة المختارة مع meta الحالي للخدمة
    $forceMeta = false;
    $icon = trim((string) (body()['icon'] ?? ''));
    if ($icon !== '' && preg_match('/^[a-z0-9\-]{2,30}$/', $icon)) {
        $st = db()->prepare("SELECT meta FROM services WHERE id = ?");
        $st->execute([$id]);
        $curMeta = json_field($st->fetchColumn() ?: '{}');
        if (!is_array($curMeta)) { $curMeta = []; }
        $curMeta['icon'] = $icon;
        $p['meta'] = json_enc($curMeta);
        $forceMeta = true;   // أدرج meta في التحديث حتى لو لم يُرسل صراحةً
    }

    $sets = [];
    $args = [];
    foreach (['category_id', 'region_id', 'owner_id', 'name', 'address', 'phone', 'whatsapp', 'note', 'meta', 'photo', 'sort_order', 'layout', 'is_active', 'is_verified'] as $k) {
        $always = in_array($k, ['name', 'address', 'phone', 'whatsapp', 'note', 'meta'], true);
        if (!array_key_exists($k, body()) && !$always && !($k === 'meta' && $forceMeta)) continue;
        $sets[] = "$k = :$k";
        $args[$k] = $p[$k];
    }
    if (!$sets) fail('لا توجد تغييرات');
    $args['id'] = $id;
    db()->prepare("UPDATE services SET " . implode(', ', $sets) . ", updated_at = '" . now_sql() . "' WHERE id = :id")->execute($args);

    if (array_key_exists('schedule', body()) && is_array(body()['schedule'])) {
        save_schedule($id, body()['schedule']);
    }
    // حالة يدوية من المدير
    if (array_key_exists('mode', body())) {
        $mode = in_arr(body()['mode'], ['open', 'closed', 'auto'], 'auto');
        ensure_status_row($id);
        $hours = max(0, min(72, (float) (body()['hours'] ?? 6)));
        $expires = $mode === 'auto' ? null : app_now()->add(new DateInterval('PT' . (int) round($hours * 60) . 'M'))->format('Y-m-d H:i:s');
        db()->prepare("UPDATE service_status SET mode = ?, note = ?, expires_at = ?, updated_by = ?, updated_at = '" . now_sql() . "' WHERE service_id = ?")
            ->execute([$mode, str_trim(body()['status_note'] ?? '', 200), $expires, (int) (current_user()['id'] ?? 0), $id]);
    }
    if (array_key_exists('on_duty', body())) {
        ensure_status_row($id);
        $on = !empty(body()['on_duty']) ? 1 : 0;
        $hours = max(0, min(72, (float) (body()['duty_hours'] ?? 12)));
        db()->prepare("UPDATE service_status SET on_duty = ?, duty_from = ?, duty_to = ?, updated_at = '" . now_sql() . "' WHERE service_id = ?")
            ->execute([$on, $on ? app_now()->format('Y-m-d H:i:s') : null, $on ? app_now()->add(new DateInterval('PT' . (int) round($hours * 60) . 'M'))->format('Y-m-d H:i:s') : null, $id]);
    }
    log_activity('update', 'service', $id, 'عدّل الخدمة', 'admin', (int) (current_user()['id'] ?? 0));
    ok(['message' => 'تم حفظ التعديلات']);
}

function admin_service_delete(?int $id): void
{
    if (!$id) fail('معرف غير صالح');
    db()->prepare("DELETE FROM services WHERE id = ?")->execute([$id]);
    log_activity('delete', 'service', $id, 'حذف خدمة', 'admin', (int) (current_user()['id'] ?? 0));
    ok(['message' => 'تم حذف الخدمة']);
}

function save_schedule(int $serviceId, array $rows)
{
    $clean = [];
    foreach ($rows as $r) {
        if (!is_array($r)) continue;
        $day = (int) ($r['day'] ?? -1);
        if ($day < 0 || $day > 6) continue;
        if (!empty($r['is_24h'])) { $clean[] = [$day, '00:00', '23:59', 1]; continue; }
        $o = (string) ($r['opens'] ?? ''); $c = (string) ($r['closes'] ?? '');
        if (!valid_time($o) || !valid_time($c) || $o === $c) continue;
        $clean[] = [$day, $o, $c, 0];
    }
    $pdo = db();
    $pdo->prepare("DELETE FROM schedules WHERE service_id = ?")->execute([$serviceId]);
    $ins = $pdo->prepare("INSERT INTO schedules (service_id, day, opens, closes, is_24h) VALUES (?,?,?,?,?)");
    foreach ($clean as $c) {
        $ins->execute([$serviceId, $c[0], $c[1], $c[2], $c[3]]);
    }
    return;
}

function admin_category_save(?int $id): void
{
    $b = body();
    $name = str_trim($b['name'] ?? '', 80);
    if ($name === '') fail('اسم القسم مطلوب');
    $slug = str_trim($b['slug'] ?? '', 60);
    if ($slug === '') $slug = 'cat-' . substr(bin2hex(random_bytes(3)), 0, 6);
    $slug = preg_replace('/[^a-z0-9\-_]/', '', strtolower($slug)) ?: ('cat-' . random_int(100, 999));
    if (preg_match('/^(meta|stats|services|auth|profile|admin|owner|my|regions|categories|uploads|service-requests)$/', $slug)) {
        fail('هذا الاسم محجوز، اختر غيره');
    }

    $data = [
        'slug'        => $slug,
        'name'        => $name,
        'singular'    => str_trim($b['singular'] ?? $name, 80),
        'icon'        => str_trim($b['icon'] ?? 'map-pin', 24),
        'color'       => str_trim($b['color'] ?? '#2ec4b6', 20),
        'description' => str_trim($b['description'] ?? '', 300),
        'route'       => str_trim($b['route'] ?? '', 60),
        'sort_order'  => (int) ($b['sort_order'] ?? 0),
        'layout'      => in_arr($b['layout'] ?? 'card', ['card', 'list', 'row'], 'card'),
        'features'    => json_enc(json_field($b['features'] ?? ['duty' => false, 'schedule' => true, 'status' => true])),
        'is_active'   => !array_key_exists('is_active', $b) ? 1 : (int) (!empty($b['is_active'])),
    ];

    if ($id) {
        $sets = implode(', ', array_map(fn($k) => "$k = :$k", array_keys($data)));
        $data['id'] = $id;
        db()->prepare("UPDATE categories SET $sets WHERE id = :id")->execute($data);
        log_activity('update', 'category', $id, 'عدّل قسم: ' . $name, 'admin', (int) (current_user()['id'] ?? 0));
        ok(['id' => $id, 'message' => 'تم تحديث القسم']);
    } else {
        $st = db()->prepare("INSERT INTO categories (slug,name,singular,icon,color,description,route,sort_order,layout,features,is_active)
                             VALUES (:slug,:name,:singular,:icon,:color,:description,:route,:sort_order,:layout,:features,:is_active)");
        $st->execute($data);
        $newId = (int) db()->lastInsertId();
        log_activity('create', 'category', $newId, 'أضاف قسم: ' . $name, 'admin', (int) (current_user()['id'] ?? 0));
        ok(['id' => $newId, 'message' => 'تمت إضافة القسم، يمكنك الآن إضافة خدمات ضمنه']);
    }
}

function admin_category_delete(?int $id): void
{
    if (!$id) fail('معرف غير صالح');
    $c = db()->prepare("SELECT COUNT(*) c FROM services WHERE category_id = ?");
    $c->execute([$id]);
    if ((int) $c->fetch()['c'] > 0 && empty(body()['force'])) {
        fail('لا يمكن حذف قسم يحتوي على خدمات. احذف الخدمات أولاً أو أرسل force=true', 409);
    }
    db()->prepare("DELETE FROM categories WHERE id = ?")->execute([$id]);
    ok(['message' => 'تم حذف القسم']);
}

function admin_region_save(?int $id): void
{
    $b = body();
    $name = str_trim($b['name'] ?? '', 80);
    if ($name === '') fail('اسم المنطقة مطلوب');
    $zone = in_arr($b['zone'] ?? 'city', ['city', 'rural'], 'city');

    // الهرمية: المحافظة إلزامية، والقرية تتبع مدينة
    $parentId = !empty($b['parent_id']) ? (int) $b['parent_id'] : null;
    $level = $parentId ? 'village' : 'city';
    $govId = !empty($b['governorate_id']) ? (int) $b['governorate_id'] : null;

    // إن كانت قرية، استرِ المحافظة من مدينتها أولاً
    // (قبل فحص الإلزام، لأن اختيار المدينة يكفي لتحديد المحافظة)
    if ($parentId) {
        $st = db()->prepare("SELECT governorate_id, level FROM regions WHERE id = ?");
        $st->execute([$parentId]);
        $parent = $st->fetch();
        if (!$parent || $parent['level'] !== 'city') fail('المدينة المختارة غير صالحة', 422);
        $govId = (int) $parent['governorate_id'];
    }

    // الآن نفحص الإلزام: إما محافظة صريحة، أو مستنتجة من المدينة الأم
    if (!$govId) fail('يجب اختيار المحافظة', 422);

    $data = [
        'name'           => $name,
        'zone'           => $zone,
        'governorate_id' => $govId,
        'parent_id'      => $parentId,
        'level'          => $level,
        'sort_order'     => (int) ($b['sort_order'] ?? 0),
        'is_active'      => !array_key_exists('is_active', $b) ? 1 : (int) (!empty($b['is_active'])),
    ];

    if ($id) {
        // امنع جعل المنطقة أماً لنفسها
        if ($parentId && $parentId === $id) fail('لا يمكن أن تكون المنطقة تابعة لنفسها', 422);
        $data['id'] = $id;
        db()->prepare("UPDATE regions SET name=:name, zone=:zone, governorate_id=:governorate_id,
                       parent_id=:parent_id, level=:level, sort_order=:sort_order, is_active=:is_active
                       WHERE id=:id")->execute($data);
        ok(['id' => $id, 'message' => 'تم تحديث المنطقة']);
    } else {
        try {
            db()->prepare("INSERT INTO regions (name, zone, governorate_id, parent_id, level, sort_order, is_active)
                           VALUES (:name,:zone,:governorate_id,:parent_id,:level,:sort_order,:is_active)")->execute($data);
        } catch (\PDOException $e) {
            fail('هذه المنطقة موجودة مسبقاً', 409);
        }
        $newId = (int) db()->lastInsertId();
        // حدّث محافظة الخدمات المرتبطة إن تغيّرت
        ok(['id' => $newId, 'message' => 'تمت إضافة المنطقة']);
    }
}

/* ═══════════ إدارة الحقول الخاصة بالأقسام ═══════════ */

/** GET /admin/category-fields?category_id=38 */
function admin_fields_list(int $categoryId): void
{
    if ($categoryId > 0) {
        ok(['items' => category_fields_list($categoryId)]);
    }
    // بدون تحديد قسم: أرجع كل الحقول مجمّعةً حسب القسم
    $rows = db()->query(
        "SELECT f.*, c.name AS category_name FROM category_fields f
           JOIN categories c ON c.id = f.category_id
          ORDER BY f.category_id, f.sort_order, f.id"
    )->fetchAll();
    $ids  = array_map(fn($f) => (int) $f['id'], $rows);

    $byField = [];
    if ($ids) {
        $in = implode(',', array_fill(0, count($ids), '?'));
        $os = db()->prepare(
            "SELECT * FROM category_field_options WHERE field_id IN ($in) ORDER BY sort_order, id"
        );
        $os->execute($ids);
        foreach ($os->fetchAll() as $o) $byField[(int) $o['field_id']][] = $o;
    }

    $out = [];
    foreach ($rows as $f) {
        $out[] = [
            'id'           => (int) $f['id'],
            'category_id'  => (int) $f['category_id'],
            'category_name' => $f['category_name'],
            'key'          => $f['field_key'],
            'label'        => $f['label'],
            'type'         => $f['type'],
            'required'     => (bool) (int) $f['required'],
            'placeholder'  => $f['placeholder'] ?? '',
            'help'         => $f['help'] ?? '',
            'show_in_card' => (bool) (int) $f['show_in_card'],
            'filterable'   => (bool) (int) $f['filterable'],
            'sort_order'   => (int) $f['sort_order'],
            'is_active'    => (bool) (int) $f['is_active'],
            'options'      => array_map(fn($o) => [
                'id'    => (int) $o['id'],
                'label' => $o['label'],
                'value' => $o['value'],
                'icon'  => $o['icon'] ?? '',
            ], $byField[(int) $f['id']] ?? []),
        ];
    }
    ok(['items' => $out]);
}

/** POST/PUT /admin/category-fields[/{id}] */
function admin_field_save(?int $id): void
{
    $b     = body();
    $pdo   = db();
    $catId = (int) ($b['category_id'] ?? 0);
    if ($catId <= 0) fail('حدد القسم', 422);

    $st = $pdo->prepare("SELECT id FROM categories WHERE id = ?");
    $st->execute([$catId]);
    if (!$st->fetch()) fail('القسم غير موجود', 404);

    // المفتاح: من الإدخال، أو مشتق من العنوان
    $key = str_trim((string) ($b['key'] ?? ''), 60);
    if ($key === '') {
        $label = str_trim((string) ($b['label'] ?? ''), 80);
        if ($label === '') fail('عنوان الحقل مطلوب', 422);
        $key = 'f' . substr(md5($label . $catId . microtime(true)), 0, 8);
    }
    // المفتاح: حروف لاتينية وأرقام وشرطة سفلية فقط
    if (!preg_match('/^[a-z][a-z0-9_]{1,40}$/i', $key)) {
        $key = 'f' . substr(md5($key), 0, 8);
    }

    $label = str_trim((string) ($b['label'] ?? ''), 80);
    if ($label === '') fail('عنوان الحقل مطلوب', 422);

    $type = in_arr((string) ($b['type'] ?? 'select'), field_types(), 'select');

    // لا نسمح بتغيير نوع حقل قائمة إلى نوع بلا خيارات والعكس دون تنبيه
    if ($id) {
        $old = $pdo->prepare("SELECT type FROM category_fields WHERE id = ?");
        $old->execute([$id]);
        $prev = $old->fetchColumn();
        if ($prev && $prev !== $type && ($prev === 'select' || $type === 'select')) {
            // القيم القديمة لن تُحلّ بشكل صحيح — نُفرغها لمنع عرض بيانات خاطئة
            // (الخيارات نفسها تُحذف تلقائياً عبر ON DELETE CASCADE عند الحاجة لاحقاً)
        }
    }

    $data = [
        'category_id'  => $catId,
        'field_key'    => $key,
        'label'        => $label,
        'type'         => $type,
        'required'     => !empty($b['required']) ? 1 : 0,
        'placeholder'  => str_trim((string) ($b['placeholder'] ?? ''), 120),
        'help'         => str_trim((string) ($b['help'] ?? ''), 200),
        'show_in_card' => !array_key_exists('show_in_card', $b) ? 1 : (!empty($b['show_in_card']) ? 1 : 0),
        'filterable'   => !empty($b['filterable']) ? 1 : 0,
        'suffix'       => str_trim((string) ($b['suffix'] ?? ''), 20),
        'hide_when_false' => !empty($b['hide_when_false']) ? 1 : 0,
        'sort_order'   => (int) ($b['sort_order'] ?? 0),
        'is_active'    => !array_key_exists('is_active', $b) ? 1 : (!empty($b['is_active']) ? 1 : 0),
    ];

    // تفرد المفتاح داخل القسم
    $dup = $pdo->prepare("SELECT id FROM category_fields WHERE category_id = ? AND field_key = ?" . ($id ? " AND id <> $id" : ''));
    $dup->execute([$catId, $key]);
    if ($dup->fetch()) fail('يوجد حقل بنفس المفتاح في هذا القسم', 409);

    if ($id) {
        $sql = "UPDATE category_fields SET " . implode(', ', array_map(fn($k) => "$k = ?", array_keys($data))) . " WHERE id = ?";
        $st  = $pdo->prepare($sql);
        $st->execute([...array_values($data), $id]);
    } else {
        $data['created_at'] = date('c');
        $sql = "INSERT INTO category_fields (" . implode(', ', array_keys($data)) . ") VALUES (" . implode(', ', array_fill(0, count($data), '?')) . ")";
        $st  = $pdo->prepare($sql);
        $st->execute(array_values($data));
        $id  = (int) $pdo->lastInsertId();
    }

    // حفظ الخيارات إن أُرسلت مع الحقل
    if (isset($b['options']) && is_array($b['options']) && $type === 'select') {
        $pdo->prepare("DELETE FROM category_field_options WHERE field_id = ?")->execute([$id]);
        $ins = $pdo->prepare(
            "INSERT INTO category_field_options (field_id, label, value, icon, sort_order, is_active, created_at)
             VALUES (?,?,?,?,?,1,datetime('now'))"
        );
        $i = 0;
        foreach ($b['options'] as $o) {
            $lbl = str_trim((string) (is_array($o) ? ($o['label'] ?? '') : $o), 80);
            if ($lbl === '') continue;
            $val  = str_trim((string) (is_array($o) ? ($o['value'] ?? '') : ''), 80);
            $icon = is_array($o) ? (string) ($o['icon'] ?? '') : '';
            $ins->execute([$id, $lbl, $val, $icon, $i]);
            $i++;
        }
    }

    ok(['id' => $id, 'message' => 'تم حفظ الحقل']);
}

/** DELETE /admin/category-fields/{id} */
function admin_field_delete(?int $id): void
{
    if (!$id) fail('معرّف غير صالح');
    $pdo = db();
    $st  = $pdo->prepare("SELECT category_id, field_key FROM category_fields WHERE id = ?");
    $st->execute([$id]);
    $f = $st->fetch();
    if (!$f) fail('الحقل غير موجود', 404);

    // الخيارات تُمحى تلقائياً (ON DELETE CASCADE)
    $pdo->prepare("DELETE FROM category_fields WHERE id = ?")->execute([$id]);
    ok(['message' => 'تم حذف الحقل']);
}

/** POST/PUT /admin/category-fields/{fieldId}/options[/{optionId}] */
function admin_field_option_save(int $fieldId, ?int $optionId): void
{
    if (!$fieldId) fail('معرّف الحقل غير صالح');
    $b   = body();
    $pdo = db();

    $st = $pdo->prepare("SELECT id, type FROM category_fields WHERE id = ?");
    $st->execute([$fieldId]);
    $f = $st->fetch();
    if (!$f) fail('الحقل غير موجود', 404);
    if ($f['type'] !== 'select') fail('هذا الحقل ليس من نوع قائمة', 422);

    $label = str_trim((string) ($b['label'] ?? ''), 80);
    if ($label === '') fail('عنوان الخيار مطلوب', 422);

    $value = str_trim((string) ($b['value'] ?? ''), 80);
    if ($value === '') $value = $label;          // القيمة = العنوان إن لم تُحدد
    $icon  = str_trim((string) ($b['icon'] ?? ''), 40);
    $sort  = (int) ($b['sort_order'] ?? 0);

    if ($optionId) {
        $pdo->prepare(
            "UPDATE category_field_options SET label=?, value=?, icon=?, sort_order=? WHERE id=? AND field_id=?"
        )->execute([$label, $value, $icon, $sort, $optionId, $fieldId]);
    } else {
        $pdo->prepare(
            "INSERT INTO category_field_options (field_id, label, value, icon, sort_order, is_active, created_at)
             VALUES (?,?,?,?,?,1,datetime('now'))"
        )->execute([$fieldId, $label, $value, $icon, $sort]);
        $optionId = (int) $pdo->lastInsertId();
    }
    ok(['id' => $optionId, 'message' => 'تم حفظ الخيار']);
}

/** DELETE /admin/category-fields/{fieldId}/options/{optionId} */
function admin_field_option_delete(int $fieldId, ?int $optionId): void
{
    if (!$fieldId || !$optionId) fail('معرّف غير صالح');
    $pdo = db();
    $pdo->prepare("DELETE FROM category_field_options WHERE id = ? AND field_id = ?")
        ->execute([$optionId, $fieldId]);
    ok(['message' => 'تم حذف الخيار']);
}

/* ═══════════ إدارة المحافظات ═══════════ */

function admin_governorate_save(?int $id): void
{
    $b = body();
    $name = str_trim($b['name'] ?? '', 80);
    if ($name === '') fail('اسم المحافظة مطلوب');
    $slug = str_trim($b['slug'] ?? '', 60);
    if ($slug === '') $slug = 'gov-' . substr(bin2hex(random_bytes(3)), 0, 6);
    $slug = preg_replace('/[^a-z0-9\-_]/', '', strtolower($slug)) ?: ('gov-' . random_int(100, 999));

    $data = [
        'name'       => $name,
        'slug'       => $slug,
        'zone'       => in_arr($b['zone'] ?? 'city', ['city', 'rural'], 'city'),
        'sort_order' => (int) ($b['sort_order'] ?? 0),
        'is_active'  => !array_key_exists('is_active', $b) ? 1 : (int) (!empty($b['is_active'])),
    ];

    if ($id) {
        $dup = db()->prepare("SELECT id FROM governorates WHERE name = ? AND id != ?");
        $dup->execute([$name, $id]);
        if ($dup->fetch()) fail('هذه المحافظة موجودة مسبقاً', 409);
        $data['id'] = $id;
        db()->prepare("UPDATE governorates SET name=:name, slug=:slug, zone=:zone,
                       sort_order=:sort_order, is_active=:is_active WHERE id=:id")->execute($data);
        log_activity('update', 'governorate', $id, 'عدّل محافظة: ' . $name, 'admin', (int) (current_user()['id'] ?? 0));
        ok(['id' => $id, 'message' => 'تم تحديث المحافظة']);
    } else {
        try {
            db()->prepare("INSERT INTO governorates (name, slug, zone, sort_order, is_active)
                           VALUES (:name,:slug,:zone,:sort_order,:is_active)")->execute($data);
        } catch (\PDOException $e) {
            fail('هذه المحافظة موجودة مسبقاً', 409);
        }
        $newId = (int) db()->lastInsertId();
        log_activity('create', 'governorate', $newId, 'أضاف محافظة: ' . $name, 'admin', (int) (current_user()['id'] ?? 0));
        ok(['id' => $newId, 'message' => 'تمت إضافة المحافظة']);
    }
}

function admin_governorate_delete(?int $id): void
{
    if (!$id) fail('معرّف غير صالح');
    $st = db()->prepare("SELECT name FROM governorates WHERE id = ?");
    $st->execute([$id]);
    $g = $st->fetch();
    if (!$g) fail('المحافظة غير موجودة', 404);

    $cnt = db()->prepare("SELECT COUNT(*) FROM services WHERE governorate_id = ?");
    $cnt->execute([$id]);
    $n = (int) $cnt->fetchColumn();

    if ($n > 0 && empty($_GET['force'])) {
        fail("لا يمكن الحذف: $n خدمة مرتبطة بهذه المحافظة", 409);
    }

    db()->prepare("UPDATE services SET governorate_id = NULL WHERE governorate_id = ?")->execute([$id]);
    db()->prepare("UPDATE regions SET governorate_id = NULL WHERE governorate_id = ?")->execute([$id]);
    db()->prepare("DELETE FROM governorates WHERE id = ?")->execute([$id]);
    log_activity('delete', 'governorate', $id, 'حذف محافظة: ' . $g['name'], 'admin', (int) (current_user()['id'] ?? 0));
    ok(['message' => 'تم حذف المحافظة']);
}

function admin_region_delete(?int $id): void
{
    if (!$id) fail('معرف غير صالح');
    db()->prepare("DELETE FROM regions WHERE id = ?")->execute([$id]);
    ok(['message' => 'تم حذف المنطقة']);
}

function admin_requests_list(): void
{
    $status = arg('status');
    $sql = "SELECT sr.*, c.name AS category_name, c.icon AS category_icon, r.name AS region_name,
                   u.full_name AS user_name, u.phone AS user_phone
            FROM service_requests sr
            LEFT JOIN categories c ON c.id = sr.category_id
            LEFT JOIN regions r ON r.id = sr.region_id
            LEFT JOIN users u ON u.id = sr.user_id WHERE 1=1";
    $args = [];
    if ($status && in_array($status, ['pending', 'approved', 'rejected'], true)) {
        $sql .= " AND sr.status = ?"; $args[] = $status;
    }
    $sql .= " ORDER BY CASE sr.status WHEN 'pending' THEN 0 ELSE 1 END, sr.id DESC LIMIT 300";
    $st = db()->prepare($sql);
    $st->execute($args);
    ok(['items' => $st->fetchAll()]);
}

function admin_request_approve(int $id): void
{
    $admin = require_admin();
    $st = db()->prepare("SELECT * FROM service_requests WHERE id = ?");
    $st->execute([$id]);
    $req = $st->fetch();
    if (!$req) fail('الطلب غير موجود', 404);
    if ($req['status'] === 'approved') fail('الطلب موافق عليه مسبقاً', 409);

    $catId = (int) ($req['category_id'] ?: (int) (body()['category_id'] ?? 0));
    if (!$catId) fail('حدد نوع الخدمة');
    $ownerId = !empty(body()['owner_id']) ? (int) body()['owner_id'] : ((int) $req['want_to_manage'] === 1 && $req['user_id'] ? (int) $req['user_id'] : null);
    $regionId = !empty(body()['region_id']) ? (int) body()['region_id'] : ($req['region_id'] ?: null);
    $name = str_trim(body()['name'] ?? $req['name'], 160);

    // المحافظة: من الطلب، أو تُشتق من المنطقة
    $govId = !empty(body()['governorate_id']) ? (int) body()['governorate_id'] : (int) ($req['governorate_id'] ?? 0);
    if (!$govId && $regionId) {
        $stg = db()->prepare("SELECT governorate_id FROM regions WHERE id = ?");
        $stg->execute([$regionId]);
        $govId = (int) ($stg->fetchColumn() ?: 0);
    }
    $govId = $govId ?: null;

    $ins = db()->prepare("INSERT INTO services (category_id, region_id, governorate_id, owner_id, name, address, phone, whatsapp, note, meta, is_verified)
                          VALUES (?,?,?,?,?,?,?,?,?,?,1)");
    $ins->execute([
        $catId,
        $regionId,
        $govId,
        $ownerId,
        $name,
        $req['address'],
        $req['phone'],
        $req['whatsapp'],
        $req['note'],
        $req['meta'] ?: '{}',
    ]);
    $sid = (int) db()->lastInsertId();
    ensure_status_row($sid);

    // جدول دوام افتراضي إن أُرسل، وإلا جدول عام 9-9
    $sched = body()['schedule'] ?? null;
    if (is_array($sched) && $sched) {
        save_schedule($sid, $sched);
    } else {
        save_schedule($sid, array_map(fn($d) => ['day' => $d, 'opens' => '09:00', 'closes' => '21:00'], [0, 1, 2, 3, 4, 5, 6]));
    }

    db()->prepare("UPDATE service_requests SET status = 'approved', admin_note = ?, created_service_id = ? WHERE id = ?")
        ->execute([str_trim(body()['admin_note'] ?? '', 300), $sid, $id]);

    log_activity('approve', 'service_request', $id, 'وافق على طلب: ' . $name . ' → خدمة #' . $sid, 'admin', (int) $admin['id']);
    ok(['service_id' => $sid, 'message' => 'تمت الموافقة وإنشاء الخدمة' . ($ownerId ? ' وربطها بحساب المستخدم' : '')]);
}

function admin_request_reject(int $id): void
{
    $admin = require_admin();
    db()->prepare("UPDATE service_requests SET status = 'rejected', admin_note = ? WHERE id = ?")
        ->execute([str_trim(body()['admin_note'] ?? '', 300), $id]);
    log_activity('reject', 'service_request', $id, 'رفض طلباً', 'admin', (int) $admin['id']);
    ok(['message' => 'تم رفض الطلب']);
}

function admin_request_delete(int $id): void
{
    db()->prepare("DELETE FROM service_requests WHERE id = ?")->execute([$id]);
    ok(['message' => 'تم حذف الطلب']);
}

function admin_users_list(): void
{
    $sql = "SELECT u.*, (SELECT COUNT(*) FROM services s WHERE s.owner_id = u.id) AS services_count FROM users u WHERE 1=1";
    $args = [];
    if ($q = str_trim((string) arg('q'), 60)) {
        $sql .= " AND (u.full_name LIKE ? OR u.phone LIKE ?)";
        array_push($args, "%$q%", "%$q%");
    }
    if ($r = arg('role')) { $sql .= " AND u.role = ?"; $args[] = in_arr($r, ['admin', 'user'], 'user'); }
    $sql .= " ORDER BY u.id DESC LIMIT 300";
    $st = db()->prepare($sql);
    $st->execute($args);
    $items = array_map(function ($u) {
        unset($u['password_hash']);
        $u['phone_intl'] = phone_intl($u['phone']);
        return $u;
    }, $st->fetchAll());
    ok(['items' => $items]);
}

function admin_user_update(?int $id): void
{
    if (!$id) fail('معرف غير صالح');
    $me  = current_user();
    $b   = body();
    $sets = []; $args = [];
    if (array_key_exists('role', $b)) {
        $role = in_arr($b['role'], ['admin', 'user'], 'user');
        // حماية: لا يمكن تنزيل دورك نفسك من الإدارة
        if ($id === (int) ($me['id'] ?? 0) && $role !== 'admin') fail('لا يمكنك إزالة صلاحية المدير من حسابك', 409);
        $sets[] = 'role = ?'; $args[] = $role;
    }
    if (array_key_exists('is_active', $b)) {
        $active = (int) (!empty($b['is_active']));
        // حماية: لا يمكن تعطيل حسابك بنفسك
        if ($id === (int) ($me['id'] ?? 0) && $active !== 1) fail('لا يمكنك تعطيل حسابك', 409);
        $sets[] = 'is_active = ?'; $args[] = $active;
    }
    if (array_key_exists('full_name', $b)) { $sets[] = 'full_name = ?'; $args[] = str_trim($b['full_name'], 120); }
    if (array_key_exists('phone', $b)) {
        $phone = normalize_phone((string) $b['phone']);
        if (!preg_match('/^09\d{8}$/', $phone)) fail('رقم هاتف سوري غير صالح (مثال: 0991234567)');
        $st = db()->prepare("SELECT id FROM users WHERE phone = ? AND id <> ?");
        $st->execute([$phone, $id]);
        if ($st->fetch()) fail('هذا الرقم مسجّل لمستخدم آخر', 409);
        $sets[] = 'phone = ?'; $args[] = $phone;
    }
    if (array_key_exists('reset_password', $b) && (string) $b['reset_password'] !== '') {
        if (u_len((string) $b['reset_password']) < 6) fail('كلمة المرور قصيرة');
        $sets[] = 'password_hash = ?'; $args[] = password_hash((string) $b['reset_password'], PASSWORD_DEFAULT);
    }
    if (!$sets) fail('لا توجد تغييرات');
    $args[] = $id;
    db()->prepare("UPDATE users SET " . implode(', ', $sets) . " WHERE id = ?")->execute($args);
    $st = db()->prepare("SELECT full_name FROM users WHERE id = ?");
    $st->execute([$id]);
    $uname = (string) ($st->fetchColumn() ?: ('#' . $id));
    log_activity('update', 'user', $id, 'تعديل بيانات المستخدم «' . $uname . '»', 'admin', (int) ($me['id'] ?? 0));
    ok(['message' => 'تم تحديث المستخدم']);
}

function admin_user_delete(?int $id): void
{
    if (!$id) fail('معرف غير صالح');
    $me = current_user();
    if ((int) ($me['id'] ?? 0) === $id) fail('لا يمكنك حذف حسابك', 409);
    $st = db()->prepare("SELECT full_name FROM users WHERE id = ?");
    $st->execute([$id]);
    $uname = (string) ($st->fetchColumn() ?: '');
    if ($uname === '') fail('المستخدم غير موجود', 404);
    db()->prepare("UPDATE services SET owner_id = NULL WHERE owner_id = ?")->execute([$id]);
    db()->prepare("DELETE FROM users WHERE id = ?")->execute([$id]);
    log_activity('delete', 'user', $id, 'حذف المستخدم «' . $uname . '»', 'admin', (int) ($me['id'] ?? 0));
    ok(['message' => 'تم حذف المستخدم وفصل خدماته']);
}

function admin_activity(): void
{
    $st = db()->query("SELECT a.*, u.full_name AS user_name FROM activity_log a LEFT JOIN users u ON u.id = a.user_id ORDER BY a.id DESC LIMIT 100");
    ok(['items' => $st->fetchAll()]);
}


/* ══════════════════════════════════════════════════════════════
   تفريغ بيانات قاعدة البيانات — منطقة الخطر
   ══════════════════════════════════════════════════════════════ */

/** الأنواع القابلة للتفريغ — الترتيب مهم لسلامة المفاتيح الأجنبية */
function clearable_targets(): array
{
    return ['services', 'requests', 'regions', 'governorates', 'users', 'activity'];
}

function admin_data_counts(): void
{
    $d = db();
    $c = [];
    foreach (clearable_targets() as $t) {
        $c[$t] = match ($t) {
            'services'     => (int) $d->query("SELECT COUNT(*) FROM services")->fetchColumn(),
            'requests'     => (int) $d->query("SELECT COUNT(*) FROM service_requests")->fetchColumn(),
            'regions'      => (int) $d->query("SELECT COUNT(*) FROM regions")->fetchColumn(),
            'governorates' => (int) $d->query("SELECT COUNT(*) FROM governorates")->fetchColumn(),
            'users'        => (int) $d->query("SELECT COUNT(*) FROM users")->fetchColumn(),
            'activity'     => (int) $d->query("SELECT COUNT(*) FROM activity_log")->fetchColumn(),
        };
    }
    $c['schedules'] = (int) $d->query("SELECT COUNT(*) FROM schedules")->fetchColumn();
    $c['statuses']  = (int) $d->query("SELECT COUNT(*) FROM service_status")->fetchColumn();
    ok(['counts' => $c]);
}

function admin_data_clear(): void
{
    $b = body();
    $me = current_user();
    $myId = (int) ($me['id'] ?? 0);

    // ── حماية ١: كلمة تأكيد مكتوبة ──
    $confirm = str_trim($b['confirm'] ?? '', 40);
    if (!in_array($confirm, ['احذف', 'احذف ', 'DELETE', 'delete'], true)) {
        fail('اكتب كلمة «احذف» في حقل التأكيد للمتابعة', 422);
    }

    // ── حماية ٢: صلاحية مدير فقط ──
    if (($me['role'] ?? '') !== 'admin') fail('هذه العملية للمدير فقط', 403);

    // ── حماية ٣: تحقّق من الأهداف ──
    $targets = array_values(array_filter(
        array_map('strval', (array) ($b['targets'] ?? [])),
        fn($t) => in_array($t, clearable_targets(), true)
    ));
    if (!$targets) fail('اختر نوع بيانات واحداً على الأقل', 422);

    $d = db();
    $deleted = [];

    $d->beginTransaction();
    try {
        // الترتيب يراعي المفاتيح الأجنبية: الأبناء قبل الآباء
        if (in_array('services', $targets, true)) {
            $d->exec("DELETE FROM schedules");
            $d->exec("DELETE FROM service_status");
            $d->exec("UPDATE service_requests SET created_service_id = NULL");
            $n = $d->exec("DELETE FROM services");
            $deleted['services'] = $n;
            $deleted['schedules'] = (int) $d->query("SELECT COUNT(*) FROM schedules")->fetchColumn();
        }

        if (in_array('requests', $targets, true)) {
            $n = $d->exec("DELETE FROM service_requests");
            $deleted['requests'] = $n;
        }

        if (in_array('regions', $targets, true)) {
            // أفصِل الخدمات عن مناطقها أولاً
            $d->exec("UPDATE services SET region_id = NULL");
            $d->exec("UPDATE regions SET parent_id = NULL");
            $n = $d->exec("DELETE FROM regions");
            $deleted['regions'] = $n;
        }

        if (in_array('governorates', $targets, true)) {
            $d->exec("UPDATE services SET governorate_id = NULL");
            $d->exec("UPDATE regions SET governorate_id = NULL");
            $d->exec("UPDATE service_requests SET governorate_id = NULL");
            $n = $d->exec("DELETE FROM governorates");
            $deleted['governorates'] = $n;
        }

        if (in_array('users', $targets, true)) {
            // لا نحذف حساب المدير الحالي — وإلا أُغلق عليه
            $d->exec("UPDATE services SET owner_id = NULL");
            $d->exec("UPDATE service_requests SET user_id = NULL");
            $d->exec("UPDATE activity_log SET user_id = NULL");
            $st = $d->prepare("DELETE FROM users WHERE id != ?");
            $st->execute([$myId]);
            $deleted['users'] = $st->rowCount();
        }

        if (in_array('activity', $targets, true)) {
            $n = $d->exec("DELETE FROM activity_log");
            $deleted['activity'] = $n;
        }

        $d->commit();
    } catch (\Throwable $e) {
        $d->rollBack();
        fail('فشل التفريغ: ' . $e->getMessage(), 500);
    }

    log_activity('delete', 'data', null, 'فرّغ بيانات: ' . implode('، ', $targets), 'admin', $myId);
    ok(['message' => 'تم تفريغ البيانات المحددة', 'deleted' => $deleted]);
}

function admin_settings_save(): void
{
    $b = body();
    foreach (['site_name', 'city', 'whatsapp_admin'] as $k) {
        if (array_key_exists($k, $b)) set_setting($k, str_trim((string) $b[$k], 200));
    }
    // «العبارة» أُلغيت: لم تعد تُحفظ ولا تُرسل للواجهة

    // زمن التبديل بين الإعلانات بالثواني — يُقيَّد بين 1 و 60
    if (array_key_exists('ad_interval', $b)) {
        $n = (int) $b['ad_interval'];
        if ($n < 1)  $n = 1;
        if ($n > 60) $n = 60;
        set_setting('ad_interval', (string) $n);
    }

    if (array_key_exists('announcements', $b) && is_array($b['announcements'])) {
        $clean = array_values(array_filter(array_map(function ($a) {
            if (!is_array($a)) return null;
            $text = str_trim($a['text'] ?? '', 300);
            if ($text === '') return null;
            $link = str_trim($a['link'] ?? '', 300);
            // روابط http(s) والروابط النسبية فقط — لا javascript:
            if ($link !== '' && !preg_match('#^(https?://|/)#i', $link) ) $link = '';
            return [
                'title' => str_trim($a['title'] ?? '', 120),
                'text'  => $text,
                'tone'  => in_arr($a['tone'] ?? 'info', ['info', 'warning', 'danger', 'success'], 'info'),
                'link'  => $link,
            ];
        }, $b['announcements']), fn($a) => $a !== null));
        set_setting('announcements', json_enc($clean));
    }
    ok(['message' => 'تم حفظ الإعدادات']);
}

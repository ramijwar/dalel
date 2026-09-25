<?php
/**
 * تزويد قاعدة البيانات ببيانات واقعية لمدينة حلب وريفها
 * التشغيل:  php api/seed.php
 */

require __DIR__ . '/includes/db.php';
require __DIR__ . '/includes/helpers.php';
require __DIR__ . '/includes/maintenance.php';

// 🔒 حماية: هذا السكربت يحذف كل البيانات — لا يُشغَّل من الويب بلا صلاحية مدير
require_maintenance_access('seed.php');

$pdo = db();

echo "→ تنظيف البيانات القديمة...\n";
$pdo->exec("DELETE FROM activity_log");
$pdo->exec("DELETE FROM service_requests");
$pdo->exec("DELETE FROM service_status");
$pdo->exec("DELETE FROM schedules");
$pdo->exec("DELETE FROM services");
$pdo->exec("DELETE FROM categories");
$pdo->exec("DELETE FROM regions");
$pdo->exec("DELETE FROM users");
$pdo->exec("DELETE FROM settings");
$pdo->exec("DELETE FROM login_attempts");

// ------------------------------------------------------------------
// الأقسام
// ------------------------------------------------------------------
$categories = [
    [
        'slug' => 'pharmacies', 'name' => 'صيدليات مناوبة', 'singular' => 'صيدلية',
        'icon' => '💊', 'color' => '#34d399', 'description' => 'حالة الصيدليات وتحديثات المناوبة',
        'route' => '/pharmacies', 'sort_order' => 1, 'layout' => 'card',
        'features' => json_encode(['duty' => true, 'schedule' => true, 'status' => true, 'verified' => true]),
    ],
    [
        'slug' => 'doctors', 'name' => 'أطباء مختصون', 'singular' => 'طبيب',
        'icon' => '🩺', 'color' => '#60a5fa', 'description' => 'أطباء حلب واختصاصاتهم ومواعيد عياداتهم',
        'route' => '/doctors', 'sort_order' => 2, 'layout' => 'card',
        'features' => json_encode(['duty' => false, 'schedule' => true, 'status' => true, 'specialty' => true]),
    ],
    [
        'slug' => 'stations', 'name' => 'كازيات', 'singular' => 'كازية',
        'icon' => '⛽', 'color' => '#fbbf24', 'description' => 'حالة محطات الوقود لحظةً بلحظة',
        'route' => '/stations', 'sort_order' => 3, 'layout' => 'card',
        'features' => json_encode(['duty' => false, 'schedule' => true, 'status' => true, 'fuel' => true]),
    ],
    [
        'slug' => 'transport', 'name' => 'سرافيس وباصات', 'singular' => 'خط نقل',
        'icon' => '🚌', 'color' => '#a78bfa', 'description' => 'خطوط النقل في حلب ومخطط الرحلة',
        'route' => '/transport', 'sort_order' => 4, 'layout' => 'row',
        'features' => json_encode(['duty' => false, 'schedule' => true, 'status' => true, 'stops' => true]),
    ],
    [
        'slug' => 'bazaars', 'name' => 'بازارات وأسواق', 'singular' => 'بازار',
        'icon' => '🛍️', 'color' => '#fb7185', 'description' => 'دليل الأسواق والبازارات الثابتة والأسبوعية',
        'route' => '/bazaars', 'sort_order' => 5, 'layout' => 'card',
        'features' => json_encode(['duty' => false, 'schedule' => true, 'status' => true, 'weekly' => true]),
    ],
];

$stCat = $pdo->prepare("INSERT INTO categories (slug,name,singular,icon,color,description,route,sort_order,layout,features) VALUES (?,?,?,?,?,?,?,?,?,?)");
$catId = [];
foreach ($categories as $c) {
    $stCat->execute([$c['slug'], $c['name'], $c['singular'], $c['icon'], $c['color'], $c['description'], $c['route'], $c['sort_order'], $c['layout'], $c['features']]);
    $catId[$c['slug']] = (int) $pdo->lastInsertId();
}
echo "✓ " . count($categories) . " أقسام\n";

// ------------------------------------------------------------------
// المناطق (مدينة حلب + الريف)
// ------------------------------------------------------------------
$city = ['الإسماعيلية','الأعظمية','الميرديان','سيف الدولة','أدونيس','الإذاعة','الأشرفية','الأكرمية','الأنصاري','الأنصاري الشرقي','التلل','الجابرية','الجميلية','الحمدانية','الحميدية','الحيدرية','الخالدية','الرازي','الزبدية','السبيل','السريان الجديدة','السريان القديمة','السكري','السليمانية','الشعار','الشهباء الجديدة','الشهباء القديمة','الشيخ أبو بكر','الشيخ خضر','الشيخ طه','الشيخ مقصود','الصاخور','الصالحين','العزيزية','الفردوس','الفرقان','الفيض','القاطرجي','الكلاسة','المحافظة','المشارقة','المشهد','المعادي','المنشية','الموغامبو','الميدان','الميسر','النيال','الهلك','باب الحديد','باب الفرج','باب النيرب','بستان الباشا','بستان القصر','جمعية الزهراء','جمعية المهندسين','حلب الجديدة','سليمان الحلبي','شارع النيل','شارع فيصل','صلاح الدين','طريق الباب','قاضي عسكر','محطة بغداد','مساكن هنانو','ميسلون','هنانو','الراموسة','الليرمون','الشيخ سعيد','العامرية','الأشرفية الشمالية'];
$rural = ['عفرين','اعزاز','الباب','منبج','السفيرة','دارة عزة','حريتان','عندان','الأتارب','الزربة','دير حافر','مسكنة','تل رفعت','نبل','الزهراء','خان العسل','أورم الكبرى','عينجارة'];

$stReg = $pdo->prepare("INSERT INTO regions (name, zone, sort_order) VALUES (?,?,?)");
$regId = [];
$i = 0;
foreach ($city as $r)  { $stReg->execute([$r, 'city', ++$i]);  $regId[$r] = (int) $pdo->lastInsertId(); }
$i = 0;
foreach ($rural as $r) { $stReg->execute([$r, 'rural', ++$i]); $regId[$r] = (int) $pdo->lastInsertId(); }
echo "✓ " . (count($city) + count($rural)) . " منطقة\n";

// ------------------------------------------------------------------
// المستخدمون
// ------------------------------------------------------------------
function add_user(PDO $pdo, string $phone, string $pass, string $name, string $role, ?string $birth = null, string $bio = ''): int
{
    $st = $pdo->prepare("INSERT INTO users (phone, password_hash, full_name, birth_date, role, bio) VALUES (?,?,?,?,?,?)");
    $st->execute([$phone, password_hash($pass, PASSWORD_DEFAULT), $name, $birth, $role, $bio]);
    return (int) $pdo->lastInsertId();
}

$adminId  = add_user($pdo, '0991000001', 'admin123', 'مدير النظام', 'admin', '1990-04-12', 'إدارة دليل الخدمات');
$pharmId  = add_user($pdo, '0991000002', 'user1234', 'أحمد محمد الحلبي', 'user', '1988-07-03', 'صيدلاني - صيدلية الشفاء');
$doctorId = add_user($pdo, '0991000003', 'user1234', 'رنا عبد الرحمن قوجة', 'user', '1985-11-21', 'طبيبة أطفال');
$userId   = add_user($pdo, '0991000004', 'user1234', 'محمود خالد العلي', 'user', '1995-02-18', '');
echo "✓ 4 مستخدمين (مدير + أصحاب خدمات + مستخدم)\n";

// ------------------------------------------------------------------
// أدوات مساعدة للتوليد
// ------------------------------------------------------------------
mt_srand(20260922);
function pick(array $a) { return $a[mt_rand(0, count($a) - 1)]; }
function phone_from_seed(int $i): string { return '09' . str_pad((string) ((30 + $i * 7919) % 100000000), 8, '0', STR_PAD_LEFT); }

/** توليد جدول دوام واقعي */
function make_schedule(int $serviceId, string $kind): array
{
    $rows = [];
    if ($kind === 'pharmacy_24') {
        for ($d = 0; $d <= 6; $d++) $rows[] = [$serviceId, $d, '00:00', '23:59', 1];
    } elseif ($kind === 'pharmacy_night') {
        for ($d = 0; $d <= 6; $d++) $rows[] = [$serviceId, $d, '09:00', '23:59', 0];
        // مناوبة ليلية تعبر منتصف الليل في أيام محددة
        $night = [1, 3, 5];
        foreach ($night as $d) $rows[] = [$serviceId, $d, '22:00', '06:00', 0];
    } elseif ($kind === 'clinic') {
        // عيادة: أيام محددة فقط، فترتان
        $days = [0, 1, 3, 4];
        foreach ($days as $d) {
            $rows[] = [$serviceId, $d, '10:00', '13:00', 0];
            $rows[] = [$serviceId, $d, '17:00', '21:00', 0];
        }
    } elseif ($kind === 'station') {
        for ($d = 0; $d <= 6; $d++) $rows[] = [$serviceId, $d, '06:00', '23:00', 0];
    } elseif ($kind === 'transport') {
        for ($d = 0; $d <= 5; $d++) $rows[] = [$serviceId, $d, '06:30', '22:00', 0];
        $rows[] = [$serviceId, 6, '07:30', '20:00', 0];
    } elseif ($kind === 'bazaar') {
        foreach ([5, 6, 2] as $d) $rows[] = [$serviceId, $d, '09:00', '21:00', 0];
    } else {
        for ($d = 0; $d <= 6; $d++) $rows[] = [$serviceId, $d, '09:00', '21:00', 0];
    }
    return $rows;
}

$allSchedules = [];
$allStatus = [];

function add_service(PDO $pdo, int $catId, ?int $regId, ?int $ownerId, string $name, string $address, string $phone, string $note, array $meta, string $schedKind, int $sort = 0, bool $verified = false, int $manualChance = 0): int
{
    global $allSchedules, $allStatus;
    $st = $pdo->prepare("INSERT INTO services (category_id, region_id, owner_id, name, address, phone, whatsapp, note, meta, sort_order, is_verified)
                         VALUES (?,?,?,?,?,?,?,?,?,?,?)");
    $st->execute([$catId, $regId, $ownerId, $name, $address, $phone, $phone, $note, json_enc($meta), $sort, $verified ? 1 : 0]);
    $id = (int) $pdo->lastInsertId();
    foreach (make_schedule($id, $schedKind) as $row) $allSchedules[] = $row;

    // بعض الخدمات لها تحديث يدوي (تعمل/مغلقة) من صاحبها
    if ($manualChance > 0 && mt_rand(1, 100) <= $manualChance) {
        $mode = mt_rand(0, 1) ? 'open' : 'closed';
        $allStatus[] = [$id, $mode, $mode === 'open' ? 'مفتوحة حالياً' : 'مغلقة مؤقتاً', 0, null, null];
    } else {
        $allStatus[] = [$id, 'auto', '', 0, null, null];
    }
    return $id;
}

// ------------------------------------------------------------------
// 1) الصيدليات
// ------------------------------------------------------------------
$phNames = ['الشفاء','الحكمة','الزهراء','النور','الأمل','الرحمة','الحياة','السلام','الأنوار','الفرات','الوحدة','الأمانة','اليرموك','الأندلس','البيان','دار الشفاء','ابن سينا','ابن النفيس','الرازي','جبران','الماسة','الوفاء','الإخلاص','النهضة','الأطباء','الجلاء','العروبة','بردى','قاسيون','السلامة','الخير','البيان','المحبة','الشهباء','القلعة','العلم','الرشيد','الفارابي','الكندي','الزهراوي','الحسن','الأمين','النخبة','الرياض','البشير','المنار','الهدى','التقوى','البركة','السعادة','الفرقان','المجد','الأصيل','الزيتون','النرجس','الياسمين','الغدير','الرعاية','الصحة','العافية','البلسم','الشذى','الندى','الرواد','الجيل','المستقبل','الصفاء','الوئام','التعاون','الأصيل','البيان','الحرمين','طيبة','مكة','المدينة','القدس','دمشق','حلب','الشام','الفيحاء','الغوطـة','الربيع','الصيف','الخريف','الشتاء','الشمس','القمر','النجم','الفجر','الضحى','العصر','المغرب','السحر','الغروب','الشروق','الأصيل'];
$prefix = ['صيدلية ', 'صيدلية ', 'صيدلية ', 'صيدلية ', 'صيدلية ', 'صيدلية ', ''];
$lastNames = ['الحلبي','الخطيب','العمار','قوجة','الشهابي','المصري','الجابري','العظم','الكيالي','بابيلي','نحاس','مؤذن','زعتر','الرفاعي','السباعي','الحموي','الحمصي','الدمشقي','البيانوني','الأخرس','زريق','مردم بيك','العابد','الصابوني','الطبّاخ','الهوّاري','السراج','القدسي','الأنطاكي','الموصلي'];
$streetBits = ['شارع بغداد','شارع النيل','شارع فيصل','شارع الجامعة','شارع القلعة','شارع البارون','شارع العزيزية','دوار الشرطة','شارع السيد علي','شارع الجلاء','شارع تشرين','طريق المطار','شارع الحرية','شارع الوحدة','ساحة سعد الله الجابري','شارع الملك فيصل','شارع هنانو','دوار الموت','شارع المستشفى','شارع المدرسة'];

$usedPh = [];
$phCount = 240;
$firstPharmacyId = null;
for ($i = 0; $i < $phCount; $i++) {
    $base = pick($phNames);
    $suffix = '';
    $tries = 0;
    while (isset($usedPh[$base . $suffix]) && $tries < 8) {
        $suffix = ' ' . pick($lastNames);
        $tries++;
    }
    $name = pick($prefix) . $base . $suffix;
    $usedPh[$base . $suffix] = true;

    $regionName = pick($city);
    $phone = phone_from_seed($i + 1);
    $is24 = mt_rand(1, 100) <= 12;
    $kind = $is24 ? 'pharmacy_24' : (mt_rand(1, 100) <= 30 ? 'pharmacy_night' : 'pharmacy_default');
    $owner = null; $verified = false;

    if ($i === 0) { // صيدلية مرتبطة بحساب صيدلاني
        $owner = $pharmId; $verified = true; $kind = 'pharmacy_night';
        $name = 'صيدلية الشفاء';
        $regionName = 'الفرقان';
        $phone = '0991000002';
        $firstPharmacyId = null;
    }

    $id = add_service(
        $pdo,
        $catId['pharmacies'],
        $regId[$regionName],
        $owner,
        $name,
        pick($streetBits) . ' - ' . $regionName,
        $phone,
        $is24 ? 'دوام 24 ساعة' : (mt_rand(1, 100) <= 25 ? 'يوجد توصيل ضمن المنطقة' : ''),
        [
            'pharmacist' => pick($lastNames) ? 'د. ' . pick(['أحمد','محمد','علي','حسن','خالد','سامر','رامي','ياسر','عمر','ماهر']) . ' ' . pick($lastNames) : '',
            'is_24h'     => $is24,
            'delivery'   => mt_rand(1, 100) <= 30,
        ],
        $kind,
        $i,
        $verified || mt_rand(1, 100) <= 20,
        18
    );
    if ($i === 0) $firstPharmacyId = $id;
}
echo "✓ $phCount صيدلية\n";

// مناوبات هذا الأسبوع: مجموعة صيدليات تُرفع عليها راية "مناوبة"
$dutySt = $pdo->prepare("SELECT id FROM services WHERE category_id = ? ORDER BY id");
$dutySt->execute([$catId['pharmacies']]);
$phIds = array_column($dutySt->fetchAll(), 'id');
$dutyFrom = (new DateTimeImmutable('today', new DateTimeZone('Asia/Damascus')))->format('Y-m-d H:i:s');
$dutyTo   = (new DateTimeImmutable('+6 days 23:59', new DateTimeZone('Asia/Damascus')))->format('Y-m-d H:i:s');
$dutyPicked = [];
for ($i = 0; $i < 34; $i++) {
    $sid = $phIds[mt_rand(0, count($phIds) - 1)];
    if (isset($dutyPicked[$sid])) continue;
    $dutyPicked[$sid] = true;
    $k = array_search($sid, array_column($allStatus, 0));
    if ($k !== false) {
        $allStatus[$k] = [$sid, $allStatus[$k][1], $allStatus[$k][2], 1, $dutyFrom, $dutyTo];
    }
}
echo "✓ " . count($dutyPicked) . " صيدلية مناوبة هذا الأسبوع\n";

// ------------------------------------------------------------------
// 2) الأطباء
// ------------------------------------------------------------------
$specialties = [
    ['أمراض قلبية', '🫀'], ['أمراض داخلية', '🩺'], ['أطفال وحديثي الولادة', '👶'], ['نسائية وتوليد', '🤰'],
    ['جراحة عامة', '⚕️'], ['عظمية', '🦴'], ['جلدية', '🧴'], ['عينية', '👁️'], ['أذنية وأنف وحنجرة', '👂'],
    ['عصبية', '🧠'], ['بولية', '💧'], ['صدرية', '🫁'], ['أسنان', '🦷'], ['غدد وسكري', '🍬'],
    ['أورام', '🎗️'], ['كلية', '🫘'], ['روماتيزم', '🦵'], ['نفسية', '🧘'], ['تغذية', '🥗'], ['تجميل', '✨'],
];
$titles = ['د.', 'د.'];
$firstNames = ['أحمد','محمد','علي','حسن','خالد','سامر','رامي','ياسر','عمر','ماهر','رنا','لينا','هبة','سارة','ميادة','ديما','نور','ريم','غادة','سلمى','بشار','فراس','زياد','مهند','طارق','أنس','وائل','عصام','كمال','نضال'];
$clinics = 150;
for ($i = 0; $i < $clinics; $i++) {
    [$spec, $icon] = pick($specialties);
    $gender = mt_rand(0, 1);
    $name = pick($titles) . ' ' . pick($gender ? ['أحمد','محمد','علي','حسن','خالد','سامر','رامي','ياسر','عمر','ماهر','بشار','فراس','زياد','مهند','طارق','أنس','وائل','عصام','كمال','نضال'] : ['رنا','لينا','هبة','سارة','ميادة','ديما','نور','ريم','غادة','سلمى']) . ' ' . pick($lastNames);
    $regionName = pick($city);
    $phone = phone_from_seed(500 + $i);
    $owner = null; $verified = false;
    if ($i === 0) {
        $owner = $doctorId; $verified = true;
        $name = 'د. رنا عبد الرحمن قوجة';
        $spec = 'أطفال وحديثي الولادة'; $icon = '👶';
        $regionName = 'السليمانية'; $phone = '0991000003';
    }
    add_service(
        $pdo,
        $catId['doctors'],
        $regId[$regionName],
        $owner,
        $name,
        'عيادة ' . $spec . ' - ' . pick($streetBits) . ' - ' . $regionName,
        $phone,
        pick(['الحجز مسبقاً عبر الهاتف', 'يوجد معاينة مجانية للأطفال', 'استقبال حتى آخر مريض', '']),
        [
            'specialty' => $spec,
            'specialty_icon' => $icon,
            'consult_fee' => pick([15000, 20000, 25000, 30000, 35000, 50000]),
            'currency' => 'ل.س',
            'hospital' => pick(['', 'مستشفى الجامعة', 'مستشفى الرازي', 'المستشفى الوطني', '']),
        ],
        'clinic',
        $i,
        $verified || mt_rand(1, 100) <= 15,
        10
    );
}
echo "✓ $clinics عيادة/طبيب\n";

// ------------------------------------------------------------------
// 3) الكازيات
// ------------------------------------------------------------------
$brands = ['سادكوب','الوطنية','الشهباء','الفرات','الأمانة','البركة','النور','السلام','الوحدة','الجلاء','الأنوار','الخير','الصفاء','الماسة','الأصيل','الريان','الزيتون','الغدير','الرحمة','الوفاء'];
$fuels = ['بنزين 90','بنزين 95','مازوت','غاز منزلي'];
$stationsCount = 90;
for ($i = 0; $i < $stationsCount; $i++) {
    $isRural = mt_rand(1, 100) <= 25;
    $regionName = $isRural ? pick($rural) : pick($city);
    $name = 'كازية ' . pick($brands);
    $available = [];
    foreach ($fuels as $f) if (mt_rand(1, 100) <= 55) $available[] = $f;
    if (!$available) $available = [pick($fuels)];
    add_service(
        $pdo,
        $catId['stations'],
        $regId[$regionName],
        null,
        $name,
        ($isRural ? 'طريق ' : '') . pick($streetBits) . ' - ' . $regionName,
        phone_from_seed(900 + $i),
        pick(['البيع على البطاقة الذكية', 'يوجد غسيل سيارات', 'مناوبة ليلية', '']),
        [
            'company' => pick($brands),
            'fuels' => $available,
            'smart_card' => mt_rand(1, 100) <= 70,
        ],
        'station',
        $i,
        mt_rand(1, 100) <= 25,
        22
    );
}
echo "✓ $stationsCount كازية\n";

// ------------------------------------------------------------------
// 4) سرافيس وباصات
// ------------------------------------------------------------------
$lines = [
    ['الإذاعة شرقي', ['محطة بغداد','الجميلية','الإذاعة','سيف الدولة','الأنصاري','السكري','الصالحين','المشهد','الكلاسة']],
    ['الإذاعة غربي', ['محطة بغداد','الجميلية','الإذاعة','الميرديان','الفرقان','الحمدانية','حلب الجديدة']],
    ['الأشرفية', ['باب الفرج','الأشرفية','الشيخ خضر','الشيخ مقصود','بستان الباشا','الشيخ طه','الأشرفية الشمالية']],
    ['الأعظمية', ['ساحة سعد الله الجابري','السبيل','الأعظمية','الفرقان','الحمدانية','العامرية','جمعية المهندسين']],
    ['الخالدية', ['باب الحديد','الخالدية','السليمانية','الميدان','العزيزية','الجميلية','التلل','المشارقة','الفيض','الحمدانية','الفرقان']],
    ['الدائري الجنوبي', ['محطة بغداد','الصاخور','طريق الباب','الميسر','هنانو','مساكن هنانو','الشيخ سعيد','الصالحين','السكري','الأنصاري','سيف الدولة','الإذاعة','الميرديان','الفرقان','الحمدانية','حلب الجديدة','الراموسة','الشيخ سعيد','الصاخور']],
    ['الدائري الشمالي', ['باب النيرب','الصاخور','الهلك','الشيخ خضر','الأشرفية','الشيخ مقصود','بستان الباشا','السليمانية','الميدان','العزيزية','السبيل','الأعظمية','الفرقان','الليرمون','الراموسة']],
    ['الراموسة', ['محطة بغداد','الجميلية','الفرقان','الحمدانية','الراموسة','الكازية الكبيرة','المدينة الصناعية']],
    ['الشيخ سعيد', ['باب النيرب','الصاخور','الشيخ سعيد','العامرية','قاضي عسكر','باب الحديد']],
    ['الشيخ مقصود', ['باب الفرج','الأشرفية','الشيخ مقصود','الشيخ طه','الشيخ خضر','بستان الباشا','الشيخ أبو بكر','الهلك','الصاخور','باب النيرب','قاضي عسكر','الميدان','العزيزية','الجميلية']],
    ['الفردوس', ['محطة بغداد','الميدان','العزيزية','الفردوس','مساكن هنانو','النيال','الميسر']],
    ['الليرمون', ['باب الفرج','الجميلية','الفرقان','الليرمون','المدينة الصناعية','خان العسل']],
    ['باب النيرب', ['باب النيرب','الصاخور','قاضي عسكر','الميدان','العزيزية','السبيل','الأعظمية']],
    ['حلب الجديدة', ['محطة بغداد','الجميلية','الحمدانية','حلب الجديدة','جمعية الزهراء','جمعية المهندسين']],
    ['صلاح الدين', ['باب الفرج','صلاح الدين','الميدان','العزيزية','السبيل','الأعظمية','الفرقان']],
    ['مساكن هنانو', ['محطة بغداد','الميدان','مساكن هنانو','هنانو','الميسر','النيال']],
    ['السفيرة', ['الكراج الشرقي','النيال','الميسر','الشيخ سعيد','السفيرة','الحاجب','تل عرن']],
    ['عفرين', ['كراج عفرين','حريتان','عندان','دير جمال','عفرين']],
];
foreach ($lines as $i => [$lineName, $stops]) {
    $type = mt_rand(1, 100) <= 30 ? 'باص' : 'سرفيس';
    $regionName = pick($city);
    add_service(
        $pdo,
        $catId['transport'],
        $regId[$regionName],
        null,
        'خط ' . $lineName,
        'من ' . $stops[0] . ' إلى ' . end($stops),
        phone_from_seed(1400 + $i),
        'قد تختلف مواعيد الانطلاق حسب الازدحام',
        [
            'vehicle' => $type,
            'fare' => pick([4000, 5000, 6000, 8000, 10000]),
            'currency' => 'ل.س',
            'stops_count' => count($stops),
            'stops' => $stops,
            'start_point' => $stops[0],
            'end_point' => end($stops),
            'frequency' => pick(['كل 5 دقائق','كل 10 دقائق','كل 15 دقيقة','عند امتلاء السرفيس']),
        ],
        'transport',
        $i,
        true,
        8
    );
}
echo "✓ " . count($lines) . " خط نقل\n";

// ------------------------------------------------------------------
// 5) البازارات
// ------------------------------------------------------------------
$bazaars = [
    ['سوق الجمعة - الحمدانية', 'الحمدانية', 'أسبوعي'],
    ['بازار الشهباء', 'الشهباء الجديدة', 'أسبوعي'],
    ['سوق الهال القديم', 'باب النيرب', 'دائم'],
    ['بازار الفرقان', 'الفرقان', 'أسبوعي'],
    ['سوق النسوان', 'الجميلية', 'دائم'],
    ['بازار السليمانية', 'السليمانية', 'أسبوعي'],
    ['سوق المدينة القديم (السويقة)', 'الحميدية', 'دائم'],
    ['بازار حلب الجديدة', 'حلب الجديدة', 'أسبوعي'],
    ['سوق الأحد - الميسر', 'الميسر', 'أسبوعي'],
    ['بازار الأعظمية', 'الأعظمية', 'أسبوعي'],
    ['سوق خان الوزير', 'المنشية', 'دائم'],
    ['بازار الأشرفية', 'الأشرفية', 'أسبوعي'],
    ['سوق الخضرة المركزي', 'الصاخور', 'دائم'],
    ['بازار عفرين الشعبي', 'عفرين', 'أسبوعي'],
    ['سوق اعزاز المركزي', 'اعزاز', 'دائم'],
    ['بازار الباب', 'الباب', 'أسبوعي'],
    ['سوق منبج', 'منبج', 'دائم'],
    ['بازار السفيرة', 'السفيرة', 'أسبوعي'],
];
foreach ($bazaars as $i => [$name, $regionName, $type]) {
    add_service(
        $pdo,
        $catId['bazaars'],
        $regId[$regionName],
        null,
        $name,
        $regionName,
        phone_from_seed(1800 + $i),
        $type === 'أسبوعي' ? pick(['يوم الجمعة من كل أسبوع','يوم السبت من كل أسبوع','يومان في الأسبوع']) : 'مفتوح يومياً',
        ['market_type' => $type, 'day' => $type === 'أسبوعي' ? pick(['الجمعة','السبت','الأحد']) : 'يومياً'],
        'bazaar',
        $i,
        true,
        12
    );
}
echo "✓ " . count($bazaars) . " بازار\n";

// ------------------------------------------------------------------
// إدخال الجداول والحالات
// ------------------------------------------------------------------
$insS = $pdo->prepare("INSERT INTO schedules (service_id, day, opens, closes, is_24h) VALUES (?,?,?,?,?)");
$pdo->beginTransaction();
foreach ($allSchedules as $row) $insS->execute($row);
$pdo->commit();

$insT = $pdo->prepare("INSERT INTO service_status (service_id, mode, note, on_duty, duty_from, duty_to) VALUES (?,?,?,?,?,?)");
$pdo->beginTransaction();
foreach ($allStatus as $row) $insT->execute($row);
$pdo->commit();
echo "✓ " . count($allSchedules) . " فترة دوام، " . count($allStatus) . " سجل حالة\n";

// ربط صيدلية الشفاء بحساب الصيدلاني + جدول مناوبة ليلي
if ($firstPharmacyId) {
    $pdo->prepare("DELETE FROM schedules WHERE service_id = ?")->execute([$firstPharmacyId]);
    $rows = [];
    for ($d = 0; $d <= 6; $d++) $rows[] = [$firstPharmacyId, $d, '08:30', '23:00', 0];
    foreach ([1, 3, 5] as $d) $rows[] = [$firstPharmacyId, $d, '23:00', '08:00', 0];
    $ins2 = $pdo->prepare("INSERT INTO schedules (service_id, day, opens, closes, is_24h) VALUES (?,?,?,?,?)");
    foreach ($rows as $r) $ins2->execute($r);
    $pdo->prepare("UPDATE service_status SET on_duty = 1, duty_from = ?, duty_to = ?, mode = 'auto' WHERE service_id = ?")->execute([$dutyFrom, $dutyTo, $firstPharmacyId]);
}

// ------------------------------------------------------------------
// إعدادات + إعلانات
// ------------------------------------------------------------------
$weekStart = (new DateTimeImmutable('monday this week', new DateTimeZone('Asia/Damascus')))->format('j-n-Y');
$weekEnd   = (new DateTimeImmutable('sunday this week', new DateTimeZone('Asia/Damascus')))->format('j-n-Y');
set_setting('site_name', 'وين في؟');
set_setting('tagline', 'حالة عدد من الخدمات اليومية في مدينة حلب لحظةً بلحظة');
set_setting('city', 'حلب');
set_setting('whatsapp_admin', '963991000001');
set_setting('announcements', json_encode([
    ['text' => 'تم تحديث جدول الصيدليات المناوبة للأسبوع الحالي (' . $weekStart . ' إلى ' . $weekEnd . ')', 'tone' => 'danger'],
    ['text' => 'أصحاب الصيدليات والعيادات: سجّلوا حسابكم لتتمكنوا من تحديث حالة خدماتكم لحظياً', 'tone' => 'info'],
], JSON_UNESCAPED_UNICODE));

// ------------------------------------------------------------------
// طلبات إضافة خدمة (نماذج جاهزة للمدير)
// ------------------------------------------------------------------
$pending = [
    [$pharmId, $catId['pharmacies'], $regId['الشيخ مقصود'], 'صيدلية الأندلس', 'شارع الشيخ مقصود الرئيسي', '0992345678', 1],
    [null, $catId['doctors'], $regId['الفرقان'], 'د. سامر العبد الله', 'عيادة جلدية - شارع النيل', '0993456789', 1],
    [null, $catId['stations'], $regId['الراموسة'], 'كازية الراموسة الجديدة', 'طريق الراموسة - قرب الكراج', '0994567890', 0],
    [$userId, $catId['transport'], $regId['هنانو'], 'خط هنانو - الجامعة', 'من هنانو إلى شارع الجامعة', '0995678901', 0],
];
$insR = $pdo->prepare("INSERT INTO service_requests (user_id, category_id, region_id, name, address, phone, want_to_manage) VALUES (?,?,?,?,?,?,?)");
foreach ($pending as $p) $insR->execute($p);
echo "✓ " . count($pending) . " طلبات إضافة معلّقة\n";

// ------------------------------------------------------------------
// ملخص
// ------------------------------------------------------------------
$total = $pdo->query("SELECT COUNT(*) c FROM services")->fetch()['c'];
$open = 0;
$rowsAll = $pdo->query("SELECT s.*, ss.mode, ss.expires_at, ss.on_duty, ss.duty_from, ss.duty_to, ss.updated_at FROM services s LEFT JOIN service_status ss ON ss.service_id = s.id")->fetchAll();
$map = [];
foreach ($pdo->query("SELECT * FROM schedules")->fetchAll() as $s) $map[(int) $s['service_id']][] = $s;
foreach ($rowsAll as $r) if (compute_status($r, $map[(int) $r['id']] ?? [])['status'] === 'open') $open++;

echo "\n===== تم التزويد بنجاح =====\n";
echo "إجمالي الخدمات: $total — تعمل الآن (حسب الوقت الحالي): $open\n";
echo "حساب المدير:  0991000001 / admin123\n";
echo "حساب صيدلاني: 0991000002 / user1234  (يملك صيدلية الشفاء)\n";
echo "حساب طبيبة:   0991000003 / user1234\n";
echo "حساب مستخدم:  0991000004 / user1234\n";

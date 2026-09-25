<?php
/**
 * ══════════════════════════════════════════════════════════════════════
 *  حماية سكربتات الصيانة — install.php · seed.php · migrate_fields.php
 * ══════════════════════════════════════════════════════════════════════
 *
 *  🔴 المشكلة التي يحلّها هذا الملف:
 *
 *  هذه السكربتات **تحذف قاعدة البيانات**. وكانت متاحة عبر الويب بلا أي
 *  مصادقة:
 *      GET /api/seed.php                  ← يمحو كل شيء ويعيد البيانات
 *      GET /api/install.php?confirm=yes   ← يمحو كل شيء ويبني قاعدة جديدة
 *
 *  أي أن أي زائر يعرف الرابط يستطيع محو الموقع بطلب واحد.
 *  (install.php كان يطلب كلمة «confirm=yes» فقط — وهي ليست حماية.)
 *
 *  ── القاعدة المطبَّقة ──
 *    • من الطرفية (CLI)              → مسموح دائماً (php seed.php)
 *    • عبر HTTP ويوجد حساب مدير      → يلزم رمز مدير صالح (Bearer Token)
 *    • عبر HTTP ولا يوجد أي مدير     → مسموح (تثبيت أول: لا شيء لنُفقده)
 *
 *  الحالة الأخيرة ضرورية للتركيب الأول، فلا يوجد حساب بعد لنصادقه.
 *  وبمجرد إنشاء المدير يُغلق الباب تلقائياً.
 *
 *  ملاحظة: هذا احتياط دفاعي يعمل على أي خادم (Nginx مثلاً لا يقرأ
 *  .htaccess). الطبقة الأولى هي قواعد المنع في .htaccess.
 * ══════════════════════════════════════════════════════════════════════
 */

/** هل يوجد في قاعدة البيانات حساب مدير نشط؟ */
function maintenance_admin_exists(): bool
{
    $file = dirname(__DIR__) . '/storage/app.sqlite';
    if (!is_file($file)) {
        return false;                 // لا قاعدة بعد → تثبيت أول
    }

    try {
        $pdo = new PDO('sqlite:' . $file);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $n = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'admin'")->fetchColumn();
        return (int) $n > 0;
    } catch (\Throwable $e) {
        // قاعدة غير مقروءة أو جداول ناقصة → اعتبرها تثبيتاً أولاً
        return false;
    }
}

/**
 * بوابة الدخول لسكربتات الصيانة.
 * تُنهي التنفيذ إن لم تتوفر الصلاحية.
 *
 * @param string $script اسم السكربت (لرسائل الخطأ)
 */
function require_maintenance_access(string $script = ''): void
{
    // ① الطرفية: مسموح دائماً
    if (PHP_SAPI === 'cli') {
        return;
    }

    // ② تثبيت أول (لا مدير بعد): مسموح — لا يوجد ما نحميه
    if (!maintenance_admin_exists()) {
        return;
    }

    // ③ يوجد مدير: لا بد من رمز مدير صالح
    $root = dirname(__DIR__);           // مجلد api/
    foreach (['db.php', 'token.php', 'auth.php', 'helpers.php'] as $inc) {
        $p = $root . '/includes/' . $inc;
        if (is_file($p)) {
            require_once $p;
        }
    }

    // نبني استجابة واضحة بدل كشف تفاصيل داخلية
    $deny = static function (string $msg): void {
        http_response_code(403);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['ok' => false, 'message' => $msg], JSON_UNESCAPED_UNICODE);
        exit;
    };

    if (!function_exists('current_user')) {
        $deny('هذا السكربت محمي — شغّله من الطرفية (CLI).');
    }

    // قاعدة غير قابلة للقراءة لا يجوز أن تفتح الباب — نرفض بأمان
    try {
        $user = current_user();
    } catch (\Throwable $e) {
        $deny('تعذّر التحقق من الصلاحية — شغّل السكربت من الطرفية (CLI).');
    }

    if ($user === null) {
        $deny('هذا السكربت محمي. سجّل الدخول بحساب مدير ثم شغّله مع ترويسة Authorization، أو شغّله من الطرفية (CLI).');
    }
    if (($user['role'] ?? '') !== 'admin') {
        $deny('هذا السكربت متاح للمدير فقط.');
    }

    // مسموح — نُسجّل الحدث
    if (function_exists('log_activity')) {
        log_activity('maintenance', 'script', null, 'تشغيل سكربت صيانة: ' . ($script ?: 'unknown'), 'admin', (int) $user['id']);
    }
}

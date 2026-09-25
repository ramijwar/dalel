<?php
/**
 * خادم الإنتاج: يخدم واجهة React + API + الصور المرفوعة
 * يعمل من أي مجلد فرعي — يكتشف مساره تلقائياً
 */

$root = __DIR__;

// اكتشاف basePath
// في Apache/Nginx: SCRIPT_NAME = /router.php أو /winfeen/router.php
// في PHP built-in server: قد يضع SCRIPT_NAME = مسار الطلب (بدون .php)
$scriptName = $_SERVER['SCRIPT_NAME'] ?? '/';
$requestUri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

if (str_ends_with($scriptName, '.php')) {
    // Apache/Nginx — dirname يعطي basePath الصحيح
    $basePath = rtrim(str_replace('\\', '/', dirname($scriptName)), '/');
} else {
    // PHP built-in server — استخدم __DIR__ لحساب basePath
    $docRoot = str_replace('\\', '/', $_SERVER['DOCUMENT_ROOT'] ?? getcwd());
    $appRoot = str_replace('\\', '/', $root);
    $basePath = '';
    if ($docRoot !== $appRoot && str_starts_with($appRoot, $docRoot)) {
        $basePath = substr($appRoot, strlen($docRoot));
    }
    $basePath = rtrim($basePath, '/');
}

// إزالة basePath من URI
$uri = $requestUri;
if ($basePath !== '' && $basePath !== '/' && str_starts_with($uri, $basePath)) {
    $uri = substr($uri, strlen($basePath)) ?: '/';
}
$uri = $uri ?: '/';
$uriPath = parse_url($uri, PHP_URL_PATH) ?: '/';

// ── ملفات الـ API ──
// نبحث عن /api في مسار الطلب الأصلي مباشرة، قبل أي قصّ لـ basePath.
// هذا يجعل التوجيه يعمل مهما كانت طريقة حساب basePath على الخادم
// (Apache / Nginx / LiteSpeed / خادم PHP المدمج / مجلد فرعي بأي اسم).
$rawUri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

if (preg_match('#/api(/|$)#', $rawUri)) {
    $pos     = strpos($rawUri, '/api');
    $apiPath = substr($rawUri, $pos + 4);          // ما بعد "/api"
    if ($apiPath === '' || $apiPath[0] !== '/') { $apiPath = '/' . ltrim($apiPath, '/'); }

    // مسار نظيف لـ api.php: بدون مجلد فرعي، وبدون قصّ إضافي
    $_SERVER['REQUEST_URI'] = '/api' . $apiPath;
    $_SERVER['SCRIPT_NAME'] = '/router.php';

    // احفظ مسار المجلد الأصلي (/daleltest مثلاً) قبل أن نطمسه:
    // تحتاجه واجهة الـAPI لبناء روابط مطلقة صحيحة (رابط تنزيل ملف APK).
    $_SERVER['WF_BASE_PATH'] = $basePath;

    require $root . '/api/api.php';
    return true;
}

// ── الصور المرفوعة ── (نفس المنهج: البحث في المسار الأصلي)
if (preg_match('#/uploads/(.+)$#', $rawUri, $m)) {
    $file = $root . '/api/storage/uploads/' . basename($m[1]);
    if (is_file($file)) {
        $types = [
            'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg',
            'png' => 'image/png', 'webp' => 'image/webp', 'gif' => 'image/gif',
        ];
        $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        header('Content-Type: ' . ($types[$ext] ?? 'application/octet-stream'));
        header('Cache-Control: public, max-age=31536000');
        readfile($file);
        return true;
    }
    http_response_code(404);
    header('Content-Type: application/json');
    echo '{"ok":false,"message":"الملف غير موجود"}';
    return true;
}

// ── الملفات الثابتة (CSS / JS / صور) ──
$file = $root . $uriPath;
if ($uriPath !== '/' && is_file($file)) {
    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    $types = [
        'html' => 'text/html; charset=utf-8',
        'js'   => 'application/javascript; charset=utf-8',
        'css'  => 'text/css; charset=utf-8',
        'svg'  => 'image/svg+xml',
        'json' => 'application/json',
        'png'  => 'image/png',
        'jpg'  => 'image/jpeg',
        'ico'  => 'image/x-icon',
        'webp' => 'image/webp',
        'woff' => 'font/woff',
        'woff2'=> 'font/woff2',
        'map'  => 'application/json',
        'txt'  => 'text/plain; charset=utf-8',
        'apk'  => 'application/vnd.android.package-archive',
    ];
    header('Content-Type: ' . ($types[$ext] ?? 'application/octet-stream'));
    header('Cache-Control: public, max-age=31536000');
    readfile($file);
    return true;
}

// ── أصول مفقودة: أعطِ 404 صريحاً بدل إرجاع HTML ──
// (يمنع خطأ MIME الذي يجعل التطبيق لا يعمل عند تحديث صفحة داخلية)
if (preg_match('#\.(js|css|map|json|png|jpe?g|gif|svg|webp|ico|woff2?|ttf)$#i', $uriPath)) {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Not Found';
    return true;
}

// ── SPA fallback: أي مسار آخر → index.html ──
$index = $root . '/index.html';
if (is_file($index)) {
    $html = file_get_contents($index);

    // حقن <base href> حتى تُحَل المسارات النسبية (./assets/…) دائماً
    // من جذر التطبيق — سواء كان/winfeen/ أو أي مجلد فرعي آخر.
    // بدون هذا: تحديث /winfeen/s/1 يطلب /winfeen/s/assets/… ويفشل.
    $href = ($basePath === '' ? '/' : $basePath . '/');
    $baseTag = '<base href="' . htmlspecialchars($href, ENT_QUOTES, 'UTF-8') . '">';
    if (stripos($html, '<base') === false) {
        $count = 0;
        $html = preg_replace('/<head(\s[^>]*)?>/i', '<head$1>' . $baseTag, $html, 1, $count);
        if ($count === 0) {
            // احتياط: لا يوجد <head> — أضِف الوسم في بداية المستند
            $html = $baseTag . $html;
        }
    }

    header('Content-Type: text/html; charset=utf-8');
    header('Cache-Control: no-store, must-revalidate');
    echo $html;
    return true;
}

http_response_code(503);
header('Content-Type: text/html; charset=utf-8');
echo '<!DOCTYPE html><html lang="ar" dir="rtl"><body style="background:#0b111d;color:#fff;font-family:sans-serif;text-align:center;padding:80px">';
echo '<h1>⚠️ الواجهة غير مبنية</h1>';
echo '<p>شغّل: <code style="background:#1a2a3a;padding:6px 12px;border-radius:6px">cd client &amp;&amp; npm run build &amp;&amp; cp -r dist/* ../ </code></p>';
echo '</body></html>';
return true;

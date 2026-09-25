<?php
/**
 * ══════════════════════════════════════════════════════════════════════
 *  تدوير مفتاح توقيع الجلسات (secret.key) — من الطرفية فقط (CLI)
 * ══════════════════════════════════════════════════════════════════════
 *
 *  لماذا؟
 *    كان `api/storage/secret.key` متاحاً للتنزيل العام قبل إغلاق الثغرة.
 *    ومن يملك هذا المفتاح يستطيع **تزوير رمز دخول بدور مدير** — بلا كلمة
 *    مرور، وبصلاحيات كاملة على الموقع. إغلاق الثغرة يمنع سرقته مستقبلاً،
 *    لكن **قيمته المسرَّبة تبقى صالحة ما لم تُبدَّل**. هذه الأداة تبدّلها.
 *
 *  الاستعمال:
 *      php api/rotate_key.php              ← يعرض الحالة ويسأل قبل التدوير
 *      php api/rotate_key.php --rotate     ← يدوّر مباشرةً (لِلسكربتات)
 *      php api/rotate_key.php --check      ← حالة المفتاح فقط، بلا تغيير
 *
 *  الأثر:
 *    • كل الجلسات القائمة تُبطَل — كل مستخدم (وأنت) يسجّل الدخول من جديد.
 *    • لا تُفقد أي بيانات، ولا يتأثر أي شيء آخر.
 *
 *  🔒 لا يُطبع المفتاح أبداً — يُطبع بصمة (أول ١٢ حرفاً من SHA-256) فقط،
 *     وهي غير قابلة للعكس فلا تكشف المفتاح.
 * ══════════════════════════════════════════════════════════════════════
 */

declare(strict_types=1);

// ─── رفض أي وصول عبر الويب ───
if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'ok'      => false,
        'message' => 'هذه الأداة تعمل من الطرفية فقط (php api/rotate_key.php).',
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

define('APP_ROOT', __DIR__);
$keyFile = APP_ROOT . '/storage/secret.key';
$storeDir = APP_ROOT . '/storage';

$args = array_slice($argv, 1);
$checkOnly = in_array('--check', $args, true) || in_array('-c', $args, true);
$autoYes   = in_array('--rotate', $args, true) || in_array('-r', $args, true);

/** بصمة غير عاكسة للمفتاح — لا تكشفه */
function key_fingerprint(string $key): string
{
    return substr(hash('sha256', $key), 0, 12);
}

function read_key(string $file): ?string
{
    if (!is_file($file)) {
        return null;
    }
    $s = trim((string) @file_get_contents($file));
    return $s === '' ? null : $s;
}

echo "\n";
echo "  ═══════════════════════════════════════════════\n";
echo "   تدوير مفتاح الجلسات — دليل الدير\n";
echo "  ═══════════════════════════════════════════════\n\n";

// ─── الحالة الحالية ───
$old = read_key($keyFile);

if ($old === null) {
    echo "  الحالة: لا يوجد مفتاح في الملف\n";
    echo "          ($keyFile)\n\n";
    echo "  لا حاجة لتدوير شيء — سيُولَّد مفتاح جديد تلقائياً عند أول\n";
    echo "  طلب يمنح رمز دخول. ولو أردت توليده الآن:\n";
    echo "      php api/rotate_key.php --rotate\n\n";
    if (!$autoYes) {
        exit(0);
    }
    echo "  ── توليد مفتاح جديد ──\n\n";
} else {
    printf("  المفتاح الحالي: %d بايت · البصمة %s\n", strlen($old), key_fingerprint($old));
    $perm = @fileperms($keyFile);
    $permTxt = $perm ? substr(sprintf('%o', $perm), -4) : '؟';
    printf("  صلاحيات الملف : %s %s\n\n", $permTxt, ($permTxt === '0600' ? '✅' : '(المستحسن 0600)'));

    if ($checkOnly) {
        echo "  (وضع الفحص — لم يُغيَّر شيء)\n\n";
        echo "  للتدوير:  php api/rotate_key.php --rotate\n\n";
        exit(0);
    }

    if (!$autoYes) {
        echo "  ⚠️  التدوير يُبطل كل الجلسات: كل مستخدم مسجَّل سيخرج\n";
        echo "      ويحتاج تسجيل الدخول من جديد. لا تُفقد أي بيانات.\n\n";
        echo "  للمتابعة اكتب (yes) ثم Enter، وللإلغاء اكتب أي شيء آخر:\n";
        echo "      > ";
        $answer = trim((string) fgets(STDIN));
        if (!in_array(strtolower($answer), ['yes', 'y', 'نعم'], true)) {
            echo "\n  أُلغي — لم يُغيَّر المفتاح.\n\n";
            exit(0);
        }
        echo "\n";
    }
}

// ─── التحقق من إمكانية الكتابة ───
if (!is_dir($storeDir) || !is_writable($storeDir)) {
    fwrite(STDERR, "✗ مجلد التخزين غير قابل للكتابة: $storeDir\n");
    fwrite(STDERR, "  المفتاح لا يمكن توليده بدون صلاحية كتابة على هذا المجلد.\n");
    exit(1);
}

// ─── التوليد والكتابة الذرّية ───
// النسق مطابق لما يولّده token.php عند غياب الملف: ٣٢ بايت عشوائية hex.
$new = bin2hex(random_bytes(32));
$tmp = $keyFile . '.tmp';

if (@file_put_contents($tmp, $new) === false) {
    fwrite(STDERR, "✗ تعذّرت الكتابة: $tmp\n");
    exit(1);
}
@chmod($tmp, 0600);

if (!@rename($tmp, $keyFile)) {
    @unlink($tmp);
    fwrite(STDERR, "✗ تعذّر استبدال الملف: $keyFile\n");
    exit(1);
}
@chmod($keyFile, 0600);

echo "  ✅ تم التدوير\n\n";
if ($old !== null) {
    printf("     قبل: %s\n", key_fingerprint($old));
}
printf("     بعد: %s\n", key_fingerprint($new));
printf("     الملف: %s (%d بايت · 0600)\n\n", $keyFile, strlen($new));

// ─── تحقق وظيفي: رمز جديد يُصدَر ويُتحقَّق منه فعلياً ───
require APP_ROOT . '/includes/token.php';

try {
    $t = issue_token(0, 'admin', 1);
    $ok = verify_token($t);
    if (is_array($ok) && isset($ok['role']) && $ok['role'] === 'admin') {
        echo "  ✅ تحقق: رمز جديد صدر وتحقّق بنجاح بالمفتاح الجديد\n";
    } else {
        echo "  ⚠️  تحذير: صدر رمز لكن التحقق منه لم ينجح — راجع صلاحيات المجلد\n";
    }
} catch (\Throwable $e) {
    echo "  ⚠️  تعذّر التحقق الوظيفي: " . $e->getMessage() . "\n";
}

echo "\n  ما بعد التدوير:\n";
echo "    ١. أنت وكل المستخدمين ستُطلب منكم إعادة تسجيل الدخول (مرة واحدة).\n";
echo "    ٢. إن كان المفتاح مسرَّباً، فالقيمة المسرَّبة صارت بلا قيمة الآن.\n";
echo "    ٣. غيّر كلمة مرور المدير أيضاً إن شككت في تسرّبها:\n";
echo "         php api/set_password.php <رقم_هاتف_المدير>\n\n";
echo "    ٤. ⚠️ لا ترفع أرشيفاً يحتوي secret.key بعد الآن — وإلا عاد\n";
echo "       مفتاح قديم معروف. الأرشيف الحالي لا يحتويه.\n\n";

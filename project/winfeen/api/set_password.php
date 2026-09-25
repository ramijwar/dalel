<?php
/**
 * ══════════════════════════════════════════════════════════════════════
 *  تعيين كلمة مرور مستخدم — من الطرفية فقط (CLI)
 * ══════════════════════════════════════════════════════════════════════
 *
 *  الاستعمال:
 *      php api/set_password.php 0936651837 "كلمة_المرور_الجديدة"
 *      php api/set_password.php 0936651837            ← يولّد كلمة عشوائية
 *
 *  يعرض أيضاً قائمة الحسابات إن شُغّل بلا وسائط:
 *      php api/set_password.php --list
 *
 *  🔒 لا يعمل عبر المتصفح إطلاقاً — يرفض أي طلب HTTP.
 *     السبب: أداة تعيد تعيين كلمات المرور لا يجوز أن تكون على الويب.
 *
 *  متى تحتاجه؟
 *    • نسيت كلمة مرور المدير.
 *    • استوردت قاعدة بيانات من مصدر آخر ولا تعرف كلمات مرورها.
 * ══════════════════════════════════════════════════════════════════════
 */

declare(strict_types=1);

// ─── رفض أي وصول عبر الويب ───
if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'ok'      => false,
        'message' => 'هذه الأداة تعمل من الطرفية فقط (php api/set_password.php).',
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

$dbFile = __DIR__ . '/storage/app.sqlite';

if (!is_file($dbFile)) {
    fwrite(STDERR, "✗ قاعدة البيانات غير موجودة: $dbFile\n");
    fwrite(STDERR, "  شغّل أولاً: php api/install.php\n");
    exit(1);
}

$args = array_slice($argv, 1);

try {
    $pdo = new PDO('sqlite:' . $dbFile);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (\Throwable $e) {
    fwrite(STDERR, "✗ تعذّر فتح قاعدة البيانات: " . $e->getMessage() . "\n");
    exit(1);
}

// ─── عرض الحسابات ───
if ($args === [] || in_array($args[0], ['--list', '-l', 'list'], true)) {
    echo "\n  الحسابات في قاعدة البيانات:\n\n";
    $rows = $pdo->query("SELECT id, phone, full_name, role, is_active FROM users ORDER BY role, id")->fetchAll(PDO::FETCH_ASSOC);
    if (!$rows) {
        echo "    (لا يوجد أي حساب)\n\n";
        exit(0);
    }
    printf("    %-4s %-13s %-22s %-7s %s\n", 'ID', 'الهاتف', 'الاسم', 'الدور', 'نشط');
    echo "    " . str_repeat('─', 60) . "\n";
    foreach ($rows as $r) {
        printf(
            "    %-4s %-13s %-22s %-7s %s\n",
            $r['id'],
            $r['phone'],
            mb_substr((string) $r['full_name'], 0, 20),
            $r['role'],
            ((int) $r['is_active'] === 1) ? 'نعم' : 'لا'
        );
    }
    echo "\n  لتعيين كلمة مرور:\n";
    echo "    php api/set_password.php <رقم_الهاتف> \"<كلمة_المرور>\"\n\n";
    exit(0);
}

// ─── تعيين كلمة المرور ───
$phone = trim((string) ($args[0] ?? ''));
if ($phone === '') {
    fwrite(STDERR, "✗ حدّد رقم الهاتف. مثال: php api/set_password.php 0936651837 \"MyPass123\"\n");
    exit(1);
}

$password = $args[1] ?? '';
if ($password === '') {
    // توليد كلمة مرور عشوائية قوية
    $alphabet = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    $password = '';
    for ($i = 0; $i < 12; $i++) {
        $password .= $alphabet[random_int(0, strlen($alphabet) - 1)];
    }
    echo "  ℹ️  لم تُدخِل كلمة مرور — وُلّدت واحدة تلقائياً:\n\n";
    echo "        \033[1;33m$password\033[0m\n\n";
}

if (mb_strlen($password) < 6) {
    fwrite(STDERR, "✗ كلمة المرور قصيرة جداً — 6 أحرف على الأقل.\n");
    exit(1);
}

$st = $pdo->prepare("SELECT id, full_name, role FROM users WHERE phone = ?");
$st->execute([$phone]);
$user = $st->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    fwrite(STDERR, "✗ لا يوجد حساب بالرقم: $phone\n");
    fwrite(STDERR, "  لعرض الحسابات: php api/set_password.php --list\n");
    exit(1);
}

$hash = password_hash($password, PASSWORD_DEFAULT);
$pdo->prepare("UPDATE users SET password_hash = ?, updated_at = datetime('now') WHERE id = ?")
    ->execute([$hash, (int) $user['id']]);

// تحقّق فعلي فوري
$st = $pdo->prepare("SELECT password_hash FROM users WHERE id = ?");
$st->execute([(int) $user['id']]);
$check = (string) $st->fetchColumn();
$verified = password_verify($password, $check);

echo "\n";
echo "  ✓ الحساب:     {$user['full_name']} (#{$user['id']}) — {$user['role']}\n";
echo "  ✓ الهاتف:     $phone\n";
echo "  ✓ كلمة المرور: $password\n";
echo "  " . ($verified ? '✓ تم التحقق من الكلمة فعلياً بالدخول إلى الهاش' : '✗ فشل التحقق — راجع الخطأ') . "\n\n";
echo "  ⚠️  غيّرها بعد الدخول من صفحة الملف الشخصي إن أردت.\n\n";

exit($verified ? 0 : 1);

<?php
/**
 * طبقة المصادقة والصلاحيات
 */

function bearer_token(): ?string
{
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($h === '' && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        $h = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    }
    if (preg_match('/Bearer\s+(\S+)/i', (string) $h, $m)) {
        return $m[1];
    }
    if (!empty($_GET['token']) && is_string($_GET['token'])) {
        return $_GET['token'];
    }
    return null;
}

/** المستخدم الحالي أو null */
function current_user(): ?array
{
    static $cached = false;
    static $user = null;
    if ($cached) {
        return $user;
    }
    $cached = true;

    $token = bearer_token();
    if ($token === null) {
        return $user = null;
    }
    $payload = verify_token($token);
    if ($payload === null) {
        return $user = null;
    }
    $st = db()->prepare("SELECT id, phone, password_hash, full_name, birth_date, avatar, bio, role, is_active, created_at FROM users WHERE id = ?");
    $st->execute([(int) $payload['sub']]);
    $row = $st->fetch();
    if (!$row || (int) $row['is_active'] !== 1) {
        return $user = null;
    }
    return $user = $row;
}

function public_user(array $u): array
{
    return [
        'id'         => (int) $u['id'],
        'phone'      => $u['phone'],
        'phone_intl' => phone_intl($u['phone']),
        'full_name'  => $u['full_name'] ?? '',
        'birth_date' => $u['birth_date'] ?? null,
        'avatar'     => $u['avatar'] ?? null,
        'bio'        => $u['bio'] ?? '',
        'role'       => $u['role'],
        'created_at' => $u['created_at'] ?? null,
    ];
}

function require_auth(): array
{
    $u = current_user();
    if ($u === null) {
        fail('يجب تسجيل الدخول للمتابعة', 401);
    }
    return $u;
}

function require_admin(): array
{
    $u = require_auth();
    if ($u['role'] !== 'admin') {
        fail('هذه العملية متاحة للمدير فقط', 403);
    }
    return $u;
}

function client_ip(): string
{
    return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
}

/**
 * حدّ لمحاولات الدخول الفاشلة: 30 محاولة كل 5 دقائق لكل IP.
 * تُسجَّل المحاولة قبل التحقق، وتُمسح سجلات IP عند نجاح الدخول.
 */
function throttle_login(): void
{
    $pdo = db();
    $pdo->prepare("DELETE FROM login_attempts WHERE created_at < datetime('now', '-5 minutes')")->execute();
    $st = $pdo->prepare("SELECT COUNT(*) c FROM login_attempts WHERE ip = ?");
    $st->execute([client_ip()]);
    if ((int) $st->fetch()['c'] >= 30) {
        fail('محاولات دخول كثيرة جداً من عنوانك، انتظر بضع دقائق ثم أعد المحاولة', 429);
    }
    $pdo->prepare("INSERT INTO login_attempts (ip) VALUES (?)")->execute([client_ip()]);
}

/** مسح سجل المحاولات بعد دخول ناجح */
function reset_login_throttle(): void
{
    db()->prepare("DELETE FROM login_attempts WHERE ip = ?")->execute([client_ip()]);
}

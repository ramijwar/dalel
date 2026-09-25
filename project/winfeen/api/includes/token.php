<?php
/**
 * رموز دخول موقّعة (HMAC-SHA256) بدون اعتماديات خارجية
 */

function token_secret(): string
{
    $file = APP_ROOT . '/storage/secret.key';
    if (is_file($file)) {
        $s = trim((string) file_get_contents($file));
        if ($s !== '') {
            return $s;
        }
    }
    $s = bin2hex(random_bytes(32));
    file_put_contents($file, $s);
    @chmod($file, 0600);
    return $s;
}

function b64url(string $data): string
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function b64url_decode(string $data): string
{
    $pad = strlen($data) % 4;
    if ($pad) {
        $data .= str_repeat('=', 4 - $pad);
    }
    return (string) base64_decode(strtr($data, '-_', '+/'));
}

function issue_token(int $userId, string $role, int $ttlDays = 14): string
{
    $header  = b64url(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
    $payload = b64url(json_encode([
        'sub'  => $userId,
        'role' => $role,
        'iat'  => time(),
        'exp'  => time() + $ttlDays * 86400,
    ]));
    $sig = b64url(hash_hmac('sha256', $header . '.' . $payload, token_secret(), true));
    return $header . '.' . $payload . '.' . $sig;
}

function verify_token(string $token): ?array
{
    $parts = explode('.', $token);
    if (count($parts) !== 3) {
        return null;
    }
    [$h, $p, $s] = $parts;
    $expect = b64url(hash_hmac('sha256', $h . '.' . $p, token_secret(), true));
    if (!hash_equals($expect, $s)) {
        return null;
    }
    $payload = json_decode(b64url_decode($p), true);
    if (!is_array($payload) || !isset($payload['exp']) || $payload['exp'] < time()) {
        return null;
    }
    return $payload;
}

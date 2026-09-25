<?php
/**
 * أدوات عامة: إخراج JSON، التحقق من المدخلات، حساب حالة التوفر
 */

const APP_TIMEZONE = 'Asia/Damascus';

function app_now(): DateTimeImmutable
{
    return new DateTimeImmutable('now', new DateTimeZone(APP_TIMEZONE));
}

function json_out($data, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function ok($data = []): void
{
    json_out(['ok' => true] + (is_array($data) ? $data : ['data' => $data]));
}

function fail(string $message, int $status = 400, array $extra = []): void
{
    json_out(['ok' => false, 'message' => $message] + $extra, $status);
}

function body(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        return $_POST ?: [];
    }
    $json = json_decode($raw, true);
    return is_array($json) ? $json : [];
}

/** تطبيع أرقام الهاتف السورية: 09xxxxxxxx / +9639xxxxxxxx / 9639xxxxxxxx */
function normalize_phone(string $phone): string
{
    $digits = preg_replace('/\D+/', '', $phone) ?? '';
    if ($digits === '') {
        return '';
    }
    if (str_starts_with($digits, '00963')) {
        $digits = substr($digits, 5);
    } elseif (str_starts_with($digits, '963') && strlen($digits) >= 12) {
        $digits = substr($digits, 3);
    }
    if (!str_starts_with($digits, '0') && strlen($digits) === 9) {
        $digits = '0' . $digits;
    }
    return $digits;
}

function phone_intl(string $phone): string
{
    $d = normalize_phone($phone);
    if ($d === '') {
        return '';
    }
    return str_starts_with($d, '0') ? '+963' . substr($d, 1) : '+' . $d;
}

/** رقم صالح للاستخدام في واتساب (بدون + أو أصفار) */
function whatsapp_number(string $phone): string
{
    return ltrim(phone_intl($phone), '+');
}

/**
 * بدائل آمنة لـ mbstring: تعمل مع UTF-8 حتى لو لم تكن الإضافة مثبتة على الاستضافة.
 */
function u_len(string $s): int
{
    if (function_exists('mb_strlen')) {
        return mb_strlen($s, 'UTF-8');
    }
    return (int) preg_match_all('/./us', $s);
}

function u_substr(string $s, int $start, ?int $length = null): string
{
    if (function_exists('mb_substr')) {
        return mb_substr($s, $start, $length, 'UTF-8');
    }
    preg_match_all('/./us', $s, $m);
    return implode('', $length === null
        ? array_slice($m[0], $start)
        : array_slice($m[0], $start, $length));
}

function str_trim(?string $v, int $max = 500): string
{
    $v = trim((string) $v);
    return u_substr($v, 0, $max);
}

function in_arr($v, array $list, $default = null)
{
    return in_array($v, $list, true) ? $v : $default;
}

/** التحقق من صيغة الوقت HH:MM */
function valid_time(?string $t): bool
{
    return is_string($t) && (bool) preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $t);
}

/** تحويل "Y-m-d H:i:s" المخزّن بتوقيت التطبيق إلى طابع زمني Unix */
function ts_of(?string $dt): ?int
{
    if ($dt === null || $dt === '') {
        return null;
    }
    try {
        return (new DateTimeImmutable($dt, new DateTimeZone(APP_TIMEZONE)))->getTimestamp();
    } catch (\Throwable $e) {
        return null;
    }
}

function minutes_of(string $t): int
{
    [$h, $m] = array_map('intval', explode(':', $t));
    return $h * 60 + $m;
}

/**
 * حساب حالة التوفر اللحظية لخدمة
 * @param array $service   صف الخدمة (يشمل mode / expires_at / updated_at)
 * @param array $schedules صفوف الجدول: day, opens, closes, is_24h
 * @return array{status:string,label:string,sublabel:string,source:string,updated_at:?string,next_open:?string,closes_at:?string}
 */
function compute_status(array $service, array $schedules): array
{
    $now       = app_now();
    $dayIndex  = ((int) $now->format('N')) % 7; // 0 = الأحد
    $minutes   = (int) $now->format('H') * 60 + (int) $now->format('i');
    $updatedAt = $service['updated_at'] ?? null;

    $nowTs = $now->getTimestamp();

    $manual = $service['mode'] ?? 'auto';
    if ($manual !== 'auto') {
        $expiresAt = ts_of($service['expires_at'] ?? null);
        $expired   = $expiresAt !== null && $expiresAt <= $nowTs;
        if (!$expired) {
            return [
                'status'     => $manual === 'open' ? 'open' : 'closed',
                'label'      => $manual === 'open' ? 'تعمل الآن' : 'مغلقة الآن',
                'sublabel'   => $manual === 'open' ? 'تحديث يدوي من المسؤول عن الخدمة' : 'تحديث يدوي من المسؤول عن الخدمة',
                'source'     => 'manual',
                'updated_at' => $updatedAt,
                'next_open'  => null,
                'closes_at'  => null,
            ];
        }
    }

    // البحث ضمن جدول الدوام
    $openRow = null;
    foreach ($schedules as $s) {
        if ((int) $s['day'] !== $dayIndex) {
            continue;
        }
        if ((int) $s['is_24h'] === 1) {
            $openRow = $s;
            break;
        }
        $o = minutes_of($s['opens']);
        $c = minutes_of($s['closes']);
        if ($c > $o) {
            if ($minutes >= $o && $minutes < $c) {
                $openRow = $s;
                break;
            }
        } else { // دوام ليلي يعبر منتصف الليل
            if ($minutes >= $o || $minutes < $c) {
                $openRow = $s;
                break;
            }
        }
    }

    if ($openRow !== null) {
        $closesAt = null;
        if ((int) $openRow['is_24h'] !== 1) {
            $closesAt = $openRow['closes'];
        }
        return [
            'status'     => 'open',
            'label'      => 'تعمل الآن',
            'sublabel'   => (int) $openRow['is_24h'] === 1 ? 'دوام 24 ساعة' : ('حتى ' . $openRow['closes']),
            'source'     => 'schedule',
            'updated_at' => $updatedAt,
            'next_open'  => null,
            'closes_at'  => $closesAt,
        ];
    }

    // أقرب وقت فتح قادم خلال 7 أيام
    $nextOpen = null;
    for ($i = 0; $i < 8; $i++) {
        $d  = ($dayIndex + $i) % 7;
        $best = null;
        foreach ($schedules as $s) {
            if ((int) $s['day'] !== $d) {
                continue;
            }
            if ((int) $s['is_24h'] === 1) {
                $best = '00:00';
                break;
            }
            $o = minutes_of($s['opens']);
            if ($i === 0 && $o <= $minutes) {
                continue;
            }
            if ($best === null || $o < minutes_of($best)) {
                $best = $s['opens'];
            }
        }
        if ($best !== null) {
            $nextOpen = ['day' => $d, 'time' => $best, 'in_days' => $i];
            break;
        }
    }

    $dayNames = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    $sub      = 'لا يوجد جدول دوام محدد';
    if ($nextOpen !== null) {
        if ($nextOpen['in_days'] === 0) {
            $sub = 'تفتح اليوم ' . $nextOpen['time'];
        } elseif ($nextOpen['in_days'] === 1) {
            $sub = 'تفتح غداً ' . $nextOpen['time'];
        } else {
            $sub = 'تفتح ' . $dayNames[$nextOpen['day']] . ' ' . $nextOpen['time'];
        }
    }

    return [
        'status'     => 'closed',
        'label'      => 'مغلقة الآن',
        'sublabel'   => $sub,
        'source'     => 'schedule',
        'updated_at' => $updatedAt,
        'next_open'  => $nextOpen,
        'closes_at'  => null,
    ];
}

function on_duty_now(array $service): bool
{
    if ((int) ($service['on_duty'] ?? 0) !== 1) {
        return false;
    }
    $now  = app_now()->getTimestamp();
    $from = ts_of($service['duty_from'] ?? null);
    $to   = ts_of($service['duty_to'] ?? null);
    if ($from !== null && $from > $now) {
        return false;
    }
    if ($to !== null && $to < $now) {
        return false;
    }
    return true;
}

/** ترميز JSON بشكل آمن مع دعم العربية */
function json_enc($data): string
{
    $j = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
    return $j === false ? '{}' : $j;
}

function json_field($raw, array $default = []): array
{
    if (is_array($raw)) {
        return $raw;
    }
    if ($raw === null || $raw === '') {
        return $default;
    }
    $d = json_decode((string) $raw, true);
    return is_array($d) ? $d : $default;
}

/** تجميع صف خدمة كامل (مع الحالة والجدول) */
function shape_service(array $row, ?array $schedules = null): array
{
    $meta = json_field($row['meta'] ?? '{}');
    $status = compute_status($row, $schedules ?? []);
    $duty   = on_duty_now($row);

    // الحقول الخاصة بالقسم — محلولة وجاهزة للعرض مباشرة
    $fields = resolve_service_fields((int) ($row['category_id'] ?? 0), is_array($meta) ? $meta : []);

    return [
        'id'          => (int) $row['id'],
        'name'        => $row['name'],
        'category_id' => (int) $row['category_id'],
        'region_id'   => $row['region_id'] !== null ? (int) $row['region_id'] : null,
        'region_name' => $row['region_name'] ?? null,
        'region_zone' => $row['region_zone'] ?? null,
        'region_level' => $row['region_level'] ?? null,
        'city_name' => $row['city_name'] ?? null,
        'governorate_id' => isset($row['governorate_id']) ? (int) $row['governorate_id'] : null,
        'governorate_name' => $row['governorate_name'] ?? null,
        'governorate_slug' => $row['governorate_slug'] ?? null,
        'category_slug' => $row['category_slug'] ?? null,
        'category_name' => $row['category_name'] ?? null,
        'category_icon' => $row['category_icon'] ?? null,
        'specialty_id'  => $row['specialty_id'] ?? null,
        'fields'      => $fields,
        'address'     => $row['address'] ?? '',
        'phone'       => $row['phone'] ?? '',
        'phone_intl'  => phone_intl($row['phone'] ?? ''),
        'whatsapp'    => $row['whatsapp'] ?? '',
        'whatsapp_number' => whatsapp_number($row['whatsapp'] ?: ($row['phone'] ?? '')),
        'note'        => $row['note'] ?? '',
        'photo'       => $row['photo'] ?? null,
        'meta'        => $meta,
        'is_verified' => (bool) ($row['is_verified'] ?? 0),
        'owner_id'    => $row['owner_id'] !== null ? (int) $row['owner_id'] : null,
        'owner_name'  => $row['owner_name'] ?? null,
        'status'      => $status['status'],
        'status_label' => $status['label'],
        'status_sublabel' => $status['sublabel'],
        'status_source' => $status['source'],
        'closes_at'   => $status['closes_at'],
        'on_duty'     => $duty,
        'duty_from'   => $row['duty_from'] ?? null,
        'duty_to'     => $row['duty_to'] ?? null,
        'updated_at'  => $row['updated_at'] ?? null,
        'created_at'  => $row['created_at'] ?? null,
    ];
}

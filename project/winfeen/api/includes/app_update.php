<?php
/**
 * تحديث تطبيق أندرويد — من داخل التطبيق
 * ============================================================
 * المدير يرفع ملف APK من لوحة التحكم (أو يضعه في مجلد /apk عبر FTP)،
 * فيقرأ الخادم الإصدار **من داخل الملف نفسه** (AndroidManifest.xml)
 * وينشره. التطبيق يسأل نقطة عامة فيعرف أن هناك إصداراً أحدث فيعرض
 * بطاقة التحديث في تبويب «حسابي».
 *
 * لا مكتبات خارجية: قارئ ZIP/AXML مكتوب هنا بـ PHP خالص، لأن
 * استضافة المستخدم قد تكون بلا امتداد zip.
 */

// =============================================================
//  إعدادات— المفاتيح المخزّنة في جدول settings
// =============================================================
const APP_APK_DIRNAME = 'apk';   // مجلد الملفات في جذر الموقع

function app_apk_dir(): string
{
    return dirname(APP_ROOT) . '/' . APP_APK_DIRNAME;
}

/** كل إعدادات التحديث كما هي مخزّنة */
function app_update_raw(): array
{
    return [
        'apk_file'     => (string) setting('app_apk_file', ''),
        'version_name' => (string) setting('app_version_name', ''),
        'version_code' => (int) setting('app_version_code', '0'),
        'notes'        => (string) setting('app_update_notes', ''),
        'force'        => setting('app_update_force', '0') === '1',
        'url'          => (string) setting('app_update_url', ''),
        'size'         => (int) setting('app_apk_size', '0'),
        'sha256'       => (string) setting('app_apk_sha256', ''),
        'uploaded_at'  => (int) setting('app_apk_uploaded_at', '0'),
    ];
}

/** هل الملف المذكور موجود فعلاً على القرص؟ */
function app_update_file_exists(?string $file = null): bool
{
    $file = $file ?? (string) setting('app_apk_file', '');
    if ($file === '') return false;
    return is_file(app_apk_dir() . '/' . basename($file));
}

/** رابط التنزيل المطلق — يتعامل مع أي مجلد فرعي (/ أو /daleltest) */
function app_update_download_url(): string
{
    $url = trim((string) setting('app_update_url', ''));
    if ($url !== '') return $url;

    $file = (string) setting('app_apk_file', '');
    if ($file === '') return '';

    return base_url() . '/' . APP_APK_DIRNAME . '/' . rawurlencode(basename($file));
}

/**
 * رأس الموقع المطلق (https://example.com/daleltest) — يُشتق من الطلب.
 * دالة مستقلة كي لا تعتمد نقطة التطبيق على وجود الجلسة.
 */
function base_url(): string
{
    $https  = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https')
        || ((int) ($_SERVER['SERVER_PORT'] ?? 0) === 443);
    $scheme = $https ? 'https' : 'http';
    $host   = $_SERVER['HTTP_HOST'] ?? ($_SERVER['SERVER_NAME'] ?? 'localhost');

    // مسار المجلد:
    // ١) ما حفظه router.php (يعمل في أي مجلد فرعي — /daleltest مثلاً)
    if (isset($_SERVER['WF_BASE_PATH'])) {
        $dir = rtrim(str_replace('\\', '/', (string) $_SERVER['WF_BASE_PATH']), '/');
    } else {
        // ٢) طلب مباشر إلى api/api.php: /daleltest/api/api.php → /daleltest
        $script = str_replace('\\', '/', $_SERVER['SCRIPT_NAME'] ?? '');
        $dir    = rtrim(str_replace('\\', '/', dirname($script)), '/');
    }
    if (str_ends_with($dir, '/api')) {
        $dir = rtrim(substr($dir, 0, -4), '/');
    }
    if ($dir === '/' || $dir === '.') $dir = '';

    return $scheme . '://' . $host . $dir;
}

/**
 * الحمولة العامة التي يقرأها تطبيق أندرويد.
 * `available` = يوجد ملف فعلاً — فلا يعرض التطبيق تحديثاً معطوباً.
 */
function app_update_public(): array
{
    $r        = app_update_raw();
    $hasFile  = app_update_file_exists($r['apk_file']);
    $url      = app_update_download_url();
    $code     = (int) $r['version_code'];

    return [
        'available'    => ($hasFile || $r['url'] !== '') && $code > 0 && $r['version_name'] !== '',
        'version_name' => $r['version_name'],
        'version_code' => $code,
        'notes'        => $r['notes'],
        'force'        => (bool) $r['force'],
        'size'         => $r['size'],
        'sha256'       => $r['sha256'],
        'url'          => $url,
        'has_file'     => $hasFile,
        'published_at' => $r['uploaded_at'] > 0 ? date('c', $r['uploaded_at']) : null,
    ];
}

/** معلومات مفصّلة للمدير — تشمل حالة الملف والمجلد وحدود الرفع */
function app_update_admin(): array
{
    $r    = app_update_raw();
    $dir  = app_apk_dir();
    $file = $dir . '/' . basename($r['apk_file']);

    return $r + [
        'has_file'      => app_update_file_exists($r['apk_file']),
        'download_url'  => app_update_download_url(),
        'dir'           => APP_APK_DIRNAME . '/',
        'dir_writable'  => is_dir($dir) ? is_writable($dir) : is_writable(dirname($dir)),
        'upload_limit'  => upload_limit_bytes(),
        'upload_limit_h'=> human_size(upload_limit_bytes()),
        'max_upload'    => ini_get('upload_max_filesize'),
        'post_max'      => ini_get('post_max_size'),
        'file_size_h'   => $r['size'] > 0 ? human_size($r['size']) : '',
        'zip_ok'        => function_exists('gzinflate'),
        'apks_in_dir'   => app_update_list_apks(),
    ];
}

/**
 * حدّ الرفع الفعلي = الأصغر بين upload_max_filesize و post_max_size.
 */
function upload_limit_bytes(): int
{
    $a = parse_ini_size((string) ini_get('upload_max_filesize'));
    $b = parse_ini_size((string) ini_get('post_max_size'));
    if ($a <= 0) return $b;
    if ($b <= 0) return $a;
    return min($a, $b);
}

function parse_ini_size(string $v): int
{
    $v = trim($v);
    if ($v === '') return 0;
    $unit = strtolower(substr($v, -1));
    $n    = (float) $v;
    return match ($unit) {
        'g'     => (int) ($n * 1024 * 1024 * 1024),
        'm'     => (int) ($n * 1024 * 1024),
        'k'     => (int) ($n * 1024),
        default => (int) $n,
    };
}

function human_size(int $bytes): string
{
    if ($bytes <= 0) return '0';
    if ($bytes >= 1024 * 1024 * 1024) return round($bytes / 1073741824, 2) . ' غيغا';
    if ($bytes >= 1024 * 1024)        return round($bytes / 1048576, 1) . ' ميغا';
    if ($bytes >= 1024)               return round($bytes / 1024, 0) . ' ك.ب';
    return $bytes . ' بايت';
}

// =============================================================
//  قراءة ملف APK: ZIP + AndroidManifest.xml الثنائي (بلا مكتبات)
// =============================================================

/**
 * قراءة مدخل واحد من ملف ZIP (تقريب الخدمة) — بلا ZipArchive.
 * يدعم الطريقتين: مخزّن (0) و مضغوط deflate (8)، وهو ما تستعمله APK.
 */
function apk_zip_entry(string $zipPath, string $entryName): ?string
{
    $fh = @fopen($zipPath, 'rb');
    if (!$fh) return null;

    $size = (int) filesize($zipPath);
    $tailLen = min($size, 66000);
    fseek($fh, $size - $tailLen);
    $tail = (string) fread($fh, $tailLen);

    $p = strrpos($tail, "PK\x05\x06");   // EOCD
    if ($p === false) { fclose($fh); return null; }

    $e = unpack('vdisk/vcddisk/ventriesC/vtotal/VcdSize/VcdOffset', substr($tail, $p + 4, 16));
    $total    = (int) $e['total'];
    $cdSize   = (int) $e['cdSize'];
    $cdOffset = (int) $e['cdOffset'];

    if ($total <= 0 || $cdSize <= 0 || $cdOffset <= 0 || $cdOffset > $size) { fclose($fh); return null; }

    fseek($fh, $cdOffset);
    $cd  = (string) fread($fh, min($cdSize, 16 * 1024 * 1024));
    $off = 0;
    $out = null;

    for ($i = 0; $i < $total; $i++) {
        if (substr($cd, $off, 4) !== "PK\x01\x02") break;
        $h = unpack(
            'vver/vneed/vflag/vmethod/vtime/vdate/Vcrc/VcSize/VuSize/vnameLen/vextraLen/vcommentLen/vdisk/vinAttr/VoutAttr/VlocalOff',
            substr($cd, $off + 4, 42)
        );
        $entryOffset = $off + 46;
        $name        = substr($cd, $entryOffset, (int) $h['nameLen']);
        $off         = $entryOffset + (int) $h['nameLen'] + (int) $h['extraLen'] + (int) $h['commentLen'];

        if ($name !== $entryName) continue;

        // ترويسة الملف المحلية: أطوال الاسم/الإضافي قد تختلف عن المركزية
        fseek($fh, (int) $h['localOff']);
        $lh = (string) fread($fh, 30);
        if (substr($lh, 0, 4) !== "PK\x03\x04") break;
        $l = unpack('vver/vflag/vmethod/vtime/vdate/Vcrc/VcSize/VuSize/vnameLen/vextraLen', substr($lh, 4, 26));

        fseek($fh, (int) $h['localOff'] + 30 + (int) $l['nameLen'] + (int) $l['extraLen']);
        $raw = (string) fread($fh, (int) $h['cSize']);

        $method = (int) $l['method'];
        $out = match ($method) {
            0       => $raw,
            8       => @gzinflate($raw) ?: null,
            default => null,
        };
        break;
    }

    fclose($fh);
    return $out;
}

/**
 * قراءة package / versionCode / versionName من AndroidManifest.xml الثنائي.
 * المراجع: بنية resXMLTree في AOSP.
 */
function apk_axml_manifest(string $bin): ?array
{
    if (strlen($bin) < 16) return null;
    $head = unpack('vtype/vheaderSize/Vsize', substr($bin, 0, 8));
    if ($head['type'] !== 0x0003) return null;   // ليس AXML

    $len     = strlen($bin);
    $pos     = 8;
    $strings = [];
    $resMap  = [];
    $result  = null;

    while ($pos + 8 <= $len) {
        $c = unpack('vtype/vheaderSize/Vsize', substr($bin, $pos, 8));
        $cSize = (int) $c['size'];
        if ($cSize < 8 || $pos + $cSize > $len) break;
        $body = substr($bin, $pos, $cSize);

        if ($c['type'] === 0x0001) {                 // ── جدول النصوص ──
            $sp    = unpack('Vcount/VstyleCount/Vflags/VstringsStart/VstylesStart', substr($body, 8, 20));
            $count = (int) $sp['count'];
            $utf8  = ((int) $sp['flags'] & 0x0100) !== 0;
            $base  = (int) $sp['stringsStart'];
            if ($count > 0 && 28 + $count * 4 <= $cSize) {
                for ($i = 0; $i < $count; $i++) {
                    $o = (int) unpack('V', substr($body, 28 + $i * 4, 4))[1];
                    $p = $base + $o;
                    if ($p < 0 || $p >= $cSize) { $strings[] = ''; continue; }

                    if ($utf8) {
                        $u16 = ord($body[$p]); $p++;
                        if ($u16 & 0x80) { $u16 = (($u16 & 0x7f) << 8) | ord($body[$p]); $p++; }
                        $u8 = ord($body[$p]); $p++;
                        if ($u8 & 0x80) { $u8 = (($u8 & 0x7f) << 8) | ord($body[$p]); $p++; }
                        $strings[] = substr($body, $p, $u8);
                    } else {
                        $n = (int) unpack('v', substr($body, $p, 2))[1]; $p += 2;
                        if ($n & 0x8000) {
                            $n = (($n & 0x7fff) << 16) | (int) unpack('v', substr($body, $p, 2))[1];
                            $p += 2;
                        }
                        $raw = substr($body, $p, $n * 2);
                        $strings[] = function_exists('mb_convert_encoding')
                            ? (string) mb_convert_encoding($raw, 'UTF-8', 'UTF-16LE')
                            : (string) @iconv('UTF-16LE', 'UTF-8//IGNORE', $raw);
                    }
                }
            }
        } elseif ($c['type'] === 0x0180) {            // ── خريطة المراجع ──
            $n = intdiv($cSize - 8, 4);
            for ($i = 0; $i < $n; $i++) {
                $resMap[] = (int) unpack('V', substr($body, 8 + $i * 4, 4))[1];
            }
        } elseif ($c['type'] === 0x0102 && $result === null) {   // ── <manifest …> ──
            $el   = unpack('Vline/Vcomment/Vns/Vname', substr($body, 8, 16));
            $name = $strings[(int) $el['name']] ?? '';
            if ($name === 'manifest') {
                $aStart = (int) unpack('v', substr($body, 24, 2))[1];
                $aSize  = (int) unpack('v', substr($body, 26, 2))[1];
                $aCount = (int) unpack('v', substr($body, 28, 2))[1];
                if ($aSize >= 20 && $aCount > 0) {
                    $out = [];
                    for ($i = 0; $i < $aCount; $i++) {
                        $ao = 16 + $aStart + $i * $aSize;   // 16 = ترويسة العقدة
                        if ($ao + 20 > $cSize) break;
                        $a  = unpack('Vns/Vname/Vraw', substr($body, $ao, 12));
                        $tv = unpack('vsize/Cres0/Ctype/Vdata', substr($body, $ao + 12, 8));
                        $key    = $strings[(int) $a['name']] ?? '';
                        $resId  = $resMap[(int) $a['name']] ?? 0;
                        $type   = (int) $tv['type'];
                        $isRef  = ($type === 0x01);   // TYPE_REFERENCE — إحالة لمورد، لا نص

                        // 0x03 = نص داخل جدول النصوص · غير ذلك = قيمة رقمية
                        $val = $type === 0x03
                            ? ($strings[(int) $tv['data']] ?? '')
                            : (string) $tv['data'];

                        if ($key !== '' && !$isRef) $out[$key] = $val;
                        if ($resId === 0x0101021b) $out['versionCode'] = (string) (int) $tv['data'];
                        if ($resId === 0x0101021c && !$isRef) $out['versionName'] = (string) $val;
                    }
                    $result = $out;
                }
            }
        }

        $pos += $cSize;
    }

    return $result;
}

/**
 * قراءة بيانات الإصدار من ملف APK.
 * @return array{package:string,versionCode:int,versionName:string}|null
 */
function apk_read_meta(string $path): ?array
{
    $manifest = apk_zip_entry($path, 'AndroidManifest.xml');
    if ($manifest === null || $manifest === '') return null;

    $attrs = apk_axml_manifest($manifest);
    if ($attrs === null) return null;

    $vname = (string) ($attrs['versionName'] ?? '');
    // احتياط: بعض الملفات القديمة تكتب الإصدار كمرجع مورد («@7F040001»)
    if ($vname !== '' && $vname[0] === '@') $vname = '';

    return [
        'package'     => (string) ($attrs['package'] ?? ''),
        'versionCode' => (int) ($attrs['versionCode'] ?? 0),
        'versionName' => $vname,
    ];
}

/** هل الملف أرشيف ZIP صالح؟ (كل APK يبدأ بـ PK\x03\x04) */
function apk_looks_valid(string $path): bool
{
    $fh = @fopen($path, 'rb');
    if (!$fh) return false;
    $sig = (string) fread($fh, 4);
    fclose($fh);
    return in_array($sig, ["PK\x03\x04", "PK\x05\x06", "PK\x07\x08"], true);
}

/** قائمة ملفات APK الموجودة في المجلد (الأحدث أولاً) */
function app_update_list_apks(): array
{
    $dir = app_apk_dir();
    if (!is_dir($dir)) return [];
    $out = [];
    foreach ((array) @scandir($dir) as $f) {
        if (!is_string($f) || !str_ends_with(strtolower($f), '.apk')) continue;
        $p = $dir . '/' . $f;
        if (!is_file($p)) continue;
        $out[] = [
            'name'     => $f,
            'size'     => (int) filesize($p),
            'size_h'   => human_size((int) filesize($p)),
            'modified' => date('c', (int) filemtime($p)),
            'current'  => $f === basename((string) setting('app_apk_file', '')),
        ];
    }
    usort($out, fn($a, $b) => strcmp($b['modified'], $a['modified']));
    return $out;
}

/**
 * يحفظ بيانات ملف APK (الاسم، الحجم، البصمة، الإصدار) في الإعدادات.
 * لا يستنتج الإصدار من الاسم — يقرأه من داخل الملف إن أمكن.
 */
function app_update_attach_file(string $file): array
{
    $path = app_apk_dir() . '/' . basename($file);
    if (!is_file($path)) return ['ok' => false, 'message' => 'الملف غير موجود في مجلد apk/'];

    set_setting('app_apk_file', basename($file));
    set_setting('app_apk_size', (string) filesize($path));
    set_setting('app_apk_sha256', (string) @hash_file('sha256', $path));
    set_setting('app_apk_uploaded_at', (string) time());

    $meta  = apk_read_meta($path);
    $found = false;

    if ($meta !== null && $meta['versionCode'] > 0) {
        set_setting('app_version_code', (string) $meta['versionCode']);
        if ($meta['versionName'] !== '') set_setting('app_version_name', $meta['versionName']);
        $found = true;
    }

    return [
        'ok'       => true,
        'meta'     => $meta,
        'detected' => $found,
        'file'     => basename($file),
        'size'     => (int) filesize($path),
        'size_h'   => human_size((int) filesize($path)),
        'message'  => $found
            ? 'تم ربط الملف وقراءة الإصدار منه'
            : 'تم ربط الملف — تعذّرت قراءة الإصدار من داخله، أدخله يدوياً',
    ];
}

/**
 * فحص مجلد apk/: يربط أحدث ملف لم يُربط بعد، أو أحدث ملف إجمالاً.
 * @param bool $force  اربط أحدث ملف حتى لو كان الملف الحالي سليماً
 */
function app_update_scan(bool $force = false): array
{
    $files = app_update_list_apks();
    if (!$files) return ['ok' => false, 'message' => 'لا يوجد أي ملف .apk في مجلد ' . APP_APK_DIRNAME . '/'];

    $current = basename((string) setting('app_apk_file', ''));

    // الملف الحالي ما زال موجوداً؟ لا تلمسه ما لم يُطلب
    if (!$force && $current !== '') {
        foreach ($files as $f) {
            if ($f['name'] === $current) {
                return ['ok' => true, 'changed' => false, 'file' => $current,
                        'message' => 'الملف الحالي محدَّث (' . $current . ')'];
            }
        }
    }

    // أحدث ملف (القائمة مرتّبة بـ modified تنازلياً)
    $best = $files[0];

    // حماية من التراجع: ملف في المجلد إصداره أقدم من المنشور حالياً
    // (نسخة قديمة نُسخت سهواً) — نربطه كملف لكن لا نُنزل رقم الإصدار،
    // وإلا صار الزبائن «محدَّثين» وأُغلق أمامهم التحديث الحقيقي.
    $storedCode = (int) setting('app_version_code', '0');
    $fileMeta   = apk_read_meta(app_apk_dir() . '/' . $best['name']);
    $fileCode   = $fileMeta !== null ? (int) $fileMeta['versionCode'] : 0;

    if ($fileCode > 0 && $storedCode > 0 && $fileCode < $storedCode) {
        set_setting('app_apk_file', $best['name']);
        set_setting('app_apk_size', (string) filesize(app_apk_dir() . '/' . $best['name']));
        set_setting('app_apk_sha256', (string) @hash_file('sha256', app_apk_dir() . '/' . $best['name']));
        set_setting('app_apk_uploaded_at', (string) time());
        return [
            'ok'       => true,
            'changed'  => ($best['name'] !== $current),
            'detected' => true,
            'meta'     => $fileMeta,
            'message'  => 'تم ربط ' . $best['name'] . ' — لكن إصداره داخل الملف (' . $fileCode
                . ') أقدم من المنشور (' . $storedCode . ')، فأبقيت رقم الإصدار المنشور. '
                . 'صحّح الإصدار يدوياً إن كنت تقصد إنزاله.',
        ];
    }

    $res  = app_update_attach_file($best['name']);
    $res['changed'] = ($best['name'] !== $current);
    return $res;
}

// =============================================================
//  نقاط النهاية
// =============================================================

/** GET /api/app-update — عامة: يقرأها تطبيق أندرويد عند كل تشغيل */
function api_app_update(): void
{
    ok(['update' => app_update_public()]);
}

/** GET /api/admin/app-update — حالة كاملة للمدير */
function admin_app_update_get(): void
{
    ok(['update' => app_update_admin()]);
}

/** PUT /api/admin/app-update — حفظ الإصدار والملاحظات والإلزامي والرابط */
function admin_app_update_save(): void
{
    $b = body();

    if (array_key_exists('version_name', $b)) {
        $v = str_trim((string) $b['version_name'], 40);
        if ($v !== '' && !preg_match('/^[0-9][0-9A-Za-z._+-]*$/', $v)) {
            fail('صيغة الإصدار غير صحيحة — استعمل أرقاماً مثل 1.2.0');
        }
        set_setting('app_version_name', $v);
    }

    if (array_key_exists('version_code', $b)) {
        $n = (int) $b['version_code'];
        if ($n < 0) $n = 0;
        set_setting('app_version_code', (string) $n);
    }

    if (array_key_exists('notes', $b)) {
        set_setting('app_update_notes', str_trim((string) $b['notes'], 2000));
    }

    if (array_key_exists('force', $b)) {
        set_setting('app_update_force', !empty($b['force']) ? '1' : '0');
    }

    if (array_key_exists('url', $b)) {
        $url = str_trim((string) $b['url'], 500);
        // https/http فقط — لا javascript: ولا مسارات غريبة
        if ($url !== '' && !preg_match('#^https?://#i', $url)) {
            fail('الرابط يجب أن يبدأ بـ http:// أو https://');
        }
        set_setting('app_update_url', $url);
    }

    $pub = app_update_public();
    log_activity('update_settings', 'app', null,
        'تحديث تطبيق أندرويد: ' . ($pub['version_name'] !== '' ? $pub['version_name'] : '—')
        . ' (كود ' . $pub['version_code'] . ')');

    ok(['message' => 'تم حفظ إعدادات التحديث', 'update' => app_update_public()]);
}

/**
 * POST /api/admin/app-update/apk — رفع ملف APK (multipart: apk)
 * الحدود القصوى مأخوذة من إعدادات PHP، وتُشرح للمدير بوضوح عند الفشل.
 */
function admin_app_update_upload(): void
{
    $limit = upload_limit_bytes();

    // رفع تجاوز post_max_size: PHP يُفرغ $_POST و$_FILES تماماً
    if (empty($_FILES) && empty($_POST) && (int) ($_SERVER['CONTENT_LENGTH'] ?? 0) > 0) {
        fail(
            'الملف أكبر من حدّ الرفع في الخادم (' . human_size($limit) . '). '
            . 'ارفع الحد من cPanel › MultiPHP INI Editor (upload_max_filesize و post_max_size) '
            . 'إلى 64M أو أكثر، أو ارفع الملف عبر FTP إلى مجلد ' . APP_APK_DIRNAME . '/ '
            . 'ثم اضغط «فحص المجلد».',
            413
        );
    }

    if (empty($_FILES['apk'])) fail('لم يتم إرسال أي ملف');

    // نصيحة واحدة تُكرَّر في كل مسارات «الملف أكبر من الحد»
    $bigHint = ' — ارفع الحد من cPanel › MultiPHP INI Editor (upload_max_filesize و post_max_size) '
        . 'إلى 64M أو أكثر، أو ارفع الملف عبر FTP إلى مجلد ' . APP_APK_DIRNAME
        . '/ ثم اضغط «فحص المجلد».';

    $f = $_FILES['apk'];
    if ((int) $f['error'] !== UPLOAD_ERR_OK) {
        $err = (int) $f['error'];
        $why = match ($err) {
            UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE =>
                'الملف أكبر من حدّ الرفع في الخادم (' . human_size($limit) . ')' . $bigHint,
            UPLOAD_ERR_PARTIAL => 'لم يكتمل الرفع — أعد المحاولة',
            UPLOAD_ERR_NO_TMP_DIR, UPLOAD_ERR_CANT_WRITE => 'تعذّرت الكتابة على الخادم',
            default => 'فشل رفع الملف (رمز ' . $err . ')',
        };
        $isSize = in_array($err, [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true);
        fail($why, $isSize ? 413 : 400);
    }

    if ((int) $f['size'] <= 0) fail('الملف فارغ');
    if ((int) $f['size'] > $limit && $limit > 0) {
        fail('حجم الملف يتجاوز الحد المسموح (' . human_size($limit) . ')' . $bigHint, 413);
    }

    if (!apk_looks_valid($f['tmp_name'])) {
        fail('الملف ليس حزمة أندرويد صالحة (APK)');
    }

    $dir = app_apk_dir();
    if (!is_dir($dir) && !@mkdir($dir, 0775, true) && !is_dir($dir)) {
        fail('تعذّر إنشاء مجلد ' . APP_APK_DIRNAME . '/ — تحقّق من صلاحيات الكتابة');
    }

    // الاسم النهائي: dalel-{الإصدار}.apk — وبلا الإصدار إن تعذّرت قراءته
    $meta = apk_read_meta($f['tmp_name']);
    $name = 'dalel';
    if ($meta !== null && $meta['versionName'] !== '') {
        $name .= '-' . preg_replace('/[^0-9A-Za-z._-]/', '', $meta['versionName']);
    } elseif ($meta !== null && $meta['versionCode'] > 0) {
        $name .= '-build' . $meta['versionCode'];
    } else {
        $name .= '-' . date('Ymd-His');
    }
    $name .= '.apk';

    $dest   = $dir . '/' . $name;
    $old    = basename((string) setting('app_apk_file', ''));
    $tmpDst = $dest . '.part';

    if (!@move_uploaded_file($f['tmp_name'], $tmpDst)) {
        // بعض الاستضافات ترفع tmp_name لقرص آخر — rename يفشل، copy ينجح
        if (!@copy($f['tmp_name'], $tmpDst)) fail('تعذّر حفظ الملف على الخادم');
        @unlink($f['tmp_name']);
    }
    @chmod($tmpDst, 0644);
    if (!@rename($tmpDst, $dest)) { @unlink($tmpDst); fail('تعذّر إتمام حفظ الملف'); }

    $res = app_update_attach_file($name);

    // حذف الملف السابق إن اختلف اسمه (لا نُبقي نسخاً بلا حدّ)
    if ($old !== '' && $old !== $name) {
        $oldPath = $dir . '/' . $old;
        if (is_file($oldPath)) @unlink($oldPath);
    }

    log_activity('update_upload', 'app', null, 'رفع ملف تحديث أندرويد: ' . $name
        . ' (' . human_size((int) filesize($dest)) . ')');

    ok([
        'message'  => $res['message'],
        'detected' => $res['detected'],
        'meta'     => $res['meta'],
        'update'   => app_update_admin(),
    ]);
}

/** POST /api/admin/app-update/scan — فحص مجلد apk/ وربط ملف منه */
function admin_app_update_scan(): void
{
    $b     = body();
    $force = !empty($b['force']);
    $pick  = str_trim((string) ($b['file'] ?? ''), 120);

    if ($pick !== '') {
        // ملف بعينه: basename فقط — لا مسارات ولا خروج من المجلد
        $name = basename($pick);
        if (!preg_match('/\.apk$/i', $name) || !is_file(app_apk_dir() . '/' . $name)) {
            fail('الملف المطلوب غير موجود في مجلد ' . APP_APK_DIRNAME . '/');
        }
        $res = app_update_attach_file($name);
        $res['changed'] = true;
    } else {
        $res = app_update_scan($force);
    }

    if (empty($res['ok'])) fail($res['message'] ?? 'تعذّر الفحص');

    log_activity('update_scan', 'app', null, 'فحص مجلد ' . APP_APK_DIRNAME . ': ' . ($res['message'] ?? ''));

    ok([
        'message'  => $res['message'] ?? 'تم الفحص',
        'changed'  => (bool) ($res['changed'] ?? false),
        'detected' => (bool) ($res['detected'] ?? false),
        'meta'     => $res['meta'] ?? null,
        'update'   => app_update_admin(),
    ]);
}

/** DELETE /api/admin/app-update/apk — إزالة الملف المنشور (يُخفي التحديث) */
function admin_app_update_delete(): void
{
    $file = basename((string) setting('app_apk_file', ''));
    $path = app_apk_dir() . '/' . $file;

    if ($file !== '' && is_file($path)) {
        if (!@unlink($path)) fail('تعذّر حذف الملف — تحقّق من صلاحيات المجلد');
    }

    set_setting('app_apk_file', '');
    set_setting('app_apk_size', '0');
    set_setting('app_apk_sha256', '');
    set_setting('app_apk_uploaded_at', '0');

    log_activity('update_delete', 'app', null, 'حذف ملف تحديث أندرويد' . ($file !== '' ? ': ' . $file : ''));

    ok(['message' => 'تم حذف الملف — لن يظهر تحديث للتطبيقات', 'update' => app_update_admin()]);
}

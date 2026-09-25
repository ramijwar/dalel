#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
══════════════════════════════════════════════════════════════════════
 بناء أرشيفات التسليم — ثلاث حزم بأمر واحد
══════════════════════════════════════════════════════════════════════
   dist.zip            واجهة الويب وحدها (index.html + assets/)
   winfeen-upload.zip  حزمة الرفع للاستضافة — محتواها في جذر الأرشيف
                       لِتُستخرج مباشرةً فوق مجلد الموقع
   dalel.zip           نسخة كاملة محدَّثة (كود + وثائق + أدوات) للمرجع

الاستخدام:
   python3 project/tools/build_archives.py
   python3 project/tools/build_archives.py --only upload

مبادئ ثابتة (مطابقة لسياسة المشروع في `.gitignore` و«دليل-الرفع»):
   • لا تُحزَّم قاعدة البيانات ولا `secret.key` أبداً — قاعدة الخادم أحدث من
     نسخة المستودع، والمفتاح سرّي لكل خادم، والخادم **يُرقّي قاعدته بنفسه**
     عند أول طلب فلا حاجة لرفعها.
   • لا مخرجات بناء (node_modules · build · .dart_tool · dist · .gradle ·
     __pycache__) ولا ثنائي بيئة التطوير `php-bin/`.
   • حزمة الرفع لا تحمل مصادر الويب (`client/`) — الموقع يحتاج `assets/` فقط.
   • فحص بعد البناء: أي ملف حسّاس داخل أرشيف ⇒ فشل صريح برمز خروج 1.
"""

import argparse
import hashlib
import os
import re
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)            # مجلد project/
REPO = os.path.dirname(ROOT)            # جذر المستودع
WINFEEN = os.path.join(ROOT, 'winfeen')
ANDROID = os.path.join(ROOT, 'dalel_android')

GREEN, RED, YELLOW, DIM, RESET = '\033[92m', '\033[91m', '\033[93m', '\033[2m', '\033[0m'

# ─── ما لا يُحزَّم أبداً (بالمسار أو بالاسم) ───
SKIP_DIRS = {
    'node_modules', 'build', '.dart_tool', '.gradle', 'dist', 'dist-audit',
    '__pycache__', '.idea', '.vscode', 'php-bin', 'signing', '.git',
}
SKIP_NAMES = {
    'app.sqlite', 'secret.key', '.DS_Store', 'Thumbs.db', 'key.properties',
    'local.properties', 'GeneratedPluginRegistrant.java',
}
SKIP_EXTS = ('.jks', '.keystore', '.iml', '.log', '.sqlite', '.sqlite-wal',
             '.sqlite-shm', '.tsbuildinfo', '.pyc')
# أسرار/ملفات حساسة لو ظهرت في أي أرشيف ⇒ فشل
FORBIDDEN = re.compile(
    r"(^|/)(app\.sqlite|secret\.key|key\.properties|.*\.jks|.*\.keystore)$"
    r"|/node_modules/|(^|/)\.env$", re.I)


def skip(name):
    """هل يُستبعد هذا المدخل؟"""
    if name in SKIP_DIRS or name in SKIP_NAMES:
        return True
    return name.endswith(SKIP_EXTS)


def walk(src):
    """يمشي على مجلد ويرجّع المسارات النسبية بعد الاستبعاد."""
    for base, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for f in sorted(files):
            if skip(f):
                continue
            full = os.path.join(base, f)
            yield full, os.path.relpath(full, src).replace(os.sep, '/')


def add(zf, path, arcname):
    zf.write(path, arcname)


def add_tree(zf, src, prefix=''):
    """يضيف شجرة كاملة مع الحفاظ على البنى (وإضافة مدخلات المجلدات)."""
    count = 0
    for full, rel in walk(src):
        add(zf, full, f'{prefix}{rel}')
        count += 1
    return count


def new_zip(path):
    zf = zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9)
    return zf


def human(n):
    if n < 1024:
        return f'{n:,} B'
    if n < 1024 * 1024:
        return f'{n / 1024:,.1f} KB'
    return f'{n / 1024 / 1024:,.2f} MB'


# ═══════════════════════════════════════════════════════════════
#  ١) dist.zip — الواجهة المبنية وحدها
# ═══════════════════════════════════════════════════════════════
def build_dist():
    out = os.path.join(ROOT, 'dist.zip')
    if os.path.exists(out):
        os.remove(out)
    with new_zip(out) as zf:
        add(zf, os.path.join(WINFEEN, 'index.html'), 'index.html')
        assets = os.path.join(WINFEEN, 'assets')
        for full, rel in walk(assets):
            add(zf, full, f'assets/{rel}')
    return out


# ═══════════════════════════════════════════════════════════════
#  ٢) winfeen-upload.zip — حزمة الرفع (جذر الأرشيف = جذر الموقع)
# ═══════════════════════════════════════════════════════════════
UPLOAD_ROOT_FILES = ['.htaccess', 'README.md', 'check.html', 'index.html', 'router.php']
UPLOAD_DIRS = ['api', 'assets', 'apk']
# لا تُرفع مصادر الويب ولا صور المستخدمين (تبقى على الخادم)
UPLOAD_SKIP = {'client'}
UPLOAD_KEEP_IN_UPLOADS = {'.gitkeep'}


def build_upload():
    out = os.path.join(ROOT, 'winfeen-upload.zip')
    if os.path.exists(out):
        os.remove(out)
    n = 0
    with new_zip(out) as zf:
        for f in UPLOAD_ROOT_FILES:
            p = os.path.join(WINFEEN, f)
            if os.path.exists(p):
                add(zf, p, f); n += 1
        for d in UPLOAD_DIRS:
            src = os.path.join(WINFEEN, d)
            if not os.path.isdir(src):
                continue
            for full, rel in walk(src):
                if rel.split('/')[0] in UPLOAD_SKIP:
                    continue
                # مجلد الرفع: نبقي .gitkeep فقط — صور المستخدمين تبقى على الخادم
                if 'storage/uploads/' in f'{d}/{rel}' or f'{d}/{rel}'.startswith('api/storage/uploads/'):
                    if os.path.basename(rel) not in UPLOAD_KEEP_IN_UPLOADS:
                        continue
                add(zf, full, f'{d}/{rel}'); n += 1
    return out


# ═══════════════════════════════════════════════════════════════
#  ٣) dalel.zip — نسخة كاملة محدَّثة (للمرجع والتحميل)
# ═══════════════════════════════════════════════════════════════
FULL_DIRS = ['_audit', '_data-archive', 'qa', 'tools', 'migration']
FULL_SKIP_TOP = {'php-bin', 'winfeen-upload.zip', 'dist.zip'}


def build_full(upload_zip, dist_zip):
    out = os.path.join(REPO, 'dalel.zip')
    if os.path.exists(out):
        os.remove(out)
    n = 0
    with new_zip(out) as zf:
        # تعليمات الرفع أولاً — أول ما يراه المفتوح
        readme = os.path.join(HERE, 'README-الرفع.md')
        if os.path.exists(readme):
            add(zf, readme, 'README-الرفع.md'); n += 1
        # كود الويب والخادم (مع مصادر الواجهة) + كود التطبيق
        n += add_tree(zf, WINFEEN, 'winfeen/')
        n += add_tree(zf, ANDROID, 'dalel_android/')
        # أدوات ووثائق ومعاينات
        for d in FULL_DIRS:
            src = os.path.join(REPO, d) if d == 'migration' else os.path.join(ROOT, d)
            if os.path.isdir(src):
                n += add_tree(zf, src, f'{d}/')
        for f in sorted(os.listdir(ROOT)):
            full = os.path.join(ROOT, f)
            if not os.path.isfile(full) or f in FULL_SKIP_TOP or skip(f):
                continue
            if f.endswith(('.md', '.html')):
                add(zf, full, f); n += 1
        # الحزم الجاهزة (نسخة الرفع + الواجهة وحدها)
        for p in (upload_zip, dist_zip):
            if os.path.exists(p):
                add(zf, p, os.path.basename(p)); n += 1
    return out


# ═══════════════════════════════════════════════════════════════
#  الفحص: لا أسرار، ولا مخرجات بناء، والعناصر المهمة موجودة
# ═══════════════════════════════════════════════════════════════
def verify(path, must_have, must_not=None):
    must_not = must_not or []
    problems = []
    with zipfile.ZipFile(path) as zf:
        names = zf.namelist()
        for bad in must_not:
            hits = [n for n in names if bad in n]
            if hits:
                problems.append(f'مدخل ممنوع «{bad}»: {hits[:3]}')
        for good in must_have:
            if not any(good in n for n in names):
                problems.append(f'عنصر ناقص: «{good}»')
        for n in names:
            if FORBIDDEN.search(n):
                problems.append(f'ملف حسّاس: {n}')
            if n.endswith('/'):
                continue
        # محتوى api.php يحمل إصلاحات الجولة الأخيرة
        try:
            api = [n for n in names if n.endswith('api/api.php')]
            if api:
                src = zf.read(api[0]).decode('utf-8')
                # الاسم القديم `specialty_from_meta` استُبدل بـ`specialty_id_of`
                # + `sync_service_specialty` — وجوده يعني أرشيفاً من نسخة قديمة.
                if 'specialty_from_meta' in src:
                    problems.append('api.php يحمل الدالة القديمة specialty_from_meta')
                for fn in ('sync_service_specialty', 'specialty_id_of'):
                    if fn not in src:
                        problems.append(f'api.php لا يحمل الإصلاح: {fn}')
            fld = [n for n in names if n.endswith('api/includes/fields.php')]
            if fld:
                fs = zf.read(fld[0]).decode('utf-8')
                if 'is_price_field' not in fs or "'banknote'" not in fs:
                    problems.append('fields.php لا يحمل أيقونة banknote')
        except (UnicodeDecodeError, KeyError) as e:
            problems.append(f'تعذّر فحص المحتوى: {e}')
    return problems


def main():
    ap = argparse.ArgumentParser(description='بناء أرشيفات التسليم')
    ap.add_argument('--only', choices=['dist', 'upload', 'full'])
    a = ap.parse_args()

    want = lambda k: (not a.only) or a.only == k
    built = {}

    if want('dist'):
        built['dist.zip'] = build_dist()
    else:
        built['dist.zip'] = os.path.join(ROOT, 'dist.zip')
    if want('upload'):
        built['winfeen-upload.zip'] = build_upload()
    else:
        built['winfeen-upload.zip'] = os.path.join(ROOT, 'winfeen-upload.zip')
    if want('full'):
        built['dalel.zip'] = build_full(built['winfeen-upload.zip'], built['dist.zip'])

    print('═' * 66)
    print(' بناء أرشيفات التسليم')
    print('═' * 66)
    for name, path in built.items():
        if not os.path.exists(path):
            print(f'  {YELLOW}—{RESET} {name}: لم يُبنَ')
            continue
        size = os.path.getsize(path)
        sha = hashlib.sha256(open(path, 'rb').read()).hexdigest()[:16]
        with zipfile.ZipFile(path) as zf:
            zf.testzip()
            cnt = len([n for n in zf.namelist() if not n.endswith('/')])
        print(f'  {GREEN}✅{RESET} {name:<20} {human(size):>10} · {cnt:>4} ملفاً · sha256 {sha}…')

    # فحص الحزم
    checks = {
        'dist.zip': ([ 'index.html', 'assets/index-' ], []),
        'winfeen-upload.zip': ([ 'index.html', 'router.php', '.htaccess',
                                 'api/api.php', 'api/includes/fields.php',
                                 'api/storage/.htaccess', 'assets/index-' ],
                               ['client/', 'app.sqlite', 'secret.key']),
        'dalel.zip': ([ 'README-الرفع.md', 'winfeen/api/api.php', 'dalel_android/pubspec.yaml',
                        'winfeen-upload.zip', 'الإصلاحات-والتغييرات.md' ],
                      ['app.sqlite', 'secret.key', 'php-bin/', 'node_modules/']),
    }
    bad = 0
    print()
    print('── الفحص ──')
    for name, (must, mustnot) in checks.items():
        path = built.get(name) if name != 'dalel.zip' else os.path.join(REPO, 'dalel.zip')
        if not path or not os.path.exists(path):
            continue
        probs = verify(path, must, mustnot)
        if probs:
            bad += len(probs)
            for p in probs:
                print(f'  {RED}✘{RESET} {name}: {p}')
        else:
            print(f'  {GREEN}✅{RESET} {name}: سليم (بلا أسرار · بلا قاعدة · الإصلاحات موجودة)')
    print('═' * 66)
    if bad:
        print(f' {RED}النتيجة: {bad} مشكلة{RESET}')
        sys.exit(1)
    print(f' {GREEN}النتيجة: سليم ✅ — ارفع winfeen-upload.zip إلى الاستضافة{RESET}')


if __name__ == '__main__':
    main()

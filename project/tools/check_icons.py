#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
══════════════════════════════════════════════════════════════════════
 فحص تطابق الأيقونات بين لوحة التحكم (ويب) وتطبيق أندرويد
══════════════════════════════════════════════════════════════════════
 السبب: المدير يختار أيقونة القسم/الخدمة من لوحة التحكم، والتطبيق يعرض
 أيقونة Flutter من خريطة `dalel_android/lib/config/icons.dart`.
 أي اسم موجود في الويب وغير موجود في الخريطة = دائرة فارغة في التطبيق.

 الاستخدام:
   python3 project/tools/check_icons.py
   python3 project/tools/check_icons.py --db winfeen/api/storage/app.sqlite

 يخرج بالرمز 1 إذا وُجد اسم مكسور (للاستخدام في CI أو قبل بناء APK).
"""

import argparse
import os
import re
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                      # مجلد project/
WEB = os.path.join(ROOT, 'winfeen', 'client', 'src', 'components', 'Lucide.tsx')
APP = os.path.join(ROOT, 'dalel_android', 'lib', 'config', 'icons.dart')

GREEN, RED, YELLOW, DIM, RESET = '\033[92m', '\033[91m', '\033[93m', '\033[2m', '\033[0m'


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def block(src, name, open_ch='{', close_ch='}'):
    """محتوى كتلة تعريف (كخريطة) بعد اسمها."""
    i = src.index(name)
    i = src.index(open_ch, i)
    depth, j = 0, i
    while j < len(src):
        if src[j] == open_ch:
            depth += 1
        elif src[j] == close_ch:
            depth -= 1
            if depth == 0:
                return src[i:j]
        j += 1
    return ''


# ─── الويب: ما يستطيع المدير اختياره ───────────────────────────────
web_src = read(WEB)
PICKABLE = set(re.findall(r"^\s*'([a-z0-9-]+)':", block(web_src, 'LUCIDE_LABELS'), re.M))
CAT_DEFAULTS = dict(re.findall(r"'([\w-]+)':\s*'([^']+)'", block(web_src, 'CATEGORY_ICONS')))

set_block = block(web_src, 'CATEGORY_ICON_SETS')
CAT_SETS = {}
for slug, arr in re.findall(r"'([\w-]+)':\s*\[([^\]]*)\]", set_block, re.S):
    CAT_SETS[slug] = re.findall(r"'([^']+)'", arr)

# ─── التطبيق: ما يستطيع رسمه ──────────────────────────────────────
app_src = read(APP)
MAP = dict(re.findall(r"'([^']+)':\s*LucideIcons\.(\w+)", block(app_src, '_map = {')))
ALIASES = dict(re.findall(r"'([^']+)':\s*'([^']+)'", block(app_src, '_aliases = {')))
FALLBACK = re.search(r"_fallback = LucideIcons\.(\w+)", app_src)

# أيقونات مرسومة يدويًا داخل AppIcon (لا تحتاج مدخلًا في الخريطة)
HAND_DRAWN = {'ambulance'}


def looks_like_name(s):
    """نفس منطق AppIcon.looksLikeName في Dart"""
    return bool(re.fullmatch(r'[a-z0-9\-_]+', s.lower()))


def resolves(name):
    """يحاكي AppIcons.get في Dart — يرجع True إن رُسمت أيقونة حقيقية."""
    if name is None or name.strip() == '':
        return True, 'فراغ → البديل (مقبول)'
    if not looks_like_name(name):
        return True, 'إيموجي/نص → يُرسم كنص (مقبول)'
    key = name.lower().strip().replace('_', '-')
    if key.startswith('lucide-'):
        key = key[7:]
    if key in HAND_DRAWN:
        return True, 'مرسومة يدويًا (CustomPainter)'
    key = ALIASES.get(key, key)
    if key in MAP:
        return True, MAP[key]
    return False, 'مجهول → ' + (FALLBACK.group(1) if FALLBACK else '?')


problems = []

print('═' * 66)
print(' فحص أيقونات لوحة التحكم مقابل تطبيق أندرويد')
print('═' * 66)
print(f"  أيقونات لوحة التحكم      : {len(PICKABLE)}")
print(f"  خريطة التطبيق            : {len(MAP)} اسمًا")
print(f"  الأسماء البديلة          : {len(ALIASES)}")
print(f"  البديل عند الجهل         : {FALLBACK.group(1) if FALLBACK else '—'}")
print()

# 1) كل أيقونة معروضة في المنتقي
bad = sorted(n for n in PICKABLE if not resolves(n)[0])
print('── ١) الأيقونات المعروضة في منتقي اللوحة ──')
if bad:
    for n in bad:
        print(f"  {RED}✘{RESET} {n}")
    problems += bad
else:
    print(f"  {GREEN}✅ كل الـ{len(PICKABLE)} أيقونة لها مقابل في التطبيق{RESET}")
print()

# 2) المجموعات المخصّصة لكل قسم (أول ما يراه المدير)
print('── ٢) مجموعة الأيقونات المقترحة لكل قسم ──')
for slug, icons in CAT_SETS.items():
    bad = [i for i in icons if not resolves(i)[0]]
    mark = f"{GREEN}✅{RESET}" if not bad else f"{RED}✘{RESET}"
    extra = '' if not bad else '  ← ' + ' · '.join(bad)
    print(f"  {mark} {slug:<12} {len(icons) - len(bad)}/{len(icons)}{extra}")
    problems += bad
print()

# 3) الأيقونات المستخدمة فعليًا في قاعدة البيانات
print('── ٣) الأيقونات المستخدمة في قاعدة البيانات ──')
db_path = os.path.join(ROOT, 'winfeen', 'api', 'storage', 'app.sqlite')
if os.path.exists(db_path):
    con = sqlite3.connect(db_path)
    used = []
    for sql in ("SELECT name, icon FROM categories",
                "SELECT label, icon FROM category_fields WHERE icon <> ''",
                "SELECT label, icon FROM field_options WHERE icon <> ''"):
        try:
            used += [(f'{r[0]}', r[1]) for r in con.execute(sql) if r[1]]
        except sqlite3.Error:
            pass
    con.close()
    if not used:
        print('  (لا أيقونات مسجّلة)')
    for label, icon in sorted(set(used)):
        ok, how = resolves(icon)
        mark = f"{GREEN}✅{RESET}" if ok else f"{RED}✘{RESET}"
        print(f"  {mark} {icon:<24} {DIM}{label}{RESET}  {DIM}→ {how}{RESET}")
        if not ok:
            problems.append(icon)
else:
    print(f"  {YELLOW}—{RESET} لا قاعدة بيانات محليًا ({os.path.relpath(db_path, ROOT)})")
print()

print('═' * 66)
if problems:
    print(f" {RED}النتيجة: {len(problems)} اسمًا بحاجة إصلاح{RESET}  →  أضِفه إلى _map أو _aliases")
    sys.exit(1)
print(f" {GREEN}النتيجة: سليم ✅ — كل أيقونات اللوحة تُرسم في التطبيق{RESET}")

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
نقل بيانات «dalel» إلى قاعدة «daleltest»
=========================================
daleltest يحمل **الجداول الأحدث** (قوالب + فلاتر + إصلاحات)، وdalel يحمل
**بياناتك الحقيقية** التي يعمل عليها تطبيقك. هذا السكربت يضع بيانات dalel
داخل قوالب daleltest: استبدال كامل للأقسام والخدمات والمستخدمين والمناطق
والمناوبات والطلبات والحقول والفلاتر.

  • لا يُنقل أي صف من daleltest (بياناته القديمة تُستبدل بالكامل).
  • تُحفظ معرّفات dalel كما هي حتى لا تتشوّه الروابط بين الجداول.
  • تُحفظ إعدادات التحديث app_* من daleltest (‏تهيئة الخادم لا «بيانات»)
    ويمكن إسقاطها بـ --drop-app-settings.

الاستخدام:
    python3 merge_dalel_into_daleltest.py
    python3 merge_dalel_into_daleltest.py --dalel <file> --daleltest <file> --out <file>
"""

import argparse
import os
import shutil
import sqlite3
import sys
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)          # جذر المستودع


def find_source(name):
    """يجد ملف القاعدة: جذر المستودع أولاً (حيث يرفعه المالك) ثم migration/sources/."""
    for p in (os.path.join(ROOT, name), os.path.join(HERE, "sources", name)):
        if os.path.exists(p):
            return p
    return os.path.join(ROOT, name)


DEFAULTS = {
    "dalel": find_source("app.sqlite-dalel.txt"),
    "daleltest": find_source("app.sqlite-daleltest.txt"),
    "out": os.path.join(HERE, "app.daleltest.sqlite"),
}

# جداول المحتوى: تُستبدل بالكامل من dalel (الترتيب: أبناء ← آباء للحذف)
CONTENT_TABLES = [
    "login_attempts", "activity_log", "service_requests", "service_status", "schedules",
    "services", "category_filters", "filters", "category_field_options", "category_fields",
    "categories", "regions", "governorates", "specialties", "users",
]

APP_PREFIX = "app_"
log = []


def say(m=""):
    print(m)
    log.append(m)


def die(m, out=None):
    say("  ✗ " + m)
    if out:
        with open(os.path.splitext(out)[0] + ".txt", "w", encoding="utf-8") as f:
            f.write("\n".join(log) + "\n")
    sys.exit(1)


def table_names(db):
    return sorted(r[0] for r in db.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"))


def columns(db, t):
    return [r[1] for r in db.execute("PRAGMA table_info(%s)" % t)]


def schema_of(db):
    out = {}
    for (n, s, k) in db.execute("SELECT name, sql, type FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'"):
        out[(k, n)] = " ".join((s or "").split())
    return out


def check_inputs(a, b):
    """التأكد أن (a)=dalel الحقيقي و(b)=daleltest قبل أي كتابة."""
    if table_names(a) != table_names(b):
        return "جدولا القاعدتين غير متطابقين — تأكد من الملفين."
    sa, sb = schema_of(a), schema_of(b)
    diff = [k for k in sa if k in sb and sa[k] != sb[k]]
    if diff:
        return "مخطط القاعدتين مختلف: %s" % diff[:3]
    n_a = a.execute("SELECT COUNT(*) FROM services").fetchone()[0]
    n_b = b.execute("SELECT COUNT(*) FROM services").fetchone()[0]
    if n_a < n_b:
        return "المصدر (dalel) فيه خدمات أقل من daleltest (%d < %d) — الملفان معكوسان؟" % (n_a, n_b)
    if a.execute("SELECT COUNT(*) FROM categories WHERE slug='hospitals'").fetchone()[0] == 0:
        return "المصدر لا يحوي قسم «مشافي» — ليس قاعدة dalel الحقيقية."
    n_users = a.execute("SELECT COUNT(*) FROM users").fetchone()[0]
    if n_users < 3:
        return "المصدر لا يحوي مستخدمي dalel (%d) — ليس القاعدة المتوقّعة." % n_users
    return None


def main():
    ap = argparse.ArgumentParser(description="نقل بيانات dalel إلى قوالب daleltest")
    ap.add_argument("--dalel", default=DEFAULTS["dalel"], help="قاعدة dalel (البيانات)")
    ap.add_argument("--daleltest", default=DEFAULTS["daleltest"], help="قاعدة daleltest (القوالب)")
    ap.add_argument("--out", default=DEFAULTS["out"])
    ap.add_argument("--drop-app-settings", action="store_true",
                    help="عدم نقل إعدادات التحديث app_* من daleltest")
    args = ap.parse_args()

    for p, what in ((args.dalel, "قاعدة dalel"), (args.daleltest, "قاعدة daleltest")):
        if not os.path.exists(p):
            die("%s غير موجودة: %s" % (what, p), args.out)

    say("═" * 66)
    say("  نقل بيانات dalel → قوالب daleltest   ·   %s" % datetime.now().strftime("%Y-%m-%d %H:%M"))
    say("═" * 66)
    say("  dalel     (البيانات): %s" % args.dalel)
    say("  daleltest (القوالب) : %s" % args.daleltest)
    say("  الناتج              : %s" % args.out)
    say()

    src = sqlite3.connect("file:%s?mode=ro" % args.dalel, uri=True)
    tmp = sqlite3.connect("file:%s?mode=ro" % args.daleltest, uri=True)

    err = check_inputs(src, tmp)
    if err:
        die(err, args.out)
    say("  التحقق من الملفين: dalel ✅   daleltest ✅   (المخطط متطابق تماماً)")
    say()

    for side in ("-wal", "-shm"):
        if os.path.exists(args.out + side):
            os.remove(args.out + side)
    shutil.copy2(args.daleltest, args.out)
    tgt = sqlite3.connect(args.out)

    before = {t: tgt.execute("SELECT COUNT(*) FROM %s" % t).fetchone()[0] for t in CONTENT_TABLES}
    app_settings = {r[0]: r[1] for r in tgt.execute(
        "SELECT key, value FROM settings WHERE key LIKE ?", (APP_PREFIX + "%",))}

    # ── الاستبدال ──
    tgt.execute("PRAGMA foreign_keys=OFF")
    tgt.execute("BEGIN")
    for t in CONTENT_TABLES:
        tgt.execute("DELETE FROM %s" % t)

    copied = {}
    for t in reversed(CONTENT_TABLES):          # آباء ← أبناء
        cs = columns(src, t)
        rows = src.execute("SELECT %s FROM %s" % (",".join(cs), t)).fetchall()
        q = "INSERT INTO %s (%s) VALUES (%s)" % (t, ",".join(cs), ",".join("?" * len(cs)))
        tgt.executemany(q, rows)
        copied[t] = len(rows)

    # تسلسلات المعرّفات: كما في dalel حتى تُكمل القاعدة من حيث توقّف
    for (t, seq) in src.execute("SELECT name, seq FROM sqlite_sequence"):
        if t in CONTENT_TABLES:
            if tgt.execute("SELECT 1 FROM sqlite_sequence WHERE name=?", (t,)).fetchone():
                tgt.execute("UPDATE sqlite_sequence SET seq=? WHERE name=?", (seq, t))
            else:
                tgt.execute("INSERT INTO sqlite_sequence (name, seq) VALUES (?,?)", (t, seq))

    # الإعدادات: قيم dalel لها الأولوية، وإعدادات التحديث تبقى (إلا بطلب)
    n_set = 0
    for (k, v) in src.execute("SELECT key, value FROM settings"):
        if k.startswith(APP_PREFIX) and k in app_settings:
            continue
        if tgt.execute("SELECT 1 FROM settings WHERE key=?", (k,)).fetchone():
            tgt.execute("UPDATE settings SET value=? WHERE key=?", (v, k))
        else:
            tgt.execute("INSERT INTO settings (key, value) VALUES (?,?)", (k, v))
        n_set += 1
    if args.drop_app_settings:
        tgt.execute("DELETE FROM settings WHERE key LIKE ?", (APP_PREFIX + "%",))

    tgt.execute("COMMIT")
    tgt.execute("PRAGMA foreign_keys=ON")
    tgt.commit()

    # ── الحصيلة ──
    say("── ما نُقل من dalel ──")
    for t in CONTENT_TABLES:
        b, a = before.get(t, 0), copied.get(t, 0)
        note = "" if b == 0 else "   (كان في daleltest: %d)" % b
        say("   %-24s %5d%s" % (t, a, note))
    say("   %-24s %5d (بقيت)" % ("settings", tgt.execute("SELECT COUNT(*) FROM settings").fetchone()[0]))
    if app_settings:
        state = "أُسقطت" if args.drop_app_settings else "بقيت"
        say("      إعدادات التحديث app_*: %d %s" % (len(app_settings), state))
    say()

    # ── التحقق ──
    say("── التحقق ──")
    ic = tgt.execute("PRAGMA integrity_check").fetchone()[0]
    say("   سلامة الملف: %s %s" % (ic, "✅" if ic == "ok" else "❌"))
    fk = [tuple(r) for r in tgt.execute("PRAGMA foreign_key_check")]
    base_fk = 0
    say("   مراجع أجنبية معلّقة: %d %s" % (len(fk), "✅" if not fk else "❌"))
    for r in fk[:5]:
        say("      · %s rowid=%s → %s غير موجود" % (r[0], r[1], r[2]))

    ok = True
    say()
    say("   ── مطابقة صفّاً بصفّ مع dalel ──")
    for t in reversed(CONTENT_TABLES):
        cs = columns(src, t)
        a = [tuple(x) for x in src.execute("SELECT %s FROM %s ORDER BY rowid" % (",".join(cs), t))]
        b = [tuple(x) for x in tgt.execute("SELECT %s FROM %s ORDER BY rowid" % (",".join(cs), t))]
        same = a == b
        ok = ok and same
        say("      %-24s %5d صفاً  %s" % (t, len(a), "✅" if same else "❌ مختلف (%d)" % (len(b) - len(a))))
    say("      ⇒ %s" % ("كل الجداول مطابقة لـ dalel ✅" if ok else "⚠️ يوجد اختلاف!"))

    say()
    say("   ── لم تبقَ بيانات daleltest القديمة ──")
    for t, q in (("services", "SELECT COUNT(*) FROM services WHERE id IN (4132,4133)"),
                 ("categories", "SELECT COUNT(*) FROM categories WHERE slug NOT IN (SELECT slug FROM categories)")):
        pass
    leftover = {
        "خدمات كانت في daleltest فقط": tgt.execute("SELECT COUNT(*) FROM services WHERE id=4132 OR id=4133").fetchone()[0],
        "أقسام ليست في dalel": tgt.execute(
            "SELECT COUNT(*) FROM categories WHERE id NOT IN (%s)" %
            ",".join(str(r[0]) for r in src.execute("SELECT id FROM categories"))).fetchone()[0],
        "مستخدمون ليسوا في dalel": tgt.execute(
            "SELECT COUNT(*) FROM users WHERE id NOT IN (%s)" %
            ",".join(str(r[0]) for r in src.execute("SELECT id FROM users"))).fetchone()[0],
    }
    for k, v in leftover.items():
        say("      %-32s %d %s" % (k, v, "✅" if v == 0 else "❌"))

    say()
    say("   ── الأقسام في الناتج ──")
    for r in tgt.execute("""SELECT c.id, c.slug, c.name, c.is_active, COUNT(s.id)
                            FROM categories c LEFT JOIN services s ON s.category_id=c.id
                            GROUP BY c.id ORDER BY c.id"""):
        say("      #%-3d %-14s %-20s نشط=%d · خدمات %d" % r)
    say("      المجموع: %d خدمة · %d منطقة · %d مستخدم" % (
        tgt.execute("SELECT COUNT(*) FROM services").fetchone()[0],
        tgt.execute("SELECT COUNT(*) FROM regions").fetchone()[0],
        tgt.execute("SELECT COUNT(*) FROM users").fetchone()[0]))

    src.close()
    tmp.close()
    tgt.close()

    with open(os.path.splitext(args.out)[0] + ".txt", "w", encoding="utf-8") as f:
        f.write("\n".join(log) + "\n")
    say()
    say("  ✅ الناتج: %s (%s بايت)" % (args.out, format(os.path.getsize(args.out), ",")))


if __name__ == "__main__":
    main()

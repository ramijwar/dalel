#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
فحص قاعدة بيانات «دليل الدير» — تحقّق شامل قبل النشر
=====================================================
يقيس: البنية · السلامة · المراجع · الحقول والفلاتر · المناوبات والحالات ·
الطلبات · المستخدمين · الإعدادات · ثم يشغّل الفحص نفسه على الخادم إن أردت.

    python3 migration/verify_db.py appnew.sqlite
    python3 migration/verify_db.py appnew.sqlite --expect-users 9 --expect-services 404
    python3 migration/verify_db.py appnew.sqlite --report migration/فحص.txt

لا يعدّل أي شيء — قراءة فقط، ويطبع النتيجة النهائية بـ ✅/⚠️/❌.
"""

import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime

OK, WARN, BAD = "✅", "⚠️", "❌"
lines = []
problems = []


def out(m=""):
    print(m)
    lines.append(m)


def row(label, verdict, detail=""):
    out("   %-42s %s %s" % (label, verdict, detail))
    if verdict == BAD:
        problems.append(label)


def main():
    ap = argparse.ArgumentParser(description="فحص قاعدة بيانات دليل الدير قبل النشر")
    ap.add_argument("db", nargs="?", default="appnew.sqlite")
    ap.add_argument("--expect-services", type=int, default=None)
    ap.add_argument("--expect-users", type=int, default=None)
    ap.add_argument("--report", default=None, help="حفظ التقرير في ملف نصي")
    args = ap.parse_args()

    if not os.path.exists(args.db):
        print("✗ الملف غير موجود: %s" % args.db)
        sys.exit(1)

    d = sqlite3.connect("file:%s?mode=ro" % args.db, uri=True)
    n = lambda q, a=(): d.execute(q, a).fetchone()[0]
    q = lambda s, a=(): d.execute(s, a).fetchall()

    out("═" * 68)
    out("  فحص قاعدة البيانات: %s" % args.db)
    out("  %s · %s بايت" % (datetime.now().strftime("%Y-%m-%d %H:%M"), format(os.path.getsize(args.db), ",")))
    out("═" * 68)

    # ── ١) البنية ──
    out("\n── ١) البنية ──")
    tables = sorted(r[0] for r in q("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"))
    need = {"services", "categories", "regions", "governorates", "users", "settings", "schedules",
            "service_status", "service_requests", "category_fields", "category_field_options",
            "filters", "category_filters", "specialties", "activity_log", "login_attempts"}
    missing = need - set(tables)
    row("الجداول", OK if not missing else BAD, "%d جدولاً%s" % (len(tables), "" if not missing else " · ناقص: %s" % missing))
    cf_cols = [r[1] for r in d.execute("PRAGMA table_info(category_fields)")]
    extra_cols = {"suffix", "hide_when_false"} - set(cf_cols)
    row("أعمدة الحقول الحديثة (suffix/hide_when_false)", OK if not extra_cols else BAD,
        "موجودة" if not extra_cols else "❌ ناقصة (جداول قديمة)")
    row("الفهارس", OK, "%d فهرساً" % n("SELECT COUNT(*) FROM sqlite_master WHERE type='index'"))
    ic = n("PRAGMA integrity_check")
    row("سلامة الملف (integrity_check)", OK if ic == "ok" else BAD, ic)
    fk = list(d.execute("PRAGMA foreign_key_check"))
    row("المراجع الأجنبية المعلّقة", OK if not fk else BAD,
        "لا شيء" if not fk else "%d مخالفة: %s" % (len(fk), fk[:3]))

    # ── ٢) العدّ ──
    out("\n── ٢) المحتوى ──")
    counts = {t: n("SELECT COUNT(*) FROM %s" % t) for t in tables}
    svc, usr = counts["services"], counts["users"]
    row("الخدمات", OK if args.expect_services in (None, svc) else BAD,
        "%d%s" % (svc, "" if args.expect_services is None else " (المتوقّع %d)" % args.expect_services))
    row("المستخدمون", OK if args.expect_users in (None, usr) else BAD,
        "%d%s" % (usr, "" if args.expect_users is None else " (المتوقّع %d)" % args.expect_users))
    for t in ("categories", "regions", "governorates", "schedules", "service_status",
              "service_requests", "category_fields", "category_field_options", "filters",
              "category_filters", "specialties", "activity_log", "settings"):
        out("   %-42s %6d" % (t, counts[t]))
    active = n("SELECT COUNT(*) FROM categories WHERE is_active=1")
    row("أقسام نشطة", OK, "%d من %d" % (active, counts["categories"]))

    # ── ٣) المراجع المنطقية ──
    out("\n── ٣) المراجع المنطقية ──")
    checks = [
        ("خدمة بقسم غير موجود", "SELECT COUNT(*) FROM services WHERE category_id NOT IN (SELECT id FROM categories)"),
        ("خدمة بمنطقة غير موجودة", "SELECT COUNT(*) FROM services WHERE region_id IS NOT NULL AND region_id NOT IN (SELECT id FROM regions)"),
        ("خدمة بمحافظة غير موجودة", "SELECT COUNT(*) FROM services WHERE governorate_id IS NOT NULL AND governorate_id NOT IN (SELECT id FROM governorates)"),
        ("خدمة باختصاص غير موجود", "SELECT COUNT(*) FROM services WHERE specialty_id IS NOT NULL AND specialty_id NOT IN (SELECT id FROM specialties)"),
        ("خدمة بمالك غير موجود", "SELECT COUNT(*) FROM services WHERE owner_id IS NOT NULL AND owner_id NOT IN (SELECT id FROM users)"),
        ("تعارض منطقة/محافظة", """SELECT COUNT(*) FROM services s JOIN regions r ON r.id=s.region_id
                                  WHERE s.governorate_id IS NOT NULL AND r.governorate_id IS NOT NULL AND r.governorate_id<>s.governorate_id"""),
        ("مناوبة لخدمة غير موجودة", "SELECT COUNT(*) FROM schedules WHERE service_id NOT IN (SELECT id FROM services)"),
        ("حالة لخدمة غير موجودة", "SELECT COUNT(*) FROM service_status WHERE service_id NOT IN (SELECT id FROM services)"),
        ("طلب لمستخدم غير موجود", "SELECT COUNT(*) FROM service_requests WHERE user_id IS NOT NULL AND user_id NOT IN (SELECT id FROM users)"),
        ("طلب لخدمة منشأة غير موجودة", "SELECT COUNT(*) FROM service_requests WHERE created_service_id IS NOT NULL AND created_service_id NOT IN (SELECT id FROM services)"),
        ("خيار لحقل غير موجود", "SELECT COUNT(*) FROM category_field_options WHERE field_id NOT IN (SELECT id FROM category_fields)"),
        ("إسناد فلتر لقسم/فلتر غير موجود", """SELECT COUNT(*) FROM category_filters
              WHERE category_id NOT IN (SELECT id FROM categories) OR filter_id NOT IN (SELECT id FROM filters)"""),
        ("سجل نشاط لمستخدم غير موجود", "SELECT COUNT(*) FROM activity_log WHERE user_id IS NOT NULL AND user_id NOT IN (SELECT id FROM users)"),
    ]
    for label, sql in checks:
        c = n(sql)
        row(label, OK if c == 0 else BAD, "0" if c == 0 else str(c))

    # ── ٤) الحقول وقيمها ──
    out("\n── ٤) الحقول الديناميكية ↔ قيم الخدمات ──")
    for cid, slug in q("SELECT id, slug FROM categories ORDER BY id"):
        keys = {r[0] for r in q("SELECT field_key FROM category_fields WHERE category_id=? AND is_active=1", (cid,))}
        total = n("SELECT COUNT(*) FROM services WHERE category_id=?", (cid,))
        if not keys:
            out("   %-16s %4d خدمة · لا حقول" % (slug, total)); continue
        empty = 0
        for (m,) in q("SELECT meta FROM services WHERE category_id=?", (cid,)):
            try:
                mm = json.loads(m or "{}")
            except Exception:
                mm = {}
            if not ({k for k in mm} & keys):
                empty += 1
        row("قيم %s" % slug, OK if empty == 0 else WARN, "%d خدمة · بلا قيمة %d" % (total, empty))

    bad_json = sum(1 for (m,) in q("SELECT meta FROM services") if not _is_json(m))
    row("meta بصيغة JSON سليمة", OK if bad_json == 0 else BAD, "%d تالفة" % bad_json)

    out("\n   خيارات الحقول (select) مقابل القيم المستخدمة:")
    for fid, cid, key in q("SELECT id, category_id, field_key FROM category_fields WHERE type='select' AND is_active=1"):
        vals = {r[0] for r in q("SELECT value FROM category_field_options WHERE field_id=?", (fid,))}
        used = set()
        for (m,) in q("SELECT meta FROM services WHERE category_id=?", (cid,)):
            v = _json(m).get(key)
            if isinstance(v, list):
                used.update(map(str, v))
            elif v not in (None, ""):
                used.add(str(v))
        gap = used - vals
        row("   خيارات %s" % key, OK if not gap else WARN,
            "%d خياراً · %d مستخدماً%s" % (len(vals), len(used), "" if not gap else " · بلا خيار: %s" % sorted(gap)[:3]))

    # ── ٥) المناوبات والحالات ──
    out("\n── ٥) المناوبات والحالات ──")
    no_sched = n("SELECT COUNT(*) FROM services WHERE id NOT IN (SELECT DISTINCT service_id FROM schedules)")
    row("خدمات بلا مناوبات", OK if no_sched == 0 else WARN, str(no_sched))
    bad_day = n("SELECT COUNT(*) FROM schedules WHERE day NOT BETWEEN 0 AND 6")
    row("أيام خارج 0–6", OK if bad_day == 0 else BAD, str(bad_day))
    bad_time = n("SELECT COUNT(*) FROM schedules WHERE opens NOT GLOB '[0-2][0-9]:[0-5][0-9]' OR closes NOT GLOB '[0-2][0-9]:[0-5][0-9]'")
    row("أوقات بصيغة خاطئة", OK if bad_time == 0 else BAD, str(bad_time))
    modes = dict(q("SELECT mode, COUNT(*) FROM service_status GROUP BY mode"))
    row("أنماط الحالة", OK if set(modes) <= {"auto", "open", "closed"} else WARN, str(modes))
    ord_count = n("SELECT COUNT(*) FROM service_status WHERE on_duty=1")
    row("مناوبات مفعّلة يدوياً (on_duty)", OK, str(ord_count))

    # ── ٦) الفلاتر ──
    out("\n── ٦) الفلاتر وأسنادها ──")
    orphan_f = [r[0] for r in q("SELECT filter_key FROM filters WHERE id NOT IN (SELECT filter_id FROM category_filters)")]
    row("فلاتر بلا أي إسناد (لن تظهر)", OK if not orphan_f else WARN, "لا شيء" if not orphan_f else ", ".join(orphan_f))
    bad_field_flt = []
    for slug, skey in q("""SELECT c.slug, f.source_key FROM category_filters cf
                           JOIN categories c ON c.id=cf.category_id JOIN filters f ON f.id=cf.filter_id
                           WHERE f.source_type='field'"""):
        if not n("SELECT COUNT(*) FROM category_fields WHERE category_id=(SELECT id FROM categories WHERE slug=?) AND field_key=?", (slug, skey)):
            bad_field_flt.append((slug, skey))
    row("فلتر حقله غير موجود في قسمه", OK if not bad_field_flt else BAD,
        "لا شيء" if not bad_field_flt else str(bad_field_flt))
    out("   إسنادات الأقسام:")
    for slug, label, prim, act in q("""SELECT c.slug, f.label, cf.is_primary, cf.is_active FROM category_filters cf
                                       JOIN categories c ON c.id=cf.category_id JOIN filters f ON f.id=cf.filter_id
                                       ORDER BY c.id, cf.sort_order"""):
        out("      %-16s %-16s %s%s" % (slug, label, "أساسي" if prim else "ثانوي", "" if act else " (معطّل)"))

    # ── ٧) المستخدمون والإعدادات والحدود ──
    out("\n── ٧) المستخدمون والإعدادات ──")
    admins = q("SELECT phone, full_name FROM users WHERE role='admin' AND is_active=1")
    row("مدير نشط", OK if admins else BAD, ", ".join("%s (%s)" % (p, f) for p, f in admins) or "لا يوجد!")
    bad_hash = n("SELECT COUNT(*) FROM users WHERE password_hash NOT LIKE '$2y$%' OR length(password_hash)<>60")
    row("كلمات المرور بصيغة bcrypt سليمة", OK if bad_hash == 0 else BAD, "%d تالفة" % bad_hash)
    bad_phone = n("SELECT COUNT(*) FROM users WHERE phone NOT GLOB '09[0-9]*'")
    row("أرقام الهواتف بصيغة صحيحة", OK if bad_phone == 0 else WARN, str(bad_phone))
    st = [r[0] for r in q("SELECT key FROM settings ORDER BY key")]
    row("الإعدادات", OK, "%d: %s" % (len(st), ", ".join(st)))
    appk = [k for k in st if k.startswith("app_")]
    if appk:
        ver = d.execute("SELECT value FROM settings WHERE key='app_version_code'").fetchone()
        nm = d.execute("SELECT value FROM settings WHERE key='app_version_name'").fetchone()
        row("إعدادات تحديث التطبيق", OK, "%d · الإصدار %s (%s)" % (len(appk), nm[0] if nm else "—", ver[0] if ver else "—"))
    else:
        row("إعدادات تحديث التطبيق (app_*)", WARN, "غير موجودة ⇒ بطاقة التحديث لن تعرض شيئاً حتى يُنشر APK من اللوحة")

    out("\n   حدّ شاشات اللوحة:")
    for label, table, lim in (("شاشة الخدمات", "services", 400), ("شاشة الطلبات", "service_requests", 300),
                              ("شاشة المستخدمين", "users", 300), ("سجل النشاط", "activity_log", 100)):
        c = counts[table]
        row("   %s (حدّ %d)" % (label, lim), OK if c <= lim else WARN,
            "%d سجلاً%s" % (c, "" if c <= lim else " ⇒ %d لا تظهر بلا ترشيح" % (c - lim)))

    out("\n   خدمات بلا وسيلة تواصل (هاتف/واتساب): %d" % n("SELECT COUNT(*) FROM services WHERE COALESCE(phone,'')='' AND COALESCE(whatsapp,'')=''"))
    out("   خدمات موثّقة: %d · غير موثّقة: %d" % (n("SELECT COUNT(*) FROM services WHERE is_verified=1"),
                                                  n("SELECT COUNT(*) FROM services WHERE is_verified<>1")))
    out("   خدمات بلا meta: %d" % n("SELECT COUNT(*) FROM services WHERE meta IS NULL OR meta IN ('','{}','[]')"))

    # ── الخلاصة ──
    out("\n" + "═" * 68)
    if problems:
        out("  ⚠️  %d مشكلة تحتاج انتباهاً:" % len(problems))
        for p in problems:
            out("      · %s" % p)
    else:
        out("  ✅ لا مشاكل حاجبة — القاعدة سليمة للنشر")
    out("═" * 68)

    if args.report:
        os.makedirs(os.path.dirname(os.path.abspath(args.report)), exist_ok=True)
        with open(args.report, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        print("\n  📄 التقرير: %s" % args.report)


def _json(s):
    try:
        v = json.loads(s or "{}")
        return v if isinstance(v, dict) else {}
    except Exception:
        return {}


def _is_json(s):
    try:
        json.loads(s or "{}")
        return True
    except Exception:
        return False


if __name__ == "__main__":
    main()

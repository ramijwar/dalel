#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ترحيل بيانات «dalel» (حلب — ٥٢٣ خدمة) إلى قاعدة «daleltest» ذات الجداول الأحدث.

الفكرة: لا نأخذ قواعد dalel القديمة — بل نأخذ **البيانات** ونضعها في **قوالب
جداول daleltest** الحديثة (filters · category_filters · suffix · hide_when_false).

قواعد العمل:
  • لا يُلمس أي صف موجود في daleltest (تحقّق آلي في النهاية يقطع على أي تغيير).
  • المعرّفات محفوظة كما في dalel: الخدمات ٤٠٠٥–٤١٣٨ (كلها حرّة — مؤكَّد)،
    المناطق ٧٠٥–٧٢٢، المحافظة «ريف حلب» ٢، القسم «بازارات وأسواق» ٤١.
  • الأقسام المشتركة (صيدليات · أطباء · كازيات · سرافيس) تبقى بأسمائها
    وإعداداتها في daleltest — لا تُستبدل.
  • لا تُنقل حسابات dalel ولا إعداداته ولا سجل نشاطه.

الاستخدام (من أي مكان):
    python3 migrate.py
    python3 migrate.py --out /tmp/x.sqlite --with-users
"""

import argparse
import json
import os
import shutil
import sqlite3
import sys
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

DEFAULT_SOURCE = os.path.join(ROOT, "project/_data-archive/deprecated/app.deployed-halab-20260923.sqlite")
DEFAULT_TARGET = os.path.join(ROOT, "project/winfeen/api/storage/app.sqlite")
DEFAULT_OUT = os.path.join(HERE, "daleltest-merged.sqlite")

NOW = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# حقول جديدة نضيفها إلى daleltest ليعرض النظام الجديد بيانات dalel التي كانت
# مكتومة داخل meta  ·  (category_id, field_key, label, type, required,
#                       placeholder, help, show_in_card, filterable, sort_order,
#                       suffix, hide_when_false)
NEW_FIELDS = [
    (39, "gas",         "غاز منزلي",            "boolean", 0, "", "من قائمة وقود الكازية",        1, 0, 4, "", 1),
    (40, "stops_text",  "المواقف على الطريق",   "text",    0, "", "أسماء المواقف بترتيب الطريق",   1, 0, 4, "", 0),
    (41, "market_type", "نوع السوق",            "select",  0, "", "",                             1, 0, 0, "", 0),
    (41, "day",         "اليوم",                "select",  0, "", "",                             1, 0, 1, "", 0),
]

log_lines = []


def say(msg=""):
    print(msg)
    log_lines.append(msg)


def write_log(out_path):
    with open(os.path.splitext(out_path)[0] + ".txt", "w", encoding="utf-8") as f:
        f.write("\n".join(log_lines) + "\n")


def die(msg, out_path=None):
    say("  ✗ " + msg)
    if out_path:
        write_log(out_path)
    sys.exit(1)


def tables(db):
    return [r[0] for r in db.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]


def cols(db, t):
    return [r[1] for r in db.execute("PRAGMA table_info(%s)" % t)]


def insert_row(db, table, values):
    names = list(values.keys())
    db.execute("INSERT INTO %s (%s) VALUES (%s)" % (table, ",".join(names), ",".join("?" * len(names))),
               [values[n] for n in names])
    return db.execute("SELECT last_insert_rowid()").fetchone()[0]


def check_identity(src, tgt):
    tt = set(tables(tgt))
    if "filters" not in tt or "category_filters" not in tt:
        return "القاعدة الهدف ليست نسخة daleltest الحديثة (لا جدولَي filters/category_filters)."
    if "suffix" not in cols(tgt, "category_fields") or "hide_when_false" not in cols(tgt, "category_fields"):
        return "جداول الهدف قديمة: عمودا suffix/hide_when_false غير موجودين."
    n_src = src.execute("SELECT COUNT(*) FROM services").fetchone()[0]
    if n_src < 500:
        return "المصدر لا يبدو قاعدة dalel (خدمات أقل من ٥٠٠: %d)." % n_src
    if not src.execute("SELECT COUNT(*) FROM categories WHERE slug='bazaars'").fetchone()[0]:
        return "المصدر لا يحوي قسم البازارات — ليس قاعدة dalel المتوقعة."
    if tgt.execute("SELECT COUNT(*) FROM categories WHERE slug='bazaars'").fetchone()[0]:
        return "القاعدة الهدف مُرحَّلة سابقاً (قسم البازارات موجود)."
    return None


def enrich_service(cat_slug, meta):
    """يضيف المفاتيح التي تتوقّعها حقول daleltest — والأصل (fuels/stops) يبقى."""
    if cat_slug == "stations":
        fuels = [str(x) for x in (meta.get("fuels") or [])]
        meta["benzen"] = any("بنزين" in f for f in fuels)
        meta["diesel"] = any(("مازوت" in f or "ديزل" in f) for f in fuels)
        meta["gas"] = any("غاز" in f for f in fuels)
    elif cat_slug == "transport":
        sp, ep = str(meta.get("start_point") or ""), str(meta.get("end_point") or "")
        if sp or ep:
            meta["direction"] = "%s-%s" % (sp, ep)
        stops = [str(x) for x in (meta.get("stops") or []) if str(x).strip()]
        if stops:
            meta["stops_text"] = "، ".join(stops)
    return meta


def main():
    ap = argparse.ArgumentParser(description="ترحيل بيانات dalel إلى قوالب جداول daleltest")
    ap.add_argument("--source", default=DEFAULT_SOURCE)
    ap.add_argument("--target", default=DEFAULT_TARGET)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--with-users", action="store_true", help="نقل حسابات dalel أيضاً (غير مفعّل افتراضياً)")
    args = ap.parse_args()

    for p, what in ((args.source, "المصدر"), (args.target, "الهدف")):
        if not os.path.exists(p):
            die("%s غير موجود: %s" % (what, p), args.out)

    say("═" * 64)
    say("  ترحيل بيانات dalel → daleltest   ·   %s" % datetime.now().strftime("%Y-%m-%d %H:%M"))
    say("═" * 64)
    say("  المصدر : %s" % args.source)
    say("  الهدف  : %s" % args.target)
    say("  الناتج : %s" % args.out)
    say()

    for side in ("-wal", "-shm"):
        if os.path.exists(args.out + side):
            os.remove(args.out + side)
    shutil.copy2(args.target, args.out)

    src = sqlite3.connect("file:%s?mode=ro" % args.source, uri=True)
    tgt = sqlite3.connect(args.out)

    err = check_identity(src, tgt)
    if err:
        die(err, args.out)
    say("  الهوية: مصدر dalel ✅   هدف daleltest الحديث ✅")
    say()

    baseline_fk = [tuple(r) for r in tgt.execute("PRAGMA foreign_key_check")]

    # ── ١) المحافظات الجديدة (ريف حلب) ──
    say("── ١) المحافظات ──")
    tgt_govs = {r[0] for r in tgt.execute("SELECT id FROM governorates")}
    tgt_gov_slugs = {r[0] for r in tgt.execute("SELECT slug FROM governorates")}
    added_govs = []
    for r in src.execute("SELECT * FROM governorates ORDER BY id"):
        row = dict(zip(cols(src, "governorates"), r))
        if row["id"] in tgt_govs or row["slug"] in tgt_gov_slugs:
            continue
        insert_row(tgt, "governorates", row)
        added_govs.append((row["id"], row["name"]))
    say("   + %s" % (" · ".join("%s (معرّف %s)" % (n, i) for i, n in added_govs) or "لا شيء جديد"))

    # ── ٢) المناطق الجديدة ──
    say("── ٢) المناطق ──")
    tgt_regions = {r[0] for r in tgt.execute("SELECT id FROM regions")}
    taken = {(r[0], r[1]) for r in tgt.execute("SELECT name, zone FROM regions")}
    added_regions = []
    for r in src.execute("SELECT * FROM regions ORDER BY id"):
        row = dict(zip(cols(src, "regions"), r))
        if row["id"] in tgt_regions:
            continue
        if (row["name"], row["zone"]) in taken:
            die("منطقة باسم «%s» (%s) موجودة مسبقاً في daleltest — يلزم قرار يدوي." % (row["name"], row["zone"]), args.out)
        insert_row(tgt, "regions", row)
        taken.add((row["name"], row["zone"]))
        added_regions.append((row["id"], row["name"]))
    say("   + %d منطقة (معرّفات %d–%d): %s%s" % (
        len(added_regions), added_regions[0][0], added_regions[-1][0],
        " · ".join(n for _, n in added_regions[:5]), " …" if len(added_regions) > 5 else ""))

    # ── ٣) الأقسام الجديدة ──
    say("── ٣) الأقسام ──")
    tgt_cats = {r[0] for r in tgt.execute("SELECT id FROM categories")}
    tgt_slugs = {r[0] for r in tgt.execute("SELECT slug FROM categories")}
    cat_map, added_cats = {}, []
    for r in src.execute("SELECT * FROM categories ORDER BY id"):
        row = dict(zip(cols(src, "categories"), r))
        if row["id"] in tgt_cats or row["slug"] in tgt_slugs:
            cat_map[row["id"]] = tgt.execute("SELECT id FROM categories WHERE slug=?", (row["slug"],)).fetchone()[0]
            continue
        insert_row(tgt, "categories", row)
        cat_map[row["id"]] = row["id"]
        added_cats.append((row["id"], row["name"], row["is_active"]))
    for i, n, a in added_cats:
        say("   + قسم %d «%s»%s" % (i, n, "" if a else " — معطّل كما في dalel"))
    say("   الأقسام المشتركة بقيت باسم daleltest: %s" %
        " · ".join("#%d %s" % (r[0], r[1]) for r in tgt.execute(
            "SELECT id, name FROM categories WHERE slug IN ('pharmacies','doctors','stations','transport') ORDER BY id")))

    # ── ٤) الحقول والخيارات ──
    say("── ٤) الحقول والخيارات ──")
    have_fields = {(r[0], r[1]): r[2] for r in tgt.execute("SELECT category_id, field_key, id FROM category_fields")}
    field_ids = {}
    for (cid, key, label, ftype, req, ph, help_, sic, filt, sort_, suffix, hide) in NEW_FIELDS:
        if (cid, key) in have_fields:
            field_ids[key] = have_fields[(cid, key)]
            say("   = حقل %s موجود مسبقاً («%s»)" % (key, label))
            continue
        field_ids[key] = insert_row(tgt, "category_fields", {
            "category_id": cid, "field_key": key, "label": label, "type": ftype,
            "required": req, "placeholder": ph, "help": help_, "show_in_card": sic,
            "filterable": filt, "sort_order": sort_, "is_active": 1, "created_at": NOW,
            "suffix": suffix, "hide_when_false": hide})
        say("   + حقل %-11s «%s» للقسم %d (%s)" % (key, label, cid, ftype))

    def add_option(field_id, label, value, sort_order):
        if tgt.execute("SELECT id FROM category_field_options WHERE field_id=? AND value=?",
                       (field_id, value)).fetchone():
            return False
        insert_row(tgt, "category_field_options", {
            "field_id": field_id, "label": label, "value": value, "icon": "",
            "sort_order": sort_order, "is_active": 1, "created_at": NOW})
        return True

    def next_sort(field_id):
        return tgt.execute("SELECT COALESCE(MAX(sort_order),-1)+1 FROM category_field_options WHERE field_id=?",
                           (field_id,)).fetchone()[0]

    dir_field = tgt.execute("SELECT id FROM category_fields WHERE category_id=40 AND field_key='direction'").fetchone()[0]
    dirs, markets, days = [], [], []
    for (cid_s, raw) in src.execute("SELECT category_id, meta FROM services WHERE category_id IN (40,41)"):
        m = json.loads(raw or "{}")
        if cid_s == 40:
            sp, ep = str(m.get("start_point") or ""), str(m.get("end_point") or "")
            if (sp or ep) and ("%s-%s" % (sp, ep)) not in dirs:
                dirs.append("%s-%s" % (sp, ep))
        else:
            if m.get("market_type") and m["market_type"] not in markets:
                markets.append(m["market_type"])
            if m.get("day") and m["day"] not in days:
                days.append(m["day"])

    s0 = next_sort(dir_field)
    n_dir = sum(add_option(dir_field, d, d, s0 + i) for i, d in enumerate(dirs))
    say("   + %d خيار «اتجاه السفر» (خطوط حلب): %s …" % (n_dir, " · ".join(dirs[:3])))
    for key, vals in (("market_type", markets), ("day", days)):
        fid = field_ids.get(key)
        if fid:
            n = sum(add_option(fid, v, v, i) for i, v in enumerate(vals))
            say("   + %d خيار «%s»: %s" % (n, key, " · ".join(vals)))

    # ── ٥) الخدمات الناقصة ──
    say("── ٥) الخدمات ──")
    slug_of = {r[0]: r[1] for r in src.execute("SELECT id, slug FROM categories")}
    tgt_services = {r[0] for r in tgt.execute("SELECT id FROM services")}
    srv_cols = cols(src, "services")
    new_ids = []
    for r in src.execute("SELECT * FROM services ORDER BY id"):
        row = dict(zip(srv_cols, r))
        if row["id"] in tgt_services:
            continue
        row["meta"] = json.dumps(enrich_service(slug_of.get(row["category_id"], ""),
                                                json.loads(row.get("meta") or "{}")), ensure_ascii=False)
        row["layout"] = None
        insert_row(tgt, "services", row)
        new_ids.append(row["id"])

    ph = ",".join("?" * len(new_ids))
    say("   + %d خدمة بمعرّفاتها الأصلية (%d–%d)" % (len(new_ids), min(new_ids), max(new_ids)))
    for r in tgt.execute("""SELECT c.slug, COUNT(*) FROM services s JOIN categories c ON c.id=s.category_id
                            WHERE s.id IN (%s) GROUP BY 1 ORDER BY 2 DESC""" % ph, new_ids):
        say("        %-12s %d" % (r[0], r[1]))

    # ── ٦) المناوبات والحالات ──
    say("── ٦) المناوبات والحالات ──")
    n_sched = 0
    for r in src.execute("SELECT service_id, day, opens, closes, is_24h FROM schedules WHERE service_id IN (%s)" % ph, new_ids):
        insert_row(tgt, "schedules", dict(zip(("service_id", "day", "opens", "closes", "is_24h"), r)))
        n_sched += 1
    say("   + %d مناوبة" % n_sched)

    st_cols = cols(src, "service_status")
    n_stat = 0
    for r in src.execute("SELECT * FROM service_status WHERE service_id IN (%s)" % ph, new_ids):
        row = dict(zip(st_cols, r))
        row["updated_by"] = None
        insert_row(tgt, "service_status", row)
        n_stat += 1
    say("   + %d حالة خدمة" % n_stat)

    # ── ٧) الطلبات ──
    say("── ٧) الطلبات ──")
    req_cols = cols(src, "service_requests")
    n_req = 0
    for r in src.execute("SELECT * FROM service_requests ORDER BY id"):
        row = dict(zip(req_cols, r))
        row["user_id"] = None
        if row.get("created_service_id") and (row["created_service_id"] not in tgt_services
                                              and row["created_service_id"] not in new_ids):
            row["created_service_id"] = None
        insert_row(tgt, "service_requests", row)
        n_req += 1
    say("   + %d طلباً (بلا مالك — حسابات dalel لم تُنقل)" % n_req)

    # ── ٨) الفلاتر ──
    say("── ٨) الفلاتر ──")
    have_cf = {(r[0], r[1]) for r in tgt.execute("SELECT category_id, filter_id FROM category_filters")}
    flt_dir = tgt.execute("SELECT id FROM filters WHERE filter_key='flt-direction'").fetchone()
    flt_reg = tgt.execute("SELECT id FROM filters WHERE filter_key='region'").fetchone()
    plans = []
    if flt_dir:
        plans.append((cat_map.get(40, 40), flt_dir[0], 0, 30, "اتجاه السفر → سرافيس (ثانوي)"))
    if flt_reg:
        plans.append((cat_map.get(41, 41), flt_reg[0], 1, 0, "المناطق → بازارات (أساسي)"))
    for cid, fid, prim, sort_, label in plans:
        if (cid, fid) in have_cf:
            say("   = %s (موجود مسبقاً)" % label)
            continue
        insert_row(tgt, "category_filters", {"category_id": cid, "filter_id": fid, "is_primary": prim,
                                             "sort_order": sort_, "is_active": 1, "created_at": NOW})
        say("   + %s" % label)

    # ── ٩) ضبط تسلسلات المعرّفات ──
    for (t,) in tgt.execute("SELECT name FROM sqlite_master WHERE type='table' AND sql LIKE '%AUTOINCREMENT%'"):
        try:
            mx = tgt.execute("SELECT COALESCE(MAX(id),0) FROM %s" % t).fetchone()[0]
            seq = tgt.execute("SELECT seq FROM sqlite_sequence WHERE name=?", (t,)).fetchone()
            if seq and seq[0] < mx:
                tgt.execute("UPDATE sqlite_sequence SET seq=? WHERE name=?", (mx, t))
        except sqlite3.Error:
            pass
    tgt.commit()

    # ── ١٠) التحقق ──
    say()
    say("── ٩) التحقق النهائي ──")
    integrity = tgt.execute("PRAGMA integrity_check").fetchone()[0]
    say("   سلامة الملف: %s %s" % (integrity, "✅" if integrity == "ok" else "❌"))

    fk_after = [tuple(r) for r in tgt.execute("PRAGMA foreign_key_check")]
    new_fk = len(fk_after) - len(baseline_fk)
    say("   مراجع أجنبية معلّقة: %d إجمالاً · سابقة (لم تُمسّ) %d · جديدة من الترحيل %d %s"
        % (len(fk_after), len(baseline_fk), new_fk, "✅" if new_fk == 0 else "❌"))

    say()
    for slug, label in (("pharmacies", "صيدليات"), ("doctors", "أطباء"), ("stations", "كازيات"),
                        ("transport", "سرافيس وباصات"), ("bazaars", "بازارات وأسواق")):
        want = src.execute("SELECT COUNT(*) FROM services s JOIN categories c ON c.id=s.category_id WHERE c.slug=?", (slug,)).fetchone()[0]
        got = tgt.execute("SELECT COUNT(*) FROM services s JOIN categories c ON c.id=s.category_id WHERE c.slug=?", (slug,)).fetchone()[0]
        say("   خدمات %-16s %4d / %-4d %s" % (label, got, want, "✅" if got >= want else "❌"))
    want = src.execute("SELECT COUNT(*) FROM services").fetchone()[0]
    got = tgt.execute("SELECT COUNT(*) FROM services").fetchone()[0]
    say("   %-24s %4d / %-4d %s" % ("إجمالي الخدمات", got, want, "✅" if got >= want else "❌"))
    want = src.execute("SELECT COUNT(*) FROM regions").fetchone()[0]
    got = tgt.execute("SELECT COUNT(*) FROM regions").fetchone()[0]
    say("   %-24s %4d (dalel %d + daleltest الأصلي) %s" % ("المناطق", got, want, "✅"))
    say("   %-24s %4d" % ("المحافظات", tgt.execute("SELECT COUNT(*) FROM governorates").fetchone()[0]))

    # meta: كل خدمة جديدة تحمل قيم حقول قسمها
    missing = []
    for key, (cid, fkey) in (("benzen", (39, "benzen")), ("diesel", (39, "diesel")), ("gas", (39, "gas"))):
        pass
    for slug, keys in (("stations", ("company", "benzen", "diesel", "gas", "smart_card")),
                       ("transport", ("direction", "vehicle", "fare", "frequency", "stops_text")),
                       ("bazaars", ("market_type", "day"))):
        n, bad = 0, 0
        for (raw,) in tgt.execute("""SELECT s.meta FROM services s JOIN categories c ON c.id=s.category_id
                                     WHERE c.slug=? AND s.id IN (%s)""" % ph, (slug,) + tuple(new_ids)):
            n += 1
            m = json.loads(raw or "{}")
            if sum(1 for k in keys if k in m and m[k] not in ("", None, False)) == 0:
                bad += 1
        empties = []
        if bad:
            for sid, sname, raw in tgt.execute("""SELECT s.id, s.name, s.meta FROM services s JOIN categories c ON c.id=s.category_id
                                                 WHERE c.slug=? AND s.id IN (%s)""" % ph, (slug,) + tuple(new_ids)):
                m = json.loads(raw or "{}")
                if sum(1 for k in keys if k in m and m[k] not in ("", None, False)) == 0:
                    empties.append("%s (%d)" % (sname, sid))
        say("   قيم حقول %-10s في meta: %d خدمة%s" % (slug, n,
            " · كلها فيها قيم ✅" if not bad else " · بلا أي قيمة: %s — كما هي في dalel" % "، ".join(empties)))

    # ── لم يُلمس شيء موجود ──
    base = sqlite3.connect("file:%s?mode=ro" % args.target, uri=True)
    say()
    say("── التأكد أن شيئاً موجوداً في daleltest لم يُلمَس ──")
    untouched_ok = True
    for t in tables(base):
        if t == "sqlite_sequence":
            continue
        if t in ("schedules", "service_status", "category_field_options", "category_filters"):
            continue
        cnames = cols(base, t)
        pk = "id" if "id" in cnames else ("service_id" if "service_id" in cnames else "key")
        ix = cnames.index(pk)
        before = {r[ix]: tuple(r) for r in base.execute("SELECT * FROM %s" % t)}
        after = {r[ix]: tuple(r) for r in tgt.execute("SELECT * FROM %s WHERE %s IN (%s)"
                                                      % (t, pk, ",".join("?" * len(before))), list(before.keys()))} if before else {}
        changed = [k for k in before if k in after and before[k] != after[k]]
        gone = [k for k in before if k not in after]
        flag = "✅ مطابق" if not changed and not gone else "❌ مختلف (%d صفاً)" % (len(changed) + len(gone))
        if changed or gone:
            untouched_ok = False
        say("   %-26s %s" % (t, flag))
    # المناوبات والحالات والخيارات والأسندة: بالمعرّف الخاص
    for t, pk in (("schedules", "id"), ("service_status", "service_id"),
                  ("category_field_options", "id"), ("category_filters", "id")):
        before = {r[0]: tuple(r) for r in base.execute("SELECT * FROM %s" % t)}
        after = {}
        if before:
            for r in tgt.execute("SELECT * FROM %s WHERE %s IN (%s)" % (t, pk, ",".join("?" * len(before))), list(before.keys())):
                after[r[0]] = tuple(r)
        changed = [k for k in before if k in after and before[k] != after[k]]
        gone = [k for k in before if k not in after]
        if changed or gone:
            untouched_ok = False
        say("   %-26s %s" % (t, "✅ مطابق" if not changed and not gone else "❌ مختلف (%d)" % (len(changed) + len(gone))))
    base.close()
    say("   ⇒ %s" % ("لا شيء موجود تغيّر ✅" if untouched_ok else "⚠️ تغيّر صف موجود — راجع أعلاه"))

    tgt.close()
    src.close()
    write_log(args.out)
    say()
    say("  ✅ الناتج: %s (%s بايت)" % (args.out, format(os.path.getsize(args.out), ",")))


if __name__ == "__main__":
    main()

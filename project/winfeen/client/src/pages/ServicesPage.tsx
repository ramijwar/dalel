import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useStore } from '../lib/store'
import { api } from '../lib/api'
import type { RegionGroup, Service, Specialty } from '../lib/types'
import ServiceCard from '../components/ServiceCard'
import MiniServiceCard from '../components/MiniServiceCard'
import ServicePanel from '../components/ServicePanel'
import Icon from '../components/Icon'
import CatIcon from '../components/CatIcon'
import { fmtDateTime, vehicleIcon } from '../lib/utils'

/** إعدادات كل قسم: العناوين وطريقة تجميع البطاقات */
interface CatCfg {
  title: string
  desc: string
  unit: string
  unitPlural: string
  /** region  : التجميع بالمنطقة (من قاعدة البيانات)
   *  specialty: التجميع بالاختصاص الطبي (من قاعدة البيانات)
   *  meta    : التجميع من حقل meta محلياً (vehicle / market) */
  group: 'region' | 'specialty' | 'meta'
  /** المفتاح داخل meta عند group = 'meta' */
  metaKey?: string
  groupTitle: string
  /** بطاقات مُصغّرة (أيقونة + اسم + نقطة حالة) مع لوحة تفاصيل سفلية */
  mini?: boolean
  /** طريقة العرض الافتراضية لهذا القسم */
  defaultLayout?: 'card' | 'list'
}

const CAT_INFO: Record<string, CatCfg> = {
  pharmacies: {
    title: 'الصيدليات المناوبة', desc: 'حالة الصيدليات وآخر تحديثات المناوبة',
    unit: 'صيدلية', unitPlural: 'صيدليات', group: 'region', groupTitle: 'المناطق', mini: true,
  },
  doctors: {
    title: 'الأطباء المختصون', desc: 'اختصاصات الأطباء ومواعيد عياداتهم',
    unit: 'طبيب', unitPlural: 'أطباء', group: 'specialty', groupTitle: 'الاختصاصات', mini: true,
  },
  stations: {
    title: 'الكازيات', desc: 'حالة محطات الوقود لحظةً بلحظة',
    unit: 'محطة', unitPlural: 'محطات', group: 'region', groupTitle: 'المناطق', mini: true,
  },
  transport: {
    title: 'سرافيس وباصات', desc: 'خطوط النقل ومخطط الرحلة',
    unit: 'مركبة', unitPlural: 'مركبات', group: 'meta', metaKey: 'vehicle', groupTitle: 'نوع المركبة',
    mini: false, defaultLayout: 'list',
  },
}

/**
 * تسميات النطاق — عامة لكل المحافظات.
 * إن ضبط المدير اسم المحافظة في الإعدادات ظهر بجانبها،
 * وإلا تعود إلى تسمية محايدة تعمل في أي محافظة.
 */
function zones(city: string) {
  const c = (city || '').trim()
  return [
    { v: '', label: 'الكل' },
    { v: 'city', label: c ? `مدينة ${c}` : 'داخل المدينة' },
    { v: 'rural', label: c ? `ريف ${c}` : 'الريف' },
  ]
}

const STATUS_OPTS = [
  { v: '', label: 'الكل' },
  { v: 'open', label: 'تعمل' },
  { v: 'on_duty', label: 'مناوبة' },
  { v: 'closed', label: 'مغلقة' },
  { v: 'manual', label: 'تحديث يدوي' },
]

interface GroupCard {
  key: string
  label: string
  icon: string
  total: number
  open: number
}

/** مفتاح التجميع المحلي من حقل meta */
function metaGroup(s: Service, metaKey: string): { key: string; label: string; icon: string } {
  const m = (s.meta ?? {}) as Record<string, any>
  if (metaKey === 'vehicle') {
    const k = String(m.vehicle || 'أخرى')
    return { key: k, label: k, icon: vehicleIcon(m.vehicle) }
  }
  // بازارات: النوع + اليوم
  const type = String(m.market_type || 'أخرى')
  const day = String(m.day || '')
  return {
    key: day ? `${type} · ${day}` : type,
    label: day || type,
    icon: type === 'دائم' ? '🏪' : '📅',
  }
}

export default function ServicesPage() {
  const { slug } = useParams<{ slug: string }>()
  const { categories, settings, governorates } = useStore()

  const cat = categories.find((c) => c.slug === slug)
  const info: CatCfg = CAT_INFO[slug ?? ''] ?? {
    title: cat?.name ?? 'الخدمات',
    desc: cat?.description ?? '',
    unit: 'خدمة',
    unitPlural: 'خدمات',
    group: 'region',
    groupTitle: 'المناطق',
  }

  const [items, setItems] = useState<Service[]>([])
  const [regionGroups, setRegionGroups] = useState<RegionGroup[]>([])
  const [specialties, setSpecialties] = useState<Specialty[]>([])
  const [openNow, setOpenNow] = useState(0)
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [updatedAt, setUpdatedAt] = useState<string>('')

  const [zone, setZone] = useState('')
  const [govId, setGovId] = useState('')
  const [status, setStatus] = useState('')
  const [regionId, setRegionId] = useState<number | null>(null)
  const [specialtyId, setSpecialtyId] = useState<number | null>(null)
  const [groupKey, setGroupKey] = useState<string | null>(null)
  const [q, setQ] = useState('')
  const [layout, setLayout] = useState<'card' | 'list'>('card')
  /** الخدمة المختارة التي تُعرض بياناتها في اللوحة السفلية */
  const [picked, setPicked] = useState<Service | null>(null)

  const stateRef = useRef({ zone, status, regionId, specialtyId, q, govId })
  stateRef.current = { zone, status, regionId, specialtyId, q, govId }

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const s = stateRef.current
      const params: Record<string, any> = { category_id: slug, limit: 300, sort: 'open_first' }
      if (s.zone) params.zone = s.zone
      if (s.govId) params.governorate_id = s.govId
      if (s.regionId) params.region_id = s.regionId
      if (s.specialtyId) params.specialty_id = s.specialtyId
      if (s.status) params.status = s.status
      if (s.q) params.q = s.q

      const r = await api.services(params)

      // ─── شبكة أمان: جلبة بقية الصفحات إن تجاوز العدد سقف الخادم ───
      // كان قسم الصيدليات (٢٤٢ خدمة) يُعرض ناقصاً لأن الخادم يقصّ الشريحة
      // عند حدّه الأقصى، بينما بطاقات المناطق تُحسب على العدد الكامل —
      // فتبدو مناطق فيها خدمات ولا تظهر عند اختيارها.
      let items = r.items
      const cap = r.limit || items.length
      if (r.total > items.length && cap > 0) {
        const pages = Math.ceil(r.total / cap)
        for (let page = 2; page <= pages && page <= 10; page++) {
          const more = await api.services({ ...params, page })
          if (!more.items?.length) break
          items = items.concat(more.items)
        }
      }

      setItems(items)
      setTotal(r.total)
      setOpenNow(r.open_now)
      setRegionGroups(r.regions ?? [])
      if (r.time) setUpdatedAt(r.time)
    } catch {
      setItems([])
    } finally {
      setLoading(false)
    }
  }, [slug])

  useEffect(() => { load() }, [load])

  useEffect(() => {
    const t = window.setTimeout(load, q ? 350 : 0)
    return () => window.clearTimeout(t)
  }, [zone, status, regionId, specialtyId, q, govId, load])

  // نبض تحديث كل 3 دقائق
  useEffect(() => {
    const id = window.setInterval(load, 180_000)
    return () => window.clearInterval(id)
  }, [load])

  // إعادة تعيين التحديد وطريقة العرض عند تغيير القسم
  useEffect(() => {
    setGroupKey(null); setRegionId(null); setSpecialtyId(null); setPicked(null)
    setLayout(info.defaultLayout ?? 'card')
  }, [slug, info.defaultLayout])

  // جلب الاختصاصات من قاعدة البيانات لقسم الأطباء
  useEffect(() => {
    if (info.group !== 'specialty') { setSpecialties([]); return }
    api.specialties()
      .then((d) => setSpecialties(d.items ?? []))
      .catch(() => setSpecialties([]))
  }, [info.group])

  /** هل يوجد فلتر نشط يؤثر على العدّادات؟ */
  const hasActiveFilter =
    govId !== '' || zone !== '' || status !== '' || q.trim() !== ''

  /** بطاقات التجميع */
  const groups = useMemo<GroupCard[]>(() => {
    if (info.group === 'region') {
      return regionGroups.map((r) => ({
        key: String(r.region_id ?? ''),
        label: r.region,
        icon: 'map-pin',   // أيقونة موقع — لا منزل
        total: r.total,
        open: r.open,
      }))
    }
    if (info.group === 'specialty') {
      // ──────────────────────────────────────────────────
      // العدّاد يجب أن يحترم الفلاتر النشطة (المحافظة/الريف/الحالة).
      // services_count القادم من /specialties عدّاد عام يتجاهلها،
      // لذا نحسبه محلياً من الخدمات المُفلترة (items).
      // ──────────────────────────────────────────────────
      const perSpec = new Map<string, { total: number; open: number }>()
      for (const s of items) {
        const spId = (s as any).specialty_id
        const k = String(spId ?? '')
        if (!spId) continue
        const cur = perSpec.get(k) ?? { total: 0, open: 0 }
        cur.total++
        if (s.status === 'open') cur.open++
        perSpec.set(k, cur)
      }
      return specialties
        .map((sp) => ({
          key: String(sp.id),
          label: sp.name,
          icon: sp.icon || '🩺',
          total: perSpec.get(String(sp.id))?.total ?? 0,
          open: perSpec.get(String(sp.id))?.open ?? 0,
        }))
        // الأخفاء الاختياري: لا نعرض اختصاصات بلا نتائج بعد الفلترة
        .filter((g) => !hasActiveFilter || g.total > 0)
        .sort((a, b) => b.total - a.total || a.label.localeCompare(b.label, 'ar'))
    }
    // تجميع محلي من meta
    const map = new Map<string, GroupCard>()
    for (const s of items) {
      const g = metaGroup(s, info.metaKey ?? '')
      const cur = map.get(g.key) ?? { key: g.key, label: g.label, icon: g.icon, total: 0, open: 0 }
      cur.total++
      if (s.status === 'open') cur.open++
      map.set(g.key, cur)
    }
    return [...map.values()].sort((a, b) => b.total - a.total || a.label.localeCompare(b.label, 'ar'))
  }, [items, regionGroups, specialties, info.group, info.metaKey, hasActiveFilter])

  /** المفتاح النشط حسب وضع القسم */
  const activeKey = info.group === 'region'
    ? (regionId === null ? null : String(regionId))
    : info.group === 'specialty'
      ? (specialtyId === null ? null : String(specialtyId))
      : groupKey

  const selectedGroup = useMemo(
    () => (activeKey === null ? null : groups.find((g) => g.key === activeKey) ?? null),
    [groups, activeKey],
  )

  /**
   * العناصر الظاهرة — تُصفَّى محلياً في وضع meta (تجميع «نوع المركبة»).
   *
   * ملاحظة: كان هنا شريط «فلاتر الحقول الديناميكية» أعلى الصفحة، أُزيل
   * بأمر المستخدم لأنه يكرّر بنية القسم نفسها — قسم الأطباء يُجمّع أصلاً
   * بالاختصاص، وقسم السرفيس يُجمّع أصلاً بنوع المركبة، فبطاقات التجميع
   * (المستوى الأول: بطاقات التجميع) هي الفلتر الأساسي وتكفي.
   */
  const visibleItems = useMemo(() => {
    if (info.group !== 'meta' || !groupKey) return items
    return items.filter((s) => metaGroup(s, info.metaKey ?? '').key === groupKey)
  }, [items, groupKey, info.group, info.metaKey])

  const selectGroup = (key: string | null) => {
    setPicked(null)
    if (info.group === 'region') setRegionId(key === null ? null : Number(key))
    else if (info.group === 'specialty') setSpecialtyId(key === null ? null : Number(key))
    else setGroupKey(groupKey === key ? null : key)
  }

  // إسقاط الخدمة المختارة عند تغيير الفلاتر أو القسم
  useEffect(() => { setPicked(null) }, [slug, zone, status, q, govId])

  const unitLabel = total === 1 ? info.unit
    : (total >= 3 && total <= 10 ? info.unitPlural : info.unit)

  return (
    <main className="page svc-page">

      {/* ── الترويسة ── */}
      <header className="svc-head">
        <Link to="/" className="back-btn"><Icon name="arrowRight" size={18} /> الرئيسية</Link>
        <div className="svc-head__row">
          <h1><CatIcon icon={cat?.icon} size={22} /> {info.title}</h1>
          {updatedAt && <span className="svc-head__updated">آخر تحديث: {fmtDateTime(updatedAt)}</span>}
        </div>
        <p className="svc-head__desc">{info.desc}</p>
      </header>

      {/* ── الصف الأول: المحافظات ── */}
      {governorates.length > 0 && (
        <div className="seg seg--gov" role="tablist" aria-label="المحافظة">
          <Icon name="map" size={14} />
          <button
            className={`seg__btn ${govId === '' ? 'is-active' : ''}`}
            onClick={() => { setGovId(''); setRegionId(null); setGroupKey(null) }}
            role="tab" aria-selected={govId === ''}
          >كل المحافظات</button>
          {governorates.map((g) => (
            <button
              key={g.id}
              className={`seg__btn ${String(govId) === String(g.id) ? 'is-active' : ''}`}
              onClick={() => { setGovId(String(g.id)); setRegionId(null); setGroupKey(null) }}
              role="tab" aria-selected={String(govId) === String(g.id)}
            >{g.name}</button>
          ))}
        </div>
      )}

      {/* ── الصف الثاني: النطاق (مدينة / ريف) داخل المحافظة ── */}
      <div className="seg" role="tablist" aria-label="نطاق المنطقة">
        {zones(settings.city).map((z) => (
          <button
            key={z.v}
            className={`seg__btn ${zone === z.v ? 'is-active' : ''}`}
            onClick={() => { setZone(z.v); setRegionId(null); setGroupKey(null) }}
            role="tab"
            aria-selected={zone === z.v}
          >
            {z.label}
          </button>
        ))}
      </div>

      {/* ── فلاتر الحالة ── */}
      <div className="chips-row">
        {STATUS_OPTS.map((o) => (
          <button
            key={o.v}
            className={`chip-btn ${status === o.v ? 'is-active' : ''}`}
            onClick={() => setStatus(o.v)}
          >
            {o.label}
          </button>
        ))}
      </div>

      {/* ── شريط العدد والبحث وطريقة العرض ── */}
      <div className="svc-bar">
        <div className="svc-bar__count">
          <strong>{total}</strong> {unitLabel}
          {openNow > 0 && <span className="svc-bar__open">🟢 {openNow} تعمل الآن</span>}
        </div>

        <div className="svc-bar__tools">
          <div className="search-input">
            <Icon name="search" size={16} />
            <input
              type="search"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="ابحث بالاسم أو العنوان…"
              aria-label="بحث"
            />
            {q && (
              <button className="search-clear" onClick={() => setQ('')} aria-label="مسح البحث">
                <Icon name="x" size={14} />
              </button>
            )}
          </div>

          <div className="seg seg--sm" role="group" aria-label="طريقة العرض">
            <button
              className={`seg__btn ${layout === 'card' ? 'is-active' : ''}`}
              onClick={() => setLayout('card')}
              title="بطاقات"
            >
              <Icon name="grid" size={16} /> <span className="seg__lbl">بطاقات</span>
            </button>
            <button
              className={`seg__btn ${layout === 'list' ? 'is-active' : ''}`}
              onClick={() => setLayout('list')}
              title="قائمة"
            >
              <Icon name="list" size={16} /> <span className="seg__lbl">قائمة</span>
            </button>
          </div>
        </div>
      </div>

      {/* ═══ المستوى الأول: بطاقات التجميع ═══ */}
      <section className="regions" aria-label={info.groupTitle}>
        <div className="regions__head">
          <h2><Icon name="pin" size={16} /> {info.groupTitle}</h2>
          {selectedGroup && (
            <button className="regions__clear" onClick={() => selectGroup(null)}>
              <Icon name="x" size={13} /> إلغاء تحديد {selectedGroup.label}
            </button>
          )}
        </div>

        <div className="regions__grid">
          {groups.map((g) => (
            <button
              key={g.key}
              className={`rcard ${activeKey === g.key ? 'is-active' : ''}`}
              onClick={() => selectGroup(g.key)}
            >
              <span className="rcard__icon"><CatIcon icon={g.icon} size={24} /></span>
              <span className="rcard__name">{g.label}</span>
              <span className="rcard__stat">
                {g.open > 0 ? `${g.open} تعمل` : `${g.total}`}
              </span>
            </button>
          ))}
        </div>
      </section>

      {/* ═══ المستوى الثاني: خدمات المجموعة المختارة فقط ═══ */}
      {loading ? (
        <div className="skeletons">
          {[1, 2, 3].map((i) => <div key={i} className="skel-card" />)}
        </div>
      ) : !selectedGroup ? (
        <div className="svc-hint">
          <span className="svc-hint__icon"><CatIcon icon={cat?.icon} size={40} /></span>
          <h3>اختر {info.groupTitle} لعرض الخدمات</h3>
          <p>
            اختر {info.group === 'region' ? 'المنطقة' : info.group === 'specialty' ? 'الاختصاص' : 'النوع'}
            {' '}التي تريدها من الأعلى، وسنعرض لك خدماتها مباشرة.
          </p>
        </div>
      ) : visibleItems.length === 0 ? (
        <div className="empty-state">
          <span className="empty-state__icon">🔍</span>
          <h3>لا توجد نتائج</h3>
          <p>لا توجد خدمات مطابقة في «{selectedGroup.label}».</p>
        </div>
      ) : (
        <>
          <div className="svc-result-head">
            <Icon name="pin" size={15} />
            <span>
              {info.group === 'region' ? `خدمات ${selectedGroup.label}` : selectedGroup.label}
            </span>
            <strong>{visibleItems.length}</strong>
          </div>

          {/* البطاقات المربعة هي الافتراضي للأقسام «المُصغّرة»،
              لكن مفتاح «بطاقات/قائمة» يبقى فاعلاً: اختيار «قائمة» يعرض صفوفاً مضغوطة */}
          {info.mini && layout === 'card' ? (
            <>
              {/* بطاقات مُصغّرة: أيقونة + اسم + نقطة حالة */}
              <div className="mini-grid">
                {visibleItems.map((s) => (
                  <MiniServiceCard
                    key={s.id}
                    s={s}
                    active={picked?.id === s.id}
                    onSelect={setPicked}
                  />
                ))}
              </div>

              {/* لوحة البيانات الكاملة — تُحدَّث في مكانها */}
              {picked ? (
                <ServicePanel s={picked} onClose={() => setPicked(null)} />
              ) : (
                <div className="panel-hint">
                  <span>👆</span> اضغط على أي {info.unit} من الأعلى لعرض بياناتها كاملةً هنا
                </div>
              )}
            </>
          ) : (
            <div className={layout === 'card' ? 'svc-grid svc-grid--compact' : 'svc-list'}>
              {visibleItems.map((s) => <ServiceCard key={s.id} s={s} compact={layout === 'list'} />)}
            </div>
          )}
        </>
      )}

    </main>
  )
}

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useStore } from '../lib/store'
import { api } from '../lib/api'
import type { GroupCard, Service } from '../lib/types'
import {
  primaryFilter,
  secondaryFilters,
  groupsFor,
  buildGroups,
  matchesGroup,
  matchesSecondary,
  secondaryOptions,
  type SecondaryState,
} from '../lib/grouping'
import ServiceCard from '../components/ServiceCard'
import MiniServiceCard from '../components/MiniServiceCard'
import ServicePanel from '../components/ServicePanel'
import Icon from '../components/Icon'
import CatIcon from '../components/CatIcon'
import { findCategory, fmtDateTime } from '../lib/utils'

/**
 * إعدادات العرض لكل قسم — العنوان والوحدة وطريقة البطاقات.
 *
 * ملاحظة مهمة: «أي فلتر يقود أي قسم» لم يبقَ هنا. كان في هذا الملف
 * `group: 'region' | 'specialty' | 'meta'` مكتوباً بالكود، فلم يستطع
 * المدير تغييره. صار الآن في قاعدة البيانات:
 *   filters (المكتبة) + category_filters (الإسناد) ← لوحة التحكم › الفلاتر
 */
interface CatCfg {
  title: string
  desc: string
  unit: string
  unitPlural: string
  /** بطاقات مُصغّرة (أيقونة + اسم + نقطة حالة) مع لوحة تفاصيل سفلية */
  mini?: boolean
  /** طريقة العرض الافتراضية لهذا القسم */
  defaultLayout?: 'card' | 'list'
}

const CAT_INFO: Record<string, CatCfg> = {
  pharmacies: {
    title: 'الصيدليات المناوبة', desc: 'حالة الصيدليات وآخر تحديثات المناوبة',
    unit: 'صيدلية', unitPlural: 'صيدليات', mini: true,
  },
  doctors: {
    title: 'الأطباء المختصون', desc: 'اختصاصات الأطباء ومواعيد عياداتهم',
    unit: 'طبيب', unitPlural: 'أطباء', mini: true,
  },
  stations: {
    title: 'الكازيات', desc: 'حالة محطات الوقود لحظةً بلحظة',
    unit: 'محطة', unitPlural: 'محطات', mini: true,
  },
  transport: {
    title: 'سرافيس وباصات', desc: 'خطوط النقل ومخطط الرحلة',
    unit: 'مركبة', unitPlural: 'مركبات', mini: false, defaultLayout: 'list',
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

export default function ServicesPage() {
  const { slug } = useParams<{ slug: string }>()
  const { categories, settings, governorates } = useStore()

  /* الرابط قد يكون المسار لا الرمز: «المخابر» رمزها laboratory ومسارها
     /laboratories. المطابقة بالرمز وحده تُرجع undefined فيصير القسم مجهولاً
     فلا فلتر ولا خدمات ولا رسالة — وهي الشكوى نفسها. */
  const cat = useMemo(() => findCategory(categories, slug ?? ''), [categories, slug])
  const catSlug = cat?.slug ?? slug ?? ''

  const info: CatCfg = CAT_INFO[catSlug] ?? {
    title: cat?.name ?? 'الخدمات',
    desc: cat?.description ?? '',
    unit: 'خدمة',
    unitPlural: 'خدمات',
  }

  // ─── الفلاتر المُسنَدة للقسم (من لوحة التحكم) ───
  const primary = primaryFilter(cat?.filters)
  const secondary = secondaryFilters(cat?.filters)

  const [items, setItems] = useState<Service[]>([])
  const [loading, setLoading] = useState(true)
  /** تجميعات الخادم بمفتاح الفلتر — تُحسب قبل ترقيم الصفحات */
  const [groups, setGroups] = useState<Record<string, GroupCard[]>>({})
  const [openNow, setOpenNow] = useState(0)
  const [total, setTotal] = useState(0)
  const [updatedAt, setUpdatedAt] = useState<string>('')

  const [zone, setZone] = useState('')
  const [govId, setGovId] = useState('')
  const [status, setStatus] = useState('')
  /** مفتاح البطاقة المختارة من الفلتر الأساسي */
  const [groupKey, setGroupKey] = useState<string | null>(null)
  /** قيم الفلاتر الثانوية: مفتاح الفلتر ← القيمة */
  const [secondaryState, setSecondaryState] = useState<SecondaryState>({})
  const [q, setQ] = useState('')
  const [layout, setLayout] = useState<'card' | 'list'>('card')
  /** الخدمة المختارة التي تُعرض بياناتها في اللوحة السفلية */
  const [picked, setPicked] = useState<Service | null>(null)

  const stateRef = useRef({ zone, status, q, govId })
  stateRef.current = { zone, status, q, govId }

  const load = useCallback(async () => {
    const s = stateRef.current
    const params: Record<string, any> = { category_id: catSlug, limit: 300, sort: 'open_first' }
    if (s.zone) params.zone = s.zone
    if (s.govId) params.governorate_id = s.govId
    if (s.status) params.status = s.status
    if (s.q) params.q = s.q

    setLoading(true)
    try {
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
      setGroups(r.groups ?? {})
      setTotal(r.total)
      setOpenNow(r.open_now)
      if (r.time) setUpdatedAt(r.time)
    } catch {
      setItems([])
      setGroups({})
    } finally {
      setLoading(false)
    }
  }, [catSlug])

  useEffect(() => { load() }, [load])

  useEffect(() => {
    const t = window.setTimeout(load, q ? 350 : 0)
    return () => window.clearTimeout(t)
  }, [zone, status, q, govId, load])

  // نبض تحديث كل 3 دقائق
  useEffect(() => {
    const id = window.setInterval(load, 180_000)
    return () => window.clearInterval(id)
  }, [load])

  // إعادة تعيين التحديد وطريقة العرض عند تغيير القسم
  useEffect(() => {
    setGroupKey(null); setSecondaryState({}); setPicked(null)
    setLayout(info.defaultLayout ?? 'card')
  }, [catSlug, info.defaultLayout])

  /**
   * بطاقات المستوى الأول — من تجميع الخادم للفلتر الأساسي.
   * وإن لم يرسل الخادم تجميعاً (حزمة واجهة أحدث من الخادم، أو قسم بلا فلتر)
   * نبنيه محلياً من الخدمات — فلا تظهر الصفحة فارغة.
   */
  const cards = useMemo(() => {
    if (!primary) return []
    const fromApi = groupsFor(primary, groups)
    return fromApi.length ? fromApi : buildGroups(items, primary)
  }, [primary, groups, items])

  const selectedCard = useMemo(
    () => (groupKey === null ? null : cards.find((g) => g.key === groupKey) ?? null),
    [cards, groupKey],
  )

  /**
   * الخدمات الظاهرة:
   *  ١. خدمات البطاقة المختارة من الفلتر الأساسي
   *  ٢. ثم الفلاتر الثانوية المُسنَدة للقسم (إن وُجدت)
   *
   * التصفية محلية لأن الخادم أرسل كل خدمات القسم مع فلاتر
   * المحافظة/النطاق/الحالة/البحث مطبَّقة — فلا طلب شبكة عند اختيار بطاقة.
   */
  const visibleItems = useMemo(() => {
    let out = items
    if (primary && groupKey !== null) {
      out = out.filter((s) => matchesGroup(s, primary, groupKey))
    }
    if (secondary.length) {
      out = out.filter((s) => matchesSecondary(s, secondary, secondaryState))
    }
    return out
  }, [items, primary, groupKey, secondary, secondaryState])

  const selectGroup = (key: string | null) => {
    setPicked(null)
    setGroupKey((cur) => (cur === key ? null : key))
  }

  // إسقاط الخدمة المختارة عند تغيير الفلاتر أو القسم
  useEffect(() => { setPicked(null) }, [catSlug, zone, status, q, govId, groupKey, secondaryState])

  /** هل هناك فلتر يضيّق النتائج؟ (يفرّق بين «قسم فارغ» و«لا نتائج مطابقة») */
  const hasNarrowingFilters = govId !== '' || zone !== '' || status !== '' || q.trim() !== ''

  const clearNarrowing = () => {
    setGovId(''); setZone(''); setStatus(''); setQ(''); setGroupKey(null); setSecondaryState({})
  }

  const unitLabel = total === 1 ? info.unit
    : (total >= 3 && total <= 10 ? info.unitPlural : info.unit)

  return (
    <main className="page">
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
            onClick={() => { setGovId(''); setGroupKey(null) }}
            role="tab" aria-selected={govId === ''}
          >كل المحافظات</button>
          {governorates.map((g) => (
            <button
              key={g.id}
              className={`seg__btn ${String(govId) === String(g.id) ? 'is-active' : ''}`}
              onClick={() => { setGovId(String(g.id)); setGroupKey(null) }}
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
            onClick={() => { setZone(z.v); setGroupKey(null) }}
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
          {/* الفلاتر الثانوية: تظهر فقط إن أسنَد المدير أكثر من فلتر للقسم */}
          {secondary.map((f) => (
            <label key={f.key} className="svc-select">
              <span className="svc-select__lbl">{f.label}</span>
              <select
                value={secondaryState[f.key] ?? ''}
                onChange={(e) => setSecondaryState((s) => ({ ...s, [f.key]: e.target.value }))}
                aria-label={f.label}
              >
                <option value="">الكل</option>
                {secondaryOptions(f, groups).map((o) => (
                  <option key={o.key} value={o.key}>{o.label} ({o.total})</option>
                ))}
              </select>
            </label>
          ))}

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

      {/* ═══ المستوى الأول: بطاقات التجميع بحسب الفلتر الأساسي ═══ */}
      {primary && cards.length > 0 && (
        <section className="regions" aria-label={primary.label}>
          <div className="regions__head">
            <h2><CatIcon icon={primary.icon || 'filter'} size={16} /> {primary.label}</h2>
            {selectedCard && (
              <button className="regions__clear" onClick={() => selectGroup(null)}>
                <Icon name="x" size={13} /> إلغاء تحديد {selectedCard.label}
              </button>
            )}
          </div>

          <div className="regions__grid">
            {cards.map((g) => (
              <button
                key={g.key}
                className={`rcard ${groupKey === g.key ? 'is-active' : ''}`}
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
      )}

      {/* ═══ المستوى الثاني: خدمات المجموعة المختارة فقط ═══ */}
      {!cat && categories.length > 0 ? (
        <div className="empty-state">
          <span className="empty-state__icon">🧭</span>
          <h3>القسم غير موجود</h3>
          <p>لا يوجد قسم بهذا الرابط. تحقّق من الرابط أو ارجع إلى الرئيسية.</p>
        </div>
      ) : loading ? (
        <div className="skeletons">
          {[1, 2, 3].map((i) => <div key={i} className="skel-card" />)}
        </div>
      ) : items.length === 0 ? (
        /* لا نتائج — والرسالة تفرّق بين «القسم فارغ» و«الفلاتر حجبت كل شيء»،
           وإلا بقي الزائر أمام صفحة صامتة لا يعرف سببها */
        hasNarrowingFilters ? (
          <div className="empty-state">
            <span className="empty-state__icon">🔍</span>
            <h3>لا توجد نتائج مطابقة</h3>
            <p>جرّب توسيع البحث: ألغِ المحافظة أو النطاق أو الحالة أو البحث النصي.</p>
            <button className="btn btn--ghost btn--sm" onClick={clearNarrowing}>إلغاء كل الفلاتر</button>
          </div>
        ) : (
          <div className="empty-state">
            <span className="empty-state__icon">📭</span>
            <h3>لا توجد خدمات بعد</h3>
            <p>لم تُضَف خدمات إلى «{info.title}» حتى الآن.</p>
          </div>
        )
      ) : !primary || cards.length === 0 ? (
        /* قسم بلا فلتر مُسنَد — خدماته تُعرض كقائمة مباشرة.
           ولا بدّ من `visibleItems` لا `items`: الفلاتر الثانوية تُطبَّق عليها،
           وإلا عُرضت خدمات حجبها فلتر اختاره الزائر. */
        visibleItems.length === 0 ? (
          <div className="empty-state">
            <span className="empty-state__icon">🔍</span>
            <h3>لا توجد نتائج مطابقة</h3>
            <p>جرّب توسيع البحث: ألغِ المحافظة أو النطاق أو الحالة أو البحث النصي.</p>
            <button className="btn btn--ghost btn--sm" onClick={clearNarrowing}>إلغاء كل الفلاتر</button>
          </div>
        ) : (
          <div className={layout === 'card' ? 'svc-grid svc-grid--compact' : 'svc-list'}>
            {visibleItems.map((s) => <ServiceCard key={s.id} s={s} compact={layout === 'list'} />)}
          </div>
        )
      ) : !selectedCard ? (
        <div className="svc-hint">
          <span className="svc-hint__icon"><CatIcon icon={cat?.icon} size={40} /></span>
          <h3>اختر {primary.label} لعرض الخدمات</h3>
          <p>
            اختر ما تريد من «{primary.label}» في الأعلى، وسنعرض لك خدماته مباشرة.
          </p>
        </div>
      ) : visibleItems.length === 0 ? (
        <div className="empty-state">
          <span className="empty-state__icon">🔍</span>
          <h3>لا توجد نتائج</h3>
          <p>لا توجد خدمات مطابقة في «{selectedCard.label}».</p>
        </div>
      ) : (
        <>
          <div className="svc-result-head">
            <Icon name="pin" size={15} />
            <span>{selectedCard.label}</span>
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

import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useStore } from '../../lib/store'
import { api } from '../../lib/api'
import type { AdminStats, ActivityItem, AppUpdateInfo, AppUpdatePathStatus, Category, CategoryField, Filter, FilterSourceOption, Governorate, Region, Service, ServiceRequest, User, Zone } from '../../lib/types'
import { useToast } from '../../lib/useToast'
import { num, fmtDateTime, fmtDate } from '../../lib/utils'
import Icon from '../../components/Icon'
import IconPicker from '../../components/IconPicker'
import CatIcon from '../../components/CatIcon'
import Modal from '../../components/Modal'
import LocationPicker from '../../components/LocationPicker'
import DangerZone from '../../components/DangerZone'
import ScheduleEditor from '../../components/ScheduleEditor'
import { FieldsBuilder, DynamicFields, toDraft, type DraftField, type FieldValues } from '../../components/CategoryFields'

type Tab = 'overview' | 'services' | 'categories' | 'filters' | 'governorates' | 'regions' | 'requests' | 'users' | 'app' | 'settings' | 'activity'

export default function AdminDashboard() {
  const { user } = useStore()
  const nav = useNavigate()
  const [tab, setTab] = useState<Tab>('overview')

  useEffect(() => { if (!user || user.role !== 'admin') nav('/auth', { replace: true }) }, [user])

  const TABS: { id: Tab; icon: string; label: string }[] = [
    { id: 'overview',   icon: 'bar-chart-3',   label: 'نظرة عامة' },
    { id: 'services',   icon: 'boxes',         label: 'الخدمات' },
    { id: 'categories', icon: 'layout-grid',   label: 'الأقسام' },
    { id: 'filters',    icon: 'list-filter',   label: 'الفلاتر' },
    { id: 'governorates', icon: 'map',         label: 'المحافظات' },
    { id: 'regions',    icon: 'map-pin',       label: 'المناطق' },
    { id: 'requests',   icon: 'inbox',         label: 'الطلبات' },
    { id: 'users',      icon: 'users',         label: 'المستخدمون' },
    { id: 'app',        icon: 'package',       label: 'تحديث التطبيق' },
    { id: 'settings',   icon: 'settings',      label: 'الإعدادات' },
    { id: 'activity',   icon: 'activity',      label: 'النشاط' },
  ]

  return (
    <main className="page admin-page">
      <header className="admin__head">
        <Link to="/profile" className="back-btn"><Icon name="arrowRight" size={18} /> حسابي</Link>
        <h1><Icon name="settings" size={24} /> لوحة تحكم المدير</h1>
      </header>

      <nav className="admin__tabs" role="tablist">
        {TABS.map((t) => (
          <button key={t.id} className={tab === t.id ? 'is-active' : ''} onClick={() => setTab(t.id)} role="tab" aria-selected={tab === t.id}>
            <Icon name={t.icon} size={15} /> <span className="admin-tab-label">{t.label}</span>
          </button>
        ))}
      </nav>

      <div className="admin__content">
        {tab === 'overview' && <OverviewTab />}
        {tab === 'services' && <ServicesTab />}
        {tab === 'categories' && <CategoriesTab />}
        {tab === 'filters' && <FiltersTab />}
        {tab === 'governorates' && <GovernoratesTab />}
        {tab === 'regions' && <RegionsTab />}
        {tab === 'requests' && <RequestsTab />}
        {tab === 'users' && <UsersTab />}
        {tab === 'app' && <AppUpdateTab />}
        {tab === 'settings' && <SettingsTab />}
        {tab === 'activity' && <ActivityTab />}
      </div>
    </main>
  )
}

function OverviewTab() {
  const [stats, setStats] = useState<AdminStats | null>(null)
  useEffect(() => { api.admin.stats().then(setStats).catch(() => {}) }, [])

  if (!stats) return <div className="skeletons"><div className="skel-card" /></div>

  return (
    <div className="admin-overview">
      <div className="stat-grid">
        {stats.categories.map((c) => (
          <div key={c.slug} className="admin-stat" style={{ '--c': c.color } as React.CSSProperties}>
            <span className="admin-stat__icon"><CatIcon icon={c.icon} size={24} /></span>
            <span className="admin-stat__num">{num(c.total)}</span>
            <span className="admin-stat__label">{c.name}</span>
            <span className="admin-stat__sub">{c.managed} مسؤول</span>
          </div>
        ))}
      </div>
      <div className="stat-grid stat-grid--small">
        <div className="admin-stat">
          <span className="admin-stat__icon"><Icon name="boxes" size={22} /></span>
          <span className="admin-stat__num">{num(stats.services_active)}</span><span className="admin-stat__label">خدمات نشطة</span></div>
        <div className="admin-stat admin-stat--green">
          <span className="admin-stat__icon"><Icon name="circle-check-big" size={22} /></span>
          <span className="admin-stat__num">{num(stats.open_now)}</span><span className="admin-stat__label">تعمل الآن</span></div>
        <div className="admin-stat admin-stat--amber">
          <span className="admin-stat__icon"><Icon name="siren" size={22} /></span>
          <span className="admin-stat__num">{num(stats.on_duty)}</span><span className="admin-stat__label">مناوبة</span></div>
        <div className="admin-stat admin-stat--blue">
          <span className="admin-stat__icon"><Icon name="inbox" size={22} /></span>
          <span className="admin-stat__num">{num(stats.requests_pending)}</span><span className="admin-stat__label">طلبات معلّقة</span></div>
        <div className="admin-stat">
          <span className="admin-stat__icon"><Icon name="users" size={22} /></span>
          <span className="admin-stat__num">{num(stats.users)}</span><span className="admin-stat__label">مستخدمون</span></div>
        <div className="admin-stat">
          <span className="admin-stat__icon"><Icon name="map-pin" size={22} /></span>
          <span className="admin-stat__num">{num(stats.regions)}</span><span className="admin-stat__label">مناطق</span></div>
      </div>
    </div>
  )
}

function ServicesTab() {
  const [items, setItems] = useState<Service[]>([])
  const [q, setQ] = useState('')

  const [editSvc, setEditSvc] = useState<Service | null>(null)
  const [showAdd, setShowAdd] = useState(false)
  const [svcNonce, setSvcNonce] = useState(0)
  const toast = useToast()

  const load = useCallback(async () => {
    /* بلا حدّ أقصى: يُعرض كل الخدمات — كان الطلب يمرّر limit: 200 والخادم
       يحدّ بـ٤٠٠، فتختفي الخدمات الأقدم عن المدير بلا ترشيح. */
    const r = await api.admin.services({ q })
    setItems(r.items)
  }, [q])

  useEffect(() => { load() }, [load])

  const doDelete = async (id: number, name: string) => {
    if (!confirm(`حذف "${name}"؟ لا يمكن التراجع.`)) return
    await api.admin.deleteService(id)
    toast('تم حذف الخدمة')
    load()
  }

  const openEdit = async (id: number) => {
    try {
      const r = await api.admin.service(id)
      setEditSvc(r.service ?? null)
    } catch (err: any) {
      toast(err?.message || 'تعذّر تحميل بيانات الخدمة', 'error')
    }
  }

  return (
    <>
      <div className="admin-toolbar">
        <div className="search-input"><Icon name="search" size={16} /><input placeholder="بحث…" value={q} onChange={(e) => setQ(e.target.value)} /></div>
        <button className="btn btn--primary btn--sm" onClick={() => { setEditSvc(null); setSvcNonce((n) => n + 1); setShowAdd(true) }}><Icon name="plus" size={14} /> إضافة خدمة</button>
        <button className="qbtn" onClick={load}><Icon name="refresh-cw" size={14} /></button>
      </div>
      <div className="admin-table-wrap">
        <table className="admin-table">
          <thead><tr><th>#</th><th>الخدمة</th><th>القسم</th><th>المنطقة</th><th>الحالة</th><th>المسؤول</th><th>إجراءات</th></tr></thead>
          <tbody>
            {items.map((s) => (
              <tr key={s.id} className={s.is_active === false ? 'is-inactive' : ''}>
                <td>{s.id}</td>
                <td><Link to={`/s/${s.id}`}><CatIcon icon={s.category_icon} meta={s.meta} size={15} /> {s.name}</Link></td>
                <td>{s.category_name}</td>
                <td>{s.region_name ?? '—'}</td>
                <td><span className={`badge badge--${s.status}`}>{s.status_label}</span>{s.on_duty && <span className="badge badge--duty">مناوبة</span>}</td>
                <td>{s.owner_name ?? <span className="text-muted">—</span>}</td>
                <td className="table-actions">
                  <button className="iconbtn" onClick={() => openEdit(s.id)} title="تعديل"><Icon name="pencil" size={15} /></button>
                  <button className="iconbtn iconbtn--danger" onClick={() => doDelete(s.id, s.name)} title="حذف"><Icon name="trash-2" size={15} /></button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <Modal open={showAdd || !!editSvc} onClose={() => { setShowAdd(false); setEditSvc(null) }} title={editSvc ? `تعديل: ${editSvc.name}` : 'إضافة خدمة'} wide>
        <AdminServiceForm
          key={editSvc ? `svc-${editSvc.id}` : `svc-new-${svcNonce}`}
          svc={editSvc}
          onSaved={() => { setShowAdd(false); setEditSvc(null); load() }}
        />
      </Modal>
    </>
  )
}

function AdminServiceForm({ svc, onSaved }: { svc: Service | null; onSaved: () => void }) {
  const { categories } = useStore()
  const toast = useToast()
  const [busy, setBusy] = useState(false)
  const [catId, setCatId] = useState(svc?.category_id ?? categories[0]?.id ?? 0)
  const [regionId, setRegionId] = useState(svc?.region_id ?? 0)
  const [govId, setGovId] = useState<number | null>(svc?.governorate_id ?? null)
  const { locations } = useStore()
  const [ownerId, setOwnerId] = useState<string>(String(svc?.owner_id ?? ''))
  const [name, setName] = useState(svc?.name ?? '')
  const [address, setAddress] = useState(svc?.address ?? '')
  const [phone, setPhone] = useState(svc?.phone ?? '')
  const [whatsapp, setWhatsapp] = useState(svc?.whatsapp ?? '')
  const [note, setNote] = useState(svc?.note ?? '')
  const [isActive, setIsActive] = useState(svc?.is_active !== false)
  const [isVerified, setIsVerified] = useState(!!svc?.is_verified)
  const [layout, setLayout] = useState<string>(svc?.layout ?? 'card')
  const [mode, setMode] = useState(svc?.mode ?? 'auto')
  const [schedule, setSchedule] = useState(svc?.schedule ?? [])
  // أيقونة الخدمة — تُختار من مجموعة أيقونات القسم المختار
  const [icon, setIcon] = useState<string>(() => String((svc?.meta as any)?.icon ?? ''))

  // الحقول الخاصة بالقسم المختار — تتغيّر تلقائياً مع القسم
  const currentCat = useMemo(
    () => categories.find((c) => c.id === catId),
    [categories, catId],
  )
  const catFields = useMemo<CategoryField[]>(
    () => currentCat?.fields ?? [],
    [currentCat],
  )
  const [fieldValues, setFieldValues] = useState<FieldValues>(() => {
    const m = (svc?.meta ?? {}) as Record<string, any>
    const init: FieldValues = {}
    for (const f of categories.find((c) => c.id === (svc?.category_id ?? 0))?.fields ?? []) {
      if (m[f.key] !== undefined) init[f.key] = m[f.key]
    }
    return init
  })

  // عند تغيير القسم: أفرغ قيم الحقول التي لا تنتمي للقسم الجديد
  // (يمنع إرسال مفاتيح من قسم آخر إلى الخادم)
  useEffect(() => {
    setFieldValues((prev) => {
      const valid = new Set(catFields.map((f) => f.key))
      const next: FieldValues = {}
      for (const [k, v] of Object.entries(prev)) {
        if (valid.has(k)) next[k] = v
      }
      return next
    })
  }, [catId])
  const save = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!govId) { toast('يجب اختيار المحافظة', 'error'); return }
    setBusy(true)
    try {
      // ─── نبدأ من meta الحالي ونحتفظ بالمفاتيح غير المُدارة ───
      // (مثل consult_fee / hospital / specialty_icon …)
      // الحقول الديناميكية تُدمج فوقها، والخادم يتولى التحقق منها.
      const meta: Record<string, any> = { ...((svc?.meta ?? {}) as Record<string, any>) }
      const base = { category_id: catId, region_id: regionId || null, governorate_id: govId, owner_id: ownerId ? Number(ownerId) : null, name, address, phone, whatsapp, note, is_active: isActive, is_verified: isVerified, layout: layout || null, meta, schedule, icon: icon || undefined,
        // الحقول الخاصة بالقسم — يتحقق منها الخادم ويدمجها داخل meta
        fields: fieldValues }
      if (svc) {
        await api.admin.updateService(svc.id, { ...base, mode })
      } else {
        await api.admin.createService(base)
      }
      onSaved()
    } catch (err: any) {
      toast(err.message || 'فشل الحفظ', 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={save} className="admin-form">
      <div className="form-grid">
        <label><span>الاسم *</span><input required value={name} onChange={(e) => setName(e.target.value)} /></label>
        <label><span>القسم</span><select value={catId} onChange={(e) => { setCatId(Number(e.target.value)); setIcon('') }}>{categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></label>

        {/* منتقي أيقونات — يعرض أيقونات القسم المختار فقط */}
        {catId > 0 && (
          <div className="field">
            <IconPicker
              categorySlug={categories.find((c) => c.id === catId)?.slug}
              value={icon}
              onChange={setIcon}
              columns={6}
            />
          </div>
        )}
        <LocationPicker
          locations={locations}
          governorateId={govId}
          regionId={regionId || null}
          onChange={(g, r) => { setGovId(g); setRegionId(r ?? 0) }}
          required
          label="الموقع"
        />
        {!govId && <p className="admin-form__hint" style={{ color: '#dc2626' }}>يجب اختيار المحافظة</p>}
        <label><span>معرف المسؤول (owner_id)</span><input value={ownerId} onChange={(e) => setOwnerId(e.target.value)} dir="ltr" placeholder="رقم أو فارغ" /></label>
      </div>
      <label><span>العنوان</span><input value={address} onChange={(e) => setAddress(e.target.value)} /></label>
      <div className="form-grid">
        <label><span>الهاتف</span><input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} dir="ltr" /></label>
        <label><span>واتساب</span><input type="tel" value={whatsapp} onChange={(e) => setWhatsapp(e.target.value)} dir="ltr" /></label>
      </div>
      <label><span>ملاحظة</span><textarea value={note} onChange={(e) => setNote(e.target.value)} rows={2} /></label>
      <div className="form-grid form-grid--checks">
        <label className="chk"><input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} /><span>نشطة</span></label>
        <label className="chk"><input type="checkbox" checked={isVerified} onChange={(e) => setIsVerified(e.target.checked)} /><span>موثقة</span></label>
        <label><span>طريقة العرض</span><select value={layout} onChange={(e) => setLayout(e.target.value as 'card'|'list'|'row')}><option value="">تلقائي</option><option value="card">بطاقة</option><option value="list">قائمة</option><option value="row">صف</option></select></label>
        <label><span>الحالة اليدوية</span><select value={mode} onChange={(e) => setMode(e.target.value as any)}><option value="auto">تلقائي (حسب الجدول)</option><option value="open">مفتوح</option><option value="closed">مغلق</option></select></label>
      </div>
      {/* ═══ الحقول الخاصة بالقسم المختار ═══ */}
      {catFields.length > 0 ? (
        <div className="admin-form__section">
          <h4>
            <Icon name="list" size={16} /> بيانات إضافية — {currentCat?.name ?? ''}
            <span className="admin-form__hint">حقول يحددها القسم</span>
          </h4>
          <DynamicFields
            fields={catFields}
            values={fieldValues}
            onChange={(k, v) => setFieldValues((prev) => ({ ...prev, [k]: v }))}
          />
        </div>
      ) : (
        currentCat && (
          <div className="admin-form__section">
            <p className="kv__empty">
              لا توجد حقول إضافية لقسم «{currentCat.name}».
              يمكنك تعريفها من: <strong>الأقسام ← تعديل «{currentCat.name}» ← الحقول الإضافية</strong>
            </p>
          </div>
        )
      )}
      <div className="admin-form__section">
        <h4><Icon name="clock" size={16} /> جدول الدوام</h4>
        <ScheduleEditor value={schedule} onChange={setSchedule} />
      </div>
      <button type="submit" className="btn btn--primary" disabled={busy}>{busy ? 'جاري الحفظ…' : svc ? 'حفظ التعديلات' : 'إضافة الخدمة'}</button>
    </form>
  )
}

function CategoriesTab() {
  const [items, setItems] = useState<Category[]>([])
  const [editCat, setEditCat] = useState<Category | null>(null)
  const [showAdd, setShowAdd] = useState(false)
  const [formNonce, setFormNonce] = useState(0)
  const toast = useToast()
  const load = () => api.admin.categories().then((r) => setItems(r.items)).catch(() => {})
  useEffect(() => { load() }, [])

  const doDelete = async (id: number, name: string) => {
    if (!confirm(`حذف قسم "${name}"؟`)) return
    try {
      await api.admin.deleteCategory(id)
      toast('تم حذف القسم')
      load()
    } catch (err: any) {
      if (err.status === 409 && confirm('القسم يحتوي خدمات. حذفه مع خدماته؟')) {
        await api.admin.deleteCategory(id, true)
        toast('تم الحذف القسري')
        load()
      } else { toast(err.message, 'error') }
    }
  }

  return (
    <>
      <div className="admin-toolbar">
        <button className="btn btn--primary btn--sm" onClick={() => { setEditCat(null); setFormNonce((n) => n + 1); setShowAdd(true) }}><Icon name="plus" size={14} /> إضافة قسم</button>
      </div>
      <div className="admin-cards">
        {items.map((c) => (
          <div key={c.id} className="admin-cat" style={{ '--c': c.color } as React.CSSProperties}>
            <span className="admin-cat__icon"><CatIcon icon={c.icon} size={26} /></span>
            <h4>{c.name}</h4>
            <p>{c.description}</p>
            <p className="text-muted">{c.slug} · {c.layout}</p>
            <div className="admin-cat__tools">
              <button className="iconbtn" onClick={() => { setEditCat(c); setShowAdd(true) }}><Icon name="pencil" size={15} /></button>
              <button className="iconbtn iconbtn--danger" onClick={() => doDelete(c.id, c.name)}><Icon name="trash-2" size={15} /></button>
            </div>
          </div>
        ))}
      </div>
      <Modal open={showAdd} onClose={() => { setShowAdd(false); setEditCat(null) }} title={editCat ? `تعديل: ${editCat.name}` : 'إضافة قسم'} wide>
        <CategoryForm
          key={editCat ? `cat-${editCat.id}` : `cat-new-${formNonce}`}
          cat={editCat}
          onSaved={() => { setShowAdd(false); setEditCat(null); load() }}
        />
      </Modal>
    </>
  )
}

function CategoryForm({ cat, onSaved }: { cat: Category | null; onSaved: () => void }) {
  const toast = useToast()
  const [busy, setBusy] = useState(false)
  const [name, setName] = useState(cat?.name ?? '')
  const [singular, setSingular] = useState(cat?.singular ?? '')
  const [slug, setSlug] = useState(cat?.slug ?? '')
  const [icon, setIcon] = useState(cat?.icon ?? '')
  const [color, setColor] = useState(cat?.color ?? '#3b82f6')
  const [desc, setDesc] = useState(cat?.description ?? '')
  const [layout, setLayout] = useState<string>(cat?.layout ?? 'card')
  const [route, setRoute] = useState(cat?.route ?? '')
  const [featDuty, setFeatDuty] = useState(cat?.features?.duty ?? false)
  const [featSchedule, setFeatSchedule] = useState(cat?.features?.schedule ?? true)
  const [featStatus, setFeatStatus] = useState(cat?.features?.status ?? true)
  // الحقول الخاصة بالقسم — تُبنى ديناميكياً
  const [fields, setFields] = useState<DraftField[]>(() => toDraft(cat?.fields ?? []))
  const [savingFields, setSavingFields] = useState(false)

  /**
   * يحفظ الحقول الخاصة بالقسم:
   *  • الحقول الجديدة   → POST
   *  • الحقول المعدّلة  → PUT  (مع خياراتها دفعةً واحدة)
   *  • الحقول المحذوفة  → DELETE
   */
  const saveFields = async (categoryId: number) => {
    setSavingFields(true)
    try {
      const original = cat?.fields ?? []
      const keptIds = new Set(fields.filter((f) => f.id).map((f) => f.id as number))

      // ١) احذف الحقول التي أزالها المستخدم
      for (const of_ of original) {
        if (typeof of_.id === 'number' && !keptIds.has(of_.id)) {
          await api.admin.deleteField(of_.id).catch(() => {})
        }
      }

      // ٢) أنشئ أو حدّث
      for (const f of fields) {
        if (!f.label.trim()) continue    // تجاهل الحقول بلا عنوان

        // نظّف الخيارات: تجاهل الفارغة
        const options = (f.type === 'select' ? f.options : [])
          .filter((o) => o.label.trim() !== '')
          .map((o) => ({ label: o.label.trim(), value: o.value.trim() || o.label.trim(), icon: o.icon.trim() }))

        const payload = {
          category_id: categoryId,
          key: f.key.trim(),
          label: f.label.trim(),
          type: f.type,
          required: f.required,
          placeholder: f.placeholder.trim(),
          suffix: f.suffix.trim(),
          hide_when_false: f.hide_when_false,
          show_in_card: f.show_in_card,
          filterable: f.filterable,
          ...(f.type === 'select' ? { options } : {}),
        }

        if (f.id) await api.admin.updateField(f.id, payload)
        else await api.admin.createField(payload)
      }
    } finally {
      setSavingFields(false)
    }
  }

  const save = async (e: React.FormEvent) => {
    e.preventDefault()
    setBusy(true)
    try {
      const features = { duty: featDuty, schedule: featSchedule, status: featStatus }
      const payload = { name, singular, slug, icon: icon || 'map-pin', color, description: desc, layout, route, features }

      let catId = cat?.id
      if (cat) await api.admin.updateCategory(cat.id, payload)
      else {
        const res = await api.admin.createCategory(payload)
        catId = res.id
      }

      // احفظ الحقول الخاصة بعد أن نعرف مُعرّف القسم
      if (catId) await saveFields(catId)

      onSaved()
    } catch (err: any) { toast(err.message, 'error') }
    setBusy(false)
  }

  return (
    <form onSubmit={save} className="admin-form">
      <label><span>الاسم *</span><input required value={name} onChange={(e) => setName(e.target.value)} /></label>
      <div className="form-grid">
        <label><span>المفرد</span><input value={singular} onChange={(e) => setSingular(e.target.value)} /></label>
        <label><span>الرمز (slug)</span><input value={slug} onChange={(e) => setSlug(e.target.value)} dir="ltr" placeholder="my-service" /></label>
      </div>
      <div className="form-grid">
        <label><span>اللون</span><input type="color" value={color} onChange={(e) => setColor(e.target.value)} /></label>
      </div>

      {/* منتقي الأيقونات: تتغيّر القائمة حسب رمز القسم (slug) */}
      <div className="field">
        <span className="field__label">أيقونة القسم</span>
        <div className="cat-icon-preview" style={{ '--c': color } as React.CSSProperties}>
          <CatIcon icon={icon || 'map-pin'} size={30} />
          <div className="cat-icon-preview__meta">
            <strong>{name || 'اسم القسم'}</strong>
            <span>{icon ? `الأيقونة: ${icon}` : 'لم تُختر أيقونة بعد'}</span>
          </div>
        </div>
        <IconPicker
          categorySlug={slug}
          value={icon}
          onChange={setIcon}
          columns={6}
        />
      </div>
      <div className="form-grid">
        <label>
          <span>المسار</span>
          <input value={route} onChange={(e) => setRoute(e.target.value)} dir="ltr" placeholder="/slug" />
          {/* معاينة الرابط: الرابط في الرئيسية يُبنى من «المسار» لا من «الرمز».
              كان اختلافهما يخفي فلتر القسم وخدماته بلا أي رسالة (المخابر). */}
          <span className="field__help">
            الرابط: <code dir="ltr">{route || (slug ? `/${slug}` : '/…')}</code>
            {route && slug && route.replace(/^\/+|\/+$/g, '') !== slug && (
              <> — يختلف عن الرمز «{slug}»، وكلا الرابطين يعمل.</>
            )}
          </span>
        </label>
        <label><span>طريقة العرض</span><select value={layout} onChange={(e) => setLayout(e.target.value)}><option value="card">بطاقة</option><option value="list">قائمة</option><option value="row">صف</option></select></label>
      </div>
      <label><span>الوصف</span><textarea value={desc} onChange={(e) => setDesc(e.target.value)} rows={2} /></label>
      <div className="admin-form__section">
        <h4>الميزات</h4>
        <label className="chk"><input type="checkbox" checked={featStatus} onChange={(e) => setFeatStatus(e.target.checked)} /><span>حالة (مفتوح/مغلق)</span></label>
        <label className="chk"><input type="checkbox" checked={featSchedule} onChange={(e) => setFeatSchedule(e.target.checked)} /><span>جدول الدوام</span></label>
        <label className="chk"><input type="checkbox" checked={featDuty} onChange={(e) => setFeatDuty(e.target.checked)} /><span>مناوبة ليلية</span></label>
      </div>

      {/* ═══ الحقول الخاصة بالقسم ═══ */}
      <div className="admin-form__section">
        <h4>
          الحقول الإضافية
          <span className="admin-form__hint">
            تظهر ديناميكياً عند إضافة أو تعديل خدمة من هذا القسم
          </span>
        </h4>
        <FieldsBuilder fields={fields} onChange={setFields} />
      </div>

      <button type="submit" className="btn btn--primary" disabled={busy || savingFields}>
        {busy || savingFields ? '…' : cat ? 'حفظ' : 'إضافة'}
      </button>
    </form>
  )
}


/* ══════════════════════════════════════════════════════════════
 *  تبويب الفلاتر
 *  ─────────────────────────────────────────────────────────────
 *  الفلاتر كانت مكتوبة في كود الواجهة (CAT_INFO): الصيدليات بالمناطق
 *  والأطباء بالاختصاص والسرفيس بنوع المركبة — بلا قدرة للمدير على
 *  التغيير. صارت الآن بيانات:
 *    • «مكتبة الفلاتر»: يُنشئ المدير فلتراً ويحدّد مصدر بياناته
 *    • «فلاتر الأقسام»: يُسنِد لكل قسم فلتراً **أساسياً** يقود بطاقات
 *      المستوى الأول في صفحته، ويمكنه إسناد فلاتر إضافية للتصفية.
 * ══════════════════════════════════════════════════════════════ */
function FiltersTab() {
  const { categories, refreshMeta } = useStore()
  const [items, setItems] = useState<Filter[]>([])
  const [sources, setSources] = useState<FilterSourceOption[]>([])
  const [showForm, setShowForm] = useState(false)
  const [editFilter, setEditFilter] = useState<Filter | null>(null)
  const [formNonce, setFormNonce] = useState(0)
  const [assignCat, setAssignCat] = useState<Category | null>(null)
  const toast = useToast()

  const load = () => {
    api.admin.filters()
      .then((r) => { setItems(r.items); setSources(r.sources ?? []) })
      .catch(() => {})
  }
  useEffect(() => { load() }, [])

  const doDelete = async (f: Filter) => {
    const used = f.used_by ?? 0
    const msg = used > 0
      ? `حذف الفلتر «${f.label}»؟\n\nمُسنَد إلى ${used} قسماً وسيُزال منها،\nوستُعرض خدماتها بلا تجميع حتى تُسنِد لها فلتراً آخر.`
      : `حذف الفلتر «${f.label}»؟`
    if (!confirm(msg)) return
    try {
      const r = await api.admin.deleteFilter(f.id)
      toast(r.message)
      load()
      refreshMeta()
    } catch (e) {
      toast(e instanceof Error ? e.message : 'تعذّر الحذف', 'error')
    }
  }

  /** وصف مصدر الفلتر — يُبنى من قائمة المصادر التي أرسلها الخادم */
  const sourceLabel = (f: Filter) => {
    const s = sources.find((x) => x.source_type === f.source_type && (f.source_type !== 'field' || x.source_key === f.source_key))
    return s ? s.hint : f.source_type
  }

  return (
    <>
      <div className="admin-toolbar">
        <button className="btn btn--primary btn--sm" onClick={() => { setEditFilter(null); setFormNonce((n) => n + 1); setShowForm(true) }}>
          <Icon name="plus" size={14} /> إضافة فلتر
        </button>
      </div>

      {/* ─── مكتبة الفلاتر ─── */}
      <h2 className="admin-sec-title"><Icon name="list-filter" size={16} /> مكتبة الفلاتر</h2>
      <div className="admin-table-wrap">
        <table className="admin-table">
          <thead>
            <tr><th>#</th><th>الاسم</th><th>المصدر</th><th>الأيقونة</th><th>مُسنَد إلى</th><th>إجراءات</th></tr>
          </thead>
          <tbody>
            {items.length === 0 && (
              <tr><td colSpan={6} className="admin-empty">لا فلاتر بعد — أضف أول فلتر</td></tr>
            )}
            {items.map((f) => (
              <tr key={f.id} className={f.is_active ? '' : 'is-muted'}>
                <td>{f.id}</td>
                <td>
                  <strong>{f.label}</strong>
                  {!f.is_active && <span className="badge badge--off">معطّل</span>}
                  <div className="admin-sub">المفتاح: <code>{f.key}</code></div>
                </td>
                <td>{sourceLabel(f)}</td>
                <td><CatIcon icon={f.icon || 'filter'} size={18} /></td>
                <td>{(f.used_by ?? 0) > 0 ? `${f.used_by} قسماً` : <span className="admin-warn">غير مُسنَد</span>}</td>
                <td className="table-actions">
                  <button className="iconbtn" onClick={() => { setEditFilter(f); setShowForm(true) }} title="تعديل"><Icon name="pencil" size={15} /></button>
                  <button className="iconbtn iconbtn--danger" onClick={() => doDelete(f)} title="حذف"><Icon name="trash-2" size={15} /></button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* ─── الإسناد للأقسام ─── */}
      <h2 className="admin-sec-title"><Icon name="layout-grid" size={16} /> فلاتر الأقسام</h2>
      <p className="admin-note">
        <strong>الفلتر الأساسي (⭐)</strong> هو الذي يبني بطاقات العرض في المستوى الأول
        لصفحة القسم — مثال: الصيدليات ← المناطق · الأطباء ← الاختصاص · السرفيس ← نوع المركبة.
        الفلاتر الإضافية تظهر قائمة اختيار داخل شريط الصفحة.
      </p>
      <div className="admin-table-wrap">
        <table className="admin-table">
          <thead>
            <tr><th>القسم</th><th>الفلاتر المُسنَدة</th><th>البطاقات تعتمد على</th><th>إجراءات</th></tr>
          </thead>
          <tbody>
            {categories.map((c) => {
              const fl = c.filters ?? []
              const primary = fl.find((f) => f.is_primary)
              return (
                <tr key={c.id}>
                  <td>
                    <span className="cat-cell"><CatIcon icon={c.icon} size={17} /> <strong>{c.name}</strong></span>
                  </td>
                  <td>
                    {fl.length === 0
                      ? <span className="admin-warn">لا فلاتر — تُعرض الخدمات بلا تجميع</span>
                      : fl.map((f) => (
                        <span key={f.id} className={`fchip ${f.is_primary ? 'is-primary' : ''}`}>
                          {f.is_primary && '⭐'} {f.label}
                        </span>
                      ))}
                  </td>
                  <td>{primary ? primary.label : '—'}</td>
                  <td className="table-actions">
                    <button className="btn btn--sm btn--ghost" onClick={() => setAssignCat(c)}>
                      <Icon name="filter" size={14} /> تعديل الفلاتر
                    </button>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      <Modal open={showForm} onClose={() => { setShowForm(false); setEditFilter(null) }} title={editFilter ? `تعديل فلتر: ${editFilter.label}` : 'إضافة فلتر'}>
        <FilterForm
          key={editFilter ? `flt-${editFilter.id}` : `flt-new-${formNonce}`}
          filter={editFilter}
          sources={sources}
          onSaved={() => { setShowForm(false); setEditFilter(null); load(); toast('تم الحفظ') }}
        />
      </Modal>

      <Modal open={!!assignCat} onClose={() => setAssignCat(null)} title={assignCat ? `فلاتر قسم: ${assignCat.name}` : ''} wide>
        {assignCat && (
          <CategoryFiltersForm
            key={`assign-${assignCat.id}`}
            cat={assignCat}
            filters={items}
            onSaved={(msg) => { setAssignCat(null); toast(msg); refreshMeta() }}
          />
        )}
      </Modal>
    </>
  )
}

/** إنشاء/تعديل فلتر — الاسم + مصدر البيانات + الأيقونة */
function FilterForm({ filter, sources, onSaved }: { filter: Filter | null; sources: FilterSourceOption[]; onSaved: () => void }) {
  const [label, setLabel] = useState(filter?.label ?? '')
  const [sourceType, setSourceType] = useState<Filter['source_type']>(filter?.source_type ?? 'region')
  const [sourceKey, setSourceKey] = useState(filter?.source_key ?? '')
  const [icon, setIcon] = useState(filter?.icon ?? '')
  const [active, setActive] = useState(filter?.is_active ?? true)
  const [busy, setBusy] = useState(false)
  const toast = useToast()

  const fieldSources = sources.filter((s) => s.source_type === 'field')
  const needsField = sourceType === 'field'

  const save = async () => {
    if (!label.trim()) { toast('اسم الفلتر مطلوب', 'error'); return }
    if (needsField && !sourceKey) { toast('اختر الحقل الذي يبني عليه الفلتر', 'error'); return }
    setBusy(true)
    try {
      const payload = { label: label.trim(), source_type: sourceType, source_key: needsField ? sourceKey : '', icon, is_active: active }
      const r = filter ? await api.admin.updateFilter(filter.id, payload) : await api.admin.createFilter(payload)
      toast(r.message)
      onSaved()
    } catch (e) {
      toast(e instanceof Error ? e.message : 'تعذّر الحفظ', 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="form">
      <label className="field">
        <span className="field__label">اسم الفلتر (يظهر للزائر)</span>
        <input value={label} onChange={(e) => setLabel(e.target.value)} placeholder="مثال: المناطق · الاختصاص · نوع المركبة" />
      </label>

      <label className="field">
        <span className="field__label">مصدر البيانات</span>
        <select value={sourceType} onChange={(e) => { const v = e.target.value as Filter['source_type']; setSourceType(v); if (v !== 'field') setSourceKey('') }}>
          <option value="region">المناطق — من جدول المناطق</option>
          <option value="specialty">الاختصاص — من جدول الاختصاصات</option>
          <option value="field">حقل قائمة في الأقسام</option>
        </select>
        <span className="field__help">المصدر يحدّد قيم الفلتر التي تُجمَّع عليها الخدمات.</span>
      </label>

      {needsField && (
        <label className="field">
          <span className="field__label">الحقل</span>
          <select value={sourceKey} onChange={(e) => setSourceKey(e.target.value)}>
            <option value="">— اختر حقلاً —</option>
            {fieldSources.map((s) => (
              <option key={s.source_key} value={s.source_key}>{s.label} — {s.hint}</option>
            ))}
          </select>
          {fieldSources.length === 0 && (
            <span className="field__help admin-warn">
              لا حقول قائمة في أي قسم. أنشئ حقلاً من نوع «قائمة» في تبويب الأقسام أولاً.
            </span>
          )}
        </label>
      )}

      <div className="field">
        <span className="field__label">الأيقونة</span>
        <IconPicker value={icon} onChange={setIcon} columns={6} />
      </div>

      <label className="chk">
        <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
        <span>مُفعَّل</span>
      </label>

      <div className="form-actions">
        <button className="btn btn--primary" onClick={save} disabled={busy}>
          {busy ? 'يحفظ…' : 'حفظ'}
        </button>
      </div>
    </div>
  )
}

/**
 * إسناد فلاتر قسم.
 * كل فلاتر المكتبة تظهر بصفوف: ☑ مُسنَد · ◉ أساسي.
 * الأساسي واحد فقط — والخادم يضمن ذلك حتى لو أُرسل أكثر من واحد.
 */
function CategoryFiltersForm({ cat, filters, onSaved }: { cat: Category; filters: Filter[]; onSaved: (msg: string) => void }) {
  const assigned = new Map((cat.filters ?? []).map((f) => [f.filter_id, f.is_primary]))
  const [chosen, setChosen] = useState<Record<number, boolean>>(() => {
    const o: Record<number, boolean> = {}
    for (const f of filters) o[f.id] = assigned.has(f.id)
    return o
  })
  const [primaryId, setPrimaryId] = useState<number | null>(() => {
    const p = (cat.filters ?? []).find((f) => f.is_primary)
    return p ? p.filter_id : null
  })
  const [busy, setBusy] = useState(false)
  const toast = useToast()

  const toggle = (id: number, on: boolean) => {
    setChosen((c) => ({ ...c, [id]: on }))
    if (on) {
      // أول فلتر يُختار يصبح أساسياً تلقائياً — والقسم بلا أساسي يفقد بطاقاته
      setPrimaryId((p) => p ?? id)
    } else {
      setPrimaryId((p) => (p === id ? null : p))
    }
  }

  const save = async () => {
    const rows = filters
      .filter((f) => chosen[f.id])
      .map((f, i) => ({ filter_id: f.id, is_primary: f.id === primaryId, sort_order: i }))
    if (rows.length && !rows.some((r) => r.is_primary)) {
      rows[0].is_primary = true
    }
    setBusy(true)
    try {
      const r = await api.admin.setCategoryFilters(cat.id, rows)
      onSaved(r.message)
    } catch (e) {
      toast(e instanceof Error ? e.message : 'تعذّر الحفظ', 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="form">
      <p className="admin-note">
        الفلتر الأساسي (⭐) يبني بطاقات المستوى الأول في صفحة «{cat.name}».
        {chosen && Object.values(chosen).filter(Boolean).length > 1 && ' إسناد أكثر من فلتر يُضيف قائمة تصفية داخل شريط الصفحة.'}
      </p>

      <div className="admin-table-scroll">
      <table className="admin-table admin-table--pick">
        <thead><tr><th>إسناد</th><th>أساسي</th><th>الفلتر</th><th>المصدر</th></tr></thead>
        <tbody>
          {filters.map((f) => (
            <tr key={f.id} className={chosen[f.id] ? 'is-picked' : ''}>
              <td>
                <input type="checkbox" checked={!!chosen[f.id]} onChange={(e) => toggle(f.id, e.target.checked)} aria-label={`إسناد ${f.label}`} />
              </td>
              <td>
                <input
                  type="radio" name={`primary-${cat.id}`}
                  checked={primaryId === f.id}
                  disabled={!chosen[f.id]}
                  onChange={() => setPrimaryId(f.id)}
                  aria-label={`${f.label} أساسي`}
                />
              </td>
              <td><CatIcon icon={f.icon || 'filter'} size={16} /> <strong>{f.label}</strong></td>
              <td className="admin-sub">{f.source_type === 'field' ? `حقل: ${f.source_key}` : f.source_type}</td>
            </tr>
          ))}
        </tbody>
      </table>
      </div>

      <div className="form-actions">
        <button className="btn btn--primary" onClick={save} disabled={busy}>{busy ? 'يحفظ…' : 'حفظ الفلاتر'}</button>
      </div>
    </div>
  )
}

function GovernoratesTab() {
  const { refreshMeta } = useStore()
  const [items, setItems] = useState<Governorate[]>([])
  const [editGov, setEditGov] = useState<Governorate | null>(null)
  const [showAdd, setShowAdd] = useState(false)
  const [formNonce, setFormNonce] = useState(0)
  const toast = useToast()
  const load = () => api.admin.governorates().then((r) => setItems(r.items)).catch(() => {})
  useEffect(() => { load() }, [])

  const doDelete = async (g: Governorate) => {
    const n = g.services_count ?? 0
    if (!confirm(`حذف محافظة «${g.name}»؟${n ? `\nتحذير: ${n} خدمة مرتبطة بها.` : ''}`)) return
    try {
      await api.admin.deleteGovernorate(g.id, true)
      toast('تم حذف المحافظة')
      load(); refreshMeta()
    } catch (err: any) { toast(err.message, 'error') }
  }

  return (
    <>
      <div className="admin-toolbar">
        <button className="btn btn--primary btn--sm" onClick={() => { setEditGov(null); setFormNonce((n) => n + 1); setShowAdd(true) }}><Icon name="plus" size={14} /> إضافة محافظة</button>
      </div>
      {items.length === 0 ? (
        <div className="empty-state"><p>لا توجد محافظات</p></div>
      ) : (
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr><th>#</th><th>الاسم</th><th>الرمز</th><th>النطاق</th><th>الخدمات</th><th>الحالة</th><th></th></tr>
            </thead>
            <tbody>
              {items.map((g) => (
                <tr key={g.id} className={g.is_active ? '' : 'is-inactive'}>
                  <td>{g.id}</td>
                  <td><strong><Icon name="map" size={14} /> {g.name}</strong></td>
                  <td dir="ltr" className="text-muted">{g.slug}</td>
                  <td><span className={`badge badge--${g.zone === 'rural' ? 'duty' : 'open'}`}>{g.zone === 'rural' ? 'ريف' : 'مدينة'}</span></td>
                  <td>{num(g.services_count ?? 0)}</td>
                  <td>{g.is_active ? <span className="badge badge--open">فعّالة</span> : <span className="badge badge--closed">معطّلة</span>}</td>
                  <td className="row-actions">
                    <button className="iconbtn" onClick={() => { setEditGov(g); setShowAdd(true) }} title="تعديل"><Icon name="pencil" size={15} /></button>
                    <button className="iconbtn iconbtn--danger" onClick={() => doDelete(g)} title="حذف"><Icon name="trash-2" size={15} /></button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Modal open={showAdd} onClose={() => { setShowAdd(false); setEditGov(null) }} title={editGov ? `تعديل: ${editGov.name}` : 'إضافة محافظة'}>
        <GovernorateForm
          key={editGov ? `gov-${editGov.id}` : `gov-new-${formNonce}`}
          gov={editGov}
          onSaved={() => { setShowAdd(false); setEditGov(null); load(); refreshMeta() }}
        />
      </Modal>
    </>
  )
}

function GovernorateForm({ gov, onSaved }: { gov: Governorate | null; onSaved: () => void }) {
  const toast = useToast()
  const [busy, setBusy] = useState(false)
  const [name, setName] = useState(gov?.name ?? '')
  const [slug, setSlug] = useState(gov?.slug ?? '')
  const [zone, setZone] = useState<string>(gov?.zone ?? 'city')
  const [sortOrder, setSortOrder] = useState(gov?.sort_order ?? 0)
  const [isActive, setIsActive] = useState(gov?.is_active !== 0)

  const save = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim()) { toast('اسم المحافظة مطلوب', 'error'); return }
    setBusy(true)
    try {
      const payload = { name: name.trim(), slug, zone: zone as any, sort_order: sortOrder, is_active: isActive }
      if (gov) await api.admin.updateGovernorate(gov.id, payload)
      else await api.admin.createGovernorate(payload)
      onSaved()
    } catch (err: any) { toast(err.message, 'error') }
    setBusy(false)
  }

  return (
    <form onSubmit={save} className="admin-form">
      <label><span>الاسم *</span><input required value={name} onChange={(e) => setName(e.target.value)} placeholder="مثال: دمشق" /></label>
      <div className="form-grid">
        <label><span>الرمز (slug)</span><input value={slug} onChange={(e) => setSlug(e.target.value)} dir="ltr" placeholder="damascus" /></label>
        <label><span>النطاق</span>
          <select value={zone} onChange={(e) => setZone(e.target.value)}>
            <option value="city">مدينة</option>
            <option value="rural">ريف</option>
          </select>
        </label>
      </div>
      <div className="form-grid">
        <label><span>الترتيب</span><input type="number" value={sortOrder} onChange={(e) => setSortOrder(Number(e.target.value))} /></label>
        <label className="chk"><input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} /><span>فعّالة</span></label>
      </div>
      <button type="submit" className="btn btn--primary" disabled={busy}>{busy ? '…' : gov ? 'حفظ' : 'إضافة'}</button>
    </form>
  )
}

function RegionsTab() {
  const [items, setItems] = useState<Region[]>([])
  const [showAdd, setShowAdd] = useState(false)
  const [editReg, setEditReg] = useState<Region | null>(null)
  const [formNonce, setFormNonce] = useState(0)
  const [zone, setZone] = useState('')
  const toast = useToast()
  const load = () => api.admin.regions(zone || undefined).then((r) => setItems(r.items)).catch(() => {})
  useEffect(() => { load() }, [zone])

  const doDelete = async (id: number) => {
    if (!confirm('حذف المنطقة؟')) return
    await api.admin.deleteRegion(id); toast('تم الحذف'); load()
  }

  return (
    <>
      <div className="admin-toolbar">
        <select value={zone} onChange={(e) => setZone(e.target.value)}><option value="">كل المناطق</option><option value="city">المدينة</option><option value="rural">الريف</option></select>
        <button className="btn btn--primary btn--sm" onClick={() => { setEditReg(null); setFormNonce((n) => n + 1); setShowAdd(true) }}><Icon name="plus" size={14} /> إضافة منطقة</button>
      </div>
      <div className="admin-table-wrap">
        <table className="admin-table">
          <thead><tr><th>#</th><th>الاسم</th><th>المحافظة</th><th>المدينة الأم</th><th>المستوى</th><th>خدمات</th><th>إجراءات</th></tr></thead>
          <tbody>
            {items.map((r) => (
              <tr key={r.id}>
                <td>{r.id}</td>
                <td><strong>{r.name}</strong></td>
                <td>{r.governorate_name ?? <span className="admin-warn">غير مرتبطة</span>}</td>
                <td>{r.parent_name ?? '—'}</td>
                <td><span className={`badge badge--${r.level === 'village' ? 'village' : r.zone}`}>{r.level === 'village' ? 'قرية' : r.zone === 'city' ? 'مدينة' : 'ريف'}</span></td>
                <td>{r.services_count ?? '—'}</td>
                <td className="table-actions">
                  <button className="iconbtn" onClick={() => { setEditReg(r); setShowAdd(true) }}><Icon name="pencil" size={15} /></button>
                  <button className="iconbtn iconbtn--danger" onClick={() => doDelete(r.id)}><Icon name="trash-2" size={15} /></button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <Modal open={showAdd} onClose={() => { setShowAdd(false); setEditReg(null) }} title={editReg ? `تعديل: ${editReg.name}` : 'إضافة منطقة'}>
        <RegionForm
          key={editReg ? `reg-${editReg.id}` : `reg-new-${formNonce}`}
          reg={editReg}
          onSaved={() => { setShowAdd(false); setEditReg(null); load(); toast('تم الحفظ') }}
        />
      </Modal>
    </>
  )
}

function RegionForm({ reg, onSaved }: { reg: Region | null; onSaved: () => void }) {
  const [name, setName] = useState(reg?.name ?? '')
  const [zone, setZone] = useState<Zone>(reg?.zone ?? 'city')
  const [govId, setGovId] = useState<number | null>(reg?.governorate_id ?? null)
  const [parentId, setParentId] = useState<number | null>(reg?.parent_id ?? null)
  const [busy, setBusy] = useState(false)
  const [err, setErr] = useState('')
  const toast = useToast()

  // كل المناطق (لحساب المدن التابعة للمحافظة المختارة)
  const [allRegions, setAllRegions] = useState<Region[]>([])
  const { governorates } = useStore()
  useEffect(() => { api.admin.regions().then((r) => setAllRegions(r.items)).catch(() => {}) }, [])

  /** المدن فقط (level=city) التابعة للمحافظة المختارة */
  const cities = useMemo(
    () => allRegions.filter((r) => r.level === 'city' && (govId == null || r.governorate_id === govId)),
    [allRegions, govId]
  )

  /** اختيار مدينة يعني أن هذه المنطقة «قرية» تابعة لها — وتَرث محافظتها تلقائياً */
  const pickCity = (id: string) => {
    const pid = id ? Number(id) : null
    setParentId(pid)
    if (pid) {
      const city = allRegions.find((r) => r.id === pid)
      if (city?.governorate_id) setGovId(city.governorate_id)
    }
  }

  const isVillage = parentId != null

  const save = async (e: React.FormEvent) => {
    e.preventDefault()
    setErr('')

    if (!name.trim()) { setErr('اسم المنطقة مطلوب'); return }
    if (!govId) { setErr('يجب اختيار المحافظة'); return }

    setBusy(true)
    try {
      const payload: Record<string, any> = {
        name: name.trim(),
        zone,
        governorate_id: govId,
        parent_id: parentId,       // null = مدينة، رقم = قرية تابعة لتلك المدينة
        sort_order: reg?.sort_order ?? 0,
        is_active: reg ? (reg.is_active ?? 1) : 1,
      }
      if (reg) await api.admin.updateRegion(reg.id, payload)
      else await api.admin.createRegion(payload)
      onSaved()
    } catch (e: any) {
      // أظهر الخطأ للمستخدم بدل ابتلاعه بصمت
      const msg = e?.message || 'تعذّر حفظ المنطقة'
      setErr(msg)
      toast(msg, 'error')
    }
    setBusy(false)
  }

  return (
    <form onSubmit={save} className="admin-form">
      <label>
        <span>الاسم *</span>
        <input required value={name} onChange={(e) => setName(e.target.value)} placeholder="مثال: الباب" />
      </label>

      <label>
        <span>المحافظة *</span>
        <select
          required
          value={govId ?? ''}
          onChange={(e) => {
            setGovId(e.target.value ? Number(e.target.value) : null)
            // تغيير المحافظة يُصفّي المدينة المختارة إن لم تعد تابعة لها
            setParentId(null)
          }}
        >
          <option value="">— اختر المحافظة —</option>
          {governorates.map((g) => (
            <option key={g.id} value={g.id}>{g.name}</option>
          ))}
        </select>
        <em className="admin-form__hint">اختيار المحافظة إلزامي لربط المنطقة بالشجرة</em>
      </label>

      <label>
        <span>المدينة التابعة لها</span>
        <select
          value={parentId ?? ''}
          onChange={(e) => pickCity(e.target.value)}
          disabled={!govId}
        >
          <option value="">— لا شيء (هذه منطقة رئيسية / مدينة) —</option>
          {cities.map((c) => (
            <option key={c.id} value={c.id}>{c.name}</option>
          ))}
        </select>
        <em className="admin-form__hint">
          {isVillage ? 'ستُسجَّل كـ«قرية» تابعة للمدينة المختارة' : 'اتركها فارغة لتكون «مدينة»'}
        </em>
      </label>

      <label>
        <span>النطاق</span>
        <select value={zone} onChange={(e) => setZone(e.target.value as Zone)}>
          <option value="city">مدينة</option>
          <option value="rural">ريف</option>
        </select>
      </label>

      {err && <p className="admin-form__err" role="alert">{err}</p>}

      <button type="submit" className="btn btn--primary" disabled={busy}>
        {busy ? '…' : 'حفظ'}
      </button>
    </form>
  )
}

function RequestsTab() {
  const [items, setItems] = useState<ServiceRequest[]>([])
  const [filter, setFilter] = useState('')

  const toast = useToast()
  const load = () => api.admin.requests(filter || undefined).then((r) => setItems(r.items)).catch(() => {})
  useEffect(() => { load() }, [filter])

  const doApprove = async (id: number) => {
    try {
      await api.admin.approveRequest(id, {})
      load()
    } catch (err: any) { toast(err.message, 'error') }
  }

  const doReject = async (id: number) => {
    const note = prompt('سبب الرفض (اختياري):') ?? ''
    await api.admin.rejectRequest(id, note)
    load()
  }

  /**
   * حذف الطلب.
   * ⚠️ الطلب الموافَق عليه أنشأ خدمة فعلية، وحذف الطلب **لا يحذفها**.
   * لذلك نُصرّح بذلك في التأكيد مع رقم الخدمة، وإلا ظنّ المدير أنه أزال
   * الطلب فبقيت الخدمة منشورة بلا أن يدري.
   */
  const doDelete = async (r: ServiceRequest) => {
    const linked = r.status === 'approved' && r.created_service_id
    const msg = linked
      ? `حذف الطلب «${r.name}»؟\n\n⚠️ الخدمة المنشأة منه (#${r.created_service_id}) لن تُحذف وستبقى ظاهرة للمستخدمين.\nاحذفها من تبويب «الخدمات» إن أردت.\n\nلا يمكن التراجع.`
      : `حذف الطلب «${r.name}»؟\n\nلا يمكن التراجع.`
    if (!confirm(msg)) return
    try {
      const res = await api.admin.deleteRequest(r.id)
      toast(res.message || 'تم حذف الطلب')
      load()
    } catch (err: any) {
      toast(err?.message || 'تعذّر حذف الطلب', 'error')
    }
  }

  return (
    <>
      <div className="admin-toolbar">
        <select value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="">الكل</option>
          <option value="pending">معلّق</option>
          <option value="approved">موافق</option>
          <option value="rejected">مرفوض</option>
        </select>
      </div>
      {items.length === 0 ? <div className="empty-state"><p>لا توجد طلبات</p></div> : (
        <div className="req-list">
          {items.map((r) => (
            <div key={r.id} className={`req-item req-item--${r.status}`}>
              <div>
                <h4><CatIcon icon={r.category_icon ?? 'map-pin'} size={16} /> {r.name}</h4>
                <p>{r.address || '—'} {r.phone && `· ${r.phone}`}</p>
                {r.user_name && <p className="text-muted">بواسطة: {r.user_name} ({r.user_phone})</p>}
                {r.want_to_manage ? <span className="badge badge--duty">يُريد الإدارة</span> : null}
                <span className={`req-status req-status--${r.status}`}>
                  <Icon name={r.status === 'pending' ? 'clock' : r.status === 'approved' ? 'circle-check-big' : 'circle-x'} size={13} />
                  {r.status === 'pending' ? ' معلّق' : r.status === 'approved' ? ' موافق' : ' مرفوض'}
                </span>
                {r.admin_note && <p className="req-note"><Icon name="pencil" size={13} /> {r.admin_note}</p>}
                {/* الخدمة المنشأة من الطلب — رابط مباشر ليتسنّى حذفها/تعديلها */}
                {r.created_service_id ? (
                  <Link to={`/s/${r.created_service_id}`} className="req-link">
                    <Icon name="boxes" size={13} /> الخدمة المنشأة #{r.created_service_id}
                  </Link>
                ) : null}
              </div>
              <div className="req-actions">
                {r.status === 'pending' && (
                  <>
                    <button className="btn btn--sm btn--success" onClick={() => doApprove(r.id)}><Icon name="check" size={13} /> موافقة</button>
                    <button className="btn btn--sm btn--danger" onClick={() => doReject(r.id)}><Icon name="circle-x" size={13} /> رفض</button>
                  </>
                )}
                {/* الحذف متاح لكل الحالات — الطلبات المرفوضة والقديمة تحتاج تنظيفاً */}
                <button className="iconbtn iconbtn--danger" onClick={() => doDelete(r)} title="حذف الطلب" aria-label={`حذف الطلب ${r.name}`}>
                  <Icon name="trash-2" size={15} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}

function UsersTab() {
  const [items, setItems] = useState<User[]>([])
  const [q, setQ] = useState('')
  const [editUser, setEditUser] = useState<User | null>(null)
  const [formNonce, setFormNonce] = useState(0)
  const toast = useToast()
  const load = () => api.admin.users({ q }).then((r) => setItems(r.items)).catch(() => {})
  useEffect(() => { load() }, [q])

  const toggleRole = async (u: User) => {
    await api.admin.updateUser(u.id, { role: u.role === 'admin' ? 'user' : 'admin' })
    toast(`تم تغيير دور ${u.full_name}`)
    load()
  }

  const toggleActive = async (u: User) => {
    await api.admin.updateUser(u.id, { is_active: u.is_active ? 0 : 1 })
    toast(u.is_active ? 'تم التعطيل' : 'تم التفعيل')
    load()
  }

  const removeUser = async (u: User) => {
    const n = u.services_count ?? 0
    if (!confirm(`حذف المستخدم «${u.full_name || u.phone}»؟${n ? `\nتحذير: ${n} خدمة مملوكة له ستفصل عنه (لن تُحذف).` : ''}\nلا يمكن التراجع.`)) return
    try {
      const r = await api.admin.deleteUser(u.id)
      toast(r.message || 'تم الحذف')
      load()
    } catch (e: any) {
      toast(e?.message || 'تعذّر الحذف')
    }
  }

  return (
    <>
      <div className="admin-toolbar">
        <div className="search-input"><Icon name="search" size={16} /><input placeholder="بحث بالاسم أو الهاتف…" value={q} onChange={(e) => setQ(e.target.value)} /></div>
      </div>
      <div className="admin-table-wrap">
        <table className="admin-table">
          <thead><tr><th>#</th><th>الاسم</th><th>الهاتف</th><th>الدور</th><th>خدمات</th><th>تاريخ الانضمام</th><th>إجراءات</th></tr></thead>
          <tbody>
            {items.map((u) => (
              <tr key={u.id} className={!u.is_active ? 'is-inactive' : ''}>
                <td>{u.id}</td>
                <td>{u.full_name || '—'}</td>
                <td dir="ltr">{u.phone_intl}</td>
                <td><span className={`badge badge--${u.role}`}>{u.role === 'admin' ? 'مدير' : 'مستخدم'}</span></td>
                <td>{u.services_count ?? 0}</td>
                <td>{fmtDate(u.created_at)}</td>
                <td className="table-actions">
                  <button className="iconbtn" onClick={() => { setEditUser(u); setFormNonce((n) => n + 1) }} title="تعديل"><Icon name="pencil" size={15} /></button>
                  <button className="iconbtn" onClick={() => toggleRole(u)} title="تبديل الدور"><Icon name={u.role === 'admin' ? 'shield-check' : 'user-round'} size={15} /></button>
                  <button className={`iconbtn ${u.is_active ? 'iconbtn--danger' : ''}`} onClick={() => toggleActive(u)} title={u.is_active ? 'تعطيل' : 'تفعيل'}><Icon name={u.is_active ? 'lock' : 'unlock'} size={15} /></button>
                  <button className="iconbtn iconbtn--danger" onClick={() => removeUser(u)} title="حذف المستخدم"><Icon name="trash-2" size={15} /></button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <Modal open={!!editUser} onClose={() => setEditUser(null)} title={`تعديل المستخدم: ${editUser?.full_name || editUser?.phone || ''}`}>
        <UserEditForm
          key={editUser ? `user-${editUser.id}-${formNonce}` : 'user-none'}
          u={editUser}
          onSaved={() => { setEditUser(null); load() }}
        />
      </Modal>
    </>
  )
}

/** نموذج تعديل مستخدم: الاسم، الهاتف، الدور، التفعيل، وكلمة مرور جديدة اختيارية */
function UserEditForm({ u, onSaved }: { u: User | null; onSaved: () => void }) {
  const toast = useToast()
  const [busy, setBusy] = useState(false)
  const [fullName, setFullName] = useState(u?.full_name ?? '')
  const [phone, setPhone] = useState(u?.phone ?? '')
  const [role, setRole] = useState<'admin' | 'user'>(u?.role ?? 'user')
  const [active, setActive] = useState(!!u?.is_active)
  const [password, setPassword] = useState('')

  if (!u) return null

  const save = async (e: React.FormEvent) => {
    e.preventDefault()
    setBusy(true)
    try {
      const payload: Record<string, any> = {
        full_name: fullName,
        phone,
        role,
        is_active: active ? 1 : 0,
      }
      if (password.trim() !== '') payload.reset_password = password.trim()
      const r = await api.admin.updateUser(u.id, payload)
      toast(r.message || 'تم الحفظ')
      onSaved()
    } catch (e: any) {
      toast(e?.message || 'تعذّر الحفظ')
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={save} className="admin-form">
      <label><span>الاسم الكامل</span><input required value={fullName} onChange={(e) => setFullName(e.target.value)} /></label>
      <label><span>رقم الهاتف *</span><input required dir="ltr" inputMode="tel" placeholder="0991234567" value={phone} onChange={(e) => setPhone(e.target.value)} /></label>
      <div className="form-grid">
        <label><span>الدور</span>
          <select value={role} onChange={(e) => setRole(e.target.value as 'admin' | 'user')}>
            <option value="user">مستخدم</option>
            <option value="admin">مدير</option>
          </select>
        </label>
        <label className="chk" style={{ alignSelf: 'end', paddingBottom: 10 }}>
          <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
          <span>الحساب مفعّل</span>
        </label>
      </div>
      <label><span>كلمة مرور جديدة</span>
        <input type="password" dir="ltr" placeholder="اتركها فارغة للإبقاء على الحالية" minLength={6} value={password} onChange={(e) => setPassword(e.target.value)} />
      </label>
      <button className="btn btn--primary" disabled={busy} type="submit">{busy ? 'جاري الحفظ…' : 'حفظ التغييرات'}</button>
    </form>
  )
}

/**
 * تبويب «تحديث التطبيق»
 * ============================================================
 * المدير هنا:
 *   ١. يرفع ملف APK  → يقرأ الخادم الإصدار من داخل الملف وينشره
 *   ٢. أو يضع الملف في مجلد apk/ ويضغط «فحص المجلد»
 *   ٣. أو يلصق رابطاً خارجياً (GitHub / Drive)
 * فتعرض تطبيقات أندرويد بطاقة التحديث في تبويب «حسابي».
 */
function AppUpdateTab() {
  const toast = useToast()
  const [info, setInfo] = useState<AppUpdateInfo | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)

  const [versionName, setVersionName] = useState('')
  const [versionCode, setVersionCode] = useState('')
  const [notes, setNotes] = useState('')
  const [force, setForce] = useState(false)
  const [url, setUrl] = useState('')
  const [path, setPath] = useState('')

  const [file, setFile] = useState<File | null>(null)
  const [percent, setPercent] = useState(0)
  const [uploading, setUploading] = useState(false)

  const load = useCallback(async () => {
    try {
      const r = await api.admin.appUpdate()
      setInfo(r.update)
      setVersionName(r.update.version_name)
      setVersionCode(String(r.update.version_code || ''))
      setNotes(r.update.notes)
      setForce(!!r.update.force)
      setUrl(r.update.url ?? '')
      setPath(r.update.path_status?.path ?? '')
    } catch {
      toast('تعذّر تحميل حالة التحديث', 'error')
    }
    setLoading(false)
  }, [toast])

  useEffect(() => { load() }, [load])

  const applyResult = (u: AppUpdateInfo) => {
    setInfo(u)
    setVersionName(u.version_name)
    setVersionCode(String(u.version_code || ''))
    setNotes(u.notes)
    setForce(!!u.force)
    setUrl(u.url ?? '')
    if (u.path_status) setPath(u.path_status.path)
  }

  const save = async (e: React.FormEvent) => {
    e.preventDefault(); setBusy(true)
    try {
      const r = await api.admin.saveAppUpdate({
        version_name: versionName,
        version_code: Number(versionCode) || 0,
        notes, force, url, path,
      })
      applyResult(r.update)
      toast(r.message)
      // تحذير الخادم: الرقم الذي أدخلته يخالف الرقم داخل الملف
      if (r.warning) toast(r.warning, 'error')
    } catch (err: any) { toast(err?.message || 'فشل الحفظ', 'error') }
    setBusy(false)
  }

  const upload = async () => {
    if (!file) return
    setUploading(true); setPercent(0)
    try {
      const r = await api.admin.uploadAppApk(file, (p) => setPercent(p))
      applyResult(r.update)
      setFile(null)
      toast(r.message + (r.detected ? ' ✅' : ' ⚠️'))
    } catch (err: any) { toast(err?.message || 'فشل الرفع', 'error') }
    setUploading(false)
  }

  const scan = async (name?: string) => {
    setBusy(true)
    try {
      const r = await api.admin.scanAppUpdate(name ? { file: name } : { force: true })
      applyResult(r.update)
      toast(r.message)
    } catch (err: any) { toast(err?.message || 'تعذّر الفحص', 'error') }
    setBusy(false)
  }

  const removeApk = async () => {
    if (!confirm('حذف الملف المنشور؟ لن يظهر أي تحديث للتطبيقات بعد ذلك.')) return
    setBusy(true)
    try {
      const r = await api.admin.deleteAppApk()
      applyResult(r.update)
      toast(r.message)
    } catch (err: any) { toast(err?.message || 'فشل الحذف', 'error') }
    setBusy(false)
  }

  if (loading) return <div className="empty-state"><p>جارٍ التحميل…</p></div>
  if (!info) return <div className="empty-state"><p>تعذّر تحميل البيانات</p></div>

  // حالة المسار: من الخادم بعد الحفظ، ومقارنة فورية لما يكتبه المدير الآن
  const pathStatus: AppUpdatePathStatus | undefined = info.path_status
  const pathEdited = path.trim() !== (pathStatus?.path ?? '')
  const fileMatchesPath = !!info.apks_in_dir?.some((f) => `apk/${f.name}` === path.trim().replace(/^\//, ''))

  const limit = info.upload_limit ?? 0
  const fileTooBig = !!file && limit > 0 && file.size > limit
  const published = info.has_file || (url !== '') || (info.version_code > 0)

  return (
    <div className="appup">
      {/* ─── الحالة الحالية ─── */}
      <div className={`appup__status${published ? ' is-live' : ''}`}>
        <div className="appup__status-head">
          <span className="appup__badge"><Icon name="package" size={16} /></span>
          <div>
            <strong>{published ? `الإصدار المنشور ${info.version_name || '—'}` : 'لا يوجد تحديث منشور'}</strong>
            <p className="appup__sub">
              {published
                ? `كود البناء ${info.version_code} · ${info.file_size_h || '—'} · ${info.has_file ? info.apk_file : 'رابط خارجي'}`
                : 'التطبيقات المثبَّتة لن تعرض أي تنبيه تحديث.'}
            </p>
          </div>
          {info.force && <span className="appup__pill appup__pill--force">إلزامي</span>}
          {published && !info.force && <span className="appup__pill">اختياري</span>}
        </div>

        {info.published_at && (
          <p className="appup__sub">نُشر: {fmtDateTime(info.published_at)}</p>
        )}
        {info.sha256 && (
          <p className="appup__sha" dir="ltr">SHA-256: {info.sha256.slice(0, 16)}…</p>
        )}
        {info.download_url && (
          <a className="appup__link" href={info.download_url} target="_blank" rel="noreferrer" dir="ltr">
            {info.download_url}
          </a>
        )}

        {(info.dir_writable === false || !info.has_file) && (
          <p className="appup__note">
            <Icon name="info" size={14} /> ضع الملف في مجلد <code dir="ltr">{info.dir}</code> عبر FTP
            ثم اضغط «فحص المجلد» — أو ارفعه من هنا مباشرةً.
          </p>
        )}
      </div>

      {/* ─── رفع الملف ─── */}
      <section className="admin-form__section appup__box">
        <h4><Icon name="upload" size={16} /> رفع ملف APK</h4>
        <input
          type="file"
          accept=".apk,application/vnd.android.package-archive"
          onChange={(e) => { setFile(e.target.files?.[0] ?? null); setPercent(0) }}
        />
        <p className="admin-form__hint">
          الحد الأقصى للرفع على الخادم: <strong>{info.upload_limit_h || '—'}</strong>
          {' '}(<code dir="ltr">upload_max_filesize={info.max_upload} · post_max_size={info.post_max}</code>).
          إن كان ملفك أكبر، ارفعه بـ FTP إلى مجلد <code dir="ltr">{info.dir}</code> ثم اضغط «فحص المجلد».
        </p>

        {file && (
          <p className="appup__file">
            <Icon name="package" size={14} /> {file.name}
            <span className="appup__sub"> {(file.size / 1048576).toFixed(2)} ميغا</span>
          </p>
        )}

        {fileTooBig && (
          <p className="admin-form__err">
            الملف أكبر من حدّ الرفع ({info.upload_limit_h}) — استعمل FTP ثم «فحص المجلد».
          </p>
        )}

        {uploading && (
          <div className="appup__progress">
            <div className="appup__bar"><span style={{ width: `${percent}%` }} /></div>
            <span className="appup__pct">{percent}%</span>
          </div>
        )}

        <div className="appup__actions">
          <button type="button" className="btn btn--primary" disabled={!file || uploading || fileTooBig} onClick={upload}>
            <Icon name="upload" size={15} /> {uploading ? 'جارٍ الرفع…' : 'رفع ونشر'}
          </button>
          <button type="button" className="btn btn--secondary" disabled={busy || uploading} onClick={() => scan()}>
            <Icon name="refresh-cw" size={15} /> فحص مجلد <span dir="ltr">{info.dir}</span>
          </button>
          {info.has_file && (
            <button type="button" className="btn btn--danger" disabled={busy || uploading} onClick={removeApk}>
              <Icon name="trash-2" size={15} /> حذف الملف المنشور
            </button>
          )}
        </div>

        {!!info.apks_in_dir?.length && (
          <div className="appup__files">
            <p className="appup__sub">ملفات موجودة في المجلد ({info.apks_in_dir.length}):</p>
            <ul>
              {info.apks_in_dir.map((f) => (
                <li key={f.name}>
                  <code dir="ltr">{f.name}</code>
                  <span className="appup__sub"> {f.size_h} · {fmtDate(f.modified)}</span>
                  {f.current
                    ? <span className="appup__pill">المنشور</span>
                    : <button type="button" className="btn btn--sm btn--outline" disabled={busy} onClick={() => scan(f.name)}>اربط هذا</button>}
                </li>
              ))}
            </ul>
          </div>
        )}
      </section>

      {/* ─── بيانات الإصدار ─── */}
      <form className="admin-form" onSubmit={save}>
        <div className="admin-form__section">
          <h4><Icon name="info" size={16} /> بيانات التحديث</h4>

          {/* ═══ مسار الملف — المصدر الذي يُنزَّل منه ═══ */}
          <label><span>مسار الملف</span>
            <input
              value={path}
              onChange={(e) => setPath(e.target.value)}
              dir="ltr"
              placeholder="apk/dalel-1.2.0.apk — أو https://…/app.apk"
            />
          </label>
          <div className={`appup__path${pathStatus?.found && !pathEdited ? ' is-ok' : pathStatus ? ' is-bad' : ''}`}>
            <Icon name={pathStatus?.found && !pathEdited ? 'check' : 'info'} size={14} />
            <div>
              <strong>
                {pathEdited
                  ? (fileMatchesPath
                    ? 'الملف موجود في مجلد apk/ — اضغط «حفظ بيانات التحديث» لتثبيت المسار'
                    : 'لم يُحفظ هذا المسار بعد — اضغط «حفظ بيانات التحديث»')
                  : (pathStatus?.message ?? 'جارٍ التحقق…')}
              </strong>
              {pathStatus?.found && pathStatus.kind !== 'url' && (
                <span className="appup__sub">
                  {' '}· {pathStatus.size_h || ''}
                  {pathStatus.meta?.versionName ? ` · الإصدار داخل الملف: ${pathStatus.meta.versionName} (${pathStatus.meta.versionCode})` : ''}
                </span>
              )}
              {pathStatus?.web_path && (
                <span className="appup__sub"> · رابط التنزيل: <code dir="ltr">{pathStatus.web_path}</code></span>
              )}
            </div>
          </div>
          <p className="admin-form__hint">
            اكتب مسار الملف على موقعك (يُقرأ الإصدار من داخله تلقائياً)، أو رابطاً كاملاً
            يبدأ بـ <code dir="ltr">https://</code>. مثال: <code dir="ltr">apk/dalel-1.2.0.apk</code>
            {' '}— أو استعمل الرفع/الفحص أسفله فيُملأ هذا الحقل تلقائياً.
          </p>

          <label><span>الإصدار (versionName)</span>
            <input value={versionName} onChange={(e) => setVersionName(e.target.value)} dir="ltr" placeholder="1.2.0" />
          </label>

          <label><span>رقم البناء (versionCode)</span>
            <input value={versionCode} onChange={(e) => setVersionCode(e.target.value)} dir="ltr" inputMode="numeric" placeholder="3" />
          </label>

          <p className="admin-form__hint">
            يُقرأ رقمان تلقائياً من داخل ملف APK عند رفعه. التطبيق يقارن رقم البناء بمثبَّته،
            فإن كان رقمك أكبر ظهر التنبيه. <strong>كبّر الرقم في كل إصدار</strong> (1 ← 2 ← 3).
          </p>
          {pathStatus?.meta?.versionCode && Number(versionCode) > 0
            && pathStatus.meta.versionCode !== Number(versionCode) && (
            <p className="admin-form__err">
              تنبيه: رقم البناء داخل الملف هو {pathStatus.meta.versionCode}، والذي أدخلته {versionCode}.
              التطبيقات تقارن برقمك — تأكد أنه الأكبر.
            </p>
          )}

          <label><span>ما الجديد في هذا الإصدار؟</span>
            <textarea
              rows={5}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder={'• إصلاح مشكلة الفلاتر\n• سرعة أعلى في التحميل'}
            />
          </label>
          <p className="admin-form__hint">تظهر هذه النقاط للمستخدم داخل بطاقة التحديث في تبويب «حسابي».</p>

          <label><span>رابط تحميل خارجي (اختياري)</span>
            <input value={url} onChange={(e) => setUrl(e.target.value)} dir="ltr" placeholder="https://github.com/…/app.apk" />
          </label>
          <p className="admin-form__hint">
            إن وُضع، يُنزِّل التطبيق من هذا الرابط بدل ملف الخادم — مفيد إن كان ملفك على GitHub أو Drive.
          </p>

          <label className="appup__check">
            <input type="checkbox" checked={force} onChange={(e) => setForce(e.target.checked)} />
            <span>تحديث إلزامي — لا يعمل التطبيق قبل التحديث</span>
          </label>
          <p className="admin-form__hint">
            استعمله عند إصلاح عطل خطير فقط؛ الإلزامي يُغلق التطبيق القديم على كل مستخدميه.
          </p>

          <button className="btn btn--primary" disabled={busy} type="submit">
            {busy ? 'جارٍ الحفظ…' : 'حفظ بيانات التحديث'}
          </button>
        </div>
      </form>
    </div>
  )
}

function SettingsTab() {
  const { settings, refreshMeta } = useStore()
  const toast = useToast()
  const [siteName, setSiteName] = useState(settings.site_name)
  // «العبارة» أُلغيت نهائياً — حلّ محلّها شريط الإعلانات في أعلى الصفحة الرئيسية
  const [city, setCity] = useState(settings.city)
  const [waAdmin, setWaAdmin] = useState(settings.whatsapp_admin)
  const [adInterval, setAdInterval] = useState(settings.ad_interval || 5)
  const [announcements, setAnnouncements] = useState(settings.announcements)
  const [busy, setBusy] = useState(false)

  const save = async (e: React.FormEvent) => {
    e.preventDefault(); setBusy(true)
    try {
      await api.admin.saveSettings({ site_name: siteName, city, whatsapp_admin: waAdmin, ad_interval: adInterval, announcements })
      await refreshMeta()
      toast('تم حفظ الإعدادات')
    } catch { toast('فشل الحفظ', 'error') }
    setBusy(false)
  }

  return (
    <form onSubmit={save} className="admin-form">
      <label><span>اسم الموقع</span><input value={siteName} onChange={(e) => setSiteName(e.target.value)} /></label>
      <label><span>المحافظة</span><input value={city} onChange={(e) => setCity(e.target.value)} placeholder="اتركه فارغاً ليعمل التطبيق لكل المحافظات" /></label>
      <p className="admin-form__hint">
        يُستخدم اسم المحافظة في تسميات النطاق (مدينة… / ريف…). اتركه فارغاً لتبقى التسميات عامة.
      </p>
      <label><span>واتساب المدير</span><input value={waAdmin} onChange={(e) => setWaAdmin(e.target.value)} dir="ltr" /></label>

      <div className="admin-form__section">
        <h4><Icon name="circle-check-big" size={16} /> الإعلانات</h4>
        <p className="admin-form__hint">
          تظهر هذه الإعلانات في شريط دوّار أعلى الصفحة الرئيسية فقط.
        </p>

        <label className="adint">
          <span>زمن التبديل بين الإعلانات</span>
          <div className="adint__row">
            <input
              type="range" min={1} max={30} step={1}
              value={adInterval} onChange={(e) => setAdInterval(Number(e.target.value))}
            />
            <input
              className="adint__num" type="number" min={1} max={60}
              value={adInterval} onChange={(e) => {
                const v = Number(e.target.value)
                setAdInterval(Number.isFinite(v) && v >= 1 && v <= 60 ? v : 5)
              }}
            />
            <span className="adint__unit">ثانية</span>
          </div>
        </label>

        {announcements.map((a, i) => (
          <div key={i} className="ann-row">
            <select value={a.tone} onChange={(e) => {
              const next = [...announcements]; next[i] = { ...next[i], tone: e.target.value as any }; setAnnouncements(next)
            }}>
              <option value="info">معلومة</option>
              <option value="success">جديد</option>
              <option value="warning">تحذير</option>
              <option value="danger">عاجل</option>
            </select>
            <div className="ann-row__fields">
              <input
                placeholder="عنوان (اختياري)"
                value={a.title || ''}
                onChange={(e) => { const next = [...announcements]; next[i] = { ...next[i], title: e.target.value }; setAnnouncements(next) }}
              />
              <input
                placeholder="نص الإعلان"
                value={a.text}
                onChange={(e) => { const next = [...announcements]; next[i] = { ...next[i], text: e.target.value }; setAnnouncements(next) }}
              />
              <input
                className="ann-row__link" dir="ltr" placeholder="رابط (اختياري) https://…"
                value={a.link || ''}
                onChange={(e) => { const next = [...announcements]; next[i] = { ...next[i], link: e.target.value }; setAnnouncements(next) }}
              />
            </div>
            <button type="button" className="iconbtn iconbtn--danger" onClick={() => setAnnouncements(announcements.filter((_, j) => j !== i))}><Icon name="circle-x" size={14} /></button>
          </div>
        ))}
        <button type="button" className="qbtn qbtn--sm" onClick={() => setAnnouncements([...announcements, { text: '', tone: 'info' as const }])}><Icon name="plus" size={13} /> إضافة إعلان</button>
      </div>

      <button type="submit" className="btn btn--primary" disabled={busy}>{busy ? '…' : 'حفظ الإعدادات'}</button>

      {/* منطقة الخطر: تفريغ بيانات قاعدة البيانات */}
      <DangerZone />
    </form>
  )
}

/** أيقونة كل نوع نشاط في سجل العمليات */
const ACTIVITY_ICONS: Record<string, string> = {
  create: 'plus',
  update: 'pencil',
  delete: 'trash-2',
  approve: 'circle-check-big',
  reject: 'circle-x',
  login: 'log-out',
  logout: 'log-out',
  toggle: 'arrow-right-left',
  status: 'circle-check-big',
}

function ActivityTab() {
  const [items, setItems] = useState<ActivityItem[]>([])
  useEffect(() => { api.admin.activity().then((r) => setItems(r.items)).catch(() => {}) }, [])

  return (
    <div className="activity-list">
      {items.length === 0 ? <div className="empty-state"><p>لا يوجد نشاط</p></div> : (
        <ul className="activity-items">
          {items.map((a, i) => (
            <li key={i} className={`activity-item activity-item--${a.action}`}>
              <span className="activity-item__icon"><Icon name={ACTIVITY_ICONS[a.action] ?? 'activity'} size={15} /></span>
              <span className="activity-item__time">{fmtDateTime(a.created_at)}</span>
              <span className="activity-item__user">{a.user_name ?? 'النظام'}</span>
              <span className="activity-item__msg">{a.message || `${a.action} ${a.entity}`}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

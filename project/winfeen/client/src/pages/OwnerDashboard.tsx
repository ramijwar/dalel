import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useStore } from '../lib/store'
import { api } from '../lib/api'
import type { Service, ScheduleRow, ServiceRequest } from '../lib/types'
import { useToast } from '../lib/useToast'
import Icon from '../components/Icon'
import IconPicker from '../components/IconPicker'
import LocationPicker from '../components/LocationPicker'
import CatIcon from '../components/CatIcon'
import StatusToggle from '../components/StatusToggle'
import ScheduleEditor from '../components/ScheduleEditor'
import Modal from '../components/Modal'

type Sub = 'services' | 'requests' | 'activity'

export default function OwnerDashboard() {
  const { user } = useStore()
  const nav = useNavigate()
  const toast = useToast()

  // اقرأ التبويب من الرابط (/my/services أو /my/requests) بدل تثبيته على «خدماتي»
  const { sub: subParam } = useParams<{ sub?: string }>()
  const normalize = (v?: string): Sub => (v === 'requests' || v === 'activity' ? v : 'services')
  const [sub, setSub] = useState<Sub>(() => normalize(subParam))

  // تابع تغيّر الرابط (مثل الرجوع/التقدّم في المتصفح)
  useEffect(() => { setSub(normalize(subParam)) }, [subParam])
  const [services, setServices] = useState<Service[]>([])
  const [requests, setRequests] = useState<ServiceRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState('')
  const [editSvc, setEditSvc] = useState<Service | null>(null)
  const [schedSvc, setSchedSvc] = useState<Service | null>(null)
  // المسوّدة الجاري تحريرها في مودال الجدول (بدونها تُلقى التعديلات)
  const [schedDraft, setSchedDraft] = useState<ScheduleRow[] | null>(null)
  const [busy, setBusy] = useState<number | null>(null)

  useEffect(() => {
    if (!user) { nav('/auth', { replace: true }); return }
    load()
  }, [user])

  const load = async () => {
    setLoading(true)
    setLoadError('')
    try {
      const [sr, rq] = await Promise.all([api.myServices(), api.myRequests()])
      setServices(sr.items ?? [])
      setRequests(rq.items ?? [])
    } catch (e: any) {
      // لا نترك التبويبات فارغة بصمت — نُظهر السبب وزر إعادة المحاولة
      setLoadError(String(e?.message || 'تعذّر تحميل البيانات'))
      setServices([])
      setRequests([])
    }
    setLoading(false)
  }

  const toggleStatus = async (svc: Service, nextOpen: boolean) => {
    setBusy(svc.id)
    try {
      await api.ownerStatus(svc.id, { mode: nextOpen ? 'open' : 'closed', hours: 6 })
      toast(nextOpen ? 'الخدمة تعمل الآن' : 'أُغلقت الخدمة مؤقتاً')
      await load()
    } catch { toast('فشل تحديث الحالة', 'error') }
    setBusy(null)
  }

  const toggleDuty = async (svc: Service) => {
    setBusy(svc.id)
    try {
      await api.ownerStatus(svc.id, { mode: 'open', on_duty: !svc.on_duty, duty_hours: 12 })
      toast(svc.on_duty ? 'أُلغيت المناوبة' : 'تم تفعيل المناوبة')
      await load()
    } catch { toast('فشل تحديث المناوبة', 'error') }
    setBusy(null)
  }

  const saveSchedule = async (svc: Service, rows: ScheduleRow[]) => {
    setBusy(svc.id)
    try {
      await api.ownerSchedule(svc.id, rows)
      toast('تم حفظ جدول الدوام')
      setSchedSvc(null)
      await load()
    } catch { toast('فشل حفظ الجدول', 'error') }
    setBusy(null)
  }

  const saveEdit = async (svc: Service, data: Record<string, any>) => {
    setBusy(svc.id)
    try {
      await api.ownerUpdate(svc.id, data)
      toast('تم حفظ التعديلات')
      setEditSvc(null)
      await load()
    } catch { toast('فشل الحفظ', 'error') }
    setBusy(null)
  }

  if (!user) return null

  return (
    <main className="page owner-page">
      <header className="owner__head">
        <Link to="/profile" className="back-btn"><Icon name="arrowRight" size={18} /> حسابي</Link>
        <div className="owner__head-row">
          <h1><Icon name="dashboard" size={24} /> لوحة التحكم</h1>
          <button className="iconbtn" title="تحديث" onClick={load} disabled={loading}>
            <Icon name="refresh" size={17} />
          </button>
        </div>
      </header>

      {loadError && (
        <div className="home__note">
          <Icon name="alert" size={16} />
          <span>{loadError}</span>
          <button className="qbtn qbtn--sm" onClick={load}>
            <Icon name="refresh" size={13} /> إعادة المحاولة
          </button>
        </div>
      )}

      <nav className="owner__tabs">
        <button
          className={sub === 'services' ? 'is-active' : ''}
          onClick={() => nav('/my/services')}
          aria-current={sub === 'services'}
        >
          <Icon name="grid" size={16} /> خدماتي ({services.length})
        </button>
        <button
          className={sub === 'requests' ? 'is-active' : ''}
          onClick={() => nav('/my/requests')}
          aria-current={sub === 'requests'}
        >
          <Icon name="inbox" size={16} /> طلباتي ({requests.length})
        </button>
      </nav>

      {loading ? (
        <div className="skeletons"><div className="skel-card" /></div>
      ) : sub === 'services' ? (
        services.length === 0 ? (
          <div className="empty-state">
            <span className="empty-state__icon">📦</span>
            <h3>لا تملك خدمات حالياً</h3>
            <p>يمكنك إرسال طلب إضافة خدمتك من <Link to="/request">هنا</Link>.</p>
          </div>
        ) : (
          <div className="owner-services">
            {services.map((svc) => (
              <div key={svc.id} className={`osvc ${svc.status === 'open' ? 'osvc--open' : 'osvc--closed'}`}>
                <div className="osvc__top">
                  <Link to={`/s/${svc.id}`} className="osvc__name">
                    <CatIcon icon={svc.category_icon} meta={svc.meta} size={17} /> {svc.name}
                  </Link>
                  {svc.region_name && <span className="osvc__region">{svc.region_name}</span>}
                </div>

                <div className="osvc__status">
                  <StatusToggle
                    open={svc.status === 'open'}
                    busy={busy === svc.id}
                    onToggle={(next) => toggleStatus(svc, next)}
                  />
                  <span className="osvc__status-text">
                    {svc.status_label} · {svc.status_sublabel}
                    {svc.status_source === 'manual' && <span className="osvc__manual">يدوي</span>}
                  </span>
                </div>

                <div className="osvc__duty-row">
                  <label className="chk chk--toggle">
                    <input type="checkbox" checked={svc.on_duty} onChange={() => toggleDuty(svc)} disabled={busy === svc.id} />
                    <span>🌙 مناوبة الآن</span>
                  </label>
                </div>

                <div className="osvc__tools">
                  <button
                    className="qbtn qbtn--sm"
                    onClick={() => { setSchedDraft(svc.schedule ?? []); setSchedSvc(svc) }}
                  >
                    <Icon name="clock" size={14} /> جدول الدوام ({svc.schedule?.length ?? 0} فترة)
                  </button>
                  <button className="qbtn qbtn--sm" onClick={() => setEditSvc(svc)}>
                    <Icon name="edit" size={14} /> تعديل البيانات
                  </button>
                  <Link to={`/s/${svc.id}`} className="qbtn qbtn--sm">
                    <Icon name="eye" size={14} /> معاينة
                  </Link>
                </div>
              </div>
            ))}
          </div>
        )
      ) : (
        /* الطلبات */
        requests.length === 0 ? (
          <div className="empty-state"><p>لا توجد طلبات</p></div>
        ) : (
          <div className="req-list">
            {requests.map((r) => (
              <div key={r.id} className={`req-item req-item--${r.status}`}>
                <div className="req-item__head">
                  <h4><CatIcon icon={r.category_icon} size={16} /> {r.name}</h4>
                  <span className={`req-status req-status--${r.status}`}>
                    {r.status === 'pending' ? '⏳ معلّق' : r.status === 'approved' ? '✅ موافق عليه' : '❌ مرفوض'}
                  </span>
                </div>

                <p className="req-item__meta">
                  {r.category_name ? `القسم: ${r.category_name}` : ''}
                  {r.region_name ? ` · المنطقة: ${r.region_name}` : ''}
                  {r.phone ? ` · الهاتف: ${r.phone}` : ''}
                </p>
                {r.address && <p className="req-item__meta">{r.address}</p>}

                {r.status === 'approved' && r.created_service_id && (
                  <div className="req-item__actions">
                    <button
                      className="btn btn--sm btn--primary"
                      onClick={() => nav('/my/services')}
                    >
                      <Icon name="dashboard" size={14} /> إدارة خدمتي الآن
                    </button>
                    <Link to={`/s/${r.created_service_id}`} className="qbtn qbtn--sm">
                      <Icon name="eye" size={14} /> معاينة الخدمة
                    </Link>
                  </div>
                )}

                {r.admin_note && <p className="req-note">ملاحظة الإدارة: {r.admin_note}</p>}
              </div>
            ))}
          </div>
        )
      )}

      {/* مودال جدول الدوام */}
      <Modal open={!!schedSvc} onClose={() => { setSchedSvc(null); setSchedDraft(null) }} title={`جدول الدوام — ${schedSvc?.name}`} wide>
        {schedSvc && (
          <ScheduleEditor
            key={schedSvc.id}
            value={schedDraft ?? []}
            onChange={setSchedDraft}
          />
        )}
        {schedSvc && (
          <div className="modal__foot">
            <button
              className="btn btn--primary"
              onClick={() => saveSchedule(schedSvc, schedDraft ?? schedSvc.schedule ?? [])}
              disabled={busy === schedSvc?.id}
            >
              {busy === schedSvc?.id ? 'جاري الحفظ…' : 'حفظ الجدول'}
            </button>
          </div>
        )}
      </Modal>

      {/* مودال تعديل بيانات الخدمة */}
      <Modal open={!!editSvc} onClose={() => setEditSvc(null)} title={`تعديل — ${editSvc?.name}`}>
        {editSvc && <EditServiceForm svc={editSvc} onSave={(d) => saveEdit(editSvc, d)} busy={busy === editSvc.id} />}
      </Modal>
    </main>
  )
}

function EditServiceForm({ svc, onSave, busy }: { svc: Service; onSave: (d: Record<string, any>) => void; busy: boolean }) {
  const [name, setName] = useState(svc.name)
  const [address, setAddress] = useState(svc.address)
  const [phone, setPhone] = useState(svc.phone)
  const [whatsapp, setWhatsapp] = useState(svc.whatsapp)
  const [note, setNote] = useState(svc.note)
  // أيقونة الخدمة — تُختار من مجموعة أيقونات قسمها
  const [icon, setIcon] = useState<string>((svc.meta as any)?.icon || '')
  // الموقع: محافظة ← مدينة ← قرية
  const { locations } = useStore()
  const [govId, setGovId] = useState<number | null>(svc.governorate_id ?? null)
  const [regionId, setRegionId] = useState<number | null>(svc.region_id ?? null)

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!govId) { window.alert('يجب اختيار المحافظة'); return }
    onSave({ name, address, phone, whatsapp, note, icon, region_id: regionId, governorate_id: govId })
  }

  return (
    <form onSubmit={submit} className="edit-form">
      <label><span>اسم الخدمة</span><input value={name} onChange={(e) => setName(e.target.value)} required /></label>
      <label><span>العنوان</span><input value={address} onChange={(e) => setAddress(e.target.value)} /></label>
      <label><span>رقم الهاتف</span><input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} dir="ltr" /></label>
      <label><span>رقم واتساب</span><input type="tel" value={whatsapp} onChange={(e) => setWhatsapp(e.target.value)} dir="ltr" /></label>
      <label><span>ملاحظة</span><textarea value={note} onChange={(e) => setNote(e.target.value)} rows={2} /></label>

      <LocationPicker
        locations={locations}
        governorateId={govId}
        regionId={regionId}
        onChange={(g, r) => { setGovId(g); setRegionId(r) }}
        required
        label="الموقع"
      />

      {/* منتقي أيقونات القسم */}
      <div className="field">
        <IconPicker
          categorySlug={svc.category_slug}
          value={icon}
          onChange={setIcon}
        />
      </div>

      <button type="submit" className="btn btn--primary" disabled={busy}>{busy ? 'جاري الحفظ…' : 'حفظ'}</button>
    </form>
  )
}

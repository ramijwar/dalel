import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useStore } from '../lib/store'
import { api } from '../lib/api'
import { useToast } from '../lib/useToast'
import { ApiError } from '../lib/api'
import Icon from '../components/Icon'
import IconPicker from '../components/IconPicker'
import LocationPicker from '../components/LocationPicker'
import { VEHICLE_TYPES, vehicleIcon } from '../lib/utils'
import { DynamicFields, type FieldValues } from '../components/CategoryFields'
import type { CategoryField } from '../lib/types'

export default function RequestPage() {
  const { user, categories, locations } = useStore()
  const toast = useToast()

  const [catId, setCatId] = useState<number>(0)
  const [regionId, setRegionId] = useState<number>(0)
  const [govId, setGovId] = useState<number | null>(null)
  const [name, setName] = useState('')
  const [address, setAddress] = useState('')
  const [phone, setPhone] = useState('')
  const [whatsapp, setWhatsapp] = useState('')
  const [note, setNote] = useState('')
  const [wantManage, setWantManage] = useState(false)
  const [busy, setBusy] = useState(false)
  const [done, setDone] = useState(false)
  /** نوع المركبة — يظهر لقسم «سرافيس وباصات» ويشمل خيار الإسعاف */
  const [vehicle, setVehicle] = useState<string>('')
  /** عدد المواقف / نقاط التوقف (اختياري) */
  const [stops, setStops] = useState('')
  /** أيقونة الخدمة — تُختار من مجموعة الأيقونات الخاصة بالقسم */
  const [icon, setIcon] = useState<string>('')
  /** قيم الحقول الخاصة بالقسم (مثل اختصاص الطبيب) */
  const [fieldValues, setFieldValues] = useState<FieldValues>({})

  const selectedCat = categories.find((c) => c.id === catId)
  const isTransport = selectedCat?.slug === 'transport'

  /* ══════════════════════════════════════════════════════════
   *  الحقول الخاصة بالقسم المختار
   *  مثل «الاختصاص» لقسم الأطباء — تُعرَّف في إعدادات القسم
   * ══════════════════════════════════════════════════════════ */
  const catFields = useMemo<CategoryField[]>(
    () => selectedCat?.fields ?? [],
    [selectedCat],
  )

  // عند تغيير القسم: أفرغ قيم الحقول التي لا تنتمي إليه
  useEffect(() => {
    setFieldValues((prev) => {
      const valid = new Set(catFields.map((f) => f.key))
      const next: FieldValues = {}
      for (const [k, v] of Object.entries(prev)) {
        if (valid.has(k)) next[k] = v
      }
      return next
    })
  }, [catFields])

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!catId) { toast('اختر نوع الخدمة', 'error'); return }
    if (isTransport && !vehicle) { toast('اختر نوع المركبة (سرفيس / باص / إسعاف)', 'error'); return }

    // تحقّق من الحقول المطلوبة للقسم (مثل الاختصاص للأطباء)
    for (const f of catFields) {
      if (!f.required) continue
      const v = fieldValues[f.key]
      if (v === undefined || v === null || String(v).trim() === '') {
        toast(`الحقل «${f.label}» مطلوب`, 'error')
        return
      }
    }

    setBusy(true)
    try {
      // حقول إضافية حسب القسم (مثل نوع المركبة للنقل)
      const meta: Record<string, any> = { icon: icon || undefined }
      if (isTransport) {
        meta.vehicle = vehicle
        if (stops && Number(stops) > 0) meta.stops_count = Number(stops)
      }

      await api.createRequest({
        category_id: catId,
        region_id: regionId || undefined,
        governorate_id: govId ?? undefined,
        name,
        address,
        phone,
        whatsapp,
        note,
        meta,
        // الحقول الخاصة بالقسم — يتحقق منها الخادم ويدمجها داخل meta
        fields: fieldValues,
        want_to_manage: wantManage,
      })
      setDone(true)
      toast('تم إرسال طلبك بنجاح، سيتم مراجعته من الإدارة')
    } catch (err) {
      toast(err instanceof ApiError ? err.message : 'حدث خطأ', 'error')
    } finally {
      setBusy(false)
    }
  }

  if (done) {
    return (
      <main className="page req-page">
        <div className="req-done">
          <span className="req-done__icon">✅</span>
          <h2>تم استلام طلبك</h2>
          <p>سيتم مراجعة الطلب من إدارة الموقع وسنقوم بإعلامك عند الموافقة.</p>
          <Link to="/" className="btn btn--primary">العودة للرئيسية</Link>
        </div>
      </main>
    )
  }

  return (
    <main className="page req-page">
      <header className="req-page__head">
        <Link to="/" className="back-btn"><Icon name="arrowRight" size={18} /> الرئيسية</Link>
        <h1><Icon name="plus" size={24} /> طلب إضافة خدمة</h1>
        <p>أرسل بيانات خدمتك وسيتم مراجعتها من فريق الإدارة.</p>
      </header>

      <form onSubmit={submit} className="req-form">
        <label>
          <span>نوع الخدمة *</span>
          <select
            required
            value={catId}
            onChange={(e) => { setCatId(Number(e.target.value)); setIcon('') }}
          >
            <option value={0}>— اختر —</option>
            {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </label>

        {/* منتقي الأيقونات — يعرض أيقونات القسم المختار فقط */}
        {selectedCat && (
          <div className="field">
            <IconPicker
              categorySlug={selectedCat.slug}
              value={icon}
              onChange={setIcon}
            />
          </div>
        )}

        {/* ═══ الحقول الخاصة بالقسم ═══
            مثل «الاختصاص» لقسم الأطباء — تظهر تلقائياً بحسب القسم */}
        {catFields.length > 0 && (
          <div className="field">
            <DynamicFields
              fields={catFields}
              values={fieldValues}
              onChange={(k, v) =>
                setFieldValues((prev) => ({ ...prev, [k]: v }))
              }
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
        {!govId && <p className="form-hint form-hint--err">يجب اختيار المحافظة</p>}

        {/* حقول خاصة بقسم «سرافيس وباصات» — تشمل خيار الإسعاف */}
        {isTransport && (
          <>
            <div className="field">
              <span className="field__label">نوع المركبة *</span>
              <div className="veh-picker">
                {VEHICLE_TYPES.map((v) => (
                  <button
                    type="button"
                    key={v}
                    className={`veh-opt ${vehicle === v ? 'is-active' : ''}`}
                    onClick={() => setVehicle(v)}
                    aria-pressed={vehicle === v}
                  >
                    <span className="veh-opt__icon">{vehicleIcon(v)}</span>
                    <span className="veh-opt__name">{v}</span>
                  </button>
                ))}
              </div>
            </div>

            <label>
              <span>عدد المواقف (اختياري)</span>
              <input
                type="number"
                min={1}
                value={stops}
                onChange={(e) => setStops(e.target.value)}
                placeholder="مثال: 9"
              />
            </label>
          </>
        )}

        <label>
          <span>اسم الخدمة *</span>
          <input
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder={isTransport ? (vehicle === 'إسعاف' ? 'مثال: إسعاف الهلال - باب الفرج' : 'مثال: خط الإذاعة شرقي') : 'مثال: صيدلية الشفاء'}
          />
        </label>

        <label>
          <span>العنوان</span>
          <input value={address} onChange={(e) => setAddress(e.target.value)} placeholder="الشارع والمنطقة" />
        </label>

        <div className="req-form__row">
          <label>
            <span>رقم الهاتف</span>
            <input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} dir="ltr" placeholder="09XX XXX XXX" />
          </label>
          <label>
            <span>رقم واتساب</span>
            <input type="tel" value={whatsapp} onChange={(e) => setWhatsapp(e.target.value)} dir="ltr" placeholder="اختياري" />
          </label>
        </div>

        <label>
          <span>ملاحظات إضافية</span>
          <textarea value={note} onChange={(e) => setNote(e.target.value)} rows={3} placeholder="أي تفاصيل إضافية" />
        </label>

        {user && (
          <label className="chk">
            <input type="checkbox" checked={wantManage} onChange={(e) => setWantManage(e.target.checked)} />
            <span>أريد التحكم بخدمتي وتحديث حالتها من حسابي</span>
          </label>
        )}

        <button type="submit" className="btn btn--primary btn--block" disabled={busy}>
          {busy ? 'جاري الإرسال…' : 'إرسال الطلب'}
        </button>
      </form>
    </main>
  )
}

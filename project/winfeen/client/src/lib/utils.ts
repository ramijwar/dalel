import { DAY_NAMES, type Service } from './types'

/** تنسيق رقم بفواصل عربية-لاتينية */
export function num(n: number | undefined | null): string {
  if (n === undefined || n === null || Number.isNaN(n)) return '0'
  return n.toLocaleString('en-US')
}

/** "قبل 5 دقائق" */
export function timeAgo(dt: string | null | undefined, now = Date.now()): string {
  if (!dt) return '—'
  // التواريخ المخزّنة بصيغة "Y-m-d H:i:s" بتوقيت دمشق
  const iso = dt.includes('T') ? dt : dt.replace(' ', 'T') + '+03:00'
  const t = new Date(iso).getTime()
  if (Number.isNaN(t)) return dt
  const s = Math.max(0, Math.floor((now - t) / 1000))
  if (s < 60) return 'الآن'
  const m = Math.floor(s / 60)
  if (m < 60) return `قبل ${m} دقيقة`
  const h = Math.floor(m / 60)
  if (h < 24) return `قبل ${h} ساعة`
  const d = Math.floor(h / 24)
  if (d < 30) return `قبل ${d} يوم`
  return new Date(t).toLocaleDateString('ar-EG')
}

export function fmtTime(t: string | null | undefined): string {
  if (!t) return '—'
  return t.length >= 5 ? t.slice(0, 5) : t
}

export function fmtDate(d: string | null | undefined): string {
  if (!d) return '—'
  const dt = new Date(d.length <= 10 ? d + 'T00:00:00' : d)
  if (Number.isNaN(dt.getTime())) return d
  return dt.toLocaleDateString('ar-EG', { year: 'numeric', month: 'long', day: 'numeric' })
}

export function fmtDateTime(dt: string | null | undefined): string {
  if (!dt) return '—'
  const iso = dt.includes('T') ? dt : dt.replace(' ', 'T') + '+03:00'
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return dt
  return d.toLocaleString('ar-EG', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

export const telHref = (phone: string) => `tel:${phone.replace(/[^\d+]/g, '')}`
export const waHref = (n: string, text = 'السلام عليكم، وجدتكم في دليل الخدمات') =>
  `https://wa.me/${n.replace(/\D/g, '')}?text=${encodeURIComponent(text)}`

export function dayLabel(day: number): string {
  return DAY_NAMES[day] ?? ''
}

/** جدول الدوام → نص مختصر */
export function scheduleSummary(rows: { day: number; opens: string; closes: string; is_24h: boolean }[] = []): string {
  if (!rows.length) return 'لا يوجد جدول دوام'
  if (rows.length === 7 && rows.every((r) => r.is_24h)) return 'دوام 24 ساعة يومياً'
  if (rows.length === 7) {
    const first = rows[0]
    if (rows.every((r) => r.opens === first.opens && r.closes === first.closes && !!r.is_24h === !!first.is_24h)) {
      return first.is_24h ? 'دوام 24 ساعة يومياً' : `يومياً ${fmtTime(first.opens)} - ${fmtTime(first.closes)}`
    }
    return 'يومياً (بأوقات مختلفة)'
  }
  const days = rows.map((r) => DAY_NAMES[r.day]?.slice(0, 3)).join('، ')
  const first = rows[0]
  return `${days} · ${first.is_24h ? '24 ساعة' : `${fmtTime(first.opens)} - ${fmtTime(first.closes)}`}`
}

/** حقول وصفية حسب نوع الخدمة لعرضها في البطاقة */
/** أنواع المركبات في قسم سرافيس وباصات (متاحة أيضاً للإسعاف) */
export const VEHICLE_TYPES = ['سرفيس', 'باص', 'إسعاف'] as const

/** أيقونة كل نوع مركبة */
export const VEHICLE_ICONS: Record<string, string> = {
  'سرفيس': '🚐',
  'باص': '🚌',
  'إسعاف': '🚑',
}

/** اسم أيقونة Lucide لكل نوع مركبة (تُستخدم إن أردت SVG بدل الإيموجي) */
export const VEHICLE_LUCIDE: Record<string, string> = {
  'سرفيس': 'car',
  'باص': 'bus',
  'إسعاف': 'ambulance',
}

export function vehicleIcon(v: string | undefined | null): string {
  return VEHICLE_ICONS[String(v ?? '').trim()] ?? '🚍'
}

export function metaChips(s: Service): { label: string; value: string; icon?: string }[] {
  const m = s.meta || {}

  // ─── الأولوية للحقول المحلولة من الخادم ───
  // تُبنى من تعريفات القسم نفسها، فتعمل مع أي قسم دون تعديل الكود
  if (Array.isArray(s.fields) && s.fields.length) {
    return s.fields
      .filter((f) => f.display !== '' && f.display != null)
      .map((f) => ({ label: f.label, value: f.display, icon: f.icon }))
      .slice(0, 4)
  }

  // ─── احتياط: الشرائح المضمّنة للبيانات القديمة ───
  const out: { label: string; value: string; icon?: string }[] = []
  const slug = s.category_slug
  if (slug === 'doctors') {
    /* meta.specialty قد يكون اسماً («أمراض داخلية») في البيانات القديمة،
       أو مُعرّف خيار («5») في الجديدة. لا نعرض الأرقام خاماً أبداً —
       بل نبحث عن الاسم المقابل في قائمة الاختصاصات. */
    const rawSp = m.specialty != null ? String(m.specialty).trim() : ''
    if (rawSp && !/^\d+$/.test(rawSp)) {
      out.push({ label: 'الاختصاص', value: rawSp, icon: m.specialty_icon || '🩺' })
    }
    if (m.consult_fee) out.push({ label: 'المعاينة', value: `${num(m.consult_fee)} ${m.currency || 'ل.س'}`, icon: '💵' })
    if (m.hospital) out.push({ label: 'المستشفى', value: m.hospital, icon: '🏥' })
  } else if (slug === 'stations') {
    if (Array.isArray(m.fuels) && m.fuels.length) out.push({ label: 'المتوفر', value: m.fuels.join(' · '), icon: '🛢️' })
    if (m.smart_card) out.push({ label: 'الدفع', value: 'بطاقة ذكية', icon: '💳' })
    if (m.company) out.push({ label: 'الشركة', value: m.company, icon: '🏢' })
  } else if (slug === 'transport') {
    if (m.vehicle) out.push({ label: 'النوع', value: m.vehicle, icon: vehicleIcon(m.vehicle) })
    if (m.fare) out.push({ label: 'الأجرة', value: `${num(m.fare)} ${m.currency || 'ل.س'}`, icon: '🎫' })
    if (m.stops_count) out.push({ label: 'المواقف', value: `${m.stops_count} موقف`, icon: '📍' })
    if (m.frequency) out.push({ label: 'الانطلاق', value: m.frequency, icon: '⏱️' })
  } else if (slug === 'pharmacies') {
    if (m.pharmacist) out.push({ label: 'الصيدلاني', value: m.pharmacist, icon: '🧑‍⚕️' })
    if (m.is_24h) out.push({ label: 'الدوام', value: '24 ساعة', icon: '🌙' })
    if (m.delivery) out.push({ label: 'التوصيل', value: 'متوفر', icon: '🛵' })
  } else if (slug === 'bazaars') {
    if (m.market_type) out.push({ label: 'النوع', value: m.market_type, icon: '🛍️' })
    if (m.day) out.push({ label: 'اليوم', value: m.day, icon: '📅' })
  }
  return out.slice(0, 4)
}

export function slugToPath(slug: string): string {
  return `/${slug}`
}

export function copyText(text: string): Promise<void> {
  if (navigator.clipboard?.writeText) return navigator.clipboard.writeText(text)
  return new Promise((resolve) => {
    const ta = document.createElement('textarea')
    ta.value = text
    ta.style.position = 'fixed'
    ta.style.opacity = '0'
    document.body.appendChild(ta)
    ta.select()
    try { document.execCommand('copy') } catch { /* ignore */ }
    document.body.removeChild(ta)
    resolve()
  })
}

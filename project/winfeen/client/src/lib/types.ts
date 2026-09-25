export type Zone = 'city' | 'rural'

/* ═══════════ الحقول الخاصة بالأقسام ═══════════ */

/** أنواع الحقول المدعومة */
export type FieldType = 'select' | 'text' | 'textarea' | 'number' | 'boolean'

/** خيار داخل حقل من نوع قائمة */
export interface FieldOption {
  /** غير موجود للخيارات الجديدة قبل الحفظ */
  id?: number
  label: string
  value: string
  icon?: string
  sort_order?: number
  is_active?: boolean
}

/** تعريف حقل خاص بقسم */
export interface CategoryField {
  id?: number
  key: string
  label: string
  type: FieldType
  required: boolean
  placeholder?: string
  help?: string
  show_in_card: boolean
  filterable: boolean
  sort_order: number
  /** وحدة تُلحَق بعد القيمة الرقمية في العرض (ل.س · موقف · كم) */
  suffix?: string
  /** للحقول المنطقية: تُخفى القيمة إن كانت «لا» — يمنع شرائح «لا» المتكررة */
  hide_when_false?: boolean
  options: FieldOption[]
  is_active?: boolean
  category_id?: number
  category_name?: string
}

/** حقل محلول وقيمته جاهزة للعرض — يرجعه الخادم مع كل خدمة */
export interface ResolvedField {
  key: string
  label: string
  type: FieldType
  value: string
  display: string
  icon?: string
}

export const FIELD_TYPES: { value: FieldType; label: string; icon: string }[] = [
  { value: 'select', label: 'قائمة اختيار', icon: '☰' },
  { value: 'text', label: 'نص قصير', icon: 'T' },
  { value: 'textarea', label: 'نص طويل', icon: '¶' },
  { value: 'number', label: 'رقم', icon: '#' },
  { value: 'boolean', label: 'نعم / لا', icon: '✓' },
]

export interface Category {
  id: number
  slug: string
  name: string
  singular: string
  icon: string
  color: string
  description: string
  route: string
  sort_order: number
  layout: 'card' | 'list' | 'row'
  features: Record<string, boolean>
  /** الحقول الخاصة بهذا القسم — تُبنى ديناميكياً في نماذج الخدمات */
  fields?: CategoryField[]
  is_active?: boolean
}

/** محافظة — المستوى الأول في هرمية الموقع */
export interface Governorate {
  id: number
  name: string
  slug: string | null
  zone: Zone
  sort_order: number
  is_active?: number | boolean
  services_count?: number
  /** يُملأ فقط في /api/locations */
  cities?: LocationCity[]
}

/** مدينة داخل محافظة (المستوى الثاني) */
export interface LocationCity {
  id: number
  governorate_id: number
  name: string
  level: 'city' | 'village'
  villages?: LocationVillage[]
}

/** قرية تابعة لمدينة (المستوى الثالث) */
export interface LocationVillage {
  id: number
  parent_id: number
  name: string
}

export interface Region {
  id: number
  name: string
  zone: Zone
  sort_order: number
  is_active?: number | boolean
  services_count?: number
  /** المحافظة التي تنتمي إليها */
  governorate_id?: number | null
  /** المدينة الأم — إن كانت قرية */
  parent_id?: number | null
  /** city = مدينة/بلدة، village = قرية تابعة لمدينة */
  level?: 'city' | 'village'
  /** اسم المحافظة (يُرجعه الخادم للعرض) */
  governorate_name?: string | null
  /** اسم المدينة الأم — إن كانت قرية (يُرجعه الخادم للعرض) */
  parent_name?: string | null
}

export interface ScheduleRow {
  day: number
  opens: string
  closes: string
  is_24h: boolean
}

export interface Service {
  id: number
  name: string
  category_id: number
  region_id: number | null
  region_name: string | null
  region_zone: Zone | null
  region_level?: 'city' | 'village' | null
  city_name?: string | null
  governorate_id?: number | null
  governorate_name?: string | null
  governorate_slug?: string | null
  category_slug?: string | null
  category_name?: string | null
  category_icon?: string
  /** الحقول الخاصة بالقسم — محلولة وجاهزة للعرض مباشرة */
  fields?: ResolvedField[]
  address: string
  phone: string
  phone_intl: string
  whatsapp: string
  whatsapp_number: string
  note: string
  photo: string | null
  meta: Record<string, any>
  is_verified: boolean
  is_active?: boolean
  owner_id: number | null
  owner_name?: string | null
  owner_phone?: string | null
  status: 'open' | 'closed'
  status_label: string
  status_sublabel: string
  status_source: 'manual' | 'schedule'
  status_note?: string
  closes_at: string | null
  on_duty: boolean
  duty_from: string | null
  duty_to: string | null
  updated_at: string | null
  created_at: string | null
  schedule?: ScheduleRow[]
  schedule_count?: number
  mode?: 'auto' | 'open' | 'closed'
  expires_at?: string | null
  layout?: string | null
  sort_order?: number
}

export interface RegionGroup {
  region: string
  region_id: number | null
  total: number
  open: number
  on_duty: number
}

export interface Specialty {
  id: number
  name: string
  icon: string
  sort_order: number
  services_count?: number
}

export interface ServiceListResponse {
  items: Service[]
  total: number
  page: number
  limit: number
  open_now: number
  on_duty: number
  regions: RegionGroup[]
  time: string
}

export interface User {
  id: number
  phone: string
  phone_intl: string
  full_name: string
  birth_date: string | null
  avatar: string | null
  bio: string
  role: 'admin' | 'user'
  created_at?: string | null
  is_active?: number
  services_count?: number
}

export interface Announcement {
  title?: string
  text: string
  tone: 'info' | 'warning' | 'danger' | 'success'
  link?: string
}

export interface Settings {
  site_name: string
  city: string
  /** زمن التبديل بين الإعلانات بالثواني (1..60) — يُضبط من لوحة التحكم */
  ad_interval: number
  announcements: Announcement[]
  whatsapp_admin: string
  service_types?: unknown[]
}

export interface MetaResponse {
  categories: Category[]
  regions: Region[]
  counts: Record<string, number>
  settings: Settings
  time: string
  governorates: Governorate[]
  locations: Governorate[]
}

export interface ServiceRequest {
  id: number
  user_id: number | null
  category_id: number | null
  region_id: number | null
  category_name?: string
  category_icon?: string
  region_name?: string
  user_name?: string | null
  user_phone?: string | null
  name: string
  address: string
  phone: string
  whatsapp: string
  note: string
  meta: string
  want_to_manage: number
  status: 'pending' | 'approved' | 'rejected'
  admin_note: string
  created_service_id: number | null
  created_at: string
}

export interface AdminStats {
  categories: Array<{ id: number; slug: string; name: string; icon: string; color: string; total: number; managed: number }>
  services: number
  services_active: number
  regions: number
  users: number
  owners: number
  requests_pending: number
  requests_total: number
  open_now: number
  manual_now: number
  on_duty: number
  time: string
}

export interface ActivityItem {
  id?: number
  action: string
  entity: string
  entity_id: number | null
  message: string
  created_at: string
  user_name?: string | null
}

export const DAY_NAMES = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت']
export const DAY_SHORT = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت']

/** فهرس اليوم في قاعدة البيانات: 0 = الأحد */
export function todayIndex(d = new Date()): number {
  return d.getDay()
}

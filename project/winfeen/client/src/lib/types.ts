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
  /** الفلاتر المُسنَدة لهذا القسم — الأساسي أولاً، وهو الذي يقود العرض */
  filters?: CategoryFilterLink[]
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
  /** يُرسله الخادم في shape_service — أساس فلتر «الاختصاص» */
  specialty_id?: number | null
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

/**
 * الفلاتر — مكتبة في قاعدة البيانات، لم تكن موجودة سابقاً.
 *
 * كان «أي فلتر يقود أي قسم» مكتوباً في كود الواجهة (CAT_INFO)، فيقود
 * الصيدليات بالمناطق والأطباء بالاختصاص والسرفيس بنوع المركبة بلا قدرة
 * للمدير على التغيير. الآن:
 *   • filters          = مكتبة الفلاتر (اسم + مصدر بيانات)
 *   • category.filters = الفلاتر المُسنَدة للقسم، الأساسي أولاً
 */
export type FilterSource = 'region' | 'specialty' | 'field'

export interface Filter {
  id: number
  key: string
  label: string
  /** region = المناطق · specialty = الاختصاص · field = حقل قائمة في قسم */
  source_type: FilterSource
  /** مفتاح الحقل عند source_type = 'field' (مثال: vehicle · direction) */
  source_key: string
  icon: string
  sort_order: number
  is_active: boolean
  /** كم قسماً يستخدم هذا الفلتر — يمنع حذفاً مفاجئاً */
  used_by?: number
}

/** فلتر مُسنَد لقسم — is_primary يقود بطاقات المستوى الأول */
export interface CategoryFilterLink {
  /** معرّف سطر الإسناد */
  id: number
  /** معرّف الفلتر في المكتبة — يُستخدم عند الحفظ في اللوحة */
  filter_id: number
  key: string
  label: string
  source_type: FilterSource
  source_key: string
  icon: string
  is_primary: boolean
  sort_order: number
}

/** بطاقة تجميع واحدة — تُحسب في الخادم من كل الخدمات قبل ترقيم الصفحات */
export interface GroupCard {
  key: string
  label: string
  icon: string
  total: number
  open: number
  on_duty: number
}

/** مصدر متاح لبناء فلتر عليه (يُعرض في لوحة التحكم) */
export interface FilterSourceOption {
  source_type: FilterSource
  source_key: string
  label: string
  hint: string
}

export interface ServiceListResponse {
  items: Service[]
  total: number
  page: number
  limit: number
  open_now: number
  on_duty: number
  regions: RegionGroup[]
  /** مجمّعة بمفتاح الفلتر: { region: [...], 'flt-vehicle': [...] } */
  groups?: Record<string, GroupCard[]>
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

export interface ApkFile {
  name: string
  size: number
  size_h: string
  modified: string
  current: boolean
}

/** حالة «مسار الملف» في لوحة تحديث التطبيق */
export interface AppUpdatePathStatus {
  /** المسار كما كتبه المدير */
  path: string
  /** 'local' مسار داخل الموقع · 'url' رابط خارجي · 'apk_dir' الملف المرفوع · 'none' */
  kind: 'local' | 'url' | 'apk_dir' | 'none'
  found: boolean
  /** المسار النسبي للتنزيل (للملفات المحلية) */
  web_path: string | null
  size: number
  size_h: string
  /** الإصدار المقروء من داخل الملف — للمقارنة برقم المدير */
  meta: { package?: string; versionCode?: number; versionName?: string } | null
  message: string
}

/** حالة تحديث تطبيق أندرويد — كما يراها التطبيق ولوحة التحكم */
export interface AppUpdateInfo {
  version_name: string
  version_code: number
  notes: string
  force: boolean
  size: number
  sha256: string
  /** الملف المنشور داخل مجلد apk/ */
  apk_file?: string
  /** رابط خارجي بديل (GitHub/Drive) إن استُعمل */
  url?: string
  has_file: boolean
  available?: boolean
  published_at?: string | null
  uploaded_at?: number
  /** حقول إدارية */
  download_url?: string
  dir?: string
  dir_writable?: boolean
  upload_limit?: number
  upload_limit_h?: string
  max_upload?: string
  post_max?: string
  file_size_h?: string
  apks_in_dir?: ApkFile[]
  path_status?: AppUpdatePathStatus
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

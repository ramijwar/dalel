import type { CategoryFilterLink, GroupCard, Service } from './types'

/**
 * ══════════════════════════════════════════════════════════════════
 *  محرّك الفلاتر — مطابقة الخدمة بالفلتر وقراءة بطاقات التجميع
 * ══════════════════════════════════════════════════════════════════
 *
 *  العدّادات تأتي جاهزة من الخادم (`groups[filter.key]`) لأنها تُحسب
 *  من **كل** الخدمات المُرشَّحة قبل ترقيم الصفحات، فلا تنقص عند تجاوز
 *  الشريحة الأولى. أما التصفية عند اختيار بطاقة فمحلية هنا — فيبقى
 *  شكل البطاقات كاملاً ويظهر أثر الاختيار فوراً بلا طلب شبكة.
 *
 *  نفس المفهوم مطبَّق في تطبيق أندرويد (يعتمد على الحقلين
 *  `source_type` و`is_primary` نفسهما).
 */

/** الفلتر الأساسي للقسم: هو الذي يقود بطاقات المستوى الأول */
export function primaryFilter(filters?: CategoryFilterLink[]): CategoryFilterLink | null {
  if (!filters || filters.length === 0) return null
  return filters.find((f) => f.is_primary) ?? filters[0]
}

/** بقية الفلاتر المُسنَدة — تُعرض كقائمة اختيار مصغّرة في شريط الأدوات */
export function secondaryFilters(filters?: CategoryFilterLink[]): CategoryFilterLink[] {
  const primary = primaryFilter(filters)
  if (!primary || !filters) return []
  return filters.filter((f) => f.key !== primary.key)
}

/**
 * قيمة الخدمة بالنسبة لفلتر — أساس المطابقة.
 *
 *  region    ← عمود region_id
 *  specialty ← عمود specialty_id
 *  field     ← الحقل المحلول من الخادم (value)، وتشمل المطابقة
 *              أيضاً النص المعروض كي تعمل البيانات القديمة المحفوظة
 *              بنص الخيار لا بمُعرّفه.
 */
export function serviceFilterValue(s: Service, f: CategoryFilterLink): string {
  if (f.source_type === 'region') {
    return s.region_id != null ? String(s.region_id) : ''
  }
  if (f.source_type === 'specialty') {
    return s.specialty_id != null ? String(s.specialty_id) : ''
  }
  const resolved = (s.fields ?? []).find((x) => x.key === f.source_key)
  return resolved ? String(resolved.value ?? '') : ''
}

/** النص المعروض لقيمة الفلتر — يُستخدم للمطابقة الاحتياطية ولبحث بسيط */
function serviceFilterDisplay(s: Service, f: CategoryFilterLink): string {
  if (f.source_type === 'field') {
    const resolved = (s.fields ?? []).find((x) => x.key === f.source_key)
    return resolved ? String(resolved.display ?? '') : ''
  }
  return ''
}

/**
 * هل تنتمي الخدمة إلى البطاقة المختارة؟
 * المفتاح `__none` يعني «غير محدد» — الخدمة التي ينقصها الحقل.
 */
export function matchesGroup(s: Service, f: CategoryFilterLink, groupKey: string): boolean {
  const value = serviceFilterValue(s, f)
  if (groupKey === '__none') return value === ''
  if (value === groupKey) return true
  // احتياط للبيانات القديمة: مطابقة النص المعروض
  return f.source_type === 'field' && serviceFilterDisplay(s, f) === groupKey
}

/** بطاقات فلتر من استجابة الخادم */
export function groupsFor(
  filter: CategoryFilterLink | null,
  apiGroups?: Record<string, GroupCard[]>,
): GroupCard[] {
  if (!filter || !apiGroups) return []
  return apiGroups[filter.key] ?? []
}

/**
 * بناء بطاقات التجميع محلياً من الخدمات — شبكة أمان.
 *
 * تُستخدم إن لم يرسل الخادم `groups` (حزمة واجهة جديدة على خادم لم يُحدَّث
 * بعد، أو قسم بلا فلتر لكن بخدمات). بلا هذه الشبكة تظهر الصفحة فارغة
 * بلا أي بطاقة ولا رسالة — وهي الشكوى التي بدأنا منها.
 */
export function buildGroups(items: Service[], filter: CategoryFilterLink): GroupCard[] {
  const buckets = new Map<string, GroupCard>()
  for (const s of items) {
    const value = serviceFilterValue(s, filter)
    const key = value === '' ? '__none' : value
    const cur = buckets.get(key) ?? {
      key,
      label: value === '' ? 'غير محدد' : (filter.source_type === 'region' ? (s.region_name || value) : value),
      icon: filter.icon || (filter.source_type === 'region' ? 'map-pin' : 'circle-dot'),
      total: 0,
      open: 0,
      on_duty: 0,
    }
    cur.total++
    if (s.status === 'open') cur.open++
    if (s.on_duty) cur.on_duty++
    buckets.set(key, cur)
  }
  return [...buckets.values()].sort((a, b) =>
    (a.key === '__none' ? 1 : 0) - (b.key === '__none' ? 1 : 0) ||
    b.open - a.open ||
    b.total - a.total ||
    a.label.localeCompare(b.label, 'ar'),
  )
}

/** مُحدِّد الفلتر الثانوي: {فلتر} ← القيمة المختارة */
export type SecondaryState = Record<string, string>

/** هل تنطبق الخدمة على كل الفلاتر الثانوية المختارة؟ */
export function matchesSecondary(
  s: Service,
  filters: CategoryFilterLink[],
  state: SecondaryState,
): boolean {
  for (const f of filters) {
    const wanted = state[f.key]
    if (!wanted) continue
    if (!matchesGroup(s, f, wanted)) return false
  }
  return true
}

/**
 * خيارات فلتر ثانوي — من نفس تجميعات الخادم، فتأتي التسميات والأيقونات
 * صحيحة لكل الأنواع الثلاثة (اسم المنطقة · اسم الاختصاص وأيقونته ·
 * نص الخيار وأيقونته) بلا إعادة اشتقاق في الواجهة.
 */
export function secondaryOptions(
  filter: CategoryFilterLink,
  apiGroups?: Record<string, GroupCard[]>,
): GroupCard[] {
  return groupsFor(filter, apiGroups)
}

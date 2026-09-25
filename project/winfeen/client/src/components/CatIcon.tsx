import { LUCIDE_PATHS, VEHICLE_LUCIDE, type LucideName } from './Lucide'

interface Props {
  /** قيمة حقل icon — إما اسم أيقونة Lucide (pill) أو إيموجي (💊) */
  icon?: string | null
  size?: number
  className?: string
  /** بيانات meta للخدمة — لاستخراج الأيقونة المختارة وأيقونة المركبة */
  meta?: Record<string, any> | null
}

/**
 * أيقونة الخدمة بترتيب أولوية:
 *   1) meta.icon  — الأيقونة التي اختارها صاحب الخدمة
 *   2) أيقونة المركبة (سرفيس/باص/إسعاف) في قسم النقل
 *   3) أيقونة القسم الافتراضية
 *   4) إيموجي قديم إن وُجد
 */
export default function CatIcon({ icon, size = 20, className = '', meta }: Props) {
  const m = (meta ?? {}) as Record<string, any>
  const chosen = typeof m?.icon === 'string' ? m.icon : null
  const vehicle = m?.vehicle ? VEHICLE_LUCIDE[String(m.vehicle)] : null

  const name = chosen || vehicle || icon
  const body = name ? LUCIDE_PATHS[name as LucideName] : null

  if (body) {
    return (
      <svg
        className={`ic lucide ${className}`}
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
        dangerouslySetInnerHTML={{ __html: body }}
      />
    )
  }

  // إيموجي أو قيمة نصية (بيانات قديمة)
  return <span className={`cat-emoji ${className}`} style={{ fontSize: size }}>{icon || '📍'}</span>
}

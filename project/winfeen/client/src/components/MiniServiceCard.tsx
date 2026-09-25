import type { Service } from '../lib/types'
import CatIcon from './CatIcon'

interface Props {
  s: Service
  active?: boolean
  onSelect: (s: Service) => void
}

/**
 * بطاقة خدمة مُصغّرة جداً: أيقونة + اسم + نقطة حالة ملوّنة.
 * 🟢 تعمل الآن   🔴 مغلقة   🟤 مناوبة
 */
export default function MiniServiceCard({ s, active = false, onSelect }: Props) {
  // الأولوية: مناوبة (بني) ← مفتوحة (أخضر) ← مغلقة (أحمر)
  const state = s.on_duty ? 'duty' : s.status === 'open' ? 'open' : 'closed'
  const label = s.on_duty ? 'مناوبة' : s.status === 'open' ? 'تعمل الآن' : 'مقفلة'

  return (
    <button
      type="button"
      className={`mini ${active ? 'is-active' : ''}`}
      onClick={() => onSelect(s)}
      aria-pressed={active}
      title={s.name}
    >
      <span className="mini__icon">
        <CatIcon icon={s.category_icon} meta={s.meta} size={26} />
      </span>
      <span className="mini__name">{s.name}</span>
      <span className={`mini__state mini__state--${state}`}>
        <span className="mini__dot" />
        <span className="mini__label">{label}</span>
      </span>
    </button>
  )
}

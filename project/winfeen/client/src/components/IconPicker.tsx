import { useMemo, useState } from 'react'
import Lucide, { LUCIDE_LABELS, CATEGORY_ICONS, CATEGORY_ICON_SETS, DEFAULT_ICON_SET } from './Lucide'

interface Props {
  /** معرّف القسم (slug) لتحديد المجموعة المعروضة */
  categorySlug?: string | null
  /** الأيقونة المختارة حالياً */
  value?: string | null
  onChange: (icon: string) => void
  /** عدد الأعمدة في الشبكة */
  columns?: number
}

/**
 * منتقي أيقونات ديناميكي:
 * يعرض فقط الأيقونات المرتبطة بالقسم المختار، فيختار المستخدم أنسب أيقونة لخدمته.
 * يتغيّر تلقائياً عند تغيير القسم.
 */
export default function IconPicker({ categorySlug, value, onChange, columns = 5 }: Props) {
  const [showAll, setShowAll] = useState(false)

  // المجموعة المناسبة للقسم — تتغيّر تلقائياً
  const set = useMemo(() => {
    const base = (categorySlug && CATEGORY_ICON_SETS[categorySlug]) || DEFAULT_ICON_SET
    return base
  }, [categorySlug])

  // الأيقونة الافتراضية للقسم
  const fallback = (categorySlug && CATEGORY_ICONS[categorySlug]) || set[0] || 'map-pin'
  const current = value || fallback

  return (
    <div className="icon-picker">
      <div className="icon-picker__head">
        <span className="icon-picker__label">أيقونة الخدمة</span>
        <span className="icon-picker__current">
          <Lucide name={current} size={18} />
          <span>{LUCIDE_LABELS[current] ?? current}</span>
        </span>
      </div>

      <div
        className="icon-picker__grid"
        style={{ gridTemplateColumns: `repeat(${columns}, 1fr)` }}
      >
        {set.map((n) => (
          <button
            type="button"
            key={n}
            className={`ipick ${current === n ? 'is-active' : ''}`}
            onClick={() => onChange(n)}
            title={LUCIDE_LABELS[n] ?? n}
            aria-pressed={current === n}
          >
            <Lucide name={n} size={22} />
            <span className="ipick__name">{LUCIDE_LABELS[n] ?? n}</span>
          </button>
        ))}
      </div>

      <button
        type="button"
        className="icon-picker__more"
        onClick={() => setShowAll((v) => !v)}
      >
        {showAll ? '▲ إخفاء باقي الأيقونات' : '▼ عرض كل الأيقونات'}
      </button>

      {showAll && (
        <div
          className="icon-picker__grid icon-picker__grid--all"
          style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(64px, 1fr))' }}
        >
          {/* كل أيقونات القسم أولاً ثم الباقي */}
          {Object.keys(LUCIDE_LABELS).map((n) => (
            <button
              type="button"
              key={n}
              className={`ipick ipick--sm ${current === n ? 'is-active' : ''}`}
              onClick={() => onChange(n)}
              title={LUCIDE_LABELS[n] ?? n}
              aria-pressed={current === n}
            >
              <Lucide name={n} size={18} />
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

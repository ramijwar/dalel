import { useNavigate } from 'react-router-dom'
import type { Service } from '../lib/types'
import { metaChips, telHref, waHref, timeAgo } from '../lib/utils'
import Icon from './Icon'
import CatIcon from './CatIcon'

interface Props {
  s: Service
  compact?: boolean
}

export default function ServiceCard({ s, compact = false }: Props) {
  const nav = useNavigate()
  const chips = metaChips(s)

  return (
    <article
      className={`svc ${s.status === 'open' ? 'svc--open' : 'svc--closed'} ${s.on_duty ? 'svc--duty' : ''} ${compact ? 'svc--compact' : ''}`}
      onClick={() => nav(`/s/${s.id}`)}
      role="link"
      tabIndex={0}
      onKeyDown={(e) => { if (e.key === 'Enter') nav(`/s/${s.id}`) }}
    >
      <div className="svc__badge">
        <span className={`svc__icon ${s.status === 'open' ? 'svc__icon--open' : ''}`}>
          <CatIcon icon={s.category_icon} meta={s.meta} size={20} />
        </span>
      </div>

      <div className="svc__body">
        <div className="svc__head">
          <h3 className="svc__name">{s.name}</h3>
          {s.is_verified && <span className="svc__verified" title="موثقة"><Icon name="shield" size={14} /></span>}
          <span className={`svc__status svc__status--${s.status}`}>
            {s.status === 'open' ? '🟢' : '🔴'} {s.status_label}
          </span>
        </div>

        {s.status_sublabel && <p className="svc__sub">{s.status_sublabel}</p>}

        {s.on_duty && <span className="svc__duty">🌙 مناوبة الآن</span>}

        {s.region_name && (
          <span className="svc__region"><Icon name="pin" size={13} /> {[s.region_name, s.governorate_name].filter(Boolean).join(' — ')}</span>
        )}

        {s.address && <p className="svc__addr">{s.address}</p>}

        {chips.length > 0 && (
          <div className="svc__chips">
            {chips.map((c, i) => (
              <span key={i} className="chip" title={c.label}><CatIcon icon={c.icon} size={13} /> {c.value}</span>
            ))}
          </div>
        )}

        {s.note && <p className="svc__note">{s.note}</p>}

        {s.schedule_count !== undefined && (
          <span className="svc__sched"><Icon name="clock" size={13} /> {s.schedule_count} فترة دوام</span>
        )}

        {s.updated_at && s.status_source === 'manual' && (
          <span className="svc__updated"><Icon name="refresh" size={12} /> تحديث يدوي {timeAgo(s.updated_at)}</span>
        )}
      </div>

      <div className="svc__actions" onClick={(e) => e.stopPropagation()}>
        {s.phone_intl && (
          <a href={telHref(s.phone_intl)} className="act act--phone" title="اتصال مباشر">
            <Icon name="phone" size={18} />
          </a>
        )}
        {s.whatsapp_number && (
          <a href={waHref(s.whatsapp_number)} className="act act--wa" target="_blank" rel="noopener" title="واتساب">
            <Icon name="whatsapp" size={18} />
          </a>
        )}
      </div>
    </article>
  )
}

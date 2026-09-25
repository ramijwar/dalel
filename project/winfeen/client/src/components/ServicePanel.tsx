import { Link } from 'react-router-dom'
import type { Service } from '../lib/types'
import { metaChips, telHref, waHref, timeAgo, fmtTime } from '../lib/utils'
import Icon from './Icon'
import CatIcon from './CatIcon'

interface Props {
  s: Service | null
  onClose?: () => void
}

/**
 * لوحة تعرض بيانات الخدمة الكاملة أسفل البطاقات.
 * تُحدَّث في مكانها عند اختيار خدمة أخرى.
 */
export default function ServicePanel({ s, onClose }: Props) {
  if (!s) return null

  const chips = metaChips(s)

  return (
    <section className="panel" aria-live="polite">
      <header className="panel__head">
        <span className="panel__icon"><CatIcon icon={s.category_icon} meta={s.meta} size={30} /></span>
        <div className="panel__title">
          <h3>
            {s.name}
            {s.is_verified && (
              <span className="svc__verified" title="موثقة"><Icon name="shield" size={14} /></span>
            )}
          </h3>
          <span className={`svc__status svc__status--${s.status}`}>
            {s.on_duty ? '🟤' : s.status === 'open' ? '🟢' : '🔴'} {s.status_label}
          </span>
        </div>
        {onClose && (
          <button className="iconbtn" onClick={onClose} aria-label="إغلاق">
            <Icon name="x" size={16} />
          </button>
        )}
      </header>

      {s.status_sublabel && <p className="panel__sub">{s.status_sublabel}</p>}

      {s.on_duty && (
        <span className="svc__duty">
          🌙 مناوبة الآن
          {s.duty_from && s.duty_to && ` · ${fmtTime(s.duty_from)} — ${fmtTime(s.duty_to)}`}
        </span>
      )}

      <dl className="panel__rows">
        {s.region_name && (
          <div className="panel__row">
            <dt><Icon name="pin" size={14} /> المنطقة</dt>
            <dd>{[s.region_name, s.governorate_name].filter(Boolean).join(' — ')}</dd>
          </div>
        )}
        {s.address && (
          <div className="panel__row">
            <dt><Icon name="map" size={14} /> العنوان</dt>
            <dd>{s.address}</dd>
          </div>
        )}
        {s.phone_intl && (
          <div className="panel__row">
            <dt><Icon name="phone" size={14} /> الهاتف</dt>
            <dd dir="ltr">{s.phone_intl}</dd>
          </div>
        )}
        {s.schedule_count !== undefined && s.schedule_count > 0 && (
          <div className="panel__row">
            <dt><Icon name="clock" size={14} /> الدوام</dt>
            <dd>{s.schedule_count} فترة دوام</dd>
          </div>
        )}
        {s.updated_at && s.status_source === 'manual' && (
          <div className="panel__row">
            <dt><Icon name="refresh" size={14} /> آخر تحديث</dt>
            <dd>{timeAgo(s.updated_at)}</dd>
          </div>
        )}
      </dl>

      {chips.length > 0 && (
        <div className="svc__chips">
          {chips.map((c, i) => (
            <span key={i} className="chip" title={c.label}><CatIcon icon={c.icon} size={13} /> {c.value}</span>
          ))}
        </div>
      )}

      {s.note && <p className="panel__note">{s.note}</p>}

      <div className="panel__actions">
        {s.phone_intl && (
          <a href={telHref(s.phone_intl)} className="btn btn--primary btn--sm">
            <Icon name="phone" size={15} /> اتصال
          </a>
        )}
        {s.whatsapp_number && (
          <a
            href={waHref(s.whatsapp_number)}
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn--whatsapp btn--sm"
          >
            <Icon name="whatsapp" size={15} /> واتساب
          </a>
        )}
        <Link to={`/s/${s.id}`} className="btn btn--ghost btn--sm">
          <Icon name="eye" size={15} /> صفحة الخدمة
        </Link>
      </div>
    </section>
  )
}

import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api } from '../lib/api'
import type { Service } from '../lib/types'
import { metaChips, telHref, waHref, fmtTime, dayLabel, timeAgo, copyText } from '../lib/utils'
import Icon from '../components/Icon'
import CatIcon from '../components/CatIcon'
import ServiceCard from '../components/ServiceCard'
import { useToast } from '../lib/useToast'

export default function ServiceDetail() {
  const { id } = useParams<{ id: string }>()
  const [svc, setSvc] = useState<Service | null>(null)
  const [nearby, setNearby] = useState<Service[]>([])
  const [loading, setLoading] = useState(true)
  const toast = useToast()

  useEffect(() => {
    if (!id) return
    setLoading(true)
    api.service(Number(id))
      .then((r) => { setSvc(r.service); setNearby(r.nearby) })
      .catch(() => { setSvc(null) })
      .finally(() => setLoading(false))
  }, [id])

  if (loading) return <main className="page"><div className="skeletons"><div className="skel-card" /></div></main>
  if (!svc) return <main className="page"><div className="empty-state"><h3>الخدمة غير موجودة</h3><Link to="/">العودة للرئيسية</Link></div></main>

  const chips = metaChips(svc)

  const handleCopy = () => {
    const text = `${svc.name}\n${svc.address}\n${svc.phone_intl}`
    copyText(text).then(() => toast('تم نسخ بيانات الخدمة'))
  }

  const handleShare = () => {
    const url = window.location.href
    if (navigator.share) {
      navigator.share({ title: svc.name, text: `${svc.name} — ${svc.address}`, url }).catch(() => {})
    } else {
      copyText(url).then(() => toast('تم نسخ الرابط'))
    }
  }

  return (
    <main className="page detail">
      <header className="detail__head">
        <Link to={svc.category_slug ? `/${svc.category_slug}` : '/'} className="back-btn">
          <Icon name="arrowRight" size={18} /> رجوع
        </Link>
      </header>

      <section className={`detail__card ${svc.status === 'open' ? 'is-open' : 'is-closed'}`}>
        <div className="detail__top">
          <span className="detail__icon"><CatIcon icon={svc.category_icon} meta={svc.meta} size={30} /></span>
          <div>
            <h1>{svc.name}</h1>
            {svc.is_verified && <span className="badge badge--verified"><Icon name="shield" size={14} /> موثقة</span>}
          </div>
        </div>

        <div className={`detail__status detail__status--${svc.status}`}>
          <span className="detail__status-label">{svc.status === 'open' ? '🟢' : '🔴'} {svc.status_label}</span>
          {svc.status_sublabel && <span className="detail__status-sub">{svc.status_sublabel}</span>}
          {svc.status_source === 'manual' && <span className="detail__status-note">تحديث يدوي من المسؤول عن الخدمة</span>}
        </div>

        <div className="detail__updated">
          <Icon name="refresh" size={15} />
          {svc.updated_at ? (
            <span>
              آخر تحديث للحالة: <strong>{timeAgo(svc.updated_at)}</strong>
              <span className="detail__updated-src">
                {svc.status_source === 'manual' ? ' (يدوي من المسؤول)' : ' (تلقائي حسب الجدول)'}
              </span>
            </span>
          ) : (
            <span>الحالة محسوبة تلقائياً من جدول الدوام</span>
          )}
        </div>

        {svc.on_duty && (
          <div className="detail__duty">
            <Icon name="moon" size={16} />
            <span>مناوبة الآن</span>
            {svc.duty_from && <span className="detail__duty-time">{timeAgo(svc.duty_from)}</span>}
          </div>
        )}

        {svc.address && (
          <div className="detail__row">
            <Icon name="pin" size={18} />
            <span>{svc.address}</span>
          </div>
        )}

        {svc.region_name && (
          <div className="detail__row">
            <Icon name="pin" size={16} />
            <span>{[svc.region_name, svc.governorate_name].filter(Boolean).join(' — ')}</span>
          </div>
        )}

        {chips.length > 0 && (
          <div className="detail__chips">
            {chips.map((c, i) => (
              <div key={i} className="detail-chip">
                <span className="detail-chip__icon"><CatIcon icon={c.icon} size={15} /></span>
                <span className="detail-chip__label">{c.label}</span>
                <span className="detail-chip__value">{c.value}</span>
              </div>
            ))}
          </div>
        )}

        {svc.note && <p className="detail__note">{svc.note}</p>}
      </section>

      {/* أزرار الاتصال */}
      <section className="detail__actions">
        {svc.phone_intl && (
          <a href={telHref(svc.phone_intl)} className="btn btn--phone">
            <Icon name="phone" size={20} /> اتصال مباشر
          </a>
        )}
        {svc.whatsapp_number && (
          <a href={waHref(svc.whatsapp_number)} className="btn btn--wa" target="_blank" rel="noopener">
            <span className="wa-icon">💬</span> واتساب
          </a>
        )}
        <button className="btn btn--outline" onClick={handleCopy}>
          <Icon name="copy" size={18} /> نسخ
        </button>
        <button className="btn btn--outline" onClick={handleShare}>
          <Icon name="share" size={18} /> مشاركة
        </button>
      </section>

      {/* زر إضافة خدمة */}
      <section className="detail__add-cta">
        <Link to="/request" className="btn btn--primary btn--block">
          <Icon name="plus" size={18} /> أضف خدمتك
        </Link>
      </section>

      {/* جدول الدوام */}
      {svc.schedule && svc.schedule.length > 0 && (
        <section className="detail__sched">
          <h2><Icon name="clock" size={18} /> جدول الدوام</h2>
          <div className="sched-table">
            {[0, 1, 2, 3, 4, 5, 6].map((d) => {
              const rows = svc.schedule!.filter((s) => s.day === d)
              return (
                <div key={d} className={`sched-row ${rows.length ? 'is-active' : ''} ${d === new Date().getDay() ? 'is-today' : ''}`}>
                  <span className="sched-row__day">{dayLabel(d)}</span>
                  {rows.length === 0 ? (
                    <span className="sched-row__val sched-row__val--off">عطلة</span>
                  ) : rows.map((r, i) => (
                    <span key={i} className="sched-row__val">{r.is_24h ? '24 ساعة' : `${fmtTime(r.opens)} — ${fmtTime(r.closes)}`}</span>
                  ))}
                </div>
              )
            })}
          </div>
        </section>
      )}

      {/* خدمات قريبة */}
      {nearby.length > 0 && (
        <section className="detail__nearby">
          <h2>خدمات قريبة في {svc.region_name}</h2>
          <div className="svc-grid svc-grid--small">
            {nearby.map((n) => <ServiceCard key={n.id} s={n} />)}
          </div>
        </section>
      )}
    </main>
  )
}

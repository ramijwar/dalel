import { useEffect, useMemo, useRef, useState } from 'react'
import Icon from './Icon'

export interface Announcement {
  title?: string
  text: string
  tone?: 'info' | 'warning' | 'danger' | 'success'
  link?: string
}

interface Props {
  items: Announcement[]
  /** زمن التبديل بالثواني — يأتي من إعدادات لوحة التحكم (1..60) */
  interval?: number
}

const TONE_ICON: Record<string, string> = {
  info: 'info',
  warning: 'alert-triangle',
  danger: 'siren',
  success: 'circle-check-big',
}

const TONE_LABEL: Record<string, string> = {
  info: 'إعلان',
  warning: 'تنبيه',
  danger: 'عاجل',
  success: 'جديد',
}

/**
 * شريط إعلانات دوّار (Carousel) أنيق — يعرض الإعلانات المضافة من لوحة التحكم.
 *
 * المميزات:
 *  - تبديل تلقائي بزمن يُضبط من الإعدادات (افتراضي ٥ ثوانٍ)
 *  - انتقال ناعم بالتلاشي والانزلاق، يحترم RTL
 *  - نقاط تنقّل + سهمان + شريط تقدّم
 *  - يُوقف مؤقتاً عند المرور بالفأرة أو إخفاء التبويب
 *  - يحترم prefers-reduced-motion
 *  - لا يعرض شيئاً إن لم تكن هناك إعلانات
 */
export default function AdCarousel({ items, interval = 5 }: Props) {
  const slides = useMemo(
    () => (items || []).filter((a) => (a.text || '').trim() !== ''),
    [items]
  )

  const n = slides.length
  const [i, setI] = useState(0)
  const [paused, setPaused] = useState(false)
  const [progress, setProgress] = useState(0)
  const [visible, setVisible] = useState(true)
  const timer = useRef<number | null>(null)
  const start = useRef(0)

  // زمن التبديل بالمللي ثانية — مُقيَّد بين ثانية ودقيقة
  const ms = Math.min(60, Math.max(1, Number(interval) || 5)) * 1000

  const reduced = useMemo(() => {
    try {
      return window.matchMedia('(prefers-reduced-motion: reduce)').matches
    } catch { return false }
  }, [])

  // أوقف التبديل إن كانت التبويب مخفية — لا تُهدر الموارد
  useEffect(() => {
    const onVis = () => setVisible(document.visibilityState === 'visible')
    document.addEventListener('visibilitychange', onVis)
    return () => document.removeEventListener('visibilitychange', onVis)
  }, [])

  // أعد الفهرس ضمن المدى عند تغيّر عدد الشرائح
  useEffect(() => { setI((cur) => (n ? Math.min(cur, n - 1) : 0)) }, [n])

  const go = (next: number) => { if (n) setI(((next % n) + n) % n); }

  useEffect(() => {
    if (n < 2 || paused || !visible) { setProgress(0); return }
    start.current = Date.now()
    setProgress(0)

    const tick = () => {
      const el = Date.now() - start.current
      setProgress(Math.min(100, (el / ms) * 100))
      if (el >= ms) { go(i + 1); return }
      timer.current = window.setTimeout(tick, 60)
    }
    timer.current = window.setTimeout(tick, 60)
    return () => { if (timer.current) window.clearTimeout(timer.current) }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [i, n, ms, paused, visible])

  if (n === 0) return null

  const cur = slides[i]
  const tone = cur.tone || 'info'
  const clickable = !!cur.link

  const inner = (
    <div className={`ad__body ad__body--${tone}`}>
      <span className="ad__icon" aria-hidden="true">
        <Icon name={TONE_ICON[tone] || 'info'} size={22} />
      </span>
      <div className="ad__text">
        <span className="ad__tone">{TONE_LABEL[tone] || 'إعلان'}</span>
        {cur.title ? <strong className="ad__title">{cur.title}</strong> : null}
        <span className="ad__msg">{cur.text}</span>
      </div>
      {clickable && <span className="ad__go"><Icon name="chevron-left" size={16} /></span>}
    </div>
  )

  return (
    <section
      className={`ad-carousel${reduced ? ' ad-carousel--noanim' : ''}`}
      aria-label="الإعلانات"
      dir="rtl"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocus={() => setPaused(true)}
      onBlur={() => setPaused(false)}
    >
      <div className="ad__stage">
        {clickable ? (
          <a key={i} className="ad__slide ad__slide--link" href={cur.link} rel="noopener noreferrer">{inner}</a>
        ) : (
          <div key={i} className="ad__slide">{inner}</div>
        )}
      </div>

      {n > 1 && (
        <>
          <button
            type="button" className="ad__nav ad__nav--prev"
            onClick={() => go(i + 1)} aria-label="الإعلان السابق"
          ><Icon name="chevron-right" size={16} /></button>
          <button
            type="button" className="ad__nav ad__nav--next"
            onClick={() => go(i - 1)} aria-label="الإعلان التالي"
          ><Icon name="chevron-left" size={16} /></button>

          <div className="ad__dots" role="tablist" aria-label="تنقّل الإعلانات">
            {slides.map((_, k) => (
              <button
                key={k} type="button" role="tab"
                aria-selected={k === i} aria-label={`الإعلان ${k + 1}`}
                className={`ad__dot${k === i ? ' is-active' : ''}`}
                onClick={() => go(k)}
              />
            ))}
          </div>

          <div className="ad__progress" aria-hidden="true">
            <span style={{ width: `${progress}%` }} />
          </div>
        </>
      )}
    </section>
  )
}

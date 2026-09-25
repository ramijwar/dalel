import { useMemo, useState } from 'react'
import Icon from './Icon'
import { DAY_NAMES, type ScheduleRow } from '../lib/types'
import { fmtTime } from '../lib/utils'

interface Props {
  value: ScheduleRow[]
  onChange: (rows: ScheduleRow[]) => void
  defaultOpens?: string
  defaultCloses?: string
}

interface DayState {
  enabled: boolean
  is24: boolean
  periods: { opens: string; closes: string }[]
}

function toDayState(rows: ScheduleRow[], dO: string, dC: string): DayState[] {
  const out: DayState[] = DAY_NAMES.map(() => ({ enabled: false, is24: false, periods: [{ opens: dO, closes: dC }] }))
  rows.forEach((r) => {
    const d = out[r.day]
    if (!d) return
    d.enabled = true
    if (r.is_24h) { d.is24 = true; d.periods = [{ opens: '00:00', closes: '23:59' }] }
    else {
      if (d.is24) { d.is24 = false; d.periods = [] }
      d.periods.push({ opens: r.opens, closes: r.closes })
    }
  })
  // إزالة الفترة الافتراضية إن أُضيفت فترات فعلية
  out.forEach((d) => { if (d.enabled && !d.is24 && d.periods.length > 1 && d.periods[0].opens === dO && d.periods[0].closes === dC) d.periods.shift() })
  return out
}

function fromDayState(days: DayState[]): ScheduleRow[] {
  const out: ScheduleRow[] = []
  days.forEach((d, day) => {
    if (!d.enabled) return
    if (d.is24) { out.push({ day, opens: '00:00', closes: '23:59', is_24h: true }); return }
    d.periods.forEach((p) => {
      if (p.opens && p.closes && p.opens !== p.closes) out.push({ day, opens: p.opens, closes: p.closes, is_24h: false })
    })
  })
  return out
}

export default function ScheduleEditor({ value, onChange, defaultOpens = '09:00', defaultCloses = '21:00' }: Props) {
  const [days, setDays] = useState<DayState[]>(() => toDayState(value, defaultOpens, defaultCloses))

  const push = (next: DayState[]) => {
    setDays(next)
    onChange(fromDayState(next))
  }

  const patch = (i: number, p: Partial<DayState>) => {
    const next = days.map((d, idx) => (idx === i ? { ...d, ...p } : d))
    push(next)
  }

  const setAll = (on: boolean) => push(days.map((d) => ({ ...d, enabled: on })))
  const setWeek = () => push(days.map((d, i) => ({ ...d, enabled: i !== 5 && i !== 6 })))
  const setWeekend = () => push(days.map((d, i) => ({ ...d, enabled: i === 5 || i === 6 })))
  const set24All = () => push(days.map((d) => ({ ...d, enabled: true, is24: true, periods: [{ opens: '00:00', closes: '23:59' }] })))

  const applyTimeToAll = (opens: string, closes: string) =>
    push(days.map((d) => (d.enabled && !d.is24 ? { ...d, periods: [{ opens, closes }] } : d)))

  const enabledCount = days.filter((d) => d.enabled).length
  const summary = useMemo(() => {
    const rows = fromDayState(days)
    if (!rows.length) return 'لا يوجد دوام محدد — ستظهر الخدمة مغلقة'
    return `${rows.length} فترة دوام على ${enabledCount} ${enabledCount === 1 ? 'يوم' : 'أيام'}`
  }, [days, enabledCount])

  const todayIdx = new Date().getDay()

  return (
    <div className="sched">
      <div className="sched__quick">
        <button type="button" className="qbtn" onClick={() => setAll(true)}><Icon name="check" size={14} /> كل الأيام</button>
        <button type="button" className="qbtn" onClick={setWeek}>أيام الأسبوع</button>
        <button type="button" className="qbtn" onClick={setWeekend}>العطلة (جمعة/سبت)</button>
        <button type="button" className="qbtn qbtn--accent" onClick={set24All}><Icon name="moon" size={14} /> دوام 24 ساعة</button>
        <button type="button" className="qbtn" onClick={() => setAll(false)}><Icon name="x" size={14} /> تفريغ</button>
      </div>

      <div className="sched__copy">
        <span>نسخ وقت موحّد للأيام المحددة:</span>
        <input type="time" defaultValue={defaultOpens} onChange={(e) => applyTimeToAll(e.target.value, days.find((d) => d.enabled && !d.is24)?.periods[0]?.closes ?? defaultCloses)} aria-label="من الساعة" />
        <span>—</span>
        <input type="time" defaultValue={defaultCloses} onChange={(e) => applyTimeToAll(days.find((d) => d.enabled && !d.is24)?.periods[0]?.opens ?? defaultOpens, e.target.value)} aria-label="إلى الساعة" />
      </div>

      <ul className="sched__days">
        {days.map((d, i) => (
          <li key={i} className={`day ${d.enabled ? 'is-on' : ''} ${i === todayIdx ? 'is-today' : ''}`}>
            <button
              type="button"
              className="day__toggle"
              aria-pressed={d.enabled}
              onClick={() => patch(i, { enabled: !d.enabled, periods: d.periods.length ? d.periods : [{ opens: defaultOpens, closes: defaultCloses }] })}
            >
              <span className="day__name">{DAY_NAMES[i]}</span>
              {i === todayIdx && <span className="day__today">اليوم</span>}
              <span className="day__state">{d.enabled ? (d.is24 ? '24 ساعة' : fmtTime(d.periods[0]?.opens) + ' - ' + fmtTime(d.periods[d.periods.length - 1]?.closes)) : 'عطلة'}</span>
            </button>

            {d.enabled && (
              <div className="day__body">
                <label className="chk">
                  <input type="checkbox" checked={d.is24} onChange={(e) => patch(i, { is24: e.target.checked })} />
                  <span>مفتوح 24 ساعة</span>
                </label>

                {!d.is24 && (
                  <div className="day__periods">
                    {d.periods.map((p, pi) => (
                      <div key={pi} className="period">
                        <span className="period__lbl">{d.periods.length > 1 ? `فترة ${pi + 1}` : 'من — إلى'}</span>
                        <input
                          type="time" value={p.opens} aria-label="من"
                          onChange={(e) => {
                            const periods = d.periods.map((x, xi) => (xi === pi ? { ...x, opens: e.target.value } : x))
                            patch(i, { periods })
                          }}
                        />
                        <span className="period__dash">—</span>
                        <input
                          type="time" value={p.closes} aria-label="إلى"
                          onChange={(e) => {
                            const periods = d.periods.map((x, xi) => (xi === pi ? { ...x, closes: e.target.value } : x))
                            patch(i, { periods })
                          }}
                        />
                        {d.periods.length > 1 && (
                          <button type="button" className="iconbtn iconbtn--danger" aria-label="حذف الفترة"
                            onClick={() => patch(i, { periods: d.periods.filter((_, xi) => xi !== pi) })}>
                            <Icon name="trash" size={14} />
                          </button>
                        )}
                      </div>
                    ))}
                    <button
                      type="button" className="qbtn qbtn--sm"
                      onClick={() => patch(i, { periods: [...d.periods, { opens: defaultOpens, closes: defaultCloses }] })}
                    >
                      <Icon name="plus" size={13} /> فترة إضافية
                    </button>
                    <p className="hint">يمكن أن يعبر الدوام منتصف الليل (مثال: 22:00 — 06:00) ليُحتسب مناوبة ليلية.</p>
                  </div>
                )}
              </div>
            )}
          </li>
        ))}
      </ul>

      <p className="sched__summary"><Icon name="clock" size={14} /> {summary}</p>
    </div>
  )
}

import { useCallback, useEffect, useState } from 'react'
import { api } from '../lib/api'
import { useToast } from '../lib/useToast'
import Icon from './Icon'
import { num } from '../lib/utils'

/** كلمة التأكيد المطلوبة لتفعيل الحذف */
const CONFIRM_WORD = 'احذف'

interface Target {
  key: string
  label: string
  /** مفتاح العدّاد في استجابة الخادم */
  countKey: string
  desc: string
  icon: string
  danger?: boolean
}

const TARGETS: Target[] = [
  { key: 'services',     countKey: 'services',     label: 'الخدمات',        desc: 'كل الخدمات مع جداول دوامها وحالاتها',            icon: 'boxes',     danger: true },
  { key: 'requests',     countKey: 'requests',     label: 'الطلبات',        desc: 'طلبات إضافة الخدمات المُقدَّمة من المستخدمين',    icon: 'inbox' },
  { key: 'regions',      countKey: 'regions',      label: 'المناطق',        desc: 'المدن والقرى (تُفصل الخدمات عنها ولا تُحذف)',     icon: 'map-pin' },
  { key: 'governorates', countKey: 'governorates', label: 'المحافظات',      desc: 'المحافظات (تُفصل المناطق عنها ولا تُحذف)',        icon: 'map' },
  { key: 'users',        countKey: 'users',        label: 'المستخدمون',     desc: 'كل المستخدمين ما عدا حسابك الحالي',              icon: 'users', danger: true },
  { key: 'activity',     countKey: 'activity',     label: 'سجل النشاط',     desc: 'سجل العمليات والتغييرات',                        icon: 'activity' },
]

/**
 * منطقة الخطر — تفريغ بيانات قاعدة البيانات.
 *
 * الحماية على ثلاث طبقات:
 *  1. اختيار صريح لأنواع البيانات
 *  2. نافذة تأكيد من المتصفح
 *  3. كتابة كلمة «احذف» يدوياً (يتحقق منها الخادم أيضاً)
 */
export default function DangerZone() {
  const toast = useToast()
  const [counts, setCounts] = useState<Record<string, number>>({})
  const [selected, setSelected] = useState<string[]>([])
  const [confirm, setConfirm] = useState('')
  const [busy, setBusy] = useState(false)
  const [loading, setLoading] = useState(true)

  const load = useCallback(() => {
    setLoading(true)
    api.admin.dataCounts()
      .then((r) => setCounts(r.counts ?? {}))
      .catch(() => toast('تعذّر جلب عدّادات البيانات', 'error'))
      .finally(() => setLoading(false))
  }, [toast])

  useEffect(() => { load() }, [load])

  const toggle = (key: string) =>
    setSelected((prev) => (prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key]))

  const wordOk = confirm.trim() === CONFIRM_WORD
  const canClear = selected.length > 0 && wordOk && !busy

  const totalSelected = selected.reduce(
    (sum, k) => sum + (counts[TARGETS.find((t) => t.key === k)?.countKey ?? ''] ?? 0), 0
  )

  const doClear = async () => {
    if (!canClear) return
    const names = selected.map((k) => TARGETS.find((t) => t.key === k)?.label ?? k).join('، ')
    if (!window.confirm(
      `⚠️ تحذير نهائي\n\nسيتم حذف نهائياً:\n${names}\n\nالإجمالي: ${num(totalSelected)} سجل\n\nهذا الإجراء لا يمكن التراجع عنه. هل أنت متأكد؟`
    )) return

    setBusy(true)
    try {
      const r = await api.admin.clearData(selected, confirm.trim())
      const parts = Object.entries(r.deleted ?? {})
        .filter(([, v]) => (v as number) > 0)
        .map(([k, v]) => `${k}: ${num(v as number)}`)
      toast(`تم التفريغ — ${parts.join(' · ') || 'لا شيء'}`, 'success')
      setSelected([]); setConfirm('')
      load()
    } catch (err: any) { toast(err.message, 'error') }
    setBusy(false)
  }

  return (
    <div className="danger">
      <div className="danger__head">
        <Icon name="alert-triangle" size={18} />
        <div>
          <h4>منطقة الخطر</h4>
          <p>تفريغ بيانات قاعدة البيانات. <strong>لا يمكن التراجع عن هذه العمليات.</strong></p>
        </div>
      </div>

      {loading ? (
        <p className="danger__loading">جاري حساب البيانات…</p>
      ) : (
        <>
          <div className="danger__list">
            {TARGETS.map((t) => {
              const n = counts[t.countKey] ?? 0
              const on = selected.includes(t.key)
              return (
                <label key={t.key} className={`danger__item${on ? ' is-on' : ''}${n === 0 ? ' is-empty' : ''}`}>
                  <input type="checkbox" checked={on} onChange={() => toggle(t.key)} />
                  <span className="danger__icon"><Icon name={t.icon} size={16} /></span>
                  <span className="danger__text">
                    <strong>{t.label}</strong>
                    <em>{t.desc}</em>
                  </span>
                  <span className={`danger__count${n === 0 ? ' is-zero' : ''}`}>{num(n)}</span>
                </label>
              )
            })}
          </div>

          {selected.length > 0 && (
            <div className="danger__confirm">
              <p className="danger__summary">
                المحدد: <strong>{selected.length}</strong> نوع ·{' '}
                <strong>{num(totalSelected)}</strong> سجل
                {selected.includes('services') && (counts.schedules ?? 0) > 0 && (
                  <> (مع {num(counts.schedules)} جدول دوام)</>
                )}
              </p>

              <label className="danger__word">
                <span>
                  اكتب كلمة <code>{CONFIRM_WORD}</code> للتأكيد:
                </span>
                <input
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  placeholder={CONFIRM_WORD}
                  autoComplete="off"
                  dir="rtl"
                />
              </label>

              <button
                type="button"
                className="btn btn--danger"
                disabled={!canClear}
                onClick={doClear}
              >
                <Icon name="trash-2" size={15} />
                {busy ? 'جاري التفريغ…' : 'تفريغ البيانات المحددة'}
              </button>
              {!wordOk && selected.length > 0 && (
                <p className="danger__hint">اكتب «{CONFIRM_WORD}» لتفعيل الزر</p>
              )}
            </div>
          )}
        </>
      )}
    </div>
  )
}

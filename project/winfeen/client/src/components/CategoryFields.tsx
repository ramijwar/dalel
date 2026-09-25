import { useMemo, useState, useRef, useEffect } from 'react'
import Lucide, { LUCIDE_LABELS } from './Lucide'
import type { CategoryField, FieldOption, FieldType, ResolvedField } from '../lib/types'
import { FIELD_TYPES } from '../lib/types'

/* ══════════════════════════════════════════════════════════════
 *  ١) منتقي خيار قابل للبحث
 *  يعرض الأيقونة + نص الخيار، مع حقل بحث سريع يفلتر القائمة
 * ══════════════════════════════════════════════════════════════ */

interface OptionPickerProps {
  options: FieldOption[]
  value: string
  onChange: (v: string) => void
  placeholder?: string
  /** أيقونة افتراضية تُعرض إن لم يكن للخيار أيقونة */
  fallbackIcon?: string
}

export function OptionPicker({
  options,
  value,
  onChange,
  placeholder = 'ابحث واختر…',
  fallbackIcon = 'circle-dot',
}: OptionPickerProps) {
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState('')
  const boxRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  const selected = useMemo(
    () => options.find((o) => String(o.value) === String(value) || String(o.id) === String(value)),
    [options, value],
  )

  // أغلق القائمة عند النقر خارجها
  useEffect(() => {
    if (!open) return
    const onDoc = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    return () => document.removeEventListener('mousedown', onDoc)
  }, [open])

  // ركّز على حقل البحث عند الفتح
  useEffect(() => {
    if (open) setTimeout(() => inputRef.current?.focus(), 30)
    else setQ('')
  }, [open])

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    if (!needle) return options
    return options.filter((o) => o.label.toLowerCase().includes(needle))
  }, [options, q])

  return (
    <div className="opt-picker" ref={boxRef}>
      <button
        type="button"
        className={`opt-picker__trigger${open ? ' is-open' : ''}`}
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
      >
        <span className="opt-picker__icon">
          <Lucide name={selected?.icon || fallbackIcon} size={17} />
        </span>
        <span className={`opt-picker__text${selected ? '' : ' is-muted'}`}>
          {selected?.label || placeholder}
        </span>
        <span className="opt-picker__chevron">
          <Lucide name="chevron-down" size={15} />
        </span>
      </button>

      {open && (
        <div className="opt-picker__panel">
          <div className="opt-picker__search">
            <Lucide name="search" size={15} />
            <input
              ref={inputRef}
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="بحث سريع…"
              aria-label="بحث في الخيارات"
            />
            {q && (
              <button type="button" onClick={() => setQ('')} aria-label="مسح البحث">
                <Lucide name="x" size={14} />
              </button>
            )}
          </div>

          <div className="opt-picker__list" role="listbox">
            {filtered.length === 0 && (
              <div className="opt-picker__empty">لا توجد نتائج مطابقة</div>
            )}
            {filtered.map((o) => {
              const isSel = String(o.value) === String(value) || String(o.id) === String(value)
              return (
                <button
                  key={o.id || o.value}
                  type="button"
                  role="option"
                  aria-selected={isSel}
                  className={`opt-picker__item${isSel ? ' is-selected' : ''}`}
                  onClick={() => {
                    // نُخزّن القيمة المستقرّة (value) إن وُجدت، وإلا المُعرّف
                    onChange(o.value || String(o.id))
                    setOpen(false)
                  }}
                >
                  <span className="opt-picker__item-icon">
                    <Lucide name={o.icon || fallbackIcon} size={16} />
                  </span>
                  <span className="opt-picker__item-label">{o.label}</span>
                  {isSel && (
                    <span className="opt-picker__check">
                      <Lucide name="check" size={15} />
                    </span>
                  )}
                </button>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}

/* ══════════════════════════════════════════════════════════════
 *  ٢) الحقول الديناميكية — تُرسم حسب تعريفات قسم الخدمة
 * ══════════════════════════════════════════════════════════════ */

export type FieldValues = Record<string, any>

interface DynamicFieldsProps {
  fields: CategoryField[]
  values: FieldValues
  onChange: (key: string, value: any) => void
}

export function DynamicFields({ fields, values, onChange }: DynamicFieldsProps) {
  if (!fields.length) return null

  return (
    <div className="dyn-fields">
      {fields.map((f) => {
        const val = values[f.key] ?? ''
        const uid = `fld-${f.key}`

        return (
          <div className="dyn-fields__row" key={f.key}>
            <label className="dyn-fields__label" htmlFor={uid}>
              {f.label}
              {f.required && <span className="req">*</span>}
            </label>

            {/* ─── قائمة اختيار ─── */}
            {f.type === 'select' && (
              <OptionPicker
                options={f.options || []}
                value={String(val)}
                onChange={(v) => onChange(f.key, v)}
                placeholder={f.placeholder || `اختر ${f.label}…`}
              />
            )}

            {/* ─── نص قصير ─── */}
            {f.type === 'text' && (
              <input
                id={uid}
                className="inp"
                type="text"
                value={val}
                placeholder={f.placeholder || ''}
                onChange={(e) => onChange(f.key, e.target.value)}
              />
            )}

            {/* ─── نص طويل ─── */}
            {f.type === 'textarea' && (
              <textarea
                id={uid}
                className="inp"
                rows={3}
                value={val}
                placeholder={f.placeholder || ''}
                onChange={(e) => onChange(f.key, e.target.value)}
              />
            )}

            {/* ─── رقم ─── */}
            {f.type === 'number' && (
              <input
                id={uid}
                className="inp"
                type="number"
                value={val}
                placeholder={f.placeholder || ''}
                onChange={(e) => onChange(f.key, e.target.value)}
              />
            )}

            {/* ─── نعم / لا ─── */}
            {f.type === 'boolean' && (
              <label className="chk">
                <input
                  type="checkbox"
                  checked={val === true || val === '1' || val === 1}
                  onChange={(e) => onChange(f.key, e.target.checked)}
                />
                <span>{f.placeholder || 'نعم'}</span>
              </label>
            )}

            {f.help && <small className="dyn-fields__help">{f.help}</small>}
          </div>
        )
      })}
    </div>
  )
}

/* ══════════════════════════════════════════════════════════════
 *  ٣) باني الحقول — يُستخدم في نموذج إضافة/تعديل قسم
 * ══════════════════════════════════════════════════════════════ */

/** حقل قيد التحرير (قد لا يكون محفوظاً بعد) */
export interface DraftField {
  _uid: string
  id?: number
  key: string
  label: string
  type: FieldType
  required: boolean
  placeholder: string
  /** وحدة تُلحَق بعد الرقم في العرض */
  suffix: string
  /** للحقول المنطقية: إخفاء القيمة إن كانت «لا» */
  hide_when_false: boolean
  show_in_card: boolean
  filterable: boolean
  options: DraftOption[]
}

export interface DraftOption {
  _uid: string
  id?: number
  label: string
  value: string
  icon: string
}

let seq = 0
const uid = () => `d${Date.now().toString(36)}${(seq++).toString(36)}`

export const emptyOption = (): DraftOption => ({ _uid: uid(), label: '', value: '', icon: '' })

export const emptyField = (): DraftField => ({
  _uid: uid(),
  key: '',
  label: '',
  type: 'select',
  required: false,
  placeholder: '',
  suffix: '',
  hide_when_false: false,
  show_in_card: true,
  filterable: false,
  options: [emptyOption()],
})

/** يحوّل حقولاً محفوظة من الخادم إلى مسوّدة قابلة للتحرير */
export function toDraft(fields: CategoryField[]): DraftField[] {
  return fields.map((f) => ({
    _uid: uid(),
    id: f.id,
    key: f.key,
    label: f.label,
    type: f.type,
    required: !!f.required,
    placeholder: f.placeholder || '',
    suffix: f.suffix || '',
    hide_when_false: !!f.hide_when_false,
    show_in_card: !!f.show_in_card,
    filterable: !!f.filterable,
    options: (f.options || []).map((o) => ({
      _uid: uid(),
      id: o.id,
      label: o.label,
      value: o.value,
      icon: o.icon || '',
    })),
  }))
}

interface FieldsBuilderProps {
  fields: DraftField[]
  onChange: (fields: DraftField[]) => void
}

export function FieldsBuilder({ fields, onChange }: FieldsBuilderProps) {
  const patch = (targetUid: string, part: Partial<DraftField>) =>
    onChange(fields.map((f) => (f._uid === targetUid ? { ...f, ...part } : f)))

  const addField = () => onChange([...fields, emptyField()])

  const removeField = (targetUid: string) =>
    onChange(fields.filter((f) => f._uid !== targetUid))

  const addOption = (fieldUid: string) => {
    const f = fields.find((x) => x._uid === fieldUid)
    if (!f) return
    patch(fieldUid, { options: [...f.options, emptyOption()] })
  }

  const patchOption = (fieldUid: string, optUid: string, part: Partial<DraftOption>) => {
    const f = fields.find((x) => x._uid === fieldUid)
    if (!f) return
    patch(fieldUid, {
      options: f.options.map((o) => (o._uid === optUid ? { ...o, ...part } : o)),
    })
  }

  const removeOption = (fieldUid: string, optUid: string) => {
    const f = fields.find((x) => x._uid === fieldUid)
    if (!f) return
    patch(fieldUid, { options: f.options.filter((o) => o._uid !== optUid) })
  }

  return (
    <div className="fb">
      {fields.length === 0 && (
        <p className="fb__empty">
          لا توجد حقول إضافية لهذا القسم. اضغط «إضافة حقل» لتعريف حقل خاص
          (مثل الاختصاص للأطباء).
        </p>
      )}

      {fields.map((f, fi) => (
        <div className="fb__field" key={f._uid}>
          <div className="fb__field-head">
            <span className="fb__index">{fi + 1}</span>
            <input
              className="inp inp--sm"
              value={f.label}
              placeholder="عنوان الحقل (مثال: الاختصاص)"
              onChange={(e) => patch(f._uid, { label: e.target.value })}
            />
            <button
              type="button"
              className="btn btn--icon btn--danger"
              onClick={() => removeField(f._uid)}
              title="حذف الحقل"
              aria-label="حذف الحقل"
            >
              <Lucide name="trash-2" size={15} />
            </button>
          </div>

          <div className="fb__grid">
            <label className="fb__cell">
              <span>المفتاح (إنجليزي)</span>
              <input
                className="inp inp--sm"
                dir="ltr"
                value={f.key}
                placeholder="specialty"
                onChange={(e) => patch(f._uid, { key: e.target.value })}
              />
            </label>

            <label className="fb__cell">
              <span>النوع</span>
              <select
                className="inp inp--sm"
                value={f.type}
                onChange={(e) => patch(f._uid, { type: e.target.value as FieldType })}
              >
                {FIELD_TYPES.map((t) => (
                  <option key={t.value} value={t.value}>
                    {t.label}
                  </option>
                ))}
              </select>
            </label>

            <label className="fb__cell">
              <span>نص إرشادي</span>
              <input
                className="inp inp--sm"
                value={f.placeholder}
                placeholder="ابحث عن الاختصاص…"
                onChange={(e) => patch(f._uid, { placeholder: e.target.value })}
              />
            </label>

            {/* الوحدة — تُلحَق بعد القيمة الرقمية (سعر المعاينة ← 15,000 ل.س) */}
            {f.type === 'number' && (
              <label className="fb__cell">
                <span>الوحدة (اختياري)</span>
                <input
                  className="inp inp--sm"
                  value={f.suffix}
                  placeholder="ل.س"
                  onChange={(e) => patch(f._uid, { suffix: e.target.value })}
                />
              </label>
            )}
          </div>

          <div className="fb__flags">
            <label className="chk chk--sm">
              <input
                type="checkbox"
                checked={f.required}
                onChange={(e) => patch(f._uid, { required: e.target.checked })}
              />
              <span>إلزامي</span>
            </label>
            <label className="chk chk--sm">
              <input
                type="checkbox"
                checked={f.show_in_card}
                onChange={(e) => patch(f._uid, { show_in_card: e.target.checked })}
              />
              <span>يظهر في البطاقة</span>
            </label>
            <label className="chk chk--sm">
              <input
                type="checkbox"
                checked={f.filterable}
                onChange={(e) => patch(f._uid, { filterable: e.target.checked })}
              />
              <span>قابل للفلترة</span>
            </label>

            {/* للحقول المنطقية فقط: لا تُعرض القيمة إن كانت «لا» */}
            {f.type === 'boolean' && (
              <label className="chk chk--sm" title="يمنع ظهور «لا» لكل خدمة تفتقد الميزة">
                <input
                  type="checkbox"
                  checked={f.hide_when_false}
                  onChange={(e) => patch(f._uid, { hide_when_false: e.target.checked })}
                />
                <span>إخفاء عند «لا»</span>
              </label>
            )}
          </div>

          {/* ─── خيارات القائمة ─── */}
          {f.type === 'select' && (
            <div className="fb__options">
              <div className="fb__options-head">
                <span>
                  <Lucide name="list" size={13} /> خيارات القائمة ({f.options.length})
                </span>
              </div>

              {f.options.map((o) => (
                <div className="fb__opt" key={o._uid}>
                  {/* أيقونة الخيار */}
                  <span className="fb__opt-icon" title="أيقونة الخيار">
                    <Lucide name={o.icon || 'circle-dot'} size={16} />
                  </span>
                  <input
                    className="inp inp--sm fb__opt-icon-in"
                    dir="ltr"
                    value={o.icon}
                    placeholder="stethoscope"
                    onChange={(e) => patchOption(f._uid, o._uid, { icon: e.target.value })}
                    aria-label="اسم الأيقونة"
                    list="lucide-icon-names"
                  />
                  <input
                    className="inp inp--sm"
                    value={o.label}
                    placeholder="اسم الخيار (مثال: أمراض قلبية)"
                    onChange={(e) => patchOption(f._uid, o._uid, { label: e.target.value })}
                  />
                  <input
                    className="inp inp--sm fb__opt-val"
                    dir="ltr"
                    value={o.value}
                    placeholder="القيمة (اختياري)"
                    onChange={(e) => patchOption(f._uid, o._uid, { value: e.target.value })}
                  />
                  <button
                    type="button"
                    className="btn btn--icon btn--danger"
                    onClick={() => removeOption(f._uid, o._uid)}
                    title="حذف الخيار"
                    aria-label="حذف الخيار"
                  >
                    <Lucide name="x" size={14} />
                  </button>
                </div>
              ))}

              <button type="button" className="btn btn--ghost btn--sm" onClick={() => addOption(f._uid)}>
                <Lucide name="plus" size={14} /> خيار إضافي
              </button>
            </div>
          )}
        </div>
      ))}

      <button type="button" className="btn btn--ghost" onClick={addField}>
        <Lucide name="plus" size={15} /> إضافة حقل
      </button>

      {/* قائمة أسماء الأيقونات المقترحة */}
      <datalist id="lucide-icon-names">
        {Object.keys(LUCIDE_LABELS).slice(0, 80).map((n) => (
          <option key={n} value={n} />
        ))}
      </datalist>
    </div>
  )
}

/* ══════════════════════════════════════════════════════════════
 *  ٤) عرض قيم الحقول المحلولة (بطاقة الخدمة / التفاصيل)
 * ══════════════════════════════════════════════════════════════ */

export function ResolvedFieldChips({
  fields,
  limit,
  className = '',
}: {
  fields?: ResolvedField[]
  limit?: number
  className?: string
}) {
  if (!fields || fields.length === 0) return null
  const shown = limit ? fields.slice(0, limit) : fields

  return (
    <div className={`field-chips ${className}`}>
      {shown.map((f) => (
        <span className="field-chip" key={f.key} title={`${f.label}: ${f.display}`}>
          {f.icon && <Lucide name={f.icon} size={13} />}
          <span className="field-chip__text">{f.display}</span>
        </span>
      ))}
    </div>
  )
}

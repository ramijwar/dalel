import type { CategoryField, Service } from '../lib/types'
import Icon from './Icon'
import Lucide from './Lucide'

/**
 * ══════════════════════════════════════════════════════════════════
 *  فلاتر الحقول الديناميكية
 * ══════════════════════════════════════════════════════════════════
 *
 *  تُبنى تلقائياً من تعريفات القسم: كل حقل عليه «قابل للفلترة» يظهر هنا،
 *  فيعمل قسم الأطباء (اختصاص) والكازيات (بنزين/مازوت) والسرفيس (النوع/الاتجاه)
 *  بلا أي تعديل على الكود عند إضافة قسم جديد.
 *
 *  كان علم «قابل للفلترة» يُحفظ في قاعدة البيانات ولا يُقرأ في أي مكان —
 *  أي أنه كان بلا أثر. هذا المكوّن يمنحه معناه.
 *
 *  التصفية تجري محلياً على العناصر المحمّلة (٣٠٠ كحد أقصى للقسم) فهي فورية
 *  بلا طلب شبكة إضافي، ولا تُفقد أي نتيجة لأن أكبر قسم فيه ٢٤٢ خدمة.
 * ══════════════════════════════════════════════════════════════════
 */

/** قيمة الفلتر المختارة: مفتاح الحقل ← القيمة المطلوبة */
export type FieldFilterState = Record<string, string>

interface Props {
  fields: CategoryField[]
  value: FieldFilterState
  onChange: (v: FieldFilterState) => void
  /** عدد النتائج المطابقة — يُعرض بجانب زر المسح */
  matchCount: number
  /** العدد الكلي قبل التصفية */
  totalCount: number
}

export default function FieldFilters({ fields, value, onChange, matchCount, totalCount }: Props) {
  // نعرض الحقول القابلة للفلترة فقط، وتلك التي لها خيارات أو منطقية
  const usable = fields.filter(
    (f) => f.filterable && (f.type === 'boolean' || (f.type === 'select' && f.options.length > 0)),
  )
  if (usable.length === 0) return null

  const activeCount = Object.values(value).filter((v) => v !== '').length

  const toggle = (key: string, val: string) =>
    onChange({ ...value, [key]: value[key] === val ? '' : val })

  return (
    <div className="ffilters">
      {usable.map((f) => (
        <div className="ffilters__row" key={f.key}>
          <span className="ffilters__label">
            <Icon name="filter" size={13} />
            {f.label}
          </span>

          <div className="ffilters__opts">
            {/* ─── حقل منطقي: خيار واحد «متوفر» ─── */}
            {f.type === 'boolean' && (
              <button
                className={`chip-btn ${value[f.key] === '1' ? 'is-active' : ''}`}
                onClick={() => toggle(f.key, '1')}
              >
                متوفر
              </button>
            )}

            {/* ─── قائمة: زر لكل خيار ─── */}
            {f.type === 'select' &&
              f.options.map((o) => (
                <button
                  key={o.id || o.value}
                  className={`chip-btn ${value[f.key] === o.value ? 'is-active' : ''}`}
                  onClick={() => toggle(f.key, o.value)}
                  title={o.label}
                >
                  {o.icon ? <Lucide name={o.icon} size={13} /> : null}
                  {o.label}
                </button>
              ))}
          </div>
        </div>
      ))}

      {activeCount > 0 && (
        <div className="ffilters__foot">
          <span>
            <strong>{matchCount}</strong> من {totalCount} مطابقة
          </span>
          <button className="ffilters__clear" onClick={() => onChange({})}>
            <Icon name="x" size={13} /> مسح الفلاتر
          </button>
        </div>
      )}
    </div>
  )
}

/**
 * هل تنطبق الخدمة على الفلاتر المختارة؟
 * نقرأ من الحقول المحلولة من الخادم (s.fields) لأنها تُراعي المطابقة
 * بالمُعرّف أو النص أو رقم الخيار، ولا تعتمد على شكل البيانات الخام.
 */
export function matchesFieldFilters(s: Service, filters: FieldFilterState): boolean {
  for (const [key, wanted] of Object.entries(filters)) {
    if (!wanted) continue

    const resolved = (s.fields ?? []).find((f) => f.key === key)

    // حقل منطقي: المطلوب «متوفر» — وغياب الحقل يعني «لا»
    // (يُخفى الحقل عند «لا» في قسمٍ ما، فهذا هو التمثيل الصحيح)
    if (wanted === '1') {
      if (!resolved) return false
      const v = String(resolved.value ?? '').toLowerCase()
      if (!['1', 'true', 'نعم', 'yes'].includes(v)) {
        // قد تكون قائمة اختيار بقيمة منطقية — نطابق العرض أيضاً
        if (resolved.display !== 'نعم') return false
      }
      continue
    }

    if (!resolved) return false

    // مطابقة بقيمة الخيار أو نصه المعروض
    if (String(resolved.value ?? '') !== wanted && resolved.display !== wanted) {
      // البطاقات المختصرة قد تعرض «نعم/لا» للحقول المنطقية فقط،
      // أما القوائم فالقيمة والنص فيها محفوظان — فلا حاجة لمزيد من الاحتمالات.
      return false
    }
  }
  return true
}

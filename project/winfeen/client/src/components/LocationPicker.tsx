import { useEffect, useMemo, useRef, useState } from 'react'
import Icon from './Icon'
import type { Governorate } from '../lib/types'

interface Props {
  /** شجرة المواقع من /api/meta (locations) */
  locations: Governorate[]
  governorateId?: number | null
  regionId?: number | null
  onChange: (govId: number | null, regionId: number | null) => void
  required?: boolean
  /** تسمية المجموعة */
  label?: string
}

/**
 * منتقي الموقع الهرمي: محافظة ← مدينة ← قرية
 *
 * - البحث الفوري يعمل على كل المستويات في آنٍ واحد
 * - اختيار قرية يحدّد مدينتها ومحافظتها تلقائياً
 * - اختيار مدينة يحدّد محافظتها تلقائياً
 * - اختيار محافظة يصفّي المدن والقرى التابعة لها
 */
export default function LocationPicker({
  locations, governorateId, regionId, onChange, required, label = 'الموقع',
}: Props) {
  const [govQ, setGovQ] = useState('')
  const [govOpen, setGovOpen] = useState(false)
  const [cityQ, setCityQ] = useState('')
  const [cityOpen, setCityOpen] = useState(false)
  const [vilQ, setVilQ] = useState('')
  const [vilOpen, setVilOpen] = useState(false)
  const wrap = useRef<HTMLDivElement>(null)

  const govs = useMemo(() => locations || [], [locations])

  const gov = useMemo(
    () => govs.find((g) => g.id === governorateId) ?? null,
    [govs, governorateId]
  )

  /** المدن التابعة للمحافظة المختارة */
  const cities = useMemo(() => gov?.cities ?? [], [gov])

  /** هل الاختيار الحالي قرية؟ */
  const asVillage = useMemo(() => {
    if (!regionId) return null
    for (const c of cities) {
      const v = (c.villages ?? []).find((x) => x.id === regionId)
      if (v) return v
    }
    return null
  }, [cities, regionId])

  /** المدينة الحالية: إما المختارة مباشرةً، أو أمّ القرية المختارة */
  const city = useMemo(() => {
    if (!regionId) return null
    const direct = cities.find((c) => c.id === regionId)
    if (direct) return direct
    if (asVillage) return cities.find((c) => c.id === asVillage.parent_id) ?? null
    return null
  }, [cities, regionId, asVillage])

  // تصفية البحث
  const norm = (t: string) => t.replace(/[أإآٱ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه').trim().toLowerCase()
  const match = (t: string, q: string) => !q || norm(t).includes(norm(q))

  const filteredGovs = govs.filter((g) => match(g.name, govQ))
  const filteredCities = cities.filter((c) => match(c.name, cityQ))
  const filteredVillages = (city?.villages ?? []).filter((v) => match(v.name, vilQ))

  // أغلق القوائم عند النقر خارجها
  useEffect(() => {
    const onDoc = (e: MouseEvent) => {
      if (wrap.current && !wrap.current.contains(e.target as Node)) {
        setGovOpen(false); setCityOpen(false); setVilOpen(false)
      }
    }
    document.addEventListener('mousedown', onDoc)
    return () => document.removeEventListener('mousedown', onDoc)
  }, [])

  // اختيار المحافظة
  const pickGov = (id: number) => {
    onChange(id, null)
    setGovQ(''); setGovOpen(false); setCityQ(''); setVilQ('')
  }
  // اختيار المدينة ← المحافظة تُستنتج تلقائياً
  const pickCity = (id: number) => {
    onChange(gov?.id ?? null, id)
    setCityQ(''); setCityOpen(false); setVilQ('')
  }
  // اختيار القرية ← المدينة والمحافظة تُستنتجان تلقائياً
  const pickVillage = (id: number) => {
    onChange(gov?.id ?? null, id)
    setVilQ(''); setVilOpen(false)
  }

  const selectedText = [
    gov?.name,
    city?.name,
    asVillage?.name,
  ].filter(Boolean).join(' ← ')

  return (
    <div className="loc" ref={wrap}>
      <div className="loc__head">
        <Icon name="map-pin" size={15} />
        <span>{label}{required ? ' *' : ''}</span>
        {selectedText && <span className="loc__path">{selectedText}</span>}
      </div>

      <div className="loc__grid">
        {/* ── المحافظة ── */}
        <div className="loc__col">
          <span className="loc__lbl">المحافظة</span>
          <button
            type="button"
            className={`loc__btn${govOpen ? ' is-open' : ''}${gov ? ' is-set' : ''}`}
            onClick={() => { setGovOpen((o) => !o); setCityOpen(false); setVilOpen(false) }}
          >
            <span className={gov ? '' : 'loc__ph'}>{gov ? gov.name : 'اختر المحافظة'}</span>
            <Icon name="chevron-down" size={14} />
          </button>
          {govOpen && (
            <div className="loc__pop">
              <div className="loc__search">
                <Icon name="search" size={14} />
                <input
                  autoFocus value={govQ} placeholder="ابحث…"
                  onChange={(e) => setGovQ(e.target.value)}
                />
                {govQ && <button type="button" className="loc__clear" onClick={() => setGovQ('')}><Icon name="circle-x" size={13} /></button>}
              </div>
              <div className="loc__list">
                {filteredGovs.length === 0 && <div className="loc__none">لا نتائج</div>}
                {filteredGovs.map((g) => (
                  <button
                    type="button" key={g.id}
                    className={`loc__opt${g.id === governorateId ? ' is-active' : ''}`}
                    onClick={() => pickGov(g.id)}
                  >
                    <Icon name="map-pin" size={13} />
                    <span>{g.name}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* ── المدينة ── */}
        <div className="loc__col">
          <span className="loc__lbl">المدينة / البلدة</span>
          <button
            type="button"
            className={`loc__btn${cityOpen ? ' is-open' : ''}${city ? ' is-set' : ''}`}
            disabled={!gov}
            onClick={() => { setCityOpen((o) => !o); setGovOpen(false); setVilOpen(false) }}
          >
            <span className={city ? '' : 'loc__ph'}>{city ? city.name : (gov ? 'اختر المدينة' : 'اختر المحافظة أولاً')}</span>
            <Icon name="chevron-down" size={14} />
          </button>
          {cityOpen && gov && (
            <div className="loc__pop">
              <div className="loc__search">
                <Icon name="search" size={14} />
                <input
                  autoFocus value={cityQ} placeholder="ابحث…"
                  onChange={(e) => setCityQ(e.target.value)}
                />
                {cityQ && <button type="button" className="loc__clear" onClick={() => setCityQ('')}><Icon name="circle-x" size={13} /></button>}
              </div>
              <div className="loc__list">
                {filteredCities.length === 0 && <div className="loc__none">لا نتائج</div>}
                {filteredCities.map((c) => (
                  <button
                    type="button" key={c.id}
                    className={`loc__opt${c.id === city?.id && !asVillage ? ' is-active' : ''}`}
                    onClick={() => pickCity(c.id)}
                  >
                    <Icon name="building" size={13} />
                    <span>{c.name}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* ── القرية ── */}
        <div className="loc__col">
          <span className="loc__lbl">القرية <em>(اختياري)</em></span>
          <button
            type="button"
            className={`loc__btn${vilOpen ? ' is-open' : ''}${asVillage ? ' is-set' : ''}`}
            disabled={!city || filteredVillages.length + (city?.villages?.length ?? 0) === 0}
            onClick={() => { setVilOpen((o) => !o); setGovOpen(false); setCityOpen(false) }}
          >
            <span className={asVillage ? '' : 'loc__ph'}>
              {asVillage ? asVillage.name : ((city?.villages?.length ?? 0) ? 'اختر القرية' : 'لا قرى تابعة')}
            </span>
            <Icon name="chevron-down" size={14} />
          </button>
          {vilOpen && city && (city.villages?.length ?? 0) > 0 && (
            <div className="loc__pop">
              <div className="loc__search">
                <Icon name="search" size={14} />
                <input
                  autoFocus value={vilQ} placeholder="ابحث…"
                  onChange={(e) => setVilQ(e.target.value)}
                />
                {vilQ && <button type="button" className="loc__clear" onClick={() => setVilQ('')}><Icon name="circle-x" size={13} /></button>}
              </div>
              <div className="loc__list">
                {filteredVillages.length === 0 && <div className="loc__none">لا نتائج</div>}
                {filteredVillages.map((v) => (
                  <button
                    type="button" key={v.id}
                    className={`loc__opt${v.id === asVillage?.id ? ' is-active' : ''}`}
                    onClick={() => pickVillage(v.id)}
                  >
                    <Icon name="house" size={13} />
                    <span>{v.name}</span>
                  </button>
                ))}
              </div>
              {asVillage && (
                <button type="button" className="loc__none loc__none--btn" onClick={() => { onChange(gov?.id ?? null, city.id); setVilOpen(false) }}>
                  إلغاء اختيار القرية
                </button>
              )}
            </div>
          )}
        </div>
      </div>

      <input type="hidden" value={governorateId ?? ''} name="governorate_id" />
      <input type="hidden" value={regionId ?? ''} name="region_id" />
    </div>
  )
}

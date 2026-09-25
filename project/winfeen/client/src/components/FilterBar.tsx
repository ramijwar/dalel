import { useState } from 'react'
import type { Region, RegionGroup, Zone } from '../lib/types'
import Icon from './Icon'

export interface Filters {
  zone: Zone | ''
  region_id: number | null
  status: string
  q: string
  sort: string
  layout: 'card' | 'list'
}

interface Props {
  value: Filters
  onChange: (f: Filters) => void
  regions: RegionGroup[]
  allRegions: Region[]
  totalCount: number
  openCount: number
  dutyCount: number
}

const STATUS_OPTS = [
  { v: '', l: 'الكل' },
  { v: 'open', l: 'تعمل الآن' },
  { v: 'on_duty', l: 'مناوبة' },
  { v: 'manual', l: 'تحديث يدوي' },
  { v: 'unmanaged', l: 'بدون مسؤول' },
]

const SORT_OPTS = [
  { v: 'open_first', l: 'المفتوحة أولاً' },
  { v: 'name', l: 'الاسم' },
  { v: 'recent', l: 'آخر تحديث' },
]

export default function FilterBar({ value, onChange, regions, allRegions, totalCount, openCount, dutyCount }: Props) {
  const [showFilters, setShowFilters] = useState(false)
  const set = (p: Partial<Filters>) => onChange({ ...value, ...p })
  const reset = () => onChange({ zone: '', region_id: null, status: '', q: '', sort: 'open_first', layout: value.layout })

  const hasFilters = value.zone || value.region_id || value.status || value.q

  const zones: { v: Zone | ''; l: string }[] = [
    { v: '', l: 'الكل' },
    { v: 'city', l: 'المدينة' },
    { v: 'rural', l: 'الريف' },
  ]

  return (
    <div className="fbar">
      <div className="fbar__top">
        <div className="fbar__counts">
          <span className="fbar__count">{totalCount} خدمة</span>
          {openCount > 0 && <span className="fbar__count fbar__count--open">🟢 {openCount} تعمل</span>}
          {dutyCount > 0 && <span className="fbar__count fbar__count--duty">🌙 {dutyCount} مناوبة</span>}
        </div>

        <div className="fbar__tools">
          <div className="search-input">
            <Icon name="search" size={16} />
            <input
              type="search"
              placeholder="ابحث بالاسم أو العنوان أو رقم الهاتف…"
              value={value.q}
              onChange={(e) => set({ q: e.target.value })}
              aria-label="بحث"
            />
            {value.q && <button className="search-clear" onClick={() => set({ q: '' })}><Icon name="x" size={14} /></button>}
          </div>

          <button
            className={`iconbtn ${value.layout === 'list' ? 'iconbtn--active' : ''}`}
            title={value.layout === 'card' ? 'عرض قائمة' : 'عرض بطاقات'}
            aria-pressed={value.layout === 'list'}
            onClick={() => set({ layout: value.layout === 'card' ? 'list' : 'card' })}
          >
            <Icon name={value.layout === 'card' ? 'list' : 'grid'} size={18} />
          </button>

          <button className={`iconbtn ${showFilters ? 'iconbtn--active' : ''}`} title="فلاتر" onClick={() => setShowFilters(!showFilters)}>
            <Icon name="filter" size={18} />
            {hasFilters && <span className="iconbtn__dot" />}
          </button>
        </div>
      </div>

      {showFilters && (
        <div className="fbar__extra">
          <div className="filter-group">
            <label className="filter-label">المنطقة</label>
            <div className="chip-group">
              {zones.map((z) => (
                <button key={z.v} className={`chip-btn ${value.zone === z.v ? 'is-active' : ''}`} onClick={() => set({ zone: z.v, region_id: z.v !== value.zone ? null : value.region_id })}>{z.l}</button>
              ))}
            </div>
          </div>

          <div className="filter-group">
            <label className="filter-label">الحي/البلدة</label>
            <select value={value.region_id ?? ''} onChange={(e) => set({ region_id: e.target.value ? Number(e.target.value) : null })}>
              <option value="">الكل</option>
              {(value.zone ? allRegions.filter((r) => r.zone === value.zone) : allRegions).map((r) => (
                <option key={r.id} value={r.id}>{r.name}</option>
              ))}
            </select>
          </div>

          <div className="filter-group">
            <label className="filter-label">الحالة</label>
            <div className="chip-group">
              {STATUS_OPTS.map((o) => (
                <button key={o.v} className={`chip-btn ${value.status === o.v ? 'is-active' : ''}`} onClick={() => set({ status: o.v })}>{o.l}</button>
              ))}
            </div>
          </div>

          <div className="filter-group">
            <label className="filter-label">ترتيب</label>
            <select value={value.sort} onChange={(e) => set({ sort: e.target.value })}>
              {SORT_OPTS.map((o) => <option key={o.v} value={o.v}>{o.l}</option>)}
            </select>
          </div>

          {hasFilters && (
            <button className="qbtn qbtn--sm qbtn--danger" onClick={reset}><Icon name="x" size={13} /> مسح الفلاتر</button>
          )}
        </div>
      )}

      {regions.length > 0 && !showFilters && (
        <div className="fbar__regions">
          {regions.slice(0, 12).map((r) => (
            <button
              key={r.region_id}
              className={`region-chip ${value.region_id === r.region_id ? 'is-active' : ''}`}
              onClick={() => set({ region_id: value.region_id === r.region_id ? null : r.region_id })}
            >
              <span className="region-chip__name">{r.region}</span>
              <span className="region-chip__stat">{r.open}/{r.total}</span>
            </button>
          ))}
          {regions.length > 12 && <span className="fbar__more">…</span>}
        </div>
      )}
    </div>
  )
}

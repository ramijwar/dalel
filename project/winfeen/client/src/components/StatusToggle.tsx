import { useEffect, useRef, useState } from 'react'
import Icon from './Icon'

interface Props {
  open: boolean
  busy?: boolean
  disabled?: boolean
  onToggle: (next: boolean) => void
  openLabel?: string
  closedLabel?: string
}

/**
 * مفتاح سحب: يسحبه المستخدم يميناً/يساراً أو يضغطه لتبديل الحالة بين
 * "تعمل الآن" و"مغلقة الآن".
 */
export default function StatusToggle({
  open, busy = false, disabled = false, onToggle,
  openLabel = 'تعمل الآن', closedLabel = 'مغلقة الآن',
}: Props) {
  const [dragX, setDragX] = useState(0)
  const [dragging, setDragging] = useState(false)
  const startX = useRef(0)
  const trackRef = useRef<HTMLDivElement>(null)
  const THRESHOLD = 34

  const width = () => trackRef.current?.clientWidth ?? 120

  const commit = (next: boolean) => {
    setDragX(0)
    setDragging(false)
    if (!disabled && !busy && next !== open) onToggle(next)
  }

  const onPointerDown = (e: React.PointerEvent) => {
    if (disabled || busy) return
    ;(e.target as HTMLElement).setPointerCapture?.(e.pointerId)
    startX.current = e.clientX
    setDragging(true)
  }

  const onPointerMove = (e: React.PointerEvent) => {
    if (!dragging) return
    // في RTL السحب لليسار = فتح
    const dx = e.clientX - startX.current
    const max = width() * 0.45
    setDragX(Math.max(-max, Math.min(max, dx)))
  }

  const onPointerUp = () => {
    if (!dragging) return
    if (Math.abs(dragX) > THRESHOLD) commit(dragX < 0 ? true : false)
    else commit(open)
  }

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === ' ' || e.key === 'Enter') {
        const el = document.activeElement
        if (el && el.getAttribute('data-status-toggle') === '1') {
          e.preventDefault()
          commit(!open)
        }
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })

  return (
    <div
      className={`switch ${open ? 'switch--open' : 'switch--closed'} ${busy ? 'is-busy' : ''} ${disabled ? 'is-disabled' : ''} ${dragging ? 'is-dragging' : ''}`}
      ref={trackRef}
      data-status-toggle="1"
      role="switch"
      tabIndex={disabled ? -1 : 0}
      aria-checked={open}
      aria-label={open ? openLabel : closedLabel}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={() => { setDragX(0); setDragging(false) }}
      onClick={() => { if (!dragging && Math.abs(dragX) < 3) commit(!open) }}
    >
      <span className="switch__track" />
      <span className="switch__label switch__label--open">
        <Icon name="check" size={13} /> {openLabel}
      </span>
      <span className="switch__label switch__label--closed">
        <Icon name="x" size={13} /> {closedLabel}
      </span>
      <span
        className="switch__knob"
        style={{ '--dx': `${dragX}px` } as React.CSSProperties}
      >
        <Icon name="power" size={15} />
      </span>
      {busy && <span className="switch__spin" />}
    </div>
  )
}

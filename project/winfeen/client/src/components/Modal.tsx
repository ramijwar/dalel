import { useEffect, useRef, type ReactNode } from 'react'
import Icon from './Icon'

interface Props {
  open: boolean
  onClose: () => void
  title?: string
  wide?: boolean
  children: ReactNode
}

export default function Modal({ open, onClose, title, wide = false, children }: Props) {
  const ref = useRef<HTMLDialogElement>(null)

  useEffect(() => {
    const d = ref.current
    if (!d) return
    if (open && !d.open) { d.showModal(); document.body.classList.add('modal-open') }
    if (!open && d.open) { d.close(); document.body.classList.remove('modal-open') }
    return () => document.body.classList.remove('modal-open')
  }, [open])

  return (
    <dialog
      ref={ref}
      className={`modal ${wide ? 'modal--wide' : ''}`}
      onClose={onClose}
      onClick={(e) => { if (e.target === ref.current) onClose() }}
    >
      <div className="modal__box">
        <header className="modal__head">
          {title && <h3>{title}</h3>}
          <button className="iconbtn" aria-label="إغلاق" onClick={onClose}><Icon name="x" size={20} /></button>
        </header>
        <div className="modal__body">{children}</div>
      </div>
    </dialog>
  )
}

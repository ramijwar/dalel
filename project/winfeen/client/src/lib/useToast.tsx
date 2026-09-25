import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'

type ToastTone = 'success' | 'error' | 'info'
interface Toast { id: number; text: string; tone: ToastTone }

const ToastCtx = createContext<((text: string, tone?: ToastTone) => void) | null>(null)

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Toast[]>([])

  const push = useCallback((text: string, tone: ToastTone = 'success') => {
    const id = Date.now() + Math.random()
    setItems((prev) => [...prev, { id, text, tone }])
    window.setTimeout(() => setItems((prev) => prev.filter((t) => t.id !== id)), 3600)
  }, [])

  return (
    <ToastCtx.Provider value={push}>
      {children}
      <div className="toast-stack" role="status" aria-live="polite">
        {items.map((t) => (
          <div key={t.id} className={`toast toast--${t.tone}`}>
            <span className="toast__icon">{t.tone === 'success' ? '✓' : t.tone === 'error' ? '✕' : 'ℹ'}</span>
            <span>{t.text}</span>
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  )
}

export function useToast() {
  const ctx = useContext(ToastCtx)
  if (!ctx) throw new Error('useToast يجب أن يُستخدم داخل ToastProvider')
  return ctx
}

/** ينبض كل دقيقة لتحديث الحالات المعتمدة على الوقت */
export function useTicker(intervalMs = 60000): number {
  const [tick, setTick] = useState(() => Date.now())
  useEffect(() => {
    const id = window.setInterval(() => setTick(Date.now()), intervalMs)
    return () => window.clearInterval(id)
  }, [intervalMs])
  return tick
}

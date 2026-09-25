import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../lib/store'
import { useToast } from '../lib/useToast'
import { ApiError } from '../lib/api'
import Icon from '../components/Icon'

type Tab = 'login' | 'register'

export default function AuthPage() {
  const { login, register, user } = useStore()
  const nav = useNavigate()
  const toast = useToast()

  const [tab, setTab] = useState<Tab>('login')
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [fullName, setFullName] = useState('')
  const [birthDate, setBirthDate] = useState('')
  const [busy, setBusy] = useState(false)

  // إعادة توجيه إن كان مسجلاً
  if (user) { nav('/profile', { replace: true }); return null }

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setBusy(true)
    try {
      if (tab === 'login') {
        await login(phone, password)
        toast('تم تسجيل الدخول بنجاح')
      } else {
        await register({ phone, password, full_name: fullName, birth_date: birthDate || undefined })
        toast('تم إنشاء الحساب بنجاح')
      }
      nav('/profile', { replace: true })
    } catch (err) {
      toast(err instanceof ApiError ? err.message : 'خطأ في الاتصال', 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <main className="page auth-page">
      <div className="auth-card">
        <h1><Icon name="user" size={28} /> {tab === 'login' ? 'تسجيل الدخول' : 'حساب جديد'}</h1>

        <div className="auth-tabs">
          <button className={tab === 'login' ? 'is-active' : ''} onClick={() => setTab('login')}>دخول</button>
          <button className={tab === 'register' ? 'is-active' : ''} onClick={() => setTab('register')}>تسجيل جديد</button>
        </div>

        <form onSubmit={onSubmit} className="auth-form">
          {tab === 'register' && (
            <>
              <label>
                <span>الاسم الثلاثي</span>
                <input required value={fullName} onChange={(e) => setFullName(e.target.value)} placeholder="الاسم الكامل" />
              </label>
              <label>
                <span>تاريخ الميلاد (اختياري)</span>
                <input type="date" value={birthDate} onChange={(e) => setBirthDate(e.target.value)} />
              </label>
            </>
          )}

          <label>
            <span>رقم الهاتف</span>
            <input
              required
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="09XXXXXXXX"
              dir="ltr"
              pattern="^0\d{8,10}$"
              title="أدخل رقم هاتف سوري يبدأ بـ 0"
            />
          </label>

          <label>
            <span>كلمة المرور</span>
            <input
              required
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="6 أحرف على الأقل"
              minLength={6}
            />
          </label>

          <button type="submit" className="btn btn--primary btn--block" disabled={busy}>
            {busy ? 'جاري المعالجة…' : tab === 'login' ? 'دخول' : 'إنشاء الحساب'}
          </button>
        </form>
      </div>
    </main>
  )
}

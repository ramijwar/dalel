import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useStore } from '../lib/store'
import { api } from '../lib/api'
import { useToast } from '../lib/useToast'
import { ApiError } from '../lib/api'
import { fmtDate } from '../lib/utils'
import { withBase } from '../lib/basePath'
import Icon from '../components/Icon'

export default function ProfilePage() {
  const { user, logout, refreshUser } = useStore()
  const nav = useNavigate()
  const toast = useToast()
  const fileRef = useRef<HTMLInputElement>(null)

  const [fullName, setFullName] = useState(user?.full_name ?? '')
  const [phone, setPhone] = useState(user?.phone ?? '')
  const [birthDate, setBirthDate] = useState(user?.birth_date ?? '')
  const [bio, setBio] = useState(user?.bio ?? '')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (!user) { nav('/auth', { replace: true }); return }
    setFullName(user.full_name)
    setPhone(user.phone ?? '')
    setBirthDate(user.birth_date ?? '')
    setBio(user.bio ?? '')
  }, [user])

  if (!user) return null

  const handleAvatar = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setBusy(true)
    try {
      await api.uploadAvatar(file)
      await refreshUser()
      toast('تم تحديث الصورة الشخصية')
    } catch (err) {
      toast(err instanceof ApiError ? err.message : 'فشل رفع الصورة', 'error')
    } finally {
      setBusy(false)
      if (fileRef.current) fileRef.current.value = ''
    }
  }

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    setBusy(true)
    try {
      const payload: Record<string, any> = { full_name: fullName, phone, birth_date: birthDate, bio }
      if (password) payload.password = password
      await api.updateProfile(payload)
      await refreshUser()
      toast('تم حفظ البيانات')
      setPassword('')
    } catch (err) {
      toast(err instanceof ApiError ? err.message : 'فشل الحفظ', 'error')
    } finally {
      setBusy(false)
    }
  }

  const handleLogout = () => { logout(); nav('/', { replace: true }); toast('تم تسجيل الخروج') }

  return (
    <main className="page profile-page">
      <header className="profile__head">
        <h1><Icon name="user" size={24} /> الملف الشخصي</h1>
      </header>

      <section className="profile__card">
        <div className="profile__avatar-wrap" onClick={() => fileRef.current?.click()} title="تغيير الصورة">
          {user.avatar ? (
            <img src={withBase(user.avatar)} alt={user.full_name} className="profile__avatar" />
          ) : (
            <div className="profile__avatar profile__avatar--placeholder">
              <Icon name="camera" size={28} />
            </div>
          )}
          <input ref={fileRef} type="file" accept="image/*" hidden onChange={handleAvatar} />
          <span className="profile__avatar-hint"><Icon name="camera" size={14} /> تغيير</span>
        </div>

        <div className="profile__info">
          <h2>{user.full_name || 'لم يُحدَّد الاسم'}</h2>
          <p className="profile__phone">{user.phone_intl}</p>
          <p className="profile__bio">{user.bio || 'لا يوجد وصف'}</p>
          {user.birth_date && <p className="profile__birth">تاريخ الميلاد: {fmtDate(user.birth_date)}</p>}
          <span className="badge">{user.role === 'admin' ? '🛡️ مدير' : '👤 مستخدم'}</span>
        </div>
      </section>

      <form onSubmit={handleSave} className="profile__form">
        <h3><Icon name="edit" size={18} /> تعديل البيانات</h3>

        <label>
          <span>الاسم الثلاثي</span>
          <input value={fullName} onChange={(e) => setFullName(e.target.value)} required />
        </label>
        <label>
          <span>رقم الهاتف</span>
          <input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="0991234567" pattern="^09\d{8}$" />
          <small>رقم سوري يبدأ بـ 09 (10 أرقام)</small>
        </label>
        <label>
          <span>تاريخ الميلاد</span>
          <input type="date" value={birthDate} onChange={(e) => setBirthDate(e.target.value)} />
        </label>
        <label>
          <span>نبذة عنك</span>
          <textarea value={bio} onChange={(e) => setBio(e.target.value)} rows={3} placeholder="اكتب نبذة مختصرة (اختياري)" />
        </label>
        <label>
          <span>كلمة المرور الجديدة (اختياري)</span>
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="اتركها فارغة لعدم التغيير" minLength={6} />
        </label>

        <button type="submit" className="btn btn--primary" disabled={busy}>{busy ? 'جاري الحفظ…' : 'حفظ التعديلات'}</button>
      </form>

      <section className="profile__nav">
        <Link to="/my/services" className="profile-link"><Icon name="dashboard" size={18} /> خدماتي</Link>
        <Link to="/my/requests" className="profile-link"><Icon name="inbox" size={18} /> طلباتي</Link>
        {user.role === 'admin' && <Link to="/admin" className="profile-link profile-link--admin"><Icon name="settings" size={18} /> لوحة التحكم</Link>}
        <button className="profile-link profile-link--danger" onClick={handleLogout}><Icon name="logout" size={18} /> تسجيل الخروج</button>
      </section>
    </main>
  )
}

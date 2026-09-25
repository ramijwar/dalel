import { BrowserRouter, Link, NavLink, Route, Routes } from 'react-router-dom'
import { StoreProvider, useStore } from './lib/store'
import { ToastProvider } from './lib/useToast'
import { getBasePath, withBase } from './lib/basePath'
import Icon from './components/Icon'

import Home from './pages/Home'
import ServicesPage from './pages/ServicesPage'
import ServiceDetail from './pages/ServiceDetail'
import AuthPage from './pages/AuthPage'
import ProfilePage from './pages/ProfilePage'
import OwnerDashboard from './pages/OwnerDashboard'
import RequestPage from './pages/RequestPage'
import AdminDashboard from './pages/admin/AdminDashboard'

const BASE = getBasePath()

export default function App() {
  return (
    <BrowserRouter basename={BASE}>
      <StoreProvider>
        <ToastProvider>
          <SiteShell />
        </ToastProvider>
      </StoreProvider>
    </BrowserRouter>
  )
}

function SiteShell() {
  const { user, settings, loading } = useStore()

  if (loading) {
    return (
      <div className="app-loader">
        <div className="loader-spinner" />
        <p>جاري التحميل…</p>
      </div>
    )
  }

  return (
    <div className="app">
      <nav className="site-nav">
        {/* يميناً: اسم الموقع بجانب الأيقونة، ثم رابط الرئيسية */}
        <div className="site-nav__start">
          <Link to="/" className="site-nav__brand">
            <span className="site-nav__mark"><Icon name="map-pin" size={20} /></span>
            <span className="site-nav__name-text">{settings.site_name}</span>
          </Link>

          <NavLink
            to="/"
            end
            className={({ isActive }) => `site-nav__link${isActive ? ' is-active' : ''}`}
          >
            <Icon name="house" size={15} />
            <span className="site-nav__link-label">الرئيسية</span>
          </NavLink>
        </div>

        {/* ─── وسط الشريط: زر إضافة خدمة ─── */}
        <div className="site-nav__center">
          <Link to="/request" className="site-nav__add">
            <Icon name="plus" size={16} />
            <span className="site-nav__add-label">أضف خدمة</span>
          </Link>
        </div>

        <div className="site-nav__right">
          {user ? (
            <NavLink to="/profile" className="site-nav__user">
              {user.avatar ? (
                <img src={withBase(user.avatar)} alt="" className="site-nav__avatar" />
              ) : (
                <span className="site-nav__avatar site-nav__avatar--ph"><Icon name="user" size={16} /></span>
              )}
              <span className="site-nav__name">{user.full_name?.split(' ')[0] || 'حسابي'}</span>
            </NavLink>
          ) : (
            <NavLink to="/auth" className="btn btn--sm btn--outline"><Icon name="user" size={15} /> دخول</NavLink>
          )}
        </div>
      </nav>

      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/auth" element={<AuthPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route path="/my/:sub" element={<OwnerDashboard />} />
        <Route path="/request" element={<RequestPage />} />
        <Route path="/admin" element={<AdminDashboard />} />
        <Route path="/admin/:tab" element={<AdminDashboard />} />
        <Route path="/s/:id" element={<ServiceDetail />} />
        <Route path="/:slug" element={<ServicesPage />} />
      </Routes>
    </div>
  )
}

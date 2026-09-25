import { Link } from 'react-router-dom'
import { useStore } from '../lib/store'
import { num } from '../lib/utils'
import Icon from '../components/Icon'
import CatIcon from '../components/CatIcon'
import AdCarousel from '../components/AdCarousel'

/**
 * الصفحة الرئيسية.
 * كل البيانات (الأقسام + العدّادات + الإعدادات) تأتي من طلب واحد هو /api/meta
 * يُنجزه المخزن مرة واحدة عند بدء التطبيق — لذلك لا يوجد هنا أي جلب أو حالة
 * تحميل أو خطأ: إن ظهرت الأقسام فالعدّادات معها تلقائياً.
 */
export default function Home() {
  const { categories, settings, counts, loading } = useStore()

  if (loading) {
    return (
      <main className="page home">
        <div className="loading-screen">
          <div className="loading-spinner"></div>
          <p>جاري التحميل...</p>
        </div>
      </main>
    )
  }

  const totalServices = Object.values(counts).reduce((a, b) => a + b, 0)
  const hasCounts = Object.keys(counts).length > 0

  return (
    <main className="page home">
      {/* شريط الإعلانات الدوّار — الإعلانات تُدار من لوحة التحكم
          وزمن التبديل يُضبط من الإعدادات (settings.ad_interval) */}
      <AdCarousel items={settings.announcements} interval={settings.ad_interval} />

      <section className="home__bar" aria-label="إحصاءات سريعة">
        <span className="home__bar-item">
          <Icon name="grid" size={15} />
          <strong>{num(categories.length)}</strong> أقسام
        </span>
        <span className="home__bar-sep" />
        <span className="home__bar-item">
          <Icon name="pin" size={15} />
          <strong>{hasCounts ? num(totalServices) : '—'}</strong> خدمة
        </span>
        <Link to="/request" className="home__bar-cta">
          <Icon name="plus" size={15} /> أضف خدمتك
        </Link>
      </section>

      <section className="home__counters" aria-label="إحصاءات الأقسام">
        {categories.map((c) => (
          <Link
            key={c.id}
            to={c.route || `/${c.slug}`}
            className="counter"
            style={{ '--cat-color': c.color } as React.CSSProperties}
          >
            <span className="counter__icon"><CatIcon icon={c.icon} size={22} /></span>
            <span className="counter__num">
              {hasCounts ? num(counts[c.slug] ?? 0) : '—'}
            </span>
            <span className="counter__label">{c.name}</span>
          </Link>
        ))}
      </section>

      <section className="home__cats" aria-label="الأقسام">
        <h2 className="home__cats-title">تصفّح الأقسام</h2>
        <div className="cat-grid">
          {categories.map((c) => (
            <Link
              key={c.id}
              to={c.route || `/${c.slug}`}
              className="cat-card"
              style={{ '--cat-color': c.color } as React.CSSProperties}
            >
              <span className="cat-card__icon"><CatIcon icon={c.icon} size={28} /></span>
              <div className="cat-card__text">
                <h3>{c.name}</h3>
                <p>{c.description}</p>
              </div>
              <span className="cat-card__arrow">
                <Icon name="arrowLeft" size={18} />
              </span>
            </Link>
          ))}
        </div>
      </section>
    </main>
  )
}

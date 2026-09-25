import { Link } from 'react-router-dom'
import { useStore } from '../lib/store'
import { num } from '../lib/utils'
import Icon from '../components/Icon'
import CatIcon from '../components/CatIcon'
import AdCarousel from '../components/AdCarousel'

/**
 * الصفحة الرئيسية.
 * البنية: شريط الإعلانات ← شريط الإحصاءات ← **بطاقات الأقسام** (وهي روابط
 * الأقسام نفسها: أيقونة + عدد الخدمات + الاسم)، ويعقبها شريط التحديث.
 * قائمة «تصفّح الأقسام» أُزيلت: كانت تكراراً للبطاقات نفسها بعناوين ووصف
 * فتُضاعف طول الصفحة بلا فائدة.
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
    </main>
  )
}

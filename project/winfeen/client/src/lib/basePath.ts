/**
 * اكتشاف basePath تلقائياً من مسار سكريبت التطبيق المُحمَّل.
 * يعمل في أي مجلد فرعي دون تعديل يدوي.
 *
 * مثال: إذا كان التطبيق على https://site.com/winfeen/
 *   → basePath = '/winfeen'
 *
 * https://site.com/
 *   → basePath = '' (جذر)
 */
export function getBasePath(): string {
  // الطريقة الأفضل: من عنصر <script type="module"> المحمّل
  const scripts = document.querySelectorAll<HTMLScriptElement>('script[src]')
  for (const s of scripts) {
    const src = s.getAttribute('src') || ''
    // نبحث عن السكريпт الذي يبدأ بـ ./assets (الملف الرئيسي)
    if (src.includes('./assets/') || src.includes('assets/')) {
      try {
        const url = new URL(src, window.location.href)
        const dir = url.pathname.replace(/\/assets\/[^/]+$/, '')
        return dir === '/' ? '' : dir.replace(/\/$/, '')
      } catch { /* fallback */ }
    }
  }

  // الطريقة البديلة: من document.baseURI
  try {
    const base = new URL(document.baseURI)
    let p = base.pathname.replace(/\/+$/, '') || ''
    // إزالة أي امتداد ملف (مثل /index.html)
    if (p.includes('.')) p = p.substring(0, p.lastIndexOf('/'))
    return p
  } catch { /* fallback */ }

  // الطريقة الأخيرة: من window.location.pathname
  // نفترض أن basePath هو المجلد الحالي
  const p = window.location.pathname
  return p.substring(0, p.lastIndexOf('/')) || ''
}

/** المسار الكامل مع basePath */
export function withBase(path: string): string {
  const base = getBasePath()
  return base + (path.startsWith('/') ? path : '/' + path)
}

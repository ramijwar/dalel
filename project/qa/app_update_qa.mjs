/**
 * فحص ميزة «تحديث تطبيق أندرويد» — من طرف إلى طرف
 * ============================================================
 * يفحص الخادم (PHP) ولوحة التحكم (المتصفح) معاً:
 *
 *   تشغيل الخادم أولاً:
 *     cd project/winfeen && ../php-bin/php -S 127.0.0.1:8090 router.php
 *   ثم:
 *     node project/qa/app_update_qa.mjs --base http://127.0.0.1:8090 --token <رمز المدير>
 *
 *   أضف --ui لتشغيل فحوص الواجهة (يحتاج: npm install jsdom)
 *
 * الرمز: من مجلد api/
 *   php -r "define('APP_ROOT',getcwd()); require APP_ROOT.'/includes/token.php'; echo issue_token(33,'admin',1);"
 */

import { readFileSync, existsSync, writeFileSync, mkdirSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const args = process.argv.slice(2)
const getArg = (name, def = '') => {
  const i = args.indexOf(name)
  return i >= 0 && args[i + 1] ? args[i + 1] : def
}
const BASE = getArg('--base', 'http://127.0.0.1:8090').replace(/\/$/, '')
const TOKEN = getArg('--token', '')
const APK = getArg('--apk', '')
const RUN_UI = args.includes('--ui')
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

let pass = 0, fail = 0
const results = []
function check(name, ok, detail = '') {
  results.push({ name, ok, detail })
  ok ? pass++ : fail++
}

const api = (path, init = {}, token = TOKEN) =>
  fetch(`${BASE}/api${path}`, {
    ...init,
    headers: {
      ...(init.body && typeof init.body === 'string' ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init.headers || {}),
    },
  })

const json = async (r) => {
  const t = await r.text()
  try { return JSON.parse(t) } catch { return { __raw: t.slice(0, 200) } }
}

console.log(`\n  ══════ فحص «تحديث تطبيق أندرويد» — ${BASE} ══════\n`)

// ─── إعادة ضبط غير مدمِّرة قبل الفحص (حتى يكون قابلاً للتكرار) ───
// لا تحذف أي ملف — فقط تُفرغ الإعدادات المنشورة.
if (TOKEN) {
  await api('/admin/app-update', {
    method: 'PUT',
    body: JSON.stringify({ path: '', url: '', version_code: 0, version_name: '', force: false, notes: '' }),
  }).catch(() => {})
  console.log('  (أُعيد ضبط حالة النشر — الفحص قابل للتكرار)\n')
}

// ─────────────────────────────────────────────
// ١) النقطة العامة قبل النشر
// ─────────────────────────────────────────────
{
  const r = await api('/app-update', {}, '')
  const d = await json(r)
  check('1) النقطة العامة تعمل بلا تسجيل دخول', r.status === 200 && d.ok === true, `HTTP ${r.status}`)
  check('2) لا تحديث منشور → available=false',
    d.update?.available === false, `available=${d.update?.available}`)
  check('3) النقطة عامة فعلاً ومن دون رمز',
    r.status === 200, 'لا 401')
}

// ─────────────────────────────────────────────
// ٢) الصلاحيات
// ─────────────────────────────────────────────
{
  const noTok = await api('/admin/app-update', {}, '')
  check('4) لوحة التحديث بلا رمز → مرفوض', noTok.status === 401, `HTTP ${noTok.status}`)

  const badTok = await api('/admin/app-update', {}, 'ZXhhbXBsZS1mYWtlLXRva2Vu')
  check('5) رمز مزيف → مرفوض', badTok.status === 401 || badTok.status === 403, `HTTP ${badTok.status}`)

  const pub = await api('/admin/app-update', {}, '')
  check('6) النقطة الإدارية محجوبة عن الزوّار', pub.status !== 200, `HTTP ${pub.status}`)
}

// ─────────────────────────────────────────────
// ٣) الحالة الإدارية
// ─────────────────────────────────────────────
{
  const d = await json(await api('/admin/app-update'))
  const u = d.update || {}
  check('7) الحالة الإدارية تُرجع حدّ الرفع ومسار المجلد',
    !!u.upload_limit_h && !!u.dir, `حد=${u.upload_limit_h} مجلد=${u.dir}`)
  check('8) المجلد قابل للكتابة', u.dir_writable === true, `dir_writable=${u.dir_writable}`)
}

// ─────────────────────────────────────────────
// ٤) الرفض: ملف ليس APK
// ─────────────────────────────────────────────
{
  const fd = new FormData()
  fd.append('apk', new Blob([new TextEncoder().encode('hello not an apk')], { type: 'application/octet-stream' }), 'fake.apk')
  const d = await json(await api('/admin/app-update/apk', { method: 'POST', body: fd }))
  check('9) ملف ليس APK → مرفوض برسالة عربية',
    typeof d.message === 'string' && /APK/.test(d.message), d.message)
}

// ─────────────────────────────────────────────
// ٥) الرفض: ملف أكبر من حدّ الخادم
// ─────────────────────────────────────────────
{
  const big = new Uint8Array(3 * 1024 * 1024)
  big.set([0x50, 0x4b, 0x03, 0x04])
  const fd = new FormData()
  fd.append('apk', new Blob([big]), 'big.apk')
  const r = await api('/admin/app-update/apk', { method: 'POST', body: fd })
  const d = await json(r)
  check('10) ملف يتجاوز الحد → رسالة تشرح الحل (FTP)',
    r.status === 413 || /FTP/i.test(d.message || ''), `HTTP ${r.status} · ${(d.message || '').slice(0, 90)}…`)
}

// ─────────────────────────────────────────────
// ٦) رفع ملف APK حقيقي وقراءة إصداره من داخله
// ─────────────────────────────────────────────
let uploaded = null
if (APK && existsSync(APK)) {
  const buf = readFileSync(APK)
  const fd = new FormData()
  fd.append('apk', new Blob([buf], { type: 'application/vnd.android.package-archive' }), 'app-release.apk')
  const r = await api('/admin/app-update/apk', { method: 'POST', body: fd })
  const d = await json(r)
  uploaded = d.update || null

  check('11) رفع ملف APK حقيقي ناجح', d.ok === true && !!d.meta, d.message)
  check('12) قُرئ الإصدار من داخل الملف (لا من الاسم)',
    d.detected === true && d.meta?.versionCode > 0,
    `package=${d.meta?.package} code=${d.meta?.versionCode} name=${d.meta?.versionName}`)
  check('13) اسم الملف المنشور مبنيّ على الإصدار',
    /^dalel-.*\.apk$/.test(uploaded?.apk_file || ''), uploaded?.apk_file)
  check('14) الحجم المُسجَّل = حجم الملف المُرسل',
    uploaded?.size === buf.length, `${uploaded?.size} مقابل ${buf.length}`)

  // ─── مطابقة مع محلّلين مستقلّين ───
  const localPhp = join(ROOT, 'php-bin', 'php')
  const phpBin = process.env.PHP_BIN || (existsSync(localPhp) ? localPhp : 'php')
  try {
    const script = `<?php define('APP_ROOT','${ROOT}/winfeen/api'); require '${ROOT}/winfeen/api/includes/app_update.php';
      $m = apk_read_meta(${JSON.stringify(APK)});
      echo json_encode($m, JSON_UNESCAPED_UNICODE);`
    writeFileSync('/tmp/_qa_meta.php', script)
    const out = execFileSync(phpBin, ['/tmp/_qa_meta.php'], { encoding: 'utf8' })
    const m = JSON.parse(out.trim())
    check('15) قارئ الإصدار في PHP يطابق ما خزّنه الخادم',
      m.versionCode === uploaded?.version_code && m.versionName === uploaded?.version_name,
      `PHP: ${m.versionCode}/${m.versionName} · الخادم: ${uploaded?.version_code}/${uploaded?.version_name}`)
  } catch (e) {
    check('16) قارئ الإصدار في PHP', false, String(e.message).slice(0, 120))
  }
} else {
  console.log('  ⚠️  لم يُمرَّر ملف APK (--apk) — تخطّي فحوص الرفع')
}

// ─────────────────────────────────────────────
// ٧) الحمولة العامة + التنزيل الفعلي
// ─────────────────────────────────────────────
if (uploaded) {
  const d = await json(await api('/app-update', {}, ''))
  const u = d.update || {}
  check('17) التطبيق يرى التحديث في النقطة العامة', u.available === true && u.version_code > 0,
    `${u.version_name} (${u.version_code})`)
  check('18) رابط التنزيل يحترم المجلد الفرعي', u.url.startsWith(BASE),
    u.url.replace(BASE, '{BASE}'))
  check('19) الرابط ينتهي بملف APK', /\.apk$/.test(u.url), u.url.split('/').pop())

  // تنزيل فعلي
  const r = await fetch(u.url)
  const bytes = new Uint8Array(await r.arrayBuffer())
  check('20) الملف يُنزَّل بنوع أندرويد الصحيح',
    (r.headers.get('content-type') || '').includes('android.package-archive'),
    r.headers.get('content-type'))
  check('21) الملف المُنزَّل مطابق بايت ببايت للأصل',
    APK && existsSync(APK) ? Buffer.compare(Buffer.from(bytes), readFileSync(APK)) === 0 : false,
    `${bytes.length} بايت`)

  const crypto = await import('node:crypto')
  const sha = crypto.createHash('sha256').update(Buffer.from(bytes)).digest('hex')
  check('22) بصمة SHA-256 في الحمولة تطابق الملف',
    sha === u.sha256, `الحمولة=${(u.sha256 || '').slice(0, 16)}… المحسوبة=${sha.slice(0, 16)}…`)
} else {
  for (const [n, label] of [[16, 'الحمولة العامة'], [17, 'رابط التنزيل'], [18, 'لاحقة APK'], [19, 'نوع الملف'], [20, 'مطابقة البايتات'], [21, 'البصمة']])
    console.log(`  ⏭️  ${n}) ${label} — تخطّي (لا ملف مرفوع)`)
}

// ─────────────────────────────────────────────
// ٨) حفظ البيانات + رفض الروابط الخبيثة
// ─────────────────────────────────────────────
{
  const d = await json(await api('/admin/app-update', {
    method: 'PUT',
    body: JSON.stringify({ notes: '• سطر أول\n• سطر ثانٍ', force: true, version_name: '9.9.9', version_code: 99 }),
  }))
  check('23) حفظ الملاحظات والإلزامي والإصدار',
    d.update?.notes?.includes('سطر أول') && d.update?.force === true && d.update?.version_code === 99,
    `${d.update?.version_name} (${d.update?.version_code}) · إلزامي=${d.update?.force}`)

  const bad = await json(await api('/admin/app-update', {
    method: 'PUT', body: JSON.stringify({ url: 'javascript:alert(1)' }),
  }))
  check('24) رابط javascript: مرفوض', bad.ok === false, bad.message)

  const good = await json(await api('/admin/app-update', {
    method: 'PUT', body: JSON.stringify({ url: '' }),
  }))
  check('25) يمكن تفريغ الرابط الخارجي', good.ok === true, '')
}

// ─────────────────────────────────────────────
// ٨-ب) «مسار الملف» — يُحدّده المدير من اللوحة
// ─────────────────────────────────────────────
{
  // رابط خارجي
  const asUrl = await json(await api('/admin/app-update', {
    method: 'PUT', body: JSON.stringify({ path: 'https://example.com/dalel-9.9.apk' }),
  }))
  check('26) مسار = رابط خارجي → يُقبل ويُستعمل كما هو',
    asUrl.ok === true && asUrl.update?.path_status?.kind === 'url'
    && (asUrl.update?.download_url || '').startsWith('https://example.com'),
    asUrl.update?.download_url)

  // مسار محلي حقيقي (الملف المُختبَر نفسه داخل مجلد apk/)
  if (uploaded?.apk_file) {
    const asLocal = await json(await api('/admin/app-update', {
      method: 'PUT', body: JSON.stringify({ path: `apk/${uploaded.apk_file}` }),
    }))
    const ps = asLocal.update?.path_status || {}
    check('27) مسار محلي → يُوجد الملف ويُبنى منه رابط تنزيل',
      ps.kind === 'local' && ps.found === true && !!ps.web_path,
      `${ps.message} · ${ps.web_path}`)
    check('28) يُقرأ الإصدار من داخل الملف في المسار',
      ps.meta?.versionCode > 0, JSON.stringify(ps.meta))
    check('29) تحذير عند تخالف رقم المدير مع رقم الملف',
      ps.meta?.versionCode !== asLocal.update?.version_code ? !!asLocal.warning : true,
      (asLocal.warning || 'لا تخالف').slice(0, 70))

    // التنزيل من المسار المُحدَّد — يُقارن بالملف الأصلي المُمرَّر بـ--apk
    const pub = await json(await api('/app-update', {}, ''))
    const r = await fetch(pub.update.url)
    const bytes = Buffer.from(new Uint8Array(await r.arrayBuffer()))
    const src = readFileSync(APK)
    check('30) التنزيل من المسار المُحدَّد مطابق بايت ببايت',
      Buffer.compare(bytes, src) === 0, `${bytes.length} بايت`)
    check('31) نوع ملف التنزيل = حزمة أندرويد',
      (r.headers.get('content-type') || '').includes('android.package-archive'),
      r.headers.get('content-type'))
  }

  // حالات الرفض
  const trav = await json(await api('/admin/app-update', {
    method: 'PUT', body: JSON.stringify({ path: '../../etc/passwd.apk' }),
  }))
  check('32) مسار يخرج من مجلد الموقع → مرفوض', trav.ok === false, trav.message)

  const ext = await json(await api('/admin/app-update', {
    method: 'PUT', body: JSON.stringify({ path: 'api/api.php' }),
  }))
  check('33) مسار لا ينتهي بـ .apk → مرفوض', ext.ok === false, ext.message)

  const ghost = await json(await api('/admin/app-update', {
    method: 'PUT', body: JSON.stringify({ path: 'apk/ghost-file.apk' }),
  }))
  check('34) ملف غير موجود → يُحفظ كمسار مع تحذير «لم يُعثر عليه»',
    ghost.ok === true && ghost.update?.path_status?.found === false,
    ghost.update?.path_status?.message)

  const after = await json(await api('/app-update', {}, ''))
  check('35) مسار بملف غير موجود → لا يُعرض تحديث معطوب للتطبيق',
    after.update?.available === false, `available=${after.update?.available}`)
}

// ─────────────────────────────────────────────
// ٩) محاولة التراجع (حماية الإصدار)
// ─────────────────────────────────────────────
if (uploaded) {
  // اجعل المنشور 99 ثم افحص المجلد: الملفات فيه إصدارها أقدم
  await api('/admin/app-update', {
    method: 'PUT',
    body: JSON.stringify({ path: '', version_code: 99, version_name: '9.9.9' }),
  })
  await api('/admin/app-update/scan', {
    method: 'POST', body: JSON.stringify({ file: uploaded.apk_file }),
  })
  await api('/admin/app-update', {
    method: 'PUT', body: JSON.stringify({ version_code: 99, version_name: '9.9.9' }),
  })
  const d = await json(await api('/admin/app-update/scan', {
    method: 'POST', body: JSON.stringify({ force: true }),
  }))
  check('36) الفحص لا يُنزل رقم الإصدار عند وجود ملف أقدم',
    d.update?.version_code === 99,
    `بقي ${d.update?.version_code} · ${d.message?.slice(0, 60)}`)
}

// ─────────────────────────────────────────────
// ١٠) الفحص: منع الخروج من المجلد
// ─────────────────────────────────────────────
{
  const d = await json(await api('/admin/app-update/scan', {
    method: 'POST', body: JSON.stringify({ file: '../../../../etc/passwd' }),
  }))
  check('37) محاولة قراءة ملف خارج مجلد apk/ مرفوضة',
    d.ok === false, d.message)
}

// ─────────────────────────────────────────────
// ١١) الحذف
// ─────────────────────────────────────────────
if (uploaded) {
  const d = await json(await api('/admin/app-update/apk', { method: 'DELETE' }))
  check('38) حذف الملف المنشور', d.ok === true && d.update?.has_file === false, d.message)

  const pub = await json(await api('/app-update', {}, ''))
  check('39) بعد الحذف: لا يعرض التطبيق تحديثاً',
    pub.update?.available === false || !pub.update?.has_file, `available=${pub.update?.available}`)
}

// ─────────────────────────────────────────────
// ١٢) سلامة الأرشيف
// ─────────────────────────────────────────────
{
  const zipPath = join(ROOT, 'winfeen-upload.zip')
  if (existsSync(zipPath)) {
    const list = execFileSync('unzip', ['-l', zipPath], { encoding: 'utf8' })
    check('40) الأرشيف يحوي الأداة الجديدة', list.includes('api/rotate_key.php'), '')
    check('41) الأرشيف يحوي وحدة التحديث', list.includes('api/includes/app_update.php'), '')
    check('42) الأرشيف لا يحوي قاعدة البيانات', !list.includes('app.sqlite'), '')
    check('43) الأرشيف لا يحوي مفتاح الجلسات', !/secret\.key/.test(list), '')
    check('44) الأرشيف يحوي مجلد apk/', list.includes('apk/'), '')
  } else {
    console.log('  ⏭️  فحوص الأرشيف — لم يُبنَ بعد')
  }
}

// ─────────────────────────────────────────────
// ١٣) الواجهة (اختياري: --ui)
// ─────────────────────────────────────────────
if (RUN_UI) {
  try {
    // jsdom قد يكون مثبّتاً خارج المستودع — اسمح بتمريره عبر JSDOM_PATH
    let jsdom = null
    try {
      jsdom = await import('jsdom')
    } catch {
      const p = process.env.JSDOM_PATH
      if (p && existsSync(p)) jsdom = await import(`file://${p}`)
      else throw new Error('jsdom غير مثبّت')
    }
    const { JSDOM, VirtualConsole } = jsdom
    const indexHtml = readFileSync(join(ROOT, 'winfeen', 'index.html'), 'utf8')
    const js = (indexHtml.match(/assets\/index-[\w-]+\.js/) || [])[0]
    const css = (indexHtml.match(/assets\/index-[\w-]+\.css/) || [])[0]

    if (!js) {
      check('45) حزمة الواجهة موجودة', false, 'لم يُعثر على assets/index-*.js')
    } else {
      check('45) حزمة الواجهة موجودة', true, `${js} · ${css}`)
      const vc = new VirtualConsole()
      const errors = []
      vc.on('jsdomError', (e) => errors.push(e.message))
      const html = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<base href="${BASE}/"><link rel="stylesheet" href="${BASE}/${css}"></head>
<body><div id="root"></div><script src="${BASE}/${js}"></script></body></html>`

      const dom = new JSDOM(html, {
        url: `${BASE}/admin`,
        runScripts: 'dangerously',
        resources: 'usable',
        pretendToBeVisual: true,
        virtualConsole: vc,
        beforeParse(w) {
          w.localStorage.setItem('winfeen_token', TOKEN)
          w.fetch = (i, o) => fetch(typeof i === 'string' ? new URL(i, BASE).href : i, o)
          w.confirm = () => true
        },
      })
      const w = dom.window
      const $$ = (s) => [...w.document.querySelectorAll(s)]
      const text = (e) => (e?.textContent || '').replace(/\s+/g, ' ').trim()
      const has = (t) => w.document.body.textContent.replace(/\s+/g, ' ').includes(t)
      const wait = (ms) => new Promise((r) => setTimeout(r, ms))

      for (let i = 0; i < 60 && !has('تحديث التطبيق'); i++) await wait(200)
      check('46) لوحة التحكم تُحمَّل', has('لوحة تحكم المدير'), '')

      const tab = $$('button[role="tab"]').find((b) => text(b).includes('تحديث التطبيق'))
      check('47) تبويب «تحديث التطبيق» موجود', !!tab, '')
      tab?.click()
      for (let i = 0; i < 50 && !w.document.querySelector('.appup'); i++) await wait(200)

      check('48) التبويب يرسم حالته', !!w.document.querySelector('.appup__status-head strong'),
        text(w.document.querySelector('.appup__status-head strong')))
      check('49) حقول الإصدار والملاحظات والإلزامي والرابط',
        $$('textarea').length > 0 && !!w.document.querySelector('.appup__check input') && $$('input[dir=ltr]').length >= 3, '')
      check('50) زر «فحص المجلد» موجود',
        $$('.btn').some((b) => text(b).includes('فحص مجلد')), '')
      check('51) زر «رفع ونشر» موجود',
        $$('.btn').some((b) => text(b).includes('رفع ونشر')), '')

      let scanReq = null
      const of = w.fetch
      w.fetch = (i, o) => { const u = String(i); if (u.includes('/scan')) scanReq = o?.method; return of(i, o) }
      $$('.btn').find((b) => text(b).includes('فحص مجلد'))?.click()
      for (let i = 0; i < 40 && !scanReq; i++) await wait(200)
      check('52) «فحص المجلد» يُرسل POST صحيحاً', scanReq === 'POST', String(scanReq))
      w.fetch = of
      await wait(600)
      check('53) لا أخطاء جافاسكربت في اللوحة', errors.length === 0, errors.slice(0, 2).join(' | '))
    }
  } catch (e) {
    console.log(`  ⚠️  فحوص الواجهة متعذّرة (${String(e.message).slice(0, 80)}) — ثبّت jsdom: npm install jsdom`)
  }
} else {
  console.log('  ℹ️  فحوص الواجهة متخطّاة — أضف --ui وثبّت jsdom')
}

// ─────────────────────────────────────────────
// النتيجة
// ─────────────────────────────────────────────
console.log('\n  ─────────────────────────────────────────────────────────────')
for (const r of results) {
  console.log(`  ${r.ok ? '✅' : '❌'} ${r.name}${r.detail ? `  → ${r.detail}` : ''}`)
}
const total = pass + fail
console.log('  ─────────────────────────────────────────────────────────────')
console.log(`  ${fail === 0 ? '🎯' : '⚠️'} النتيجة: ${pass}/${total} ناجح${fail ? ` · ${fail} فاشل` : ''}\n`)
process.exit(fail === 0 ? 0 : 1)

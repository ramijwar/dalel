# فحوص المشروع

## `app_update_qa.mjs` — ميزة تحديث تطبيق أندرويد

يفحص الخاصية من طرف إلى طرف: الخادم (PHP) ولوحة التحكم (في متصفح افتراضي).

```bash
# ١) شغّل الخادم
cd project/winfeen && ../php-bin/php -S 127.0.0.1:8090 router.php

# ٢) خُذ رمز المدير
cd api && php -r "define('APP_ROOT',getcwd()); require APP_ROOT.'/includes/token.php'; echo issue_token(33,'admin',1);"

# ٣) شغّل الفحص (أضف --apk لملف APK حقيقي و --ui لفحوص اللوحة)
node project/qa/app_update_qa.mjs --base http://127.0.0.1:8090 --token <الرمز> --apk /مسار/app.apk --ui
```

فحوص الواجهة تحتاج `jsdom`. إن ثبّتها خارج المستودع فأشر إليها:

```bash
npm install jsdom && JSDOM_PATH=$PWD/node_modules/jsdom/lib/api.js node project/qa/app_update_qa.mjs … --ui
```

**آخر نتيجة: ٤١/٤١ ناجح** (خادم في مجلد فرعي + ملف APK حقيقي).

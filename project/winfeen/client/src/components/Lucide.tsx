/**
 * أيقونات Lucide — مستخرجة من ajabwen.online
 *
 * المصدر: lucide-static (رخصة ISC) — نفس المكتبة التي يستخدمها الموقع الأصلي.
 * مضمّنة كـ SVG داخلي: لا شبكة، لا CDN، وتعمل مع currentColor فتتلوّن تلقائياً.
 * العدد: 103 أيقونة (أقسام + واجهة + لوحة تحكم).
 */
import type { CSSProperties } from 'react'

/** مسارات كل أيقونة — مستخرجة من ملفات SVG الأصلية للمكتبة */
export const LUCIDE_PATHS: Record<string, string> = {
  'a-large-small': // حجم الخط
    '<path d="m15 16 2.536-7.328a1.02 1.02 1 0 1 1.928 0L22 16" /><path d="M15.697 14h5.606" /><path d="m2 16 4.039-9.69a.5.5 0 0 1 .923 0L11 16" /><path d="M3.304 13h6.392" />',
  'activity': // نشاط
    '<path d="M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2" />',
  'alert-triangle': // تحذير
    '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3" /><path d="M12 9v4" /><path d="M12 17h.01" />',
  'ambulance': // إسعاف
    '<path d="M10 10H6" /><path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2" /><path d="M19 18h2a1 1 0 0 0 1-1v-3.28a1 1 0 0 0-.684-.948l-1.923-.641a1 1 0 0 1-.578-.502l-1.539-3.076A1 1 0 0 0 16.382 8H14" /><path d="M8 8v4" /><path d="M9 18h6" /><circle cx="17" cy="18" r="2" /><circle cx="7" cy="18" r="2" />',
  'arrow-left': // رجوع
    '<path d="m12 19-7-7 7-7" /><path d="M19 12H5" />',
  'arrow-right': // التالي
    '<path d="M5 12h14" /><path d="m12 5 7 7-7 7" />',
  'arrow-right-left': // تبديل
    '<path d="m16 3 4 4-4 4" /><path d="M20 7H4" /><path d="m8 21-4-4 4-4" /><path d="M4 17h16" />',
  'arrow-up-down': // ترتيب
    '<path d="m21 16-4 4-4-4" /><path d="M17 20V4" /><path d="m3 8 4-4 4 4" /><path d="M7 4v16" />',
  'badge-check': // موثق
    '<path d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z" /><path d="m16 9-5.5 5.5L8 12" />',
  'bandage': // ضمادة
    '<path d="M10 10.01h.01" /><path d="M10 14.01h.01" /><path d="M14 10.01h.01" /><path d="M14 14.01h.01" /><path d="M18 6v12" /><path d="M6 6v12" /><rect x="2" y="6" width="20" height="12" rx="2" />',
  'bar-chart-3': // إحصاءات
    '<path d="M3 3v16a2 2 0 0 0 2 2h16" /><path d="M18 17V9" /><path d="M13 17V5" /><path d="M8 17v-3" />',
  'battery-charging': // شحن
    '<path d="m11 7-3 5h4l-3 5" /><path d="M14.856 6H16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2.935" /><path d="M22 14v-4" /><path d="M5.14 18H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2.936" />',
  'bell': // تنبيهات
    '<path d="M10.268 21a2 2 0 0 0 3.464 0" /><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326" />',
  'bell-plus': // إضافة تنبيه
    '<path d="M10.268 21a2 2 0 0 0 3.464 0" /><path d="M15 8h6" /><path d="M18 5v6" /><path d="M20.002 14.464a9 9 0 0 0 .738.863A1 1 0 0 1 20 17H4a1 1 0 0 1-.74-1.673C4.59 13.956 6 12.499 6 8a6 6 0 0 1 8.75-5.332" />',
  'bike': // دراجة
    '<circle cx="18.5" cy="17.5" r="3.5" /><circle cx="5.5" cy="17.5" r="3.5" /><circle cx="15" cy="5" r="1" /><path d="M12 17.5V14l-3-3 4-3 2 3h2" />',
  'bone': // عظام
    '<path d="M17 10c.7-.7 1.69 0 2.5 0a2.5 2.5 0 1 0 0-5 .5.5 0 0 1-.5-.5 2.5 2.5 0 1 0-5 0c0 .81.7 1.8 0 2.5l-7 7c-.7.7-1.69 0-2.5 0a2.5 2.5 0 0 0 0 5c.28 0 .5.22.5.5a2.5 2.5 0 1 0 5 0c0-.81-.7-1.8 0-2.5Z" />',
  'boxes': // صناديق
    '<path d="M2.97 12.92A2 2 0 0 0 2 14.63v3.24a2 2 0 0 0 .97 1.71l3 1.8a2 2 0 0 0 2.06 0L12 19v-5.5l-5-3-4.03 2.42Z" /><path d="m7 16.5-4.74-2.85" /><path d="m7 16.5 5-3" /><path d="M7 16.5v5.17" /><path d="M12 13.5V19l3.97 2.38a2 2 0 0 0 2.06 0l3-1.8a2 2 0 0 0 .97-1.71v-3.24a2 2 0 0 0-.97-1.71L17 10.5l-5 3Z" /><path d="m17 16.5-5-3" /><path d="m17 16.5 4.74-2.85" /><path d="M17 16.5v5.17" /><path d="M7.97 4.42A2 2 0 0 0 7 6.13v4.37l5 3 5-3V6.13a2 2 0 0 0-.97-1.71l-3-1.8a2 2 0 0 0-2.06 0l-3 1.8Z" /><path d="M12 8 7.26 5.15" /><path d="m12 8 4.74-2.85" /><path d="M12 13.5V8" />',
  'brain': // مخ وأعصاب
    '<path d="M12 18V5" /><path d="M15 13a4.17 4.17 0 0 1-3-4 4.17 4.17 0 0 1-3 4" /><path d="M17.598 6.5A3 3 0 1 0 12 5a3 3 0 1 0-5.598 1.5" /><path d="M17.997 5.125a4 4 0 0 1 2.526 5.77" /><path d="M18 18a4 4 0 0 0 2-7.464" /><path d="M19.967 17.483A4 4 0 1 1 12 18a4 4 0 1 1-7.967-.517" /><path d="M6 18a4 4 0 0 1-2-7.464" /><path d="M6.003 5.125a4 4 0 0 0-2.526 5.77" />',
  'building': // مبنى
    '<path d="M12 10h.01" /><path d="M12 14h.01" /><path d="M12 6h.01" /><path d="M16 10h.01" /><path d="M16 14h.01" /><path d="M16 6h.01" /><path d="M8 10h.01" /><path d="M8 14h.01" /><path d="M8 6h.01" /><path d="M9 22v-3a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v3" /><rect x="4" y="2" width="16" height="20" rx="2" />',
  'bus': // باص
    '<path d="M8 6v6" /><path d="M15 6v6" /><path d="M2 12h19.6" /><path d="M18 18h3s.5-1.7.8-2.8c.1-.4.2-.8.2-1.2 0-.4-.1-.8-.2-1.2l-1.4-5C20.1 6.8 19.1 6 18 6H4a2 2 0 0 0-2 2v10h3" /><circle cx="7" cy="18" r="2" /><path d="M9 18h5" /><circle cx="16" cy="18" r="2" />',
  'calendar': // تاريخ
    '<path d="M8 2v3" /><path d="M16 2v3" /><rect x="3" y="3" width="18" height="18" rx="2" /><path d="M3 9h18" />',
  'car': // سيارة
    '<path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2" /><circle cx="7" cy="17" r="2" /><path d="M9 17h6" /><circle cx="17" cy="17" r="2" />',
  'chart-pie': // نِسَب
    '<path d="M21 12c.552 0 1.005-.449.95-.998a10 10 0 0 0-8.953-8.951c-.55-.055-.998.398-.998.95v8a1 1 0 0 0 1 1z" /><path d="M21.21 15.89A10 10 0 1 1 8 2.83" />',
  'check': // موافقة
    '<path d="M20 6 9 17l-5-5" />',
  'check-circle-2': // مؤكد
    '<circle cx="12" cy="12" r="10" /><path d="m16 9-5.5 5.5L8 12" />',
  'chevron-down': // أسفل
    '<path d="m6 9 6 6 6-6" />',
  'chevron-left': // السابق
    '<path d="m15 18-6-6 6-6" />',
  'chevron-right': // التالي
    '<path d="m9 18 6-6-6-6" />',
  'chevrons-up-down': // ترتيب
    '<path d="m7 15 5 5 5-5" /><path d="m7 9 5-5 5 5" />',
  'circle-check-big': // مؤكد
    '<path d="M21.801 10A10 10 0 1 1 17 3.335" /><path d="m9 11 3 3L22 4" />',
  'circle-x': // مرفوض
    '<circle cx="12" cy="12" r="10" /><path d="m15 9-6 6" /><path d="m9 9 6 6" />',
  'clock': // دوام
    '<circle cx="12" cy="12" r="10" /><path d="M12 6v6l4 2" />',
  'crown': // مدير
    '<path d="M11.562 3.266a.5.5 0 0 1 .876 0L15.39 8.87a1 1 0 0 0 1.516.294L21.183 5.5a.5.5 0 0 1 .798.519l-2.834 10.246a1 1 0 0 1-.956.734H5.81a1 1 0 0 1-.957-.734L2.02 6.02a.5.5 0 0 1 .798-.519l4.276 3.664a1 1 0 0 0 1.516-.294z" /><path d="M5 21h14" />',
  'database': // قاعدة بيانات
    '<ellipse cx="12" cy="5" rx="9" ry="3" /><path d="M3 5V19A9 3 0 0 0 21 19V5" /><path d="M3 12A9 3 0 0 0 21 12" />',
  'download': // تنزيل
    '<path d="M12 15V3" /><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><path d="m7 10 5 5 5-5" />',
  'droplets': // سوائل
    '<path d="M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z" /><path d="M12.56 6.6A10.97 10.97 0 0 0 14 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 0 1-11.91 4.97" />',
  'ellipsis': // المزيد
    '<circle cx="12" cy="12" r="1" /><circle cx="19" cy="12" r="1" /><circle cx="5" cy="12" r="1" />',
  'eye': // عرض
    '<path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0" /><circle cx="12" cy="12" r="3" />',
  'eye-off': // إخفاء
    '<path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49" /><path d="M14.084 14.158a3 3 0 0 1-4.242-4.242" /><path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143" /><path d="m2 2 20 20" />',
  'file-text': // ملف
    '<path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z" /><path d="M14 2v5a1 1 0 0 0 1 1h5" /><path d="M10 9H8" /><path d="M16 13H8" /><path d="M16 17H8" />',
  'filter': // تصفية
    '<path d="M10 20a1 1 0 0 0 .553.895l2 1A1 1 0 0 0 14 21v-7a2 2 0 0 1 .517-1.341L21.74 4.67A1 1 0 0 0 21 3H3a1 1 0 0 0-.742 1.67l7.225 7.989A2 2 0 0 1 10 14z" />',
  'folder': // مجلد
    '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z" />',
  'fuel': // وقود
    '<path d="M14 13h2a2 2 0 0 1 2 2v2a2 2 0 0 0 4 0v-6.998a2 2 0 0 0-.59-1.42L18 5" /><path d="M14 21V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v16" /><path d="M2 21h13" /><path d="M3 9h11" />',
  'gift': // هدايا
    '<path d="M12 7v14" /><path d="M20 11v8a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-8" /><path d="M7.5 7a1 1 0 0 1 0-5A4.8 8 0 0 1 12 7a4.8 8 0 0 1 4.5-5 1 1 0 0 1 0 5" /><rect x="3" y="7" width="18" height="4" rx="1" />',
  'heart': // قلب
    '<path d="M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5" />',
  'heart-pulse': // نبض
    '<path d="M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5" /><path d="M3.22 13H9.5l.5-1 2 4.5 2-7 1.5 3.5h5.27" />',
  'hospital': // مستشفى
    '<path d="M12 7v4" /><path d="M14 21v-3a2 2 0 0 0-4 0v3" /><path d="M14 9h-4" /><path d="M18 11h2a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2h2" /><path d="M18 21V5a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16" />',
  'house': // الرئيسية
    '<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8" /><path d="M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />',
  'image': // صورة
    '<rect width="18" height="18" x="3" y="3" rx="2" ry="2" /><circle cx="9" cy="9" r="2" /><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21" />',
  'inbox': // صندوق الوارد
    '<polyline points="22 12 16 12 14 15 10 15 8 12 2 12" /><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z" />',
  'info': // معلومات
    '<circle cx="12" cy="12" r="10" /><path d="M12 16v-4" /><path d="M12 8h.01" />',
  'layout-grid': // بطاقات
    '<rect width="7" height="7" x="3" y="3" rx="1" /><rect width="7" height="7" x="14" y="3" rx="1" /><rect width="7" height="7" x="14" y="14" rx="1" /><rect width="7" height="7" x="3" y="14" rx="1" />',
  'list': // قائمة
    '<path d="M3 5h.01" /><path d="M3 12h.01" /><path d="M3 19h.01" /><path d="M8 5h13" /><path d="M8 12h13" /><path d="M8 19h13" />',
  'list-filter': // ترتيب
    '<path d="M2 5h20" /><path d="M6 12h12" /><path d="M9 19h6" />',
  'locate-fixed': // موقعي
    '<line x1="2" x2="5" y1="12" y2="12" /><line x1="19" x2="22" y1="12" y2="12" /><line x1="12" x2="12" y1="2" y2="5" /><line x1="12" x2="12" y1="19" y2="22" /><circle cx="12" cy="12" r="7" /><circle cx="12" cy="12" r="3" />',
  'lock': // قفل
    '<rect width="18" height="11" x="3" y="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" />',
  'log-out': // خروج
    '<path d="m16 17 5-5-5-5" /><path d="M21 12H9" /><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />',
  'map': // خريطة
    '<path d="M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z" /><path d="M15 5.764v15" /><path d="M9 3.236v15" />',
  'map-pin': // موقع
    '<path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0" /><circle cx="12" cy="10" r="3" />',
  'menu': // قائمة
    '<path d="M4 5h16" /><path d="M4 12h16" /><path d="M4 19h16" />',
  'message-circle': // رسالة
    '<path d="M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719" />',
  'minus': // حذف
    '<path d="M5 12h14" />',
  'package': // طرود
    '<path d="M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z" /><path d="M12 22V12" /><polyline points="3.29 7 12 12 20.71 7" /><path d="m7.5 4.27 9 5.15" />',
  'pencil': // تعديل
    '<path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z" /><path d="m15 5 4 4" />',
  'phone': // هاتف
    '<path d="M13.832 16.568a1 1 0 0 0 1.213-.303l.355-.465A2 2 0 0 1 17 15h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2A18 18 0 0 1 2 4a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v3a2 2 0 0 1-.8 1.6l-.468.351a1 1 0 0 0-.292 1.233 14 14 0 0 0 6.392 6.384" />',
  'pill': // صيدلية
    '<path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z" /><path d="m8.5 8.5 7 7" />',
  'plus': // إضافة
    '<path d="M5 12h14" /><path d="M12 5v14" />',
  'refresh-cw': // تحديث
    '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" /><path d="M21 3v5h-5" /><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" /><path d="M8 16H3v5" />',
  'save': // حفظ
    '<path d="M15.2 3a2 2 0 0 1 1.4.6l3.8 3.8a2 2 0 0 1 .6 1.4V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z" /><path d="M17 21v-7a1 1 0 0 0-1-1H8a1 1 0 0 0-1 1v7" /><path d="M7 3v4a1 1 0 0 0 1 1h7" />',
  'search': // بحث
    '<path d="m21 21-4.34-4.34" /><circle cx="11" cy="11" r="8" />',
  'server': // خادم
    '<rect width="20" height="8" x="2" y="2" rx="2" ry="2" /><rect width="20" height="8" x="2" y="14" rx="2" ry="2" /><line x1="6" x2="6.01" y1="6" y2="6" /><line x1="6" x2="6.01" y1="18" y2="18" />',
  'settings': // إعدادات
    '<path d="M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915" /><circle cx="12" cy="12" r="3" />',
  'shield': // صلاحية
    '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z" />',
  'shield-alert': // تحذير صلاحية
    '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z" /><path d="M12 8v4" /><path d="M12 16h.01" />',
  'shield-check': // حماية
    '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z" /><path d="m9 12 2 2 4-4" />',
  'shopping-bag': // سوق
    '<path d="M16 10a4 4 0 0 1-8 0" /><path d="M3.103 6.034h17.794" /><path d="M3.4 5.467a2 2 0 0 0-.4 1.2V20a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6.667a2 2 0 0 0-.4-1.2l-2-2.667A2 2 0 0 0 17 2H7a2 2 0 0 0-1.6.8z" />',
  'shopping-cart': // عربة تسوق
    '<path d="m2.05 2.05 1.099-.028a1 1 0 0 1 1.008.815l2.69 14.347A1 1 0 0 0 7.83 18H18" /><path d="M4.563 5h16.435a1 1 0 0 1 .981 1.204l-1.026 6.226A2 2 0 0 1 18.962 14H6.25" /><circle cx="18" cy="20" r="2" /><circle cx="8" cy="20" r="2" />',
  'siren': // إنذار
    '<path d="M7 18v-6a5 5 0 1 1 10 0v6" /><path d="M5 21a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-1a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2z" /><path d="M21 12h1" /><path d="M18.5 4.5 18 5" /><path d="M2 12h1" /><path d="M12 2v1" /><path d="m4.929 4.929.707.707" /><path d="M12 12v6" />',
  'sliders-horizontal': // ضبط
    '<path d="M10 5H3" /><path d="M12 19H3" /><path d="M14 3v4" /><path d="M16 17v4" /><path d="M21 12h-9" /><path d="M21 19h-5" /><path d="M21 5h-7" /><path d="M8 10v4" /><path d="M8 12H3" />',
  'sort-desc': // فرز
    '<path d="m3 16 4 4 4-4" /><path d="M7 20V4" /><path d="M11 4h10" /><path d="M11 8h7" /><path d="M11 12h4" />',
  'star': // مميز
    '<path d="M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z" />',
  'stethoscope': // سماعة طبية
    '<path d="M11 2v2" /><path d="M5 2v2" /><path d="M5 3H4a2 2 0 0 0-2 2v4a6 6 0 0 0 12 0V5a2 2 0 0 0-2-2h-1" /><path d="M8 15a6 6 0 0 0 12 0v-3" /><circle cx="20" cy="10" r="2" />',
  'store': // متجر
    '<path d="M15 21v-5a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v5" /><path d="M17.774 10.31a1.12 1.12 0 0 0-1.549 0 2.5 2.5 0 0 1-3.451 0 1.12 1.12 0 0 0-1.548 0 2.5 2.5 0 0 1-3.452 0 1.12 1.12 0 0 0-1.549 0 2.5 2.5 0 0 1-3.77-3.248l2.889-4.184A2 2 0 0 1 7 2h10a2 2 0 0 1 1.653.873l2.895 4.192a2.5 2.5 0 0 1-3.774 3.244" /><path d="M4 10.95V19a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8.05" />',
  'syringe': // حقنة
    '<path d="m18 2 4 4" /><path d="m17 7 3-3" /><path d="M19 9 8.7 19.3c-1 1-2.5 1-3.4 0l-.6-.6c-1-1-1-2.5 0-3.4L15 5" /><path d="m9 11 4 4" /><path d="m5 19-3 3" /><path d="m14 4 6 6" />',
  'table-2': // جدول
    '<path d="M3 9h18" /><path d="M9 3v18" /><rect x="3" y="3" width="18" height="18" rx="2" />',
  'tag': // وسم
    '<path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z" /><circle cx="7.5" cy="7.5" r=".5" fill="currentColor" />',
  'tags': // وسوم
    '<path d="M13.172 2a2 2 0 0 1 1.414.586l6.71 6.71a2.4 2.4 0 0 1 0 3.408l-4.592 4.592a2.4 2.4 0 0 1-3.408 0l-6.71-6.71A2 2 0 0 1 6 9.172V3a1 1 0 0 1 1-1z" /><path d="M2 7v6.172a2 2 0 0 0 .586 1.414l6.71 6.71a2.4 2.4 0 0 0 3.191.193" /><circle cx="10.5" cy="6.5" r=".5" fill="currentColor" />',
  'thermometer': // حرارة
    '<path d="M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z" />',
  'train-front': // قطار
    '<path d="M8 3.1V7a4 4 0 0 0 8 0V3.1" /><path d="m9 15-1-1" /><path d="m15 15 1-1" /><path d="M9 19c-2.8 0-5-2.2-5-5v-4a8 8 0 0 1 16 0v4c0 2.8-2.2 5-5 5Z" /><path d="m8 19-2 3" /><path d="m16 19 2 3" />',
  'trash-2': // حذف
    '<path d="M10 11v6" /><path d="M14 11v6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" /><path d="M3 6h18" /><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />',
  'trending-up': // اتجاه
    '<path d="M16 7h6v6" /><path d="m22 7-8.5 8.5-5-5L2 17" />',
  'truck': // شاحنة
    '<path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2" /><path d="M15 18H9" /><path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.624l-3.48-4.35A1 1 0 0 0 17.52 8H14" /><circle cx="17" cy="18" r="2" /><circle cx="7" cy="18" r="2" />',
  'unlock': // فتح
    '<rect width="18" height="11" x="3" y="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 9.9-1" />',
  'upload': // رفع
    '<path d="M12 3v12" /><path d="m17 8-5-5-5 5" /><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />',
  'user': // مستخدم
    '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2" /><circle cx="12" cy="7" r="4" />',
  'user-check': // تفعيل مستخدم
    '<path d="m16 11 2 2 4-4" /><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />',
  'user-round': // مستخدم
    '<circle cx="12" cy="8" r="5" /><path d="M20 21a8 8 0 0 0-16 0" />',
  'user-x': // تعطيل مستخدم
    '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><line x1="17" x2="22" y1="8" y2="13" /><line x1="22" x2="17" y1="8" y2="13" />',
  'users': // مستخدمون
    '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><path d="M16 3.128a4 4 0 0 1 0 7.744" /><path d="M22 21v-2a4 4 0 0 0-3-3.87" /><circle cx="9" cy="7" r="4" />',
  'warehouse': // مستودع
    '<path d="M18 21V10a1 1 0 0 0-1-1H7a1 1 0 0 0-1 1v11" /><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 1.132-1.803l7.95-3.974a2 2 0 0 1 1.837 0l7.948 3.974A2 2 0 0 1 22 8z" /><path d="M6 13h12" /><path d="M6 17h12" />',
  'wrench': // أدوات
    '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.106-3.105c.32-.322.863-.22.983.218a6 6 0 0 1-8.259 7.057l-7.91 7.91a1 1 0 0 1-2.999-3l7.91-7.91a6 6 0 0 1 7.057-8.259c.438.12.54.662.219.984z" />',
  'x-circle': // مرفوض
    '<circle cx="12" cy="12" r="10" /><path d="m15 9-6 6" /><path d="m9 9 6 6" />',
  'zap': // كهرباء
    '<path d="M15.914 4a1.5 1.5 0 00-2.474-1.561l-9 9A1.5 1.5 0 005.5 14h4.002a.5.5 0 01.471.666L8.086 20a1.5 1.5 0 002.475 1.56l9-9A1.5 1.5 0 0018.5 10h-3.997a.5.5 0 01-.472-.667z" />',
}

/** الاسم العربي لكل أيقونة */
export const LUCIDE_LABELS: Record<string, string> = {
  'a-large-small': 'حجم الخط',
  'activity': 'نشاط',
  'alert-triangle': 'تحذير',
  'ambulance': 'إسعاف',
  'arrow-left': 'رجوع',
  'arrow-right': 'التالي',
  'arrow-right-left': 'تبديل',
  'arrow-up-down': 'ترتيب',
  'badge-check': 'موثق',
  'bandage': 'ضمادة',
  'bar-chart-3': 'إحصاءات',
  'battery-charging': 'شحن',
  'bell': 'تنبيهات',
  'bell-plus': 'إضافة تنبيه',
  'bike': 'دراجة',
  'bone': 'عظام',
  'boxes': 'صناديق',
  'brain': 'مخ وأعصاب',
  'building': 'مبنى',
  'bus': 'باص',
  'calendar': 'تاريخ',
  'car': 'سيارة',
  'chart-pie': 'نِسَب',
  'check': 'موافقة',
  'check-circle-2': 'مؤكد',
  'chevron-down': 'أسفل',
  'chevron-left': 'السابق',
  'chevron-right': 'التالي',
  'chevrons-up-down': 'ترتيب',
  'circle-check-big': 'مؤكد',
  'circle-x': 'مرفوض',
  'clock': 'دوام',
  'crown': 'مدير',
  'database': 'قاعدة بيانات',
  'download': 'تنزيل',
  'droplets': 'سوائل',
  'ellipsis': 'المزيد',
  'eye': 'عرض',
  'eye-off': 'إخفاء',
  'file-text': 'ملف',
  'filter': 'تصفية',
  'folder': 'مجلد',
  'fuel': 'وقود',
  'gift': 'هدايا',
  'heart': 'قلب',
  'heart-pulse': 'نبض',
  'hospital': 'مستشفى',
  'house': 'الرئيسية',
  'image': 'صورة',
  'inbox': 'صندوق الوارد',
  'info': 'معلومات',
  'layout-grid': 'بطاقات',
  'list': 'قائمة',
  'list-filter': 'ترتيب',
  'locate-fixed': 'موقعي',
  'lock': 'قفل',
  'log-out': 'خروج',
  'map': 'خريطة',
  'map-pin': 'موقع',
  'menu': 'قائمة',
  'message-circle': 'رسالة',
  'minus': 'حذف',
  'package': 'طرود',
  'pencil': 'تعديل',
  'phone': 'هاتف',
  'pill': 'صيدلية',
  'plus': 'إضافة',
  'refresh-cw': 'تحديث',
  'save': 'حفظ',
  'search': 'بحث',
  'server': 'خادم',
  'settings': 'إعدادات',
  'shield': 'صلاحية',
  'shield-alert': 'تحذير صلاحية',
  'shield-check': 'حماية',
  'shopping-bag': 'سوق',
  'shopping-cart': 'عربة تسوق',
  'siren': 'إنذار',
  'sliders-horizontal': 'ضبط',
  'sort-desc': 'فرز',
  'star': 'مميز',
  'stethoscope': 'سماعة طبية',
  'store': 'متجر',
  'syringe': 'حقنة',
  'table-2': 'جدول',
  'tag': 'وسم',
  'tags': 'وسوم',
  'thermometer': 'حرارة',
  'train-front': 'قطار',
  'trash-2': 'حذف',
  'trending-up': 'اتجاه',
  'truck': 'شاحنة',
  'unlock': 'فتح',
  'upload': 'رفع',
  'user': 'مستخدم',
  'user-check': 'تفعيل مستخدم',
  'user-round': 'مستخدم',
  'user-x': 'تعطيل مستخدم',
  'users': 'مستخدمون',
  'warehouse': 'مستودع',
  'wrench': 'أدوات',
  'x-circle': 'مرفوض',
  'zap': 'كهرباء',
}

/** الأيقونة الافتراضية لكل قسم — مطابقة للموقع الأصلي */
export const CATEGORY_ICONS: Record<string, string> = {
  'pharmacies': 'pill',
  'doctors': 'stethoscope',
  'stations': 'fuel',
  'transport': 'bus',
  'bazaars': 'shopping-bag',
}

/**
 * الأيقونات المقترحة لكل قسم — تظهر في منتقي الأيقونات عند إضافة أو تعديل خدمة.
 */
export const CATEGORY_ICON_SETS: Record<string, string[]> = {
  'pharmacies': [
    'pill', 'syringe', 'bandage', 'heart-pulse', 'thermometer', 'activity', 'package', 'badge-check', 'clock', 'map-pin',
  ],
  'doctors': [
    'stethoscope', 'heart', 'heart-pulse', 'brain', 'bone', 'eye', 'thermometer', 'activity', 'hospital', 'building', 'badge-check',
  ],
  'stations': [
    'fuel', 'droplets', 'car', 'truck', 'zap', 'battery-charging', 'warehouse', 'package', 'badge-check', 'clock',
  ],
  'transport': [
    'bus', 'car', 'ambulance', 'siren', 'train-front', 'truck', 'bike', 'package', 'clock', 'map-pin',
  ],
  'bazaars': [
    'shopping-bag', 'store', 'shopping-cart', 'package', 'tag', 'gift', 'warehouse', 'building', 'clock', 'map-pin',
  ],
}

/** مجموعة عامة تُستخدم إن لم يكن للقسم مجموعة خاصة */
export const DEFAULT_ICON_SET: string[] = [
  'map-pin', 'store', 'package', 'badge-check', 'clock', 'building', 'warehouse', 'tag', 'info',
]

/** أيقونة كل نوع مركبة في قسم النقل */
export const VEHICLE_LUCIDE: Record<string, string> = {
  'سرفيس': 'car',
  'باص': 'bus',
  'إسعاف': 'ambulance',
}

/** أيقونات تبويبات لوحة تحكم المدير */
export const ADMIN_TAB_ICONS: Record<string, string> = {
  overview: 'bar-chart-3',
  services: 'boxes',
  categories: 'layout-grid',
  regions: 'map-pin',
  requests: 'inbox',
  users: 'users',
  settings: 'settings',
  activity: 'activity',
}

/** أسماء كل الأيقونات المتاحة */
export const ALL_ICONS: string[] = Object.keys(LUCIDE_PATHS)

export type LucideName = string

interface Props {
  name: string
  size?: number
  className?: string
  style?: CSSProperties
  strokeWidth?: number
  title?: string
}

/**
 * أيقونة Lucide قابلة للتلوين والتحجيم.
 * @example <Lucide name="pill" size={20} />
 */
export default function Lucide({
  name,
  size = 20,
  className = '',
  style,
  strokeWidth = 2,
  title,
}: Props) {
  const body = LUCIDE_PATHS[name]

  // ─── احتياط: أيقونة ليست من Lucide ───
  // خيارات الحقول الديناميكية قد تحمل إيموجي (مثل 👶 للاختصاص) بدل اسم Lucide.
  // بلا هذا الاحتياط كان الوسم يُرجع null فتختفي الأيقونة بصمت من البطاقات
  // ومن منتقي الخيارات. نرسم أي نص لا يشبه أسماء Lucide اللاتينية كما هو.
  if (!body) {
    const isTextIcon = !!name && !/^[a-z0-9-]+$/.test(name)
    if (!isTextIcon) return null
    return (
      <span
        className={`lc lc--text ${className}`}
        style={{ fontSize: Math.round(size * 0.92), lineHeight: 1, ...style }}
        role={title ? 'img' : undefined}
        aria-label={title || undefined}
        aria-hidden={title ? undefined : true}
      >
        {name}
      </span>
    )
  }

  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={`lc ${className}`}
      style={style}
      role={title ? 'img' : undefined}
      aria-hidden={title ? undefined : true}
      dangerouslySetInnerHTML={{ __html: title ? `<title>${title}</title>${body}` : body }}
    />
  )
}
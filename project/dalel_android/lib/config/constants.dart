/// ثوابت التطبيق — الإعدادات العامة
class AppConfig {
  AppConfig._();

  /// رأس الخادم المباشر (بدون شرطة لاحقة)
  ///
  /// يمكن تغييره وقت البناء بلا تعديل الكود:
  ///   flutter build apk --dart-define=DALEL_BASE_URL=https://t3lam.site/daleltest
  /// فتبني نسخة تخاطب مسار الاختبار، وأخرى تخاطب المسار الأساسي.
  static const String baseUrl = String.fromEnvironment(
    'DALEL_BASE_URL',
    defaultValue: 'https://t3lam.site/dalel',
  );

  /// رأس نقاط النهاية البرمجية
  static const String apiBase = '$baseUrl/api';

  /// اسم التطبيق
  static const String appName = 'دليل الدير';

  /// وصف التطبيق
  static const String appTagline = 'دليل الخدمات اليومية';

  /// مدة صلاحية الذاكرة المؤقتة قبل إعادة المزامنة (بالدقائق)
  static const int cacheTtlMinutes = 10;

  /// عدد العناصر في كل صفحة — مطابق لسقف الخادم (min(200, limit))
  static const int pageSize = 200;

  /// حد قراءة الخدمات من القاعدة المحلية — يجب أن يتسع لكل خدمات
  /// كل الأقسام مجتمعة (القراءة المحلية رخيصة ولا سبب لقصّها)
  static const int localQueryLimit = 5000;

  /// مهلة الاتصال
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);

  /// رقم واتساب الإدارة (يُستبدل من الإعدادات عند توفرها)
  static String whatsappAdmin = '';
}

/// حالات الخدمة — تطابق الخادم
class ServiceStatus {
  ServiceStatus._();

  static const String open = 'open';
  static const String closed = 'closed';

  static String label(String? status, {bool onDuty = false}) {
    if (onDuty) return 'مناوبة';
    switch (status) {
      case open:
        return 'تعمل الآن';
      case closed:
        return 'مغلقة';
      default:
        return 'غير محددة';
    }
  }
}

/// ألوان الحالة
class StatusColors {
  StatusColors._();

  /// أخضر — تعمل الآن
  static const int open = 0xFF16A34A;

  /// أحمر — مغلقة
  static const int closed = 0xFFDC2626;

  /// بني — مناوبة
  static const int duty = 0xFF8B5E3C;

  /// رمادي — غير محددة
  static const int unknown = 0xFF94A3B8;

  static int of(String? status, {bool onDuty = false}) {
    if (onDuty) return duty;
    switch (status) {
      case ServiceStatus.open:
        return open;
      case ServiceStatus.closed:
        return closed;
      default:
        return unknown;
    }
  }
}

/// إعدادات عرض كل قسم — تطابق سلوك موقع الويب
class SectionConfig {
  final String slug;
  final String unit;
  final String unitPlural;

  /// 'region' | 'specialty' | 'meta'
  final String groupBy;

  /// مفتاح التجميع من حقل meta لقسم النقل
  final String? metaKey;

  /// بطاقات مربعة مُصغّرة (أيقونة + اسم + نقطة حالة) مع لوحة سفلية
  final bool mini;

  /// طريقة العرض الافتراضية
  final String defaultLayout;

  const SectionConfig({
    required this.slug,
    required this.unit,
    required this.unitPlural,
    required this.groupBy,
    this.metaKey,
    this.mini = true,
    this.defaultLayout = 'card',
  });

  static const Map<String, SectionConfig> all = {
    'pharmacies': SectionConfig(
      slug: 'pharmacies',
      unit: 'صيدلية',
      unitPlural: 'صيدليات',
      groupBy: 'region',
    ),
    'doctors': SectionConfig(
      slug: 'doctors',
      unit: 'طبيب',
      unitPlural: 'أطباء',
      groupBy: 'specialty',
    ),
    'stations': SectionConfig(
      slug: 'stations',
      unit: 'محطة',
      unitPlural: 'محطات',
      groupBy: 'region',
    ),
    'transport': SectionConfig(
      slug: 'transport',
      unit: 'مركبة',
      unitPlural: 'مركبات',
      groupBy: 'meta',
      metaKey: 'vehicle',
      mini: false,
      defaultLayout: 'list',
    ),
  };

  /// إعداد افتراضي للأقسام غير المعروفة (التي يضيفها المدير)
  static SectionConfig fallback(String slug) => SectionConfig(
        slug: slug,
        unit: 'خدمة',
        unitPlural: 'خدمات',
        groupBy: 'region',
      );

  static SectionConfig of(String slug) => all[slug] ?? fallback(slug);
}

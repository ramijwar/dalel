import 'dart:convert';

/// ══════════════════════════════════════════════════════════════
/// نماذج البيانات — مطابقة تماماً لاستجابات خادم /dalel/api
/// ══════════════════════════════════════════════════════════════

// ─────────────── محولات آمنة ───────────────
int _i(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
double _d(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
bool _b(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
String _s(dynamic v) => v?.toString() ?? '';
String? _sn(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.map((k, e) => MapEntry(k.toString(), e)) : <String, dynamic>{};

// ═══════════════ القسم ═══════════════
/* ══════════════════════════════════════════════════════════════
 *  الحقول الخاصة بالأقسام
 *  تُعرَّف من لوحة الإدارة، وتُرسم ديناميكياً في نماذج الخدمات.
 *  الأنواع: select | text | textarea | number | boolean
 * ══════════════════════════════════════════════════════════════ */

/// خيار داخل حقل من نوع قائمة
class FieldOption {
  final int id;
  final String label;
  final String value;
  final String icon;

  const FieldOption({
    this.id = 0,
    required this.label,
    required this.value,
    this.icon = '',
  });

  factory FieldOption.fromJson(Map<String, dynamic> j) => FieldOption(
        id: _i(j['id']),
        label: _s(j['label']),
        value: _s(j['value']),
        icon: _s(j['icon']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'value': value,
        'icon': icon,
      };
}

/// تعريف حقل خاص بقسم
class CategoryField {
  final int id;
  final String key;
  final String label;
  /// select | text | textarea | number | boolean
  final String type;
  final bool required;
  final String placeholder;
  final String help;
  final bool showInCard;
  final bool filterable;
  final int sortOrder;
  /// وحدة تُلحَق بعد القيمة الرقمية في العرض (ل.س · موقف · كم)
  final String suffix;
  /// للحقول المنطقية: تُخفى القيمة إن كانت «لا» — يمنع شرائح «لا» المتكررة
  final bool hideWhenFalse;
  final List<FieldOption> options;

  const CategoryField({
    this.id = 0,
    required this.key,
    required this.label,
    this.type = 'select',
    this.required = false,
    this.placeholder = '',
    this.help = '',
    this.showInCard = true,
    this.filterable = false,
    this.sortOrder = 0,
    this.suffix = '',
    this.hideWhenFalse = false,
    this.options = const [],
  });

  bool get isSelect => type == 'select';
  bool get isBoolean => type == 'boolean';
  bool get isNumber => type == 'number';
  bool get isTextarea => type == 'textarea';

  factory CategoryField.fromJson(Map<String, dynamic> j) => CategoryField(
        id: _i(j['id']),
        key: _s(j['key']),
        label: _s(j['label']),
        type: _s(j['type']).isEmpty ? 'select' : _s(j['type']),
        required: _b(j['required']),
        placeholder: _s(j['placeholder']),
        help: _s(j['help']),
        showInCard: j['show_in_card'] == null ? true : _b(j['show_in_card']),
        filterable: _b(j['filterable']),
        sortOrder: _i(j['sort_order']),
        suffix: _s(j['suffix']),
        hideWhenFalse: _b(j['hide_when_false']),
        options: (j['options'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(FieldOption.fromJson)
            .toList(),
      );
}

/// حقل محلول وقيمته جاهزة للعرض — يرجعه الخادم مع كل خدمة
class ResolvedField {
  final String key;
  final String label;
  final String type;
  final String value;
  final String display;
  final String icon;

  const ResolvedField({
    required this.key,
    required this.label,
    required this.type,
    required this.value,
    required this.display,
    this.icon = '',
  });

  factory ResolvedField.fromJson(Map<String, dynamic> j) => ResolvedField(
        key: _s(j['key']),
        label: _s(j['label']),
        type: _s(j['type']),
        value: _s(j['value']),
        display: _s(j['display']),
        icon: _s(j['icon']),
      );
}

/* ══════════════════════════════════════════════════════════════
 *  فلتر مُسنَد لقسم — من مكتبة الفلاتر في لوحة التحكم
 *
 *  المدير يُنشئ فلاتر (المناطق · الاختصاص · نوع المركبة …) ثم يُسنِد
 *  لكل قسم الفلتر الذي تُعرض خدماته على أساسه. «الأساسي» هو الذي يبني
 *  بطاقات المستوى الأول في صفحة القسم.
 *
 *  يُطابق `category.filters[]` في ردّ `/api/meta`، ومصدر قيمته:
 *    region    → منطقة الخدمة (region_id)
 *    specialty → اختصاص الخدمة (specialty_id)
 *    field     → حقل من حقول القسم (source_key، من `meta`/`fields`)
 * ══════════════════════════════════════════════════════════════ */
class CategoryFilterLink {
  /// معرّف الإسناد في جدول category_filters
  final int id;

  /// معرّف الفلتر في المكتبة
  final int filterId;

  /// مفتاح التجميع — يُطابق مفتاح `groups` في ردّ الخدمات
  final String key;
  final String label;

  /// 'region' | 'specialty' | 'field'
  final String sourceType;

  /// مفتاح الحقل عندما يكون المصدر field
  final String sourceKey;
  final String icon;

  /// الأساسي واحد لكل قسم — هو الذي يقود بطاقات المستوى الأول
  final bool isPrimary;
  final int sortOrder;

  const CategoryFilterLink({
    required this.id,
    required this.filterId,
    required this.key,
    required this.label,
    this.sourceType = 'region',
    this.sourceKey = '',
    this.icon = '',
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  factory CategoryFilterLink.fromJson(Map<String, dynamic> j) => CategoryFilterLink(
        id: _i(j['id']),
        filterId: _i(j['filter_id'] ?? j['id']),
        key: _s(j['key']),
        label: _s(j['label']),
        sourceType: _s(j['source_type']).isEmpty ? 'region' : _s(j['source_type']),
        sourceKey: _s(j['source_key']),
        icon: _s(j['icon']),
        isPrimary: _b(j['is_primary']),
        sortOrder: _i(j['sort_order']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'filter_id': filterId,
        'key': key,
        'label': label,
        'source_type': sourceType,
        'source_key': sourceKey,
        'icon': icon,
        'is_primary': isPrimary ? 1 : 0,
        'sort_order': sortOrder,
      };

  bool get isRegion => sourceType == 'region';
  bool get isSpecialty => sourceType == 'specialty';
  bool get isField => sourceType == 'field';
}

class Category {
  final int id;
  final String slug;
  final String name;
  final String singular;
  final String icon;
  final String color;
  final String description;
  final String route;
  final int sortOrder;
  final String layout;
  final Map<String, dynamic> features;
  /// الحقول الخاصة بهذا القسم — تُبنى ديناميكياً في نماذج الخدمات
  final List<CategoryField> fields;

  /// الفلاتر المُسنَدة لهذا القسم — من مكتبة الفلاتر في لوحة التحكم.
  /// قد تكون فارغة (خادم قديم، أو قسم أُلغيت فلاتره عمداً) فيُستخدم
  /// التجميع الاحتياطي المضمّن في التطبيق.
  final List<CategoryFilterLink> filters;
  final bool isActive;

  Category({
    required this.id,
    required this.slug,
    required this.name,
    this.singular = '',
    this.icon = 'circle',
    this.color = '#0EA5E9',
    this.description = '',
    this.route = '',
    this.sortOrder = 0,
    this.layout = 'card',
    this.features = const {},
    this.fields = const [],
    this.filters = const [],
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: _i(j['id']),
        slug: _s(j['slug']),
        name: _s(j['name']),
        singular: _s(j['singular']),
        icon: _sn(j['icon']) ?? 'circle',
        color: _sn(j['color']) ?? '#0EA5E9',
        description: _s(j['description']),
        route: _s(j['route']),
        sortOrder: _i(j['sort_order']),
        layout: _sn(j['layout']) ?? 'card',
        features: _m(j['features']),
        fields: (j['fields'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CategoryField.fromJson)
            .toList(),
        filters: (j['filters'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CategoryFilterLink.fromJson)
            .toList(),
        isActive: _b(j['is_active']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'singular': singular,
        'icon': icon,
        'color': color,
        'description': description,
        'route': route,
        'sort_order': sortOrder,
        'layout': layout,
        'features': jsonEncode(features),
        // يُخزَّن كنص JSON — يُقرأ في database_service عند العمل بلا شبكة
        'filters': jsonEncode(filters.map((f) => f.toJson()).toList()),
        'is_active': isActive ? 1 : 0,
      };

  /// الفلتر الأساسي — واحد فقط، وهو الذي يبني بطاقات المستوى الأول
  CategoryFilterLink? get primaryFilter {
    for (final f in filters) {
      if (f.isPrimary) return f;
    }
    return null;
  }

  /// بقية الفلاتر المُسنَدة (تُعرض كفلاتر ثانوية تُضيّق النتائج)
  List<CategoryFilterLink> get secondaryFilters =>
      filters.where((f) => !f.isPrimary).toList();

  /// لون القسم من النص السداسي
  int get colorValue {
    final hex = color.replaceAll('#', '');
    return int.tryParse('FF$hex', radix: 16) ?? 0xFF0EA5E9;
  }

  bool get supportsDuty => features['duty'] == true;
  bool get supportsSchedule => features['schedule'] == true;
  bool get supportsStatus => features['status'] == true;
}

// ═══════════════ المحافظة ═══════════════
class Governorate {
  final int id;
  final String name;
  final String slug;
  final String zone; // 'city' | 'rural'
  final int sortOrder;
  final int servicesCount;

  Governorate({
    required this.id,
    required this.name,
    this.slug = '',
    this.zone = 'city',
    this.sortOrder = 0,
    this.servicesCount = 0,
  });

  factory Governorate.fromJson(Map<String, dynamic> j) => Governorate(
        id: _i(j['id']),
        name: _s(j['name']),
        slug: _s(j['slug']),
        zone: _sn(j['zone']) ?? 'city',
        sortOrder: _i(j['sort_order']),
        servicesCount: _i(j['services_count']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'zone': zone,
        'sort_order': sortOrder,
        'services_count': servicesCount,
      };
}

// ═══════════════ المنطقة ═══════════════
class Region {
  final int id;
  final String name;
  final String zone;
  final int sortOrder;
  final int? governorateId;
  final int? parentId;

  /// 'city' | 'village'
  final String level;
  final int servicesCount;

  Region({
    required this.id,
    required this.name,
    this.zone = 'city',
    this.sortOrder = 0,
    this.governorateId,
    this.parentId,
    this.level = 'city',
    this.servicesCount = 0,
  });

  factory Region.fromJson(Map<String, dynamic> j) => Region(
        id: _i(j['id']),
        name: _s(j['name']),
        zone: _sn(j['zone']) ?? 'city',
        sortOrder: _i(j['sort_order']),
        governorateId:
            j['governorate_id'] == null ? null : _i(j['governorate_id']),
        parentId: j['parent_id'] == null ? null : _i(j['parent_id']),
        level: _sn(j['level']) ?? 'city',
        servicesCount: _i(j['services_count']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'zone': zone,
        'sort_order': sortOrder,
        'governorate_id': governorateId,
        'parent_id': parentId,
        'level': level,
        'services_count': servicesCount,
      };
}

// ═══════════════ الاختصاص الطبي ═══════════════
class Specialty {
  final int id;
  final String name;
  final String slug;
  final String icon;
  final int servicesCount;

  Specialty({
    required this.id,
    required this.name,
    this.slug = '',
    this.icon = 'stethoscope',
    this.servicesCount = 0,
  });

  factory Specialty.fromJson(Map<String, dynamic> j) => Specialty(
        id: _i(j['id']),
        name: _s(j['name']),
        slug: _s(j['slug']),
        icon: _sn(j['icon']) ?? 'stethoscope',
        servicesCount: _i(j['services_count']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'icon': icon,
        'services_count': servicesCount,
      };
}

// ═══════════════ جدول الدوام ═══════════════
class ScheduleRow {
  /// 0 = الأحد … 6 = السبت
  final int day;
  final bool isOpen;
  final String from;
  final String to;

  ScheduleRow({
    required this.day,
    this.isOpen = true,
    this.from = '08:00',
    this.to = '20:00',
  });

  factory ScheduleRow.fromJson(Map<String, dynamic> j) => ScheduleRow(
        day: _i(j['day']),
        isOpen: _b(j['is_open'] ?? j['open']),
        from: _sn(j['from'] ?? j['open_time']) ?? '08:00',
        to: _sn(j['to'] ?? j['close_time']) ?? '20:00',
      );

  Map<String, dynamic> toJson() =>
      {'day': day, 'is_open': isOpen ? 1 : 0, 'from': from, 'to': to};

  static const List<String> dayNames = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  String get dayName =>
      (day >= 0 && day < dayNames.length) ? dayNames[day] : '';
}

// ═══════════════ الخدمة ═══════════════
class Service {
  final int id;
  final String name;
  final int categoryId;
  final String categorySlug;
  final String categoryName;
  final String categoryIcon;

  final int? regionId;
  final String? regionName;
  final String? regionZone;
  final String? regionLevel;
  final String? cityName;

  final int? governorateId;
  final String? governorateName;
  final String? governorateSlug;

  final int? specialtyId;
  final String address;
  final String phone;
  final String phoneIntl;
  final String whatsapp;
  final String whatsappNumber;
  final String note;
  final String? photo;
  /// الحقول الخاصة بالقسم — محلولة وجاهزة للعرض
  final List<ResolvedField> fields;
  final Map<String, dynamic> meta;

  final bool isVerified;
  final int? ownerId;
  final String? ownerName;

  /// 'open' | 'closed'
  final String status;
  final String statusLabel;
  final String statusSublabel;
  final String? statusSource;
  final String? closesAt;

  final bool onDuty;
  final String? dutyFrom;
  final String? dutyTo;

  final String? updatedAt;
  final String? createdAt;
  final int scheduleCount;

  /// جدول الدوام (يُحمَّل من نقطة نهاية التفاصيل)
  final List<ScheduleRow> schedule;

  Service({
    required this.id,
    required this.name,
    this.categoryId = 0,
    this.categorySlug = '',
    this.categoryName = '',
    this.categoryIcon = 'circle',
    this.regionId,
    this.regionName,
    this.regionZone,
    this.regionLevel,
    this.cityName,
    this.governorateId,
    this.governorateName,
    this.governorateSlug,
    this.specialtyId,
    this.address = '',
    this.phone = '',
    this.phoneIntl = '',
    this.whatsapp = '',
    this.whatsappNumber = '',
    this.note = '',
    this.photo,
    this.fields = const [],
    this.meta = const {},
    this.isVerified = false,
    this.ownerId,
    this.ownerName,
    this.status = 'closed',
    this.statusLabel = '',
    this.statusSublabel = '',
    this.statusSource,
    this.closesAt,
    this.onDuty = false,
    this.dutyFrom,
    this.dutyTo,
    this.updatedAt,
    this.createdAt,
    this.scheduleCount = 0,
    this.schedule = const [],
  });

  factory Service.fromJson(Map<String, dynamic> j) {
    List<ScheduleRow> sched = const [];
    final raw = j['schedule'];
    if (raw is List) {
      sched = raw.map((e) => ScheduleRow.fromJson(_m(e))).toList();
    }
    return Service(
      id: _i(j['id']),
      name: _s(j['name']),
      categoryId: _i(j['category_id']),
      categorySlug: _s(j['category_slug']),
      categoryName: _s(j['category_name']),
      categoryIcon: _sn(j['category_icon']) ?? 'circle',
      regionId: j['region_id'] == null ? null : _i(j['region_id']),
      regionName: _sn(j['region_name']),
      regionZone: _sn(j['region_zone']),
      regionLevel: _sn(j['region_level']),
      cityName: _sn(j['city_name']),
      governorateId:
          j['governorate_id'] == null ? null : _i(j['governorate_id']),
      governorateName: _sn(j['governorate_name']),
      governorateSlug: _sn(j['governorate_slug']),
      specialtyId: j['specialty_id'] == null ? null : _i(j['specialty_id']),
      address: _s(j['address']),
      phone: _s(j['phone']),
      phoneIntl: _s(j['phone_intl']),
      whatsapp: _s(j['whatsapp']),
      whatsappNumber: _s(j['whatsapp_number']),
      note: _s(j['note']),
      photo: _sn(j['photo']),
      fields: (j['fields'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ResolvedField.fromJson)
          .toList(),
      meta: _m(j['meta']),
      isVerified: _b(j['is_verified']),
      ownerId: j['owner_id'] == null ? null : _i(j['owner_id']),
      ownerName: _sn(j['owner_name']),
      status: _sn(j['status']) ?? 'closed',
      statusLabel: _s(j['status_label']),
      statusSublabel: _s(j['status_sublabel']),
      statusSource: _sn(j['status_source']),
      closesAt: _sn(j['closes_at']),
      onDuty: _b(j['on_duty']),
      dutyFrom: _sn(j['duty_from']),
      dutyTo: _sn(j['duty_to']),
      updatedAt: _sn(j['updated_at']),
      createdAt: _sn(j['created_at']),
      scheduleCount: _i(j['schedule_count']),
      schedule: sched,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category_id': categoryId,
        'category_slug': categorySlug,
        'category_name': categoryName,
        'category_icon': categoryIcon,
        'region_id': regionId,
        'region_name': regionName,
        'region_zone': regionZone,
        'region_level': regionLevel,
        'city_name': cityName,
        'governorate_id': governorateId,
        'governorate_name': governorateName,
        'governorate_slug': governorateSlug,
        'specialty_id': specialtyId,
        'address': address,
        'phone': phone,
        'phone_intl': phoneIntl,
        'whatsapp': whatsapp,
        'whatsapp_number': whatsappNumber,
        'note': note,
        'photo': photo,
        'meta': jsonEncode(meta),
        'is_verified': isVerified ? 1 : 0,
        'owner_id': ownerId,
        'owner_name': ownerName,
        'status': status,
        'status_label': statusLabel,
        'status_sublabel': statusSublabel,
        'status_source': statusSource,
        'closes_at': closesAt,
        'on_duty': onDuty ? 1 : 0,
        'duty_from': dutyFrom,
        'duty_to': dutyTo,
        'updated_at': updatedAt,
        'created_at': createdAt,
        'schedule_count': scheduleCount,
      };

  Service copyWith({
    String? status,
    String? statusLabel,
    String? statusSublabel,
    bool? onDuty,
    String? closesAt,
    String? name,
    String? address,
    String? phone,
    String? whatsapp,
    String? note,
    int? regionId,
    int? governorateId,
    String? regionName,
    String? governorateName,
    List<ScheduleRow>? schedule,
    String? photo,
    String? updatedAt,
    Map<String, dynamic>? meta,
    List<ResolvedField>? fields,
  }) =>
      Service(
        id: id,
        name: name ?? this.name,
        categoryId: categoryId,
        categorySlug: categorySlug,
        categoryName: categoryName,
        categoryIcon: categoryIcon,
        regionId: regionId ?? this.regionId,
        regionName: regionName ?? this.regionName,
        regionZone: regionZone,
        regionLevel: regionLevel,
        cityName: cityName,
        governorateId: governorateId ?? this.governorateId,
        governorateName: governorateName ?? this.governorateName,
        governorateSlug: governorateSlug,
        specialtyId: specialtyId,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        phoneIntl: phoneIntl,
        whatsapp: whatsapp ?? this.whatsapp,
        whatsappNumber: whatsappNumber,
        note: note ?? this.note,
        photo: photo ?? this.photo,
        fields: fields ?? this.fields,
        meta: meta ?? this.meta,
        isVerified: isVerified,
        ownerId: ownerId,
        ownerName: ownerName,
        status: status ?? this.status,
        statusLabel: statusLabel ?? this.statusLabel,
        statusSublabel: statusSublabel ?? this.statusSublabel,
        statusSource: statusSource,
        closesAt: closesAt ?? this.closesAt,
        onDuty: onDuty ?? this.onDuty,
        dutyFrom: dutyFrom,
        dutyTo: dutyTo,
        updatedAt: updatedAt ?? this.updatedAt,
        createdAt: createdAt,
        scheduleCount: scheduleCount,
        schedule: schedule ?? this.schedule,
      );

  /// هل الخدمة مفتوحة الآن؟
  bool get isOpen => status == 'open';

  /// تسمية المنطقة الكاملة: «المنطقة — المحافظة»
  String get fullRegionLabel => [regionName, governorateName]
      .where((e) => e != null && e.isNotEmpty)
      .join(' — ');

  /// تسمية الحالة المعروضة
  String get displayStatus {
    if (onDuty) return 'مناوبة';
    if (statusLabel.isNotEmpty) return statusLabel;
    return status == 'open' ? 'تعمل الآن' : 'مغلقة';
  }

  /// رقم الواتساب المُهيّأ للرابط
  String get whatsappReady {
    final w = whatsappNumber.isNotEmpty ? whatsappNumber : whatsapp;
    final cleaned = w.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.isEmpty) return '';
    return cleaned.startsWith('963')
        ? cleaned
        : '963${cleaned.replaceFirst(RegExp(r'^0'), '')}';
  }

  /// قيمة meta لقسم النقل (نوع المركبة)
  String? metaVal(String key) {
    final v = meta[key];
    return v?.toString();
  }
}

// ═══════════════ المستخدم ═══════════════
class User {
  final int id;
  final String phone;
  final String phoneIntl;
  final String fullName;
  final String? birthDate;
  final String? avatar;
  final String? bio;
  final String role;
  final String? createdAt;

  User({
    required this.id,
    required this.phone,
    this.phoneIntl = '',
    this.fullName = '',
    this.birthDate,
    this.avatar,
    this.bio,
    this.role = 'user',
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: _i(j['id']),
        phone: _s(j['phone']),
        phoneIntl: _s(j['phone_intl']),
        fullName: _s(j['full_name']),
        birthDate: _sn(j['birth_date']),
        avatar: _sn(j['avatar']),
        bio: _sn(j['bio']),
        role: _sn(j['role']) ?? 'user',
        createdAt: _sn(j['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'phone_intl': phoneIntl,
        'full_name': fullName,
        'birth_date': birthDate,
        'avatar': avatar,
        'bio': bio,
        'role': role,
        'created_at': createdAt,
      };

  bool get isAdmin => role == 'admin';

  /// الحرف الأول للصورة الرمزية
  String get initial =>
      fullName.isNotEmpty ? fullName[0] : (phone.isNotEmpty ? phone[0] : '؟');
}

// ═══════════════ طلب إضافة خدمة ═══════════════
class ServiceRequest {
  final int id;
  final String name;
  final int categoryId;
  final String? categoryName;
  final int? regionId;
  final String? regionName;
  final int? governorateId;
  final String? governorateName;
  final String address;
  final String phone;
  final String note;
  final String status;
  final String? rejectReason;
  final String? createdAt;

  /// اسم صاحب الطلب (يأتي في مسار الإدارة admin/requests فقط)
  final String? userName;

  /// هل يريد صاحب الطلب إدارة الخدمة بعد نشرها؟
  final bool wantToManage;

  ServiceRequest({
    required this.id,
    required this.name,
    this.categoryId = 0,
    this.categoryName,
    this.regionId,
    this.regionName,
    this.governorateId,
    this.governorateName,
    this.address = '',
    this.phone = '',
    this.note = '',
    this.status = 'pending',
    this.rejectReason,
    this.createdAt,
    this.userName,
    this.wantToManage = false,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> j) => ServiceRequest(
        id: _i(j['id']),
        name: _s(j['name']),
        categoryId: _i(j['category_id']),
        categoryName: _sn(j['category_name']),
        regionId: j['region_id'] == null ? null : _i(j['region_id']),
        regionName: _sn(j['region_name']),
        governorateId:
            j['governorate_id'] == null ? null : _i(j['governorate_id']),
        governorateName: _sn(j['governorate_name']),
        address: _s(j['address']),
        phone: _s(j['phone']),
        note: _s(j['note']),
        status: _sn(j['status']) ?? 'pending',
        rejectReason: _sn(j['reject_reason'] ?? j['admin_note']),
        createdAt: _sn(j['created_at']),
        userName: _sn(j['user_name']),
        wantToManage: (j['want_to_manage'] ?? 0) == 1 ||
            j['want_to_manage'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category_id': categoryId,
        'category_name': categoryName,
        'region_id': regionId,
        'region_name': regionName,
        'governorate_id': governorateId,
        'governorate_name': governorateName,
        'address': address,
        'phone': phone,
        'note': note,
        'status': status,
        'reject_reason': rejectReason,
        'created_at': createdAt,
        'user_name': userName,
        'want_to_manage': wantToManage ? 1 : 0,
      };

  String get statusLabel => switch (status) {
        'pending' => 'قيد المراجعة',
        'approved' => 'مقبول',
        'rejected' => 'مرفوض',
        _ => status,
      };

  int get statusColor => switch (status) {
        'pending' => 0xFFD97706,
        'approved' => 0xFF16A34A,
        'rejected' => 0xFFDC2626,
        _ => 0xFF94A3B8,
      };
}

// ═══════════════ إعلان ═══════════════
class Announcement {
  final String text;
  final String? link;
  final String? color;
  final String? icon;

  Announcement({required this.text, this.link, this.color, this.icon});

  factory Announcement.fromJson(dynamic j) {
    if (j is String) return Announcement(text: j);
    final m = _m(j);
    return Announcement(
      text: _s(m['text'] ?? m['title'] ?? m['body']),
      link: _sn(m['link'] ?? m['url']),
      color: _sn(m['color']),
      icon: _sn(m['icon']),
    );
  }

  int get colorValue {
    final c = color?.replaceAll('#', '') ?? '';
    if (c.length == 6) return int.tryParse('FF$c', radix: 16) ?? 0xFF0EA5E9;
    return 0xFF0EA5E9;
  }
}

// ═══════════════ الإعدادات ═══════════════
class AppSettings {
  final String siteName;
  final String city;
  final int adInterval;
  final List<Announcement> announcements;
  final String whatsappAdmin;
  final List<String> serviceTypes;

  AppSettings({
    this.siteName = 'دليل الدير',
    this.city = '',
    this.adInterval = 5,
    this.announcements = const [],
    this.whatsappAdmin = '',
    this.serviceTypes = const [],
  });

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final anns = j['announcements'];
    return AppSettings(
      siteName: _sn(j['site_name']) ?? 'دليل الدير',
      city: _s(j['city']),
      adInterval: _i(j['ad_interval'] ?? 5),
      announcements: anns is List
          ? anns
              .map((e) => Announcement.fromJson(e))
              .where((a) => a.text.isNotEmpty)
              .toList()
          : const [],
      whatsappAdmin: _s(j['whatsapp_admin']),
      serviceTypes: j['service_types'] is List
          ? (j['service_types'] as List).map((e) => _s(e)).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'site_name': siteName,
        'city': city,
        'ad_interval': adInterval,
        'announcements': announcements.map((e) => e.text).toList(),
        'whatsapp_admin': whatsappAdmin,
        'service_types': serviceTypes,
      };
}

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../config/constants.dart';

/// حالة الاتصال
enum OnlineStatus { online, offline, unknown }

/// ══════════════════════════════════════════════════════════════
/// مزوّد التطبيق الرئيسي — البيانات المرجعية + المزامنة
/// يعمل من قاعدة البيانات المحلية أولاً، ثم يحدّث من الشبكة
/// ══════════════════════════════════════════════════════════════
class AppProvider extends ChangeNotifier {
  final _api = ApiService.instance;
  final _db = DatabaseService.instance;

  // ─── البيانات المرجعية ───
  List<Category> _categories = [];
  List<Region> _regions = [];
  List<Governorate> _governorates = [];
  List<Specialty> _specialties = [];
  Map<String, int> _counts = {};
  AppSettings _settings = AppSettings();

  // ─── الحالة ───
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  OnlineStatus _online = OnlineStatus.unknown;
  DateTime? _lastSync;

  // ─── المستمعون ───
  List<Category> get categories => _categories;
  List<Region> get regions => _regions;
  List<Governorate> get governorates => _governorates;
  List<Specialty> get specialties => _specialties;
  Map<String, int> get counts => _counts;
  AppSettings get settings => _settings;
  bool get loading => _loading;
  bool get syncing => _syncing;
  String? get error => _error;
  OnlineStatus get online => _online;
  DateTime? get lastSync => _lastSync;
  bool get isOffline => _online == OnlineStatus.offline;

  /// إجمالي الخدمات المعروضة على الصفحة الرئيسية
  int get totalServices => _counts.values.fold(0, (a, b) => a + b);

  /// ══════════════════════════════════════════════════════════
  /// حقن بيانات تجريبية — للاختبارات فقط
  /// يُتيح اختبار الواجهات دون الحاجة لخادم أو قاعدة بيانات
  /// ══════════════════════════════════════════════════════════
  void debugInject({
    List<Category>? categories,
    List<Region>? regions,
    List<Governorate>? governorates,
    List<Specialty>? specialties,
    List<Service>? services,
  }) {
    if (categories != null) _categories = categories;
    if (regions != null) _regions = regions;
    if (governorates != null) _governorates = governorates;
    if (specialties != null) _specialties = specialties;
    if (services != null) _allServices = services;
    _debugMode = true;
    _loading = false;
    // لا نستدعي notifyListeners هنا — تُستدعى غالباً من initState،
    // ونداء التغيير أثناء البناء يرمي استثناءً في الاختبارات.
    // تُستدعى يدوياً عند الحاجة بعد أول بناء.
  }

  /// كل الخدمات المُحمَّلة (تُستخدم لعرض الأقسام دون طلب شبكي)
  List<Service> _allServices = [];
  List<Service> get allServices => _allServices;

  /// خدمات قسم محدَّد
  List<Service> servicesFor(int categoryId) =>
      _allServices.where((s) => s.categoryId == categoryId).toList();

  Category? categoryBySlug(String slug) {
    try {
      return _categories.firstWhere((c) => c.slug == slug);
    } catch (_) {
      return null;
    }
  }

  int countFor(String slug) => _counts[slug] ?? 0;

  /// ══════════════════════════════════════════════════════════
  /// التحميل الأولي — من المحلي فوراً، ثم من الشبكة
  /// ══════════════════════════════════════════════════════════
  Future<void> init() async {
    _loading = true;
    notifyListeners();

    // ١) اقرأ المحلي فوراً (لا انتظار)
    await _loadLocal();

    // ٢) حدّث من الشبكة في الخلفية
    await sync(force: false);

    _loading = false;
    notifyListeners();
  }

  Future<void> _loadLocal() async {
    try {
      _categories = await _db.getCategories();
      _regions = await _db.getRegions();
      _governorates = await _db.getGovernorates();
      _specialties = await _db.getSpecialties();
      final s = await _db.getSettings();
      if (s != null) _settings = s;
      _lastSync = await _db.getLastSync();
      notifyListeners();
    } catch (_) {
      // أول تشغيل — لا بيانات محلية
    }
  }

  /// ══════════════════════════════════════════════════════════
  /// المزامنة مع الخادم
  ///
  /// ملاحظة: أُزيل حاجز «الذاكرة المؤقتة ١٠ دقائق» — كان يجعل
  /// تعديلات لوحة الويب (إضافة/إزالة حقول الأقسام مثلاً) لا تصل
  /// للتطبيق إلا بعد انتهاء المهلة. نداء /meta رخيص ويتكرر عند
  /// كل فتح للتطبيق دون كلفة تُذكر.
  /// ══════════════════════════════════════════════════════════
  Future<bool> sync({bool force = false}) async {
    if (_syncing) return false;

    // وضع الاختبار: البيانات محقونة، فلا نلمس الشبكة — نفس حماية loadSection
    if (_debugMode) return false;

    _syncing = true;
    _error = null;
    notifyListeners();

    try {
      final bundle = await _api.meta();
      _online = OnlineStatus.online;

      _categories = bundle.categories;
      _regions = bundle.regions;
      _governorates = bundle.governorates;
      _counts = bundle.counts;
      _settings = bundle.settings;
      AppConfig.whatsappAdmin = bundle.settings.whatsappAdmin;

      // احفظ محلياً
      await _db.saveCategories(_categories);
      await _db.saveRegions(_regions);
      await _db.saveGovernorates(_governorates);
      await _db.saveSettings(_settings);
      await _db.setSyncedAt();
      _lastSync = DateTime.now();

      // الاختصاصات (قسم الأطباء فقط)
      try {
        _specialties = await _api.specialties();
        await _db.saveSpecialties(_specialties);
      } catch (_) {
        // غير حرجة
      }

      _syncing = false;
      notifyListeners();
      return true;
    } on OfflineException {
      _online = OnlineStatus.offline;
      _syncing = false;
      if (_categories.isEmpty) {
        _error = 'لا يوجد اتصال بالإنترنت ولا بيانات محفوظة';
      }
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      _syncing = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'تعذّر الاتصال بالخادم';
      _syncing = false;
      notifyListeners();
      return false;
    }
  }

  /// تحميل خدمات قسم معيّن (محلياً إن أمكن)
  /// في وضع الاختبار نرجع البيانات المحقونة دون لمس الشبكة أو قاعدة البيانات
  bool _debugMode = false;

  Future<List<Service>> loadSection(String slug,
      {bool forceNetwork = false}) async {
    final cat = categoryBySlug(slug);
    if (cat == null) return [];

    if (_debugMode) {
      return _allServices.where((s) => s.categoryId == cat.id).toList();
    }

    // جرّب الشبكة أولاً إن كانت متاحة
    if (!isOffline) {
      try {
        // servicesAll تجلب كل الصفحات — قسم الصيدليات (٢٤٢) أكبر من pageSize
        final list = await _api.servicesAll(categoryId: cat.id);
        await _db.saveServices(list);
        _online = OnlineStatus.online;
        notifyListeners();
        return list;
      } on OfflineException {
        _online = OnlineStatus.offline;
        notifyListeners();
      } on ApiException {
        // استخدم المحلي
      }
    }

    // الرجوع للبيانات المحلية — بحد يتسع لكل خدمات القسم (لا 200)
    return _db.queryServices(categoryId: cat.id, limit: AppConfig.localQueryLimit);
  }

  Future<void> refreshSection(String slug) async {
    await loadSection(slug, forceNetwork: true);
  }

  /// تحميل تفاصيل خدمة (مع جدولها)
  Future<Service> loadService(int id) async {
    try {
      final s = await _api.service(id);
      await _db.saveService(s);
      return s;
    } on OfflineException {
      final cached = await _db.getService(id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  void setOnline(OnlineStatus s) {
    if (_online != s) {
      _online = s;
      notifyListeners();
      // مزامنة تلقائية عند عودة الاتصال
      if (s == OnlineStatus.online) sync(force: true);
    }
  }
}

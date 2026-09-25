import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/models.dart';

/// استثناء من الخادم (يحمل الرسالة العربية المعروضة للمستخدم)
class ApiException implements Exception {
  final String message;
  final int? status;

  ApiException(this.message, {this.status});

  @override
  String toString() => message;
}

/// انقطاع الاتصال — يميّزه التطبيق ليعرض البيانات المحفوظة
class OfflineException extends ApiException {
  OfflineException() : super('لا يوجد اتصال بالإنترنت', status: 0);
}

/// ══════════════════════════════════════════════════════════════
/// عميل HTTP لخادم /dalel/api
/// ══════════════════════════════════════════════════════════════
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();

  String? _token;

  void setToken(String? t) => _token = t;
  String? get token => _token;

  Map<String, String> get _headers {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (_token != null && _token!.isNotEmpty)
      h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Uri _u(String path, [Map<String, String>? q]) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final base = Uri.parse('${AppConfig.apiBase}/$clean');
    if (q == null || q.isEmpty) return base;
    final params = Map<String, String>.from(q)
      ..removeWhere((_, v) => v.isEmpty);
    return base.replace(queryParameters: params);
  }

  /// تنفيذ الطلب مع ترجمة الأخطاء
  Future<dynamic> _req(Future<http.Response> Function() fn) async {
    http.Response res;
    try {
      res = await fn()
          .timeout(AppConfig.connectTimeout + AppConfig.receiveTimeout);
    } on SocketException {
      throw OfflineException();
    } on TimeoutException {
      throw OfflineException();
    } on HandshakeException {
      throw OfflineException();
    } catch (_) {
      throw OfflineException();
    }

    if (res.statusCode >= 500) {
      throw ApiException('خطأ في الخادم، حاول لاحقاً', status: res.statusCode);
    }

    dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ApiException('استجابة غير صالحة من الخادم', status: res.statusCode);
    }

    if (res.statusCode == 401)
      throw ApiException('انتهت صلاحية الجلسة، سجّل الدخول من جديد',
          status: 401);
    if (res.statusCode == 403) {
      throw ApiException(_msg(body, 'ليس لديك صلاحية لهذه العملية'),
          status: 403);
    }

    if (body is Map && body['ok'] == false) {
      throw ApiException(_msg(body, 'حدث خطأ'), status: res.statusCode);
    }
    if (res.statusCode >= 400) {
      throw ApiException(_msg(body, 'تعذّر إتمام الطلب'),
          status: res.statusCode);
    }
    return body;
  }

  String _msg(dynamic body, String fallback) {
    if (body is Map) {
      final m = body['message'] ?? body['error'];
      if (m != null && m.toString().trim().isNotEmpty) return m.toString();
    }
    return fallback;
  }

  Future<dynamic> get(String path, [Map<String, String>? q]) =>
      _req(() => _client.get(_u(path, q), headers: _headers));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _req(() =>
      _client.post(_u(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) => _req(() =>
      _client.put(_u(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> del(String path) =>
      _req(() => _client.delete(_u(path), headers: _headers));

  // ══════════════════════════════════════════════════════════
  // عام
  // ══════════════════════════════════════════════════════════

  Future<bool> health() async {
    try {
      final r = await get('health');
      return r is Map && r['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// كل البيانات المرجعية دفعةً واحدة (أقسام · مناطق · محافظات · إعدادات)
  Future<MetaBundle> meta() async {
    final r = await get('meta');
    final m = r as Map<String, dynamic>;
    return MetaBundle.fromJson(m);
  }

  Future<List<Service>> services({
    int? categoryId,
    String? categorySlug,
    int? regionId,
    int? governorateId,
    int? specialtyId,
    String? status,
    String? search,
    int page = 1,
    int limit = AppConfig.pageSize,
  }) async {
    final q = <String, String>{
      if (categoryId != null) 'category_id': '$categoryId',
      if (categorySlug != null) 'category_slug': categorySlug,
      if (regionId != null) 'region_id': '$regionId',
      if (governorateId != null) 'governorate_id': '$governorateId',
      if (specialtyId != null) 'specialty_id': '$specialtyId',
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'q': search,
      'page': '$page',
      'limit': '$limit',
    };
    final r = await get('services', q);
    final items = (r['items'] as List? ?? []);
    return items
        .map((e) => Service.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// ══════════════════════════════════════════════════════════
  /// جلب كل خدمات قسم (كل الصفحات)
  ///
  /// الخادم يقص أي طلب إلى 200 صف كحد أقصى للصفحة (min(200, limit))،
  /// فطلب 500 يعيد 200 فقط — وهذا جعل الشرط «length < pageSize»
  /// يظن أن الصفحة الأولى هي الأخيرة ويُسقط الباقي بصمت (٢٤٢ ← ٢٠٠).
  /// الحل: طلب 200 بالضبط فيتابع الترقيم حتى نفاد الصفحات فعلياً.
  /// ══════════════════════════════════════════════════════════
  Future<List<Service>> servicesAll({
    int? categoryId,
    int? regionId,
    int? governorateId,
    int? specialtyId,
    String? status,
    int pageSize = AppConfig.pageSize,
    int maxPages = 50,
  }) async {
    final all = <Service>[];
    for (var page = 1; page <= maxPages; page++) {
      final batch = await services(
        categoryId: categoryId,
        regionId: regionId,
        governorateId: governorateId,
        specialtyId: specialtyId,
        status: status,
        page: page,
        limit: pageSize,
      );
      all.addAll(batch);
      if (batch.length < pageSize) break;   // آخر صفحة
    }
    return all;
  }

  Future<Service> service(int id) async {
    final r = await get('services/$id');
    final m = r is Map && r['service'] is Map ? r['service'] : r;
    return Service.fromJson(m as Map<String, dynamic>);
  }

  Future<List<Specialty>> specialties() async {
    final r = await get('specialties');
    final list = r is Map ? (r['items'] ?? r['specialties'] ?? []) : r;
    return (list as List)
        .map((e) => Specialty.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ══════════════════════════════════════════════════════════
  // الحساب
  // ══════════════════════════════════════════════════════════

  Future<AuthResult> login(String phone, String password) async {
    final r = await post('auth/login', {'phone': phone, 'password': password});
    _token = r['token'] as String;
    return AuthResult(
      token: r['token'] as String,
      user: User.fromJson(r['user'] as Map<String, dynamic>),
    );
  }

  Future<AuthResult> register({
    required String phone,
    required String password,
    required String fullName,
    String? birthDate,
  }) async {
    final r = await post('auth/register', {
      'phone': phone,
      'password': password,
      'full_name': fullName,
      if (birthDate != null) 'birth_date': birthDate,
    });
    _token = r['token'] as String;
    return AuthResult(
      token: r['token'] as String,
      user: User.fromJson(r['user'] as Map<String, dynamic>),
    );
  }

  Future<User> me() async {
    final r = await get('auth/me');
    return User.fromJson(r['user'] as Map<String, dynamic>);
  }

  Future<User> updateProfile({
    String? fullName,
    String? birthDate,
    String? bio,
    String? avatarBase64,
  }) async {
    final r = await post('auth/profile', {
      if (fullName != null) 'full_name': fullName,
      if (birthDate != null) 'birth_date': birthDate,
      if (bio != null) 'bio': bio,
      if (avatarBase64 != null) 'avatar': avatarBase64,
    });
    return User.fromJson(r['user'] as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════
  // المالك
  // ══════════════════════════════════════════════════════════

  Future<List<Service>> myServices() async {
    final r = await get('my/services');
    return (r['items'] as List? ?? [])
        .map((e) => Service.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ServiceRequest>> myRequests() async {
    final r = await get('my/requests');
    return (r['items'] as List? ?? [])
        .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// ══════════════════════════════════════════════════════════
  /// طلبات الإضافة المنتظرة موافقة الإدارة — للمدير فقط
  /// في التطبيق تُعرض للتنبيه والاطلاع فقط؛ الموافقة نفسها
  /// تتم من لوحة التحكم في تطبيق الويب.
  /// ══════════════════════════════════════════════════════════
  Future<List<ServiceRequest>> adminPendingRequests() async {
    final r = await get('admin/requests', {'status': 'pending'});
    return (r['items'] as List? ?? [])
        .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Service> ownerService(int id) async {
    final r = await get('owner/services/$id');
    final m = r is Map && r['service'] is Map ? r['service'] : r;
    return Service.fromJson(m as Map<String, dynamic>);
  }

  /// تبديل الحالة: مفتوح/مقلق/مناوبة
  Future<Service> ownerStatus(
    int id, {
    required String mode,
    int? hours,
    bool? onDuty,
    int? dutyHours,
  }) async {
    final body = <String, dynamic>{
      'mode': mode,
      if (hours != null) 'hours': hours,
      if (onDuty != null) 'on_duty': onDuty,
      if (dutyHours != null) 'duty_hours': dutyHours,
    };
    final r = await put('owner/services/$id/status', body);
    final m = r is Map && r['service'] is Map ? r['service'] : r;
    return Service.fromJson(m as Map<String, dynamic>);
  }

  Future<Service> ownerSchedule(int id, List<ScheduleRow> rows) async {
    final r = await put('owner/services/$id/schedule', {
      'schedule': rows.map((e) => e.toJson()).toList(),
    });
    final m = r is Map && r['service'] is Map ? r['service'] : r;
    return Service.fromJson(m as Map<String, dynamic>);
  }

  Future<Service> ownerUpdate(int id, Map<String, dynamic> data) async {
    final r = await put('owner/services/$id', data);
    final m = r is Map && r['service'] is Map ? r['service'] : r;
    return Service.fromJson(m as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════
  // طلب إضافة خدمة
  // ══════════════════════════════════════════════════════════

  Future<void> createRequest({
    required String name,
    required int categoryId,
    int? governorateId,
    int? regionId,
    String? address,
    String? phone,
    String? note,
    Map<String, dynamic>? meta,
    /// «أريد التحكم في خدمتي وتحديث حالتها من حسابي»
    bool wantManage = false,
    /// الحقول الخاصة بالقسم (مثل الاختصاص للأطباء) — key => value
    Map<String, dynamic>? fields,
  }) async {
    await post('service-requests', {
      'name': name,
      'category_id': categoryId,
      if (governorateId != null) 'governorate_id': governorateId,
      if (regionId != null) 'region_id': regionId,
      if (address != null && address.isNotEmpty) 'address': address,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (note != null && note.isNotEmpty) 'note': note,
      if (meta != null && meta.isNotEmpty) 'meta': meta,
      // الخادم يربط الخدمة بحساب صاحبها بعد الموافقة
      if (wantManage) 'want_to_manage': true,
      // الحقول الخاصة بالقسم
      if (fields != null && fields.isNotEmpty) 'fields': fields,
    });
  }

  void dispose() => _client.close();
}

/// نتيجة المصادقة
class AuthResult {
  final String token;
  final User user;

  AuthResult({required this.token, required this.user});
}

/// حزمة البيانات المرجعية من /api/meta
class MetaBundle {
  final List<Category> categories;
  final List<Region> regions;
  final List<Governorate> governorates;
  final Map<String, int> counts;
  final AppSettings settings;
  final String? time;

  MetaBundle({
    required this.categories,
    required this.regions,
    required this.governorates,
    required this.counts,
    required this.settings,
    this.time,
  });

  factory MetaBundle.fromJson(Map<String, dynamic> m) {
    return MetaBundle(
      categories: (m['categories'] as List? ?? [])
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .where((c) => c.isActive)
          .toList(),
      regions: (m['regions'] as List? ?? [])
          .map((e) => Region.fromJson(e as Map<String, dynamic>))
          .toList(),
      governorates: (m['governorates'] as List? ?? [])
          .map((e) => Governorate.fromJson(e as Map<String, dynamic>))
          .toList(),
      counts: (m['counts'] as Map? ?? {}).map((k, v) =>
          MapEntry(k.toString(), v is int ? v : int.tryParse('$v') ?? 0)),
      settings: AppSettings.fromJson(
          (m['settings'] as Map? ?? {}).cast<String, dynamic>()),
      time: m['time']?.toString(),
    );
  }
}

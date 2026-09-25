import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// ══════════════════════════════════════════════════════════════
/// مزوّد المصادقة — تسجيل الدخول والحساب
/// ══════════════════════════════════════════════════════════════
class AuthProvider extends ChangeNotifier {
  final _api = ApiService.instance;

  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';

  User? _user;
  String? _token;
  bool _loading = false;
  String? _error;
  bool _initialized = false;

  User? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null && (_token?.isNotEmpty ?? false);
  bool get initialized => _initialized;

  /// استعادة الجلسة المحفوظة عند الإقلاع
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_kToken);
    final u = prefs.getString(_kUser);

    if (t != null && t.isNotEmpty && u != null) {
      try {
        // فكّ ترميز المستخدم المحفوظ
        final map = _decodeUser(u);
        if (map != null) {
          _token = t;
          _user = User.fromJson(map);
          _api.setToken(t);
        }
      } catch (_) {
        await prefs.remove(_kToken);
        await prefs.remove(_kUser);
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Map<String, dynamic>? _decodeUser(String json) {
    // تخزين مبسّط بصيغة key=value|key=value لتجنّب اعتماد إضافي
    try {
      final m = <String, dynamic>{};
      for (final pair in json.split('|')) {
        final idx = pair.indexOf('=');
        if (idx <= 0) continue;
        final k = pair.substring(0, idx);
        final v = pair.substring(idx + 1);
        if (k == 'id') {
          m[k] = int.tryParse(v);
        } else {
          m[k] = v.isEmpty ? null : v;
        }
      }
      return m['id'] != null ? m : null;
    } catch (_) {
      return null;
    }
  }

  String _encodeUser(User u) {
    final parts = <String>[
      'id=${u.id}',
      'phone=${u.phone}',
      'phone_intl=${u.phoneIntl}',
      'full_name=${u.fullName}',
      'birth_date=${u.birthDate ?? ''}',
      'avatar=${u.avatar ?? ''}',
      'bio=${u.bio ?? ''}',
      'role=${u.role}',
      'created_at=${u.createdAt ?? ''}',
    ];
    return parts.join('|');
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null && _user != null) {
      await prefs.setString(_kToken, _token!);
      await prefs.setString(_kUser, _encodeUser(_user!));
    }
  }

  /// ═══════════════ تسجيل الدخول ═══════════════
  Future<bool> login(String phone, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final r = await _api.login(phone, password);
      _token = r.token;
      _user = r.user;
      _api.setToken(r.token);
      await _persist();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : 'تعذّر تسجيل الدخول';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// ═══════════════ إنشاء حساب ═══════════════
  Future<bool> register({
    required String phone,
    required String password,
    required String fullName,
    String? birthDate,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final r = await _api.register(
        phone: phone,
        password: password,
        fullName: fullName,
        birthDate: birthDate,
      );
      _token = r.token;
      _user = r.user;
      _api.setToken(r.token);
      await _persist();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : 'تعذّر إنشاء الحساب';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// ═══════════════ تحديث الملف الشخصي ═══════════════
  Future<bool> updateProfile({
    String? fullName,
    String? birthDate,
    String? bio,
    String? avatarBase64,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final u = await _api.updateProfile(
        fullName: fullName,
        birthDate: birthDate,
        bio: bio,
        avatarBase64: avatarBase64,
      );
      _user = u;
      await _persist();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : 'تعذّر الحفظ';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// تحديث بيانات المستخدم محلياً
  void setUser(User u) {
    _user = u;
    _persist();
    notifyListeners();
  }

  /// ═══════════════ تسجيل الخروج ═══════════════
  Future<void> logout() async {
    _token = null;
    _user = null;
    _api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

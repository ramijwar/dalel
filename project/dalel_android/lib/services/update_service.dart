import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'api_service.dart';

/// مرحلة التحديث
enum UpdatePhase {
  /// لا شيء معروف بعد
  idle,

  /// يسأل الخادم
  checking,

  /// هناك إصدار أحدث، جاهز للتنزيل
  available,

  /// يُنزَّل الآن
  downloading,

  /// اكتمل التنزيل — بانتظار التثبيت
  downloaded,

  /// فُتح مثبّت النظام
  installing,

  /// فشل شيء
  failed,
}

/// ══════════════════════════════════════════════════════════════
/// خدمة تحديث التطبيق
/// تسأل الخادم عن إصدار أحدث، تُنزّل ملف APK مع نسبة وسرعة،
/// ثم تفتح مثبّت النظام — ولا شيء غير ذلك.
/// ══════════════════════════════════════════════════════════════
class UpdateService extends ChangeNotifier {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String apkMime = 'application/vnd.android.package-archive';

  final _api = ApiService.instance;
  final _client = http.Client();

  AppUpdate? _update;
  UpdatePhase _phase = UpdatePhase.idle;
  String? _error;

  // ─── النسخة المثبَّتة على الجهاز ───
  int _installedCode = 0;
  String _installedName = '';
  bool _installedRead = false;

  // ─── التنزيل ───
  double _progress = 0; // 0..1
  int _received = 0;
  int _total = 0;
  double _speed = 0; // بايت/ثانية
  String? _filePath;
  bool _cancelRequested = false;
  bool _dismissed = false;

  // ═══════════════ الحالة ═══════════════
  AppUpdate? get update => _update;
  UpdatePhase get phase => _phase;
  String? get error => _error;
  double get progress => _progress;
  int get received => _received;
  int get total => _total;
  double get speed => _speed;
  String? get filePath => _filePath;
  int get installedCode => _installedCode;
  String get installedName => _installedName;

  bool get hasUpdate => _update != null && !_dismissed;
  bool get isDownloading => _phase == UpdatePhase.downloading;
  bool get isDownloaded => _phase == UpdatePhase.downloaded || _phase == UpdatePhase.installing;
  bool get isForced => _update?.force == true;

  int get remaining => (_total - _received) > 0 ? _total - _received : 0;
  int get percent => (_progress * 100).clamp(0, 100).round();

  /// «٢٫٤ م.ب/ث»
  String get speedLabel => formatSpeed(_speed);

  /// «٨٫٢ ميغا من ٢٤٫٠ ميغا»
  String get receivedLabel => _total > 0
      ? '${formatBytes(_received)} من ${formatBytes(_total)}'
      : formatBytes(_received);

  /// «بقي ١:٢٠ د» — يفرغ إن كانت السرعة مجهولة
  String get etaLabel {
    if (_speed < 1024 || remaining <= 0) return '';
    final eta = formatEta((remaining / _speed).ceil());
    return eta.isEmpty ? '' : 'بقي $eta';
  }

  // ══════════════════════════════════════════════════════════
  // الفحص
  // ══════════════════════════════════════════════════════════

  /// قراءة رقم الإصدار المثبَّت من حزمة التطبيق نفسها
  Future<void> _readInstalled() async {
    if (_installedRead) return;
    _installedRead = true;
    try {
      final info = await PackageInfo.fromPlatform();
      _installedName = info.version;
      _installedCode = int.tryParse(info.buildNumber.trim()) ?? 0;
    } catch (_) {
      // تعذّرت القراءة: نكمل بمقارنة الاسم
      _installedCode = 0;
    }
  }

  /// الوصول إلى رقم الإصدار المثبَّت (للعرض في تبويب «حسابي»)
  Future<String> installedLabel() async {
    await _readInstalled();
    if (_installedName.isEmpty) return '—';
    return _installedCode > 0 ? '$_installedName ($_installedCode)' : _installedName;
  }

  /// يسأل الخادم: هل هناك إصدار أحدث؟
  /// [silent] = لا تُظهر حالة «جارٍ الفحص» ولا خطأ الشبكة.
  Future<void> check({bool silent = true}) async {
    if (_phase == UpdatePhase.downloading) return;

    await _readInstalled();

    if (!silent) {
      _phase = UpdatePhase.checking;
      _error = null;
      notifyListeners();
    }

    try {
      final u = await _api.appUpdate();

      if (u == null || !u.hasUrl) {
        _update = null;
        _phase = UpdatePhase.idle;
        _error = null;
      } else if (!u.isNewerThan(
        installedCode: _installedCode,
        installedName: _installedName,
      )) {
        // إصدارنا الحالي هو الأحدث — لا نعرض شيئاً، وننظّف ملفاً قديماً إن وُجد
        _update = null;
        _phase = UpdatePhase.idle;
        _error = null;
        await _cleanOldFiles();
      } else {
        _update = u;
        _dismissed = false;
        // هل نُزِّل هذا الإصدار سابقاً (تنزيل مكتمل من جلسة سابقة)؟
        final ready = await _findDownloaded(u);
        _phase = ready ? UpdatePhase.downloaded : UpdatePhase.available;
        _filePath = ready ? _filePath : null;
        _error = null;
      }
    } catch (e) {
      _error = e is ApiException ? e.message : 'تعذّر التحقّق من التحديث';
      if (!silent) _phase = UpdatePhase.failed;
    }

    notifyListeners();
  }

  /// إخفاء بطاقة التحديث لهذه الجلسة (لا يُسمح به في التحديث الإلزامي)
  void dismiss() {
    if (isForced) return;
    _dismissed = true;
    notifyListeners();
  }

  /// إظهار البطاقة من جديد (زر «لاحقاً» ثم إعادة الفحص)
  void restore() {
    _dismissed = false;
    notifyListeners();
  }

  String _fileNameFor(AppUpdate u) {
    final tag = u.versionName.isNotEmpty
        ? u.versionName.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '')
        : 'build${u.versionCode}';
    return 'dalel-$tag.apk';
  }

  /// هل الملف مُنزَّل مسبقاً وبالحجم الصحيح؟
  Future<bool> _findDownloaded(AppUpdate u) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/${_fileNameFor(u)}');
      if (!await f.exists()) return false;
      final len = await f.length();
      if (u.size > 0 && len != u.size) {
        await f.delete(); // ناقص/تالف — أعد التنزيل
        return false;
      }
      _filePath = f.path;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// حذف ملفات APK المتنزّلة القديمة من مجلد المؤقّت
  Future<void> _cleanOldFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      await for (final e in dir.list()) {
        if (e is File && e.path.toLowerCase().endsWith('.apk')) {
          await e.delete();
        }
      }
    } catch (_) {
      // لا يهم
    }
  }

  // ══════════════════════════════════════════════════════════
  // التنزيل
  // ══════════════════════════════════════════════════════════

  /// يُنزّل الملف مع تحديث النسبة والسرعة، ويتحقّق من بصمة SHA-256.
  Future<void> download() async {
    final u = _update;
    if (u == null || !u.hasUrl || _phase == UpdatePhase.downloading) return;

    _cancelRequested = false;
    _error = null;
    _phase = UpdatePhase.downloading;
    _progress = 0;
    _received = 0;
    _speed = 0;
    _total = u.size;
    notifyListeners();

    File? file;
    IOSink? sink;
    final digestSink = _DigestSink();
    final digest = sha256.startChunkedConversion(digestSink);

    try {
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/${_fileNameFor(u)}');
      if (await file.exists()) await file.delete();
      _filePath = file.path;

      final res = await _client.send(http.Request('GET', Uri.parse(u.url)));
      if (res.statusCode != 200) {
        throw ApiException('تعذّر التنزيل (رمز ${res.statusCode})');
      }
      if (res.contentLength != null && res.contentLength! > 0) {
        _total = res.contentLength!;
      }

      sink = file.openWrite();
      var lastTick = DateTime.now();
      var lastBytes = 0;

      await for (final chunk in res.stream) {
        if (_cancelRequested) break;
        sink.add(chunk);
        digest.add(chunk);
        _received += chunk.length;
        if (_total > 0) {
          _progress = (_received / _total).clamp(0.0, 1.0);
        }

        final now = DateTime.now();
        final ms = now.difference(lastTick).inMilliseconds;
        if (ms >= 250) {
          final instant = (_received - lastBytes) * 1000 / ms;
          // تنعيم بسيط كي لا يرتجف الرقم المعروض
          _speed = _speed <= 0 ? instant : (_speed * 0.65 + instant * 0.35);
          lastTick = now;
          lastBytes = _received;
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;
      digest.close();

      if (_cancelRequested) {
        _cancelRequested = false;
        if (await file.exists()) await file.delete();
        _filePath = null;
        _progress = 0;
        _received = 0;
        _speed = 0;
        _phase = UpdatePhase.available;
        notifyListeners();
        return;
      }

      // ─── التحقق من السلامة ───
      if (u.sha256.isNotEmpty) {
        final got = (digestSink.value?.toString() ?? '').toLowerCase();
        if (got != u.sha256.toLowerCase()) {
          if (await file.exists()) await file.delete();
          throw ApiException('الملف المُنزَّل تالف — أعد المحاولة');
        }
      }

      _progress = 1;
      if (_total > 0) _received = _total;
      _speed = 0;
      _phase = UpdatePhase.downloaded;
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
      _filePath = null;
      _speed = 0;
      _phase = UpdatePhase.failed;
      _error = e is ApiException ? e.message : 'تعذّر تنزيل التحديث';
    }

    notifyListeners();
  }

  /// إلغاء التنزيل الجاري
  void cancelDownload() {
    if (_phase == UpdatePhase.downloading) _cancelRequested = true;
  }

  // ══════════════════════════════════════════════════════════
  // التثبيت
  // ══════════════════════════════════════════════════════════

  /// يفتح مثبّت أندرويد على الملف المُنزَّل.
  /// ملاحظة: التثبيت الصامت غير مسموح في أندرويد — يرى المستخدم
  /// نافذة النظام ويضغط «تثبيت» بنفسه.
  Future<void> install() async {
    final path = _filePath;
    if (path == null || path.isEmpty) {
      _error = 'لا يوجد ملف مُنزَّل';
      _phase = UpdatePhase.failed;
      notifyListeners();
      return;
    }

    _phase = UpdatePhase.installing;
    _error = null;
    notifyListeners();

    try {
      final exists = await File(path).exists();
      if (!exists) {
        _filePath = null;
        _phase = UpdatePhase.available;
        _error = 'الملف لم يعد موجوداً — أعد التنزيل';
        notifyListeners();
        return;
      }

      final r = await OpenFilex.open(path, type: apkMime);
      if (r.type != ResultType.done) {
        _error = r.type == ResultType.permissionDenied
            ? 'اسمح للتطبيق بتثبيت التطبيقات من الإعدادات ثم أعد المحاولة'
            : 'تعذّر فتح مثبّت النظام${r.message.isEmpty ? '' : ': ${r.message}'}';
      }
      _phase = UpdatePhase.downloaded;
    } catch (e) {
      _phase = UpdatePhase.downloaded;
      _error = 'تعذّر فتح مثبّت النظام — افتح الملف يدوياً';
    }

    notifyListeners();
  }

  /// إعادة المحاولة بعد فشل
  Future<void> retry() async {
    if (_update == null) {
      await check(silent: false);
      return;
    }
    _error = null;
    _phase = UpdatePhase.available;
    notifyListeners();
  }
}

/// مستقبِل بسيط لنتيجة sha256 المتدفّقة (بلا تجميع الملف كله في الذاكرة)
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

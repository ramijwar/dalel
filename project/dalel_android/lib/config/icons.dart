import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// ══════════════════════════════════════════════════════════════
/// خريطة أيقونات Lucide — تطابق أسماء أيقونات موقع الويب
/// ══════════════════════════════════════════════════════════════
class AppIcons {
  AppIcons._();

  static final Map<String, IconData> _map = {
    // ─── الأقسام ───
    'pill': LucideIcons.pill,
    'stethoscope': LucideIcons.stethoscope,
    'fuel': LucideIcons.fuel,
    'bus': LucideIcons.bus,
    'shopping-bag': LucideIcons.shoppingBag,
    'store': LucideIcons.store,
    'shopping-cart': LucideIcons.shoppingCart,
    'car': LucideIcons.car,
    'truck': LucideIcons.truck,
    'van': LucideIcons.truck,
    'siren': LucideIcons.siren,

    // ─── الموقع ───
    'map-pin': LucideIcons.mapPin,
    'map': LucideIcons.map,
    'map-pinned': LucideIcons.mapPin,
    'navigation': LucideIcons.navigation,
    'compass': LucideIcons.compass,
    'globe': LucideIcons.globe,
    'home': LucideIcons.home,
    'house': LucideIcons.home,
    'building': LucideIcons.building,
    'building-2': LucideIcons.building2,
    'warehouse': LucideIcons.warehouse,
    'landmark': LucideIcons.landmark,

    // ─── التنقل والواجهة ───
    'search': LucideIcons.search,
    'grid': LucideIcons.layoutGrid,
    'list': LucideIcons.list,
    'layout-grid': LucideIcons.layoutGrid,
    'rows': LucideIcons.rows,
    'menu': LucideIcons.menu,
    'x': LucideIcons.x,
    'chevron-down': LucideIcons.chevronDown,
    'chevron-up': LucideIcons.chevronUp,
    'chevron-left': LucideIcons.chevronLeft,
    'chevron-right': LucideIcons.chevronRight,
    'arrow-left': LucideIcons.arrowLeft,
    'arrow-right': LucideIcons.arrowRight,
    'arrow-up-down': LucideIcons.arrowUpDown,
    'refresh': LucideIcons.refreshCw,
    'refresh-cw': LucideIcons.refreshCw,
    'settings': LucideIcons.settings,
    'settings-2': LucideIcons.settings2,
    'sliders': LucideIcons.slidersHorizontal,
    'filter': LucideIcons.filter,
    'more': LucideIcons.moreHorizontal,
    'ellipsis': LucideIcons.moreHorizontal,
    'external-link': LucideIcons.externalLink,

    // ─── الاتصال ───
    'phone': LucideIcons.phone,
    'phone-call': LucideIcons.phoneCall,
    'message-circle': LucideIcons.messageCircle,
    'message-square': LucideIcons.messageSquare,
    'whatsapp': LucideIcons.messageCircle,
    'send': LucideIcons.send,
    'share': LucideIcons.share2,
    'share-2': LucideIcons.share2,
    'link': LucideIcons.link,

    // ─── المستخدمون ───
    'user': LucideIcons.user,
    'users': LucideIcons.users,
    'user-plus': LucideIcons.userPlus,
    'user-check': LucideIcons.userCheck,
    'user-round': LucideIcons.userCircle,
    'circle-user': LucideIcons.userCircle,
    'log-in': LucideIcons.logIn,
    'log-out': LucideIcons.logOut,
    'key': LucideIcons.key,
    'lock': LucideIcons.lock,
    'shield': LucideIcons.shield,
    'shield-check': LucideIcons.shieldCheck,
    'badge-check': LucideIcons.badgeCheck,
    'heart': LucideIcons.heart,
    'star': LucideIcons.star,
    'bookmark': LucideIcons.bookmark,

    // ─── الحالة والوقت ───
    'clock': LucideIcons.clock,
    'calendar': LucideIcons.calendar,
    'calendar-days': LucideIcons.calendarDays,
    'calendar-clock': LucideIcons.calendarClock,
    'timer': LucideIcons.timer,
    'hourglass': LucideIcons.hourglass,
    'activity': LucideIcons.activity,
    'circle': LucideIcons.circle,
    'dot': LucideIcons.circle,
    'check': LucideIcons.check,
    'check-circle': LucideIcons.checkCircle,
    'check-circle-2': LucideIcons.checkCircle2,
    'x-circle': LucideIcons.xCircle,
    'alert-circle': LucideIcons.alertCircle,
    'alert-triangle': LucideIcons.alertTriangle,
    'info': LucideIcons.info,
    'ban': LucideIcons.ban,
    'zap': LucideIcons.zap,
    'trending-up': LucideIcons.trendingUp,
    'toggle-left': LucideIcons.toggleLeft,
    'toggle-right': LucideIcons.toggleRight,
    'power': LucideIcons.power,

    // ─── الإدارة ───
    'boxes': LucideIcons.boxes,
    'package': LucideIcons.package,
    'inbox': LucideIcons.inbox,
    'trash': LucideIcons.trash,
    'trash-2': LucideIcons.trash2,
    'pencil': LucideIcons.pencil,
    'edit': LucideIcons.pencil,
    'edit-2': LucideIcons.edit2,
    'plus': LucideIcons.plus,
    'plus-circle': LucideIcons.plusCircle,
    'minus': LucideIcons.minus,
    'save': LucideIcons.save,
    'copy': LucideIcons.copy,
    'download': LucideIcons.download,
    'upload': LucideIcons.upload,
    'image': LucideIcons.image,
    'camera': LucideIcons.camera,
    'eye': LucideIcons.eye,
    'eye-off': LucideIcons.eyeOff,

    // ─── متنوع ───
    'tag': LucideIcons.tag,
    'tags': LucideIcons.tags,
    'layers': LucideIcons.layers,
    'folder': LucideIcons.folder,
    'file': LucideIcons.file,
    'file-text': LucideIcons.fileText,
    'bell': LucideIcons.bell,
    'bell-ring': LucideIcons.bellRing,
    'megaphone': LucideIcons.megaphone,
    'sparkles': LucideIcons.sparkles,
    'crown': LucideIcons.crown,
    'gift': LucideIcons.gift,
    'coffee': LucideIcons.coffee,
    'utensils': LucideIcons.utensils,
    'wifi': LucideIcons.wifi,
    'wifi-off': LucideIcons.wifiOff,
    'cloud': LucideIcons.cloud,
    'cloud-off': LucideIcons.cloudOff,
    'database': LucideIcons.database,
    'server': LucideIcons.server,
    'smartphone': LucideIcons.smartphone,
    'monitor': LucideIcons.monitor,
    'baby': LucideIcons.baby,
    'briefcase': LucideIcons.briefcase,
    'graduation-cap': LucideIcons.graduationCap,
    'book': LucideIcons.book,
    'dumbbell': LucideIcons.dumbbell,
    'scissors': LucideIcons.scissors,
    'wrench': LucideIcons.wrench,
    'hammer': LucideIcons.hammer,
    'paintbrush': LucideIcons.paintbrush,
    'shirt': LucideIcons.shirt,
    'watch': LucideIcons.watch,
    'laptop': LucideIcons.laptop,
    'tv': LucideIcons.tv,
    'headphones': LucideIcons.headphones,
    'credit-card': LucideIcons.creditCard,
    'wallet': LucideIcons.wallet,
    'banknote': LucideIcons.banknote,
    'coins': LucideIcons.coins,
  };

  /// حوّل اسم الأيقونة إلى IconData (مع بديل آمن)
  static IconData get(String? name) {
    if (name == null || name.isEmpty) return LucideIcons.circle;
    final key = name.toLowerCase().trim();
    return _map[key] ?? _map[key.replaceAll('_', '-')] ?? LucideIcons.circle;
  }

  /// هل الاسم أيقونة معروفة؟
  static bool has(String? name) =>
      name != null && _map.containsKey(name.toLowerCase().trim());

  /// قائمة الأيقونات المتاحة (بدون «إسعاف» المرسومة يدوياً)
  static List<String> get names => _map.keys.toList()..sort();
}

/// ══════════════════════════════════════════════════════════════
/// أيقونة الإسعاف — مرسومة يدوياً لأن حزمة lucide_icons لا تحتويها
/// ══════════════════════════════════════════════════════════════
class AmbulancePainter extends CustomPainter {
  final Color color;

  AmbulancePainter({this.color = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.072
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()..color = color;
    final w = size.width;
    final h = size.height;

    // هيكل السيارة
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, h * 0.3, w * 0.68, h * 0.38),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(body, p);

    // مقدمة السيارة
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.74, h * 0.42, w * 0.22, h * 0.26),
        Radius.circular(w * 0.05),
      ),
      p,
    );

    // النوافذ
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.36, w * 0.22, h * 0.18),
        Radius.circular(w * 0.03),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.36, w * 0.22, h * 0.18),
        Radius.circular(w * 0.03),
      ),
      p,
    );

    // العجلات
    canvas.drawCircle(Offset(w * 0.26, h * 0.72), w * 0.085, p);
    canvas.drawCircle(Offset(w * 0.74, h * 0.72), w * 0.085, p);

    // إشارة الصليب الأحمر فوق السقف
    canvas.drawLine(
      Offset(w * 0.5, h * 0.3),
      Offset(w * 0.5, h * 0.17),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round,
    );

    // الصليب
    final cx = w * 0.5;
    final cy = h * 0.115;
    final arm = w * 0.072;
    final thick = w * 0.038;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - thick / 2, cy - arm, thick, arm * 2),
        Radius.circular(thick * 0.25),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - arm, cy - thick / 2, arm * 2, thick),
        Radius.circular(thick * 0.25),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant AmbulancePainter old) => old.color != color;
}

/// ودجة أيقونة الإسعاف
class AmbulanceIcon extends StatelessWidget {
  final double size;
  final Color color;

  const AmbulanceIcon({super.key, this.size = 22, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: AmbulancePainter(color: color)),
    );
  }
}

/// ودجة أيقونة — تتعامل مع الرموز التعبيرية وأيقونة الإسعاف المرسومة
class AppIcon extends StatelessWidget {
  final String? name;
  final double size;
  final Color? color;

  const AppIcon(this.name, {super.key, this.size = 22, this.color});

  /// أسماء Lucide: حروف لاتينية صغيرة وشرطات وأرقام فقط
  static bool looksLikeName(String s) =>
      RegExp(r'^[a-z0-9\-_]+$').hasMatch(s.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final n = (name ?? '').trim();
    if (n.isEmpty) {
      return Icon(LucideIcons.circle, size: size, color: color);
    }

    // أيقونة الإسعاف المرسومة يدوياً
    if (n == 'ambulance' || n == 'اسعاف' || n == 'إسعاف') {
      return AmbulanceIcon(size: size, color: color ?? Colors.black);
    }

    // رمز تعبيري أو نص
    if (!looksLikeName(n)) {
      return Text(n, style: TextStyle(fontSize: size, color: color));
    }

    return Icon(AppIcons.get(n), size: size, color: color);
  }
}

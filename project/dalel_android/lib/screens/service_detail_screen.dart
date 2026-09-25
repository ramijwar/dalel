import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../config/constants.dart';
import '../config/icons.dart';
import '../widgets/dynamic_fields.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import 'request_service_screen.dart';
import '../widgets/widgets.dart';

/// ══════════════════════════════════════════════════════════════
/// شاشة تفاصيل الخدمة — بيانات كاملة + اتصال + واتساب + جدول الدوام
/// ══════════════════════════════════════════════════════════════
class ServiceDetailScreen extends StatefulWidget {
  final Service service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  late Service _s;
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _s = widget.service;
    _loadFull();
    _checkFav();
  }

  Future<void> _loadFull() async {
    try {
      final app = context.read<AppProvider>();
      final s = await app.loadService(_s.id);
      if (!mounted) return;
      setState(() {
        _s = s;
      });
    } catch (_) {
      // احتفظ بالبيانات الممرّرة إن تعذّر التحديث
    }
  }

  Future<void> _checkFav() async {
    final fav = await DatabaseService.instance.isFavorite(_s.id);
    if (mounted) setState(() => _isFav = fav);
  }

  Future<void> _toggleFav() async {
    await DatabaseService.instance.toggleFavorite(_s.id);
    await _checkFav();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = SectionConfig.of(_s.categorySlug);
    final accent = const [
      Color(0xFF0EA5E9),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
    ][_s.categoryId % 4];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('تفاصيل الخدمة'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowRight),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFav ? LucideIcons.bookmark : LucideIcons.bookmark,
              color: _isFav ? AppTheme.primary : AppTheme.textMuted,
            ),
            tooltip: _isFav ? 'إزالة من المحفوظات' : 'حفظ',
            onPressed: _toggleFav,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── بطاقة العنوان ───
            _buildHeader(accent, cfg),
            const SizedBox(height: 14),

            // ─── أزرار الاتصال ───
            if (_s.phone.isNotEmpty || _s.whatsappReady.isNotEmpty)
              _buildActions(),
            const SizedBox(height: 14),

            // ─── المعلومات ───
            _buildInfo(accent),
            const SizedBox(height: 14),

            // ─── جدول الدوام ───
            if (_s.schedule.isNotEmpty) _buildSchedule(accent),

            const SizedBox(height: 14),

            // ─── «أضف خدمتك» (على صفحة التفاصيل فقط) ───
            _buildOwnerCta(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent, SectionConfig cfg) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: AppIcon(_s.categoryIcon, size: 32, color: accent),
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_s.isVerified) ...[
                const Icon(LucideIcons.badgeCheck,
                    size: 17, color: AppTheme.primary),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  _s.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _s.categoryName,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          // حالة كبيرة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: _s.onDuty
                  ? AppTheme.dutyBg
                  : _s.isOpen
                      ? AppTheme.openBg
                      : AppTheme.closedBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusDot(status: _s.status, onDuty: _s.onDuty, size: 9),
                const SizedBox(width: 7),
                Text(
                  _s.displayStatus,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _s.onDuty
                        ? AppTheme.duty
                        : _s.isOpen
                            ? AppTheme.open
                            : AppTheme.closed,
                  ),
                ),
              ],
            ),
          ),
          if (_s.statusSublabel.isNotEmpty) ...[
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.clock,
                    size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 5),
                Text(
                  _s.statusSublabel,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
          if (_s.updatedAt != null) ...[
            const SizedBox(height: 11),
            Text(
              'آخر تحديث: ${_s.updatedAt}',
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        if (_s.phone.isNotEmpty)
          Expanded(
            child: _BigAction(
              icon: LucideIcons.phone,
              label: 'اتصال',
              color: AppTheme.open,
              onTap: () => _launch('tel:${_s.phone}'),
            ),
          ),
        if (_s.phone.isNotEmpty && _s.whatsappReady.isNotEmpty)
          const SizedBox(width: 11),
        if (_s.whatsappReady.isNotEmpty)
          Expanded(
            child: _BigAction(
              icon: LucideIcons.messageCircle,
              label: 'واتساب',
              color: const Color(0xFF25D366),
              onTap: () =>
                  _launch('https://wa.me/${_s.whatsappReady}', external: true),
            ),
          ),
      ],
    );
  }

  /// صف حقل ديناميكي بأيقونته الخاصة.
  ///
  /// الخادم يرسل `icon` لكل حقل (مثل `hash` لسعر المعاينة و`type` للنص، أو
  /// إيموجي لخيارات القائمة). كان التطبيق يرسم `LucideIcons.tag` لكل الحقول
  /// فيتجاهل الأيقونة المختارة من اللوحة — نرسمها الآن: اسم Lucide معروف ←
  /// أيقونته، رمز تعبيري ← يُعرض كما هو، وإلا فالوسم كاحتياط.
  _InfoRowData _fieldRow(ResolvedField f) {
    final ic = f.icon.trim();
    if (ic.isEmpty) return _InfoRowData(LucideIcons.tag, f.label, f.display);
    if (!AppIcon.looksLikeName(ic)) {
      return _InfoRowData(LucideIcons.tag, f.label, f.display, emoji: ic);
    }
    return _InfoRowData(
      AppIcons.has(ic) ? AppIcons.get(ic) : LucideIcons.tag,
      f.label,
      f.display,
    );
  }

  Widget _buildInfo(Color accent) {
    final rows = <_InfoRowData>[
      if (_s.fullRegionLabel.isNotEmpty)
        _InfoRowData(LucideIcons.mapPin, 'المنطقة', _s.fullRegionLabel),
      if (_s.address.isNotEmpty)
        _InfoRowData(LucideIcons.navigation, 'العنوان', _s.address),
      if (_s.phone.isNotEmpty)
        _InfoRowData(LucideIcons.phone, 'الهاتف', _s.phone, isLtr: true),
      if (_s.ownerName != null && _s.ownerName!.isNotEmpty)
        _InfoRowData(LucideIcons.user, 'المسؤول', _s.ownerName!),
      if (_s.note.isNotEmpty)
        _InfoRowData(LucideIcons.fileText, 'ملاحظات', _s.note),
      // الحقول الخاصة بالقسم — محلولة من الخادم (مثل اختصاص الطبيب وسعر المعاينة)
      ..._s.fields
          .where((f) => f.display.isNotEmpty)
          .map(_fieldRow),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(LucideIcons.info, size: 15, color: accent),
              ),
              const SizedBox(width: 9),
              const Text(
                'معلومات الخدمة',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.emoji != null && r.emoji!.isNotEmpty)
                      SizedBox(
                        width: 15,
                        child: Text(
                          r.emoji!,
                          style: const TextStyle(
                              fontSize: 12.5, height: 1.2),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Icon(r.icon, size: 15, color: AppTheme.textMuted),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 62,
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.value,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppTheme.textPrimary,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                        textDirection:
                            r.isLtr ? TextDirection.ltr : TextDirection.rtl,
                        textAlign: r.isLtr ? TextAlign.right : TextAlign.start,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSchedule(Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(LucideIcons.calendarClock, size: 15, color: accent),
              ),
              const SizedBox(width: 9),
              const Text(
                'أوقات الدوام',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // الأسبوع كاملاً (٠ الأحد … ٦ السبت) كي يظهر اليوم الذي لا دوام
          // فيه «عطلة» بدل أن يُحذف من القائمة. يومٌ بفترتين يُعرض بسطر واحد
          // يفصل بينهما «·»، والأيام المرسلة باسم is_24h تعرض «٢٤ ساعة».
          ...List.generate(7, (d) {
            final rows = _s.schedule.where((r) => r.day == d).toList()
              ..sort((a, b) => a.from.compareTo(b.from));
            final open = rows.where((r) => r.isOpen).toList();
            final isToday = d == DateTime.now().weekday % 7;
            final value = open.isEmpty
                ? 'عطلة'
                : open
                    .map((r) => r.is24 ? '٢٤ ساعة' : '${r.from} – ${r.to}')
                    .join('  ·  ');
            final isOff = open.isEmpty;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isToday ? AppTheme.primarySoft : AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: isToday ? AppTheme.primaryLight : Colors.transparent,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 62,
                    child: Text(
                      ScheduleRow.dayNames[d],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday
                            ? AppTheme.primaryDark
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isOff
                            ? AppTheme.textMuted
                            : (isToday
                                ? AppTheme.primaryDark
                                : AppTheme.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// «أضف خدمتك» — على صفحة التفاصيل فقط (وليس في شريط التنقل)
  Widget _buildOwnerCta() {
    final auth = context.watch<AuthProvider>();
    final mine = auth.user != null && auth.user!.id == _s.ownerId;

    if (mine) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.primaryLight),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(LucideIcons.settings2,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Text(
                'هذه الخدمة مرتبطة بحسابك — تحكّم بحالتها من لوحة المالك',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child:
                Icon(LucideIcons.plusCircle, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'هل تملك هذه الخدمة أو خدمة مشابهة؟ أضفها للدليل',
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RequestServiceScreen(
                  initialCategory: _s.categoryId > 0
                      ? Category(
                          id: _s.categoryId,
                          slug: _s.categorySlug,
                          name: _s.categoryName,
                          icon: _s.categoryIcon,
                        )
                      : null,
                ),
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('أضف خدمتك', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String url, {bool external = false}) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: external
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
    }
  }
}

class _InfoRowData {
  final IconData icon;
  final String label;
  final String value;
  final bool isLtr;

  /// رمز تعبيري يُرسم كنص بدل أيقونة Lucide (خيارات الحقول قد تحمل إيموجي)
  final String? emoji;

  _InfoRowData(this.icon, this.label, this.value,
      {this.isLtr = false, this.emoji});
}

class _BigAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BigAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

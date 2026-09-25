import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/theme.dart';
import '../config/icons.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import 'section_screen.dart';
import 'request_service_screen.dart';

/// الصفحة الرئيسية — carousel إعلانات + بطاقات الأقسام
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () => app.sync(force: true),
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            // ─── الشريط العلوي ───
            SliverAppBar(
              pinned: true,
              expandedHeight: 0,
              backgroundColor: AppTheme.surface,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 62,
              // الشريط كاملاً داخل title ليصبح الزر في المنتصف تماماً
              // (brand | مسافة | زر الإضافة | مسافة | تحديث)
              title: Row(
                children: [
                  // ─── القسمان الجانبيان بـ Expanded متساوٍ ───
                  // فيصبح الزر في منتصف الشريط تماماً (مثل الويب)
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _buildTitle(app),
                    ),
                  ),
                  _buildAddButton(),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: IconButton(
                        icon: const Icon(LucideIcons.refreshCw, size: 20),
                        tooltip: 'تحديث',
                        onPressed:
                            app.syncing ? null : () => app.sync(force: true),
                      ),
                    ),
                  ),
                ],
              ),
              actions: const [],
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── carousel الإعلانات ───
                  AdCarousel(
                    items: app.settings.announcements,
                    intervalSeconds: app.settings.adInterval,
                  ),

                  // ─── عدّاد إجمالي ───
                  if (app.totalServices > 0) _buildCounter(app),

                  // ─── الأقسام ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.layoutGrid,
                            size: 17, color: AppTheme.textSecondary),
                        const SizedBox(width: 7),
                        const Text(
                          'الأقسام',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${app.categories.length} أقسام',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),

                  if (app.loading && app.categories.isEmpty)
                    const _CategoriesSkeleton()
                  else if (app.categories.isEmpty)
                    const EmptyState(
                      icon: LucideIcons.boxes,
                      title: 'لا توجد أقسام',
                      subtitle: 'اسحب الشاشة للأسفل للتحديث',
                    )
                  else
                    _buildCategories(app),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ══════════════════════════════════════════════════════════
  /// زر «أضف خدمة» في وسط الشريط العلوي
  /// ══════════════════════════════════════════════════════════
  Widget _buildAddButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RequestServiceScreen()),
        ),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.28),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(LucideIcons.plus, size: 15, color: Colors.white),
              SizedBox(width: 5),
              Text(
                'أضف خدمة',
                style: TextStyle(
                  fontSize: 12.5,
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

  Widget _buildTitle(AppProvider app) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(LucideIcons.mapPin, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                app.settings.siteName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (app.settings.city.isNotEmpty)
                Text(
                  app.settings.city,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCounter(AppProvider app) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.layers,
                size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${app.totalServices}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Text(
                  'خدمة في الدليل',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (app.isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.wifiOff, size: 11, color: Color(0xFFB45309)),
                  SizedBox(width: 3),
                  Text('محفوظة',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategories(AppProvider app) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
        childAspectRatio: 1.28,
      ),
      itemCount: app.categories.length,
      itemBuilder: (context, i) {
        final c = app.categories[i];
        return CategoryCard(
          category: c,
          count: app.countFor(c.slug),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SectionScreen(category: c)),
          ),
        );
      },
    );
  }
}

class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
        childAspectRatio: 1.28,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
        ),
      ),
    );
  }
}

/// ══════════════════════════════════════════════════════════════
/// ألوان الإعلانات — لكل نوع أيقونة لون يميّزه
/// ══════════════════════════════════════════════════════════════
class AdColors {
  AdColors._();

  /// اللون الأساسي لكل نوع أيقونة
  static const Map<String, Color> byIcon = {
    // إعلان وإشعار
    'megaphone': Color(0xFFEA580C),   // برتقالي
    'bell': Color(0xFF7C3AED),        // بنفسجي
    'bell-ring': Color(0xFF8B5CF6),   // بنفسجي فاتح
    'sparkles': Color(0xFFD946EF),    // فوشي
    'star': Color(0xFFF59E0B),        // كهرماني
    'zap': Color(0xFFEAB308),         // أصفر
    'gift': Color(0xFFEC4899),        // وردي
    'crown': Color(0xFFCA8A04),       // ذهبي
    'tag': Color(0xFF0EA5E9),         // أزرق
    'tags': Color(0xFF0284C7),        // أزرق داكن
    // خدمات
    'pill': Color(0xFF3B82F6),        // أزرق طبي
    'stethoscope': Color(0xFF06B6D4), // سماوي
    'fuel': Color(0xFFF59E0B),        // كهرماني
    'bus': Color(0xFF8B5CF6),         // بنفسجي
    'car': Color(0xFF10B981),         // أخضر
    'truck': Color(0xFF14B8A6),       // تركوازي
    'shopping-bag': Color(0xFFF43F5E),// أحمر وردي
    'store': Color(0xFF0EA5E9),       // أزرق
    'utensils': Color(0xFFF97316),    // برتقالي
    'coffee': Color(0xFF92400E),      // بني
    // حالة
    'check-circle': Color(0xFF16A34A),// أخضر
    'info': Color(0xFF0EA5E9),        // أزرق
    'alert-triangle': Color(0xFFD97706),
    'heart': Color(0xFFEF4444),       // أحمر
    'phone': Color(0xFF059669),       // أخضر مزرق
    'map-pin': Color(0xFF0EA5E9),     // أزرق
    'clock': Color(0xFF6366F1),       // نيلي
    'calendar': Color(0xFF8B5CF6),    // بنفسجي
    'users': Color(0xFF14B8A6),       // تركوازي
    'trending-up': Color(0xFF10B981), // أخضر
  };

  /// ألوان احتياطية متناوبة للإعلانات بلا أيقونة — تضمن تمايزاً بصرياً
  static const List<Color> fallback = [
    Color(0xFF0EA5E9), // أزرق سماوي
    Color(0xFF8B5CF6), // بنفسجي
    Color(0xFFF59E0B), // كهرماني
    Color(0xFF10B981), // أخضر زمردي
    Color(0xFFF43F5E), // وردي
    Color(0xFF06B6D4), // سماوي
  ];

  /// لون الإعلان: من الإعدادات ← من الأيقونة ← تناوب احتياطي
  static Color forAd(Announcement a, int index) {
    // ١) اللون الذي حدّده المدير له الأولوية
    if (a.color != null && a.color!.trim().isNotEmpty) {
      final hex = a.color!.replaceAll('#', '').trim();
      if (hex.length == 6) {
        final v = int.tryParse('FF$hex', radix: 16);
        if (v != null) return Color(v);
      }
    }
    // ٢) لون حسب نوع الأيقونة
    if (a.icon != null && a.icon!.isNotEmpty) {
      final key = a.icon!.toLowerCase().trim();
      final c = byIcon[key];
      if (c != null) return c;
    }
    // ٣) تناوب احتياطي لضمان اختلاف كل إعلان عن جاره
    return fallback[index % fallback.length];
  }
}

/// ═══════════════ carousel الإعلانات ═══════════════
/// يُغذّى من إعلانات لوحة التحكم فقط، والفاصل الزمني قابل للضبط
class AdCarousel extends StatefulWidget {
  final List<Announcement> items;
  final int intervalSeconds;

  const AdCarousel({
    super.key,
    required this.items,
    this.intervalSeconds = 5,
  });

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  final PageController _ctrl = PageController();
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  void _startAuto() {
    if (widget.items.length <= 1) return;
    Future.delayed(
        Duration(
            seconds: widget.intervalSeconds < 2 ? 5 : widget.intervalSeconds),
        () {
      if (!mounted) return;
      if (widget.items.isEmpty) return;
      final next = (_current + 1) % widget.items.length;
      if (_ctrl.hasClients) {
        _ctrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
        );
      }
      _startAuto();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      height: 108,
      child: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.items.length,
            itemBuilder: (context, i) {
              final a = widget.items[i];
              final adColor = AdColors.forAd(a, i);
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      adColor,
                      adColor.withOpacity(0.78),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: AppTheme.softShadow,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: a.icon != null && a.icon!.isNotEmpty
                          ? AppIcon(a.icon, size: 21, color: Colors.white)
                          : const Icon(LucideIcons.megaphone,
                              size: 21, color: Colors.white),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        a.text,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.45,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.items.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.items.length, (i) {
                  final active = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

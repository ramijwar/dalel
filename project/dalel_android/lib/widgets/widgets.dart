import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/theme.dart';
import '../config/icons.dart';
import '../models/models.dart';

/// ══════════════════════════════════════════════════════════════
/// ودجات مشتركة
/// ══════════════════════════════════════════════════════════════

// ═══════════════ نقطة الحالة ═══════════════
class StatusDot extends StatelessWidget {
  final String? status;
  final bool onDuty;
  final double size;

  const StatusDot({super.key, this.status, this.onDuty = false, this.size = 9});

  @override
  Widget build(BuildContext context) {
    final c = onDuty
        ? AppTheme.duty
        : status == 'open'
            ? AppTheme.open
            : AppTheme.closed;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: c.withOpacity(0.4), blurRadius: 4, spreadRadius: 0.5),
        ],
      ),
    );
  }
}

// ═══════════════ شارة الحالة ═══════════════
class StatusBadge extends StatelessWidget {
  final Service service;
  final bool compact;

  const StatusBadge({super.key, required this.service, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = service.onDuty
        ? AppTheme.duty
        : service.isOpen
            ? AppTheme.open
            : AppTheme.closed;
    final bg = service.onDuty
        ? AppTheme.dutyBg
        : service.isOpen
            ? AppTheme.openBg
            : AppTheme.closedBg;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 5 : 6.5,
            height: compact ? 5 : 6.5,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 3 : 5),
          Flexible(
            child: Text(
              service.displayStatus,
              style: TextStyle(
                fontSize: compact ? 9.5 : 11,
                fontWeight: FontWeight.w700,
                color: c,
                height: 1.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════ بطاقة القسم (الصفحة الرئيسية) ═══════════════
class CategoryCard extends StatelessWidget {
  final Category category;
  final int count;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: AppIcon(category.icon, size: 23, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      category.singular.isNotEmpty ? category.singular : 'خدمة',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════ بطاقة التجميع (المستوى الأول) ═══════════════
class GroupCard extends StatelessWidget {
  final String title;
  final int count;
  final bool selected;
  final Widget icon;
  final VoidCallback onTap;

  const GroupCard({
    super.key,
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
    this.icon =
        const Icon(LucideIcons.mapPin, size: 15, color: AppTheme.textSecondary),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected ? AppTheme.softShadow : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.25)
                      : AppTheme.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════ بطاقة الخدمة المربّعة المُصغّرة ═══════════════
/// أيقونة في الأعلى + الاسم تحتها + نقطة حالة مع نص صغير جداً
/// لون ثابت مشتق من معرّف القسم
int catColor(Service s) {
  const colors = [0xFF0EA5E9, 0xFF8B5CF6, 0xFFF59E0B, 0xFF10B981];
  return colors[s.categoryId % colors.length];
}

class MiniServiceCard extends StatelessWidget {
  final Service service;
  final bool selected;
  final VoidCallback onTap;

  const MiniServiceCard({
    super.key,
    required this.service,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Color(
      service.categoryIcon.isNotEmpty ? catColor(service) : 0xFF0EA5E9,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: selected ? accent : AppTheme.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? AppTheme.softShadow : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              // الأيقونة
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppIcon(service.categoryIcon, size: 21, color: accent),
              ),
              const SizedBox(height: 7),
              // الاسم
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 5),
              // نقطة الحالة + نص صغير جداً
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusDot(
                      status: service.status, onDuty: service.onDuty, size: 6),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      service.displayStatus,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: service.onDuty
                            ? AppTheme.duty
                            : service.isOpen
                                ? AppTheme.open
                                : AppTheme.closed,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════ بطاقة الخدمة (القائمة) ═══════════════
class ServiceListTile extends StatelessWidget {
  final Service service;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsapp;

  const ServiceListTile({
    super.key,
    required this.service,
    required this.onTap,
    this.onCall,
    this.onWhatsapp,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(catColor(service));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          AppIcon(service.categoryIcon, size: 21, color: color),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (service.isVerified) ...[
                                const SizedBox(width: 5),
                                const Icon(LucideIcons.badgeCheck,
                                    size: 15, color: AppTheme.primary),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          StatusBadge(service: service),
                        ],
                      ),
                    ),
                  ],
                ),
                if (service.statusSublabel.isNotEmpty ||
                    service.fullRegionLabel.isNotEmpty ||
                    service.address.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 9),
                ],
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (service.statusSublabel.isNotEmpty)
                      _InfoChip(
                        icon: LucideIcons.clock,
                        text: service.statusSublabel,
                      ),
                    if (service.fullRegionLabel.isNotEmpty)
                      _InfoChip(
                        icon: LucideIcons.mapPin,
                        text: service.fullRegionLabel,
                      ),
                    if (service.address.isNotEmpty)
                      _InfoChip(
                          icon: LucideIcons.navigation, text: service.address),
                  ],
                ),
                if (service.phone.isNotEmpty ||
                    service.whatsappReady.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (service.phone.isNotEmpty)
                        Expanded(
                          child: _ActionButton(
                            icon: LucideIcons.phone,
                            label: 'اتصال',
                            color: AppTheme.open,
                            onTap: onCall,
                          ),
                        ),
                      if (service.phone.isNotEmpty &&
                          service.whatsappReady.isNotEmpty)
                        const SizedBox(width: 8),
                      if (service.whatsappReady.isNotEmpty)
                        Expanded(
                          child: _ActionButton(
                            icon: LucideIcons.messageCircle,
                            label: 'واتساب',
                            color: const Color(0xFF25D366),
                            onTap: onWhatsapp,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 11.5, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════ حالات فارغة وتحميل ═══════════════
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 7),
              Text(
                subtitle!,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMuted, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        height: 96,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.border),
        ),
      ),
    );
  }
}

// ═══════════════ شريط التنبيه بعدم الاتصال ═══════════════
class OfflineBanner extends StatelessWidget {
  final DateTime? lastSync;
  final VoidCallback onRetry;

  const OfflineBanner({super.key, this.lastSync, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.wifiOff, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              lastSync == null
                  ? 'لا يوجد اتصال — لا توجد بيانات محفوظة'
                  : 'لا يوجد اتصال — عرض البيانات المحفوظة',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('إعادة المحاولة', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

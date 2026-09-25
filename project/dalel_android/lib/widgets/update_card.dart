import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../services/update_service.dart';

/// ══════════════════════════════════════════════════════════════
/// بطاقة تحديث التطبيق — تُعرض في تبويب «حسابي»
/// لا تظهر إطلاقاً إن لم يكن هناك إصدار أحدث منشور على الخادم.
///
///  ١. تنبيه: «يتوفر إصدار جديد 1.2.0» + ما الجديد
///  ٢. عند الضغط على «تحديث الآن»: شريط نسبة + سرعة + المتبقّي
///  ٣. عند الاكتمال: زر «تثبيت» يفتح مثبّت أندرويد
/// ══════════════════════════════════════════════════════════════
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = UpdateService.instance;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        if (!s.hasUpdate) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _body(context, s),
        );
      },
    );
  }

  Widget _body(BuildContext context, UpdateService s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: s.isForced ? AppTheme.danger.withOpacity(0.45) : AppTheme.primary,
          width: s.isForced ? 1.4 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (s.isForced ? AppTheme.danger : AppTheme.primary)
                .withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _head(s),
          if (s.update!.hasNotes && !s.isDownloading) ...[
            const SizedBox(height: 10),
            _notes(s.update!),
          ],
          if (s.error != null) ...[
            const SizedBox(height: 10),
            _errorBox(s.error!),
          ],
          const SizedBox(height: 12),
          if (s.isDownloading) _progress(s) else _actions(context, s),
        ],
      ),
    );
  }

  // ─── الترويسة ───
  Widget _head(UpdateService s) {
    final u = s.update!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (s.isForced ? AppTheme.danger : AppTheme.primary)
                .withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            s.isDownloaded ? LucideIcons.checkCircle : LucideIcons.arrowDown,
            size: 21,
            color: s.isForced ? AppTheme.danger : AppTheme.primary,
          ),
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
                      s.isDownloaded
                          ? 'التحديث جاهز للتثبيت'
                          : 'يتوفر إصدار جديد ${u.versionName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (s.isForced) _badge('إلزامي', AppTheme.danger, AppTheme.closedBg),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                [
                  if (u.size > 0) u.sizeLabel,
                  if (u.versionCode > 0) 'بناء ${u.versionCode}',
                  if (u.publishedLabel.isNotEmpty) u.publishedLabel,
                ].join(' · '),
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
        ),
      );

  // ─── ما الجديد ───
  Widget _notes(AppUpdate u) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ما الجديد',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          ...u.noteLines.take(8).map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5, left: 6),
                        child: Icon(LucideIcons.check, size: 11, color: AppTheme.open),
                      ),
                      Expanded(
                        child: Text(
                          l,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.closedBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, size: 15, color: AppTheme.danger),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontSize: 11.5, color: AppTheme.danger, height: 1.4),
              ),
            ),
          ],
        ),
      );

  // ─── شريط التنزيل: النسبة + السرعة + المتبقّي ───
  Widget _progress(UpdateService s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 9,
                  color: AppTheme.border,
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: s.progress.clamp(0.02, 1.0),
                    child: Container(color: AppTheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 42,
              child: Text(
                '${s.percent}%',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(LucideIcons.download, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(
              s.speedLabel,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                s.receivedLabel,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (s.etaLabel.isNotEmpty)
              Text(
                s.etaLabel,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: s.cancelDownload,
            icon: const Icon(LucideIcons.x, size: 15),
            label: const Text('إلغاء'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.borderStrong),
              padding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
        ),
      ],
    );
  }

  // ─── الأزرار ───
  Widget _actions(BuildContext context, UpdateService s) {
    // ١) جاهز للتثبيت
    if (s.isDownloaded) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: s.install,
              icon: const Icon(LucideIcons.checkCircle, size: 17),
              label: const Text('تثبيت التحديث'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.open,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: s.download,
              child: const Text('إعادة التنزيل', style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      );
    }

    // ٢) فشل — أعد المحاولة
    if (s.phase == UpdatePhase.failed) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: s.retry,
          icon: const Icon(LucideIcons.refreshCw, size: 16),
          label: const Text('إعادة المحاولة'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    }

    // ٣) متاح — أزرار التنزيل / لاحقاً
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: s.phase == UpdatePhase.checking ? null : s.download,
            icon: const Icon(LucideIcons.download, size: 16),
            label: const Text('تحديث الآن'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        // «لاحقاً» لا تظهر في التحديث الإلزامي
        if (!s.isForced) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: s.dismiss,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.borderStrong),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            child: const Text('لاحقاً'),
          ),
        ],
      ],
    );
  }
}

/// ══════════════════════════════════════════════════════════════
/// نافذة التحديث الإلزامي — لا تُغلق حتى يُنزَّل التحديث
/// (تُستدعى من تبويب «حسابي» عند وجود تحديث إلزامي)
/// ══════════════════════════════════════════════════════════════
class ForceUpdateDialog extends StatelessWidget {
  const ForceUpdateDialog({super.key});

  /// يعرض النافذة إن كان التحديث المنشور إلزامياً
  static Future<void> maybeShow(BuildContext context) async {
    final s = UpdateService.instance;
    if (!s.hasUpdate || !s.isForced) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ForceUpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = UpdateService.instance;
    return PopScope(
      canPop: false, // لا رجوع للخلف
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.shieldAlert, size: 20, color: AppTheme.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تحديث إلزامي',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: AnimatedBuilder(
            animation: s,
            builder: (context, _) {
              final u = s.update;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'يجب تحديث التطبيق إلى الإصدار ${u?.versionName ?? ''} للمتابعة.',
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  if (u != null && u.hasNotes) ...[
                    const SizedBox(height: 10),
                    ...u.noteLines.take(5).map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $l',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 14),
                  if (s.isDownloading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 9,
                        color: AppTheme.border,
                        child: FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: s.progress.clamp(0.02, 1.0),
                          child: Container(color: AppTheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${s.percent}% · ${s.speedLabel} · ${s.receivedLabel}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ] else if (s.isDownloaded)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: s.install,
                        icon: const Icon(LucideIcons.checkCircle, size: 17),
                        label: const Text('تثبيت التحديث'),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.open),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: s.download,
                        icon: const Icon(LucideIcons.download, size: 16),
                        label: const Text('تحديث الآن'),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                      ),
                    ),
                  if (s.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      s.error!,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.danger),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

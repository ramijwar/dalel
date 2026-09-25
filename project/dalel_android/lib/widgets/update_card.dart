import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../services/update_service.dart';

/// ══════════════════════════════════════════════════════════════
/// شريط تحديث التطبيق — يُعرض في تبويب «حسابي»
///
/// لا يظهر إطلاقاً إن لم يكن هناك إصدار أحدث منشور على الخادم.
///
/// **شريط لا بطاقة**: صفٌّ واحد بارتفاع ثابت (~٦٤ نقطة):
///   [ أيقونة ] اسم الإصدار وسطر التفاصيل        [ زر الإجراء ] [ ✕ ]
///
/// كان سابقاً بطاقة رأسية كبيرة (ترويسة + صندوق «ما الجديد» بثمانية
/// أسطر + زرّان بعرض الشاشة) فتشغل نصف الشاشة وتدفع زر التنزيل إلى ما
/// تحت مجال الرؤية — وهو ما جعل الزر يبدو «غير موجود».
///
/// الإجراء يتغيّر مع الحالة في مكانه (بلا قفز في التخطيط):
///   متاح       → «تنزيل»
///   يُنزَّل     → «٪» + إلغاء، وشريط تقدّم رقيق أسفل الشريط
///   مُنزَّل     → «تثبيت» (أخضر)
///   فشل        → «إعادة»
/// و«ما الجديد» انتقل إلى ورقة سفلية تُفتح من زر ⓘ — فبقي الشريط قصيراً
/// مهما طالت ملاحظات الإصدار.
/// ══════════════════════════════════════════════════════════════
class UpdateCard extends StatelessWidget {
  /// تُمرَّر في الاختبارات؛ وفي التطبيق تُستخدم الخدمة المفردة.
  final UpdateService? service;

  const UpdateCard({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    final s = service ?? UpdateService.instance;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        if (!s.hasUpdate) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _bar(context, s),
        );
      },
    );
  }

  // ═══════════════ الشريط ═══════════════
  Widget _bar(BuildContext context, UpdateService s) {
    final accent = s.isForced ? AppTheme.danger : AppTheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: s.isDownloaded ? s.install : null,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: s.isForced ? accent.withOpacity(0.5) : AppTheme.border,
              width: s.isForced ? 1.3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
                child: Row(
                  children: [
                    _leadingIcon(s, accent),
                    const SizedBox(width: 10),
                    Expanded(child: _texts(s, accent)),
                    const SizedBox(width: 8),
                    _action(s, accent),
                    // «ما الجديد» متاح في كل المراحل — قبل التنزيل أيضاً
                    if (s.update!.hasNotes && !s.isDownloading)
                      _iconTap(
                        icon: LucideIcons.info,
                        tooltip: 'تفاصيل التحديث',
                        color: AppTheme.textMuted,
                        onTap: () => _showDetails(context, s),
                      ),
                    if (!s.isForced && !s.isDownloading)
                      _iconTap(
                        icon: LucideIcons.x,
                        tooltip: 'لاحقاً',
                        color: AppTheme.textMuted,
                        onTap: s.dismiss,
                      ),
                  ],
                ),
              ),
              // شريط تقدّم رقيق في حاشية الشريط أثناء التنزيل
              if (s.isDownloading)
                SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: s.progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leadingIcon(UpdateService s, Color accent) {
    final icon = s.isDownloaded
        ? LucideIcons.checkCircle
        : s.phase == UpdatePhase.failed
            ? LucideIcons.alertTriangle
            : s.isDownloading
                ? LucideIcons.download
                : LucideIcons.arrowDown;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 20, color: accent),
    );
  }

  /// سطران: العنوان وتفاصيله — يُقتطعان بـ«…» فلا يطول الشريط أبداً.
  Widget _texts(UpdateService s, Color accent) {
    final u = s.update!;
    final title = s.isDownloaded
        ? 'التحديث جاهز للتثبيت'
        : s.isDownloading
            ? 'يُنزَّل التحديث ${s.percent}%'
            : s.phase == UpdatePhase.failed
                ? 'تعذّر التحديث'
                : 'يتوفر إصدار جديد ${u.versionName}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
            if (s.isForced) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.closedBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'إلزامي',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.danger,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _subtitle(s),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.2,
            color: s.phase == UpdatePhase.failed
                ? AppTheme.danger
                : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  /// السطر الثاني: تفاصيل الإصدار، ويتحول أثناء التنزيل إلى السرعة والمتبقّي.
  String _subtitle(UpdateService s) {
    final u = s.update!;
    if (s.isDownloading) {
      return [
        s.speedLabel,
        s.receivedLabel,
        if (s.etaLabel.isNotEmpty) s.etaLabel,
      ].where((x) => x.isNotEmpty).join(' · ');
    }
    if (s.phase == UpdatePhase.failed && (s.error?.isNotEmpty ?? false)) {
      return '${s.error!} — اضغط «إعادة»';
    }
    return [
      if (u.size > 0) u.sizeLabel,
      if (u.versionCode > 0) 'بناء ${u.versionCode}',
      if (u.publishedLabel.isNotEmpty) u.publishedLabel,
    ].join(' · ');
  }

  // ═══════════════ زر الإجراء ═══════════════
  Widget _action(UpdateService s, Color accent) {
    // ١) التنزيل جارٍ — الزر يصير «إلغاء»
    if (s.isDownloading) {
      return _compactButton(
        label: 'إلغاء',
        icon: LucideIcons.x,
        background: AppTheme.background,
        foreground: AppTheme.textSecondary,
        border: AppTheme.borderStrong,
        onTap: s.cancelDownload,
      );
    }

    // ٢) مُنزَّل — التثبيت
    if (s.isDownloaded) {
      return _compactButton(
        label: 'تثبيت',
        icon: LucideIcons.checkCircle,
        background: AppTheme.open,
        foreground: Colors.white,
        onTap: s.install,
      );
    }

    // ٣) فشل — إعادة المحاولة
    if (s.phase == UpdatePhase.failed) {
      return _compactButton(
        label: 'إعادة',
        icon: LucideIcons.refreshCw,
        background: AppTheme.primary,
        foreground: Colors.white,
        onTap: s.retry,
      );
    }

    // ٤) متاح — زر التنزيل، وهو الإجراء الأساسي
    return _compactButton(
      label: 'تنزيل',
      icon: LucideIcons.download,
      background: accent,
      foreground: Colors.white,
      // أثناء الفحص فقط يكون معطّلاً؛ وبقية الحالات قابل للضغط
      onTap: s.phase == UpdatePhase.checking ? null : s.download,
    );
  }

  /// زر مدمج بارتفاع ثابت ٣٤ — لا يزيد ارتفاع الشريط مهما كان نصّه.
  Widget _compactButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback? onTap,
    Color? border,
  }) {
    return SizedBox(
      height: 34,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withOpacity(0.4),
          disabledForegroundColor: Colors.white,
          side: border == null ? BorderSide.none : BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
      ),
    );
  }

  Widget _iconTap({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  // ═══════════════ ورقة التفاصيل («ما الجديد») ═══════════════
  void _showDetails(BuildContext context, UpdateService s) {
    final u = s.update!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => AnimatedBuilder(
        animation: s,
        builder: (ctx, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إصدار ${u.versionName}'
                  '${u.versionCode > 0 ? ' (بناء ${u.versionCode})' : ''}',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (u.size > 0) u.sizeLabel,
                    if (u.publishedLabel.isNotEmpty) u.publishedLabel,
                    if (s.isDownloaded) 'مُحمَّل على الجهاز',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
                if (u.hasNotes) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'ما الجديد',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: u.noteLines
                            .map(
                              (l) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4, left: 7),
                                      child: Icon(LucideIcons.check,
                                          size: 12, color: AppTheme.open),
                                    ),
                                    Expanded(
                                      child: Text(
                                        l,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          height: 1.5,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
                if (s.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.closedBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      s.error!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.danger, height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (s.isDownloaded) {
                        s.install();
                      } else if (s.isDownloading) {
                        s.cancelDownload();
                      } else {
                        s.download();
                      }
                    },
                    icon: Icon(
                      s.isDownloaded
                          ? LucideIcons.checkCircle
                          : s.isDownloading
                              ? LucideIcons.x
                              : LucideIcons.download,
                      size: 17,
                    ),
                    label: Text(
                      s.isDownloaded
                          ? 'تثبيت التحديث'
                          : s.isDownloading
                              ? 'إلغاء التنزيل'
                              : 'تنزيل التحديث',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          s.isDownloaded ? AppTheme.open : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                      child: LinearProgressIndicator(
                        value: s.progress.clamp(0.0, 1.0),
                        minHeight: 9,
                        backgroundColor: AppTheme.border,
                        valueColor:
                            const AlwaysStoppedAnimation(AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${s.percent}% · ${s.speedLabel} · ${s.receivedLabel}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textMuted),
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

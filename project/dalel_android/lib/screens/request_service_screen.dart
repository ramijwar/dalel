import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme.dart';
import '../config/icons.dart';
import '../widgets/dynamic_fields.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// ══════════════════════════════════════════════════════════════
/// شاشة طلب إضافة خدمة
/// المحافظة إلزامية — اختيار قرية يعبّئ المدينة والمحافظة تلقائياً
/// ══════════════════════════════════════════════════════════════
class RequestServiceScreen extends StatefulWidget {
  /// القسم المبدئي — يُمرَّر عند الدخول من شاشة قسم أو تفاصيل خدمة
  final Category? initialCategory;

  const RequestServiceScreen({super.key, this.initialCategory});

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  final _api = ApiService.instance;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();

  int? _categoryId;
  int? _governorateId;
  int? _regionId;

  /// «أريد التحكم في خدمتي وتحديث حالتها من حسابي» — للمسجّلين فقط
  bool _wantManage = false;

  /// قيم الحقول الخاصة بالقسم المختار
  final Map<String, dynamic> _fieldValues = {};

  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // عبّئ القسم تلقائياً إن دخلنا من شاشة قسم
    if (widget.initialCategory != null) {
      _categoryId = widget.initialCategory!.id;
    }
  }

  /// حقول القسم المختار حالياً
  List<CategoryField> _fieldsFor(AppProvider app) {
    if (_categoryId == null) return const [];
    final cat = app.categories.where((c) => c.id == _categoryId).toList();
    if (cat.isEmpty) return const [];
    return cat.first.fields;
  }

  /// عند تغيير القسم: أفرغ قيم الحقول التي لا تنتمي له
  void _pruneFields(List<CategoryField> fields) {
    final valid = fields.map((f) => f.key).toSet();
    _fieldValues.removeWhere((k, _) => !valid.contains(k));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();

    // مناطق المحافظة المختارة
    final regions = _governorateId == null
        ? app.regions
        : app.regions.where((r) => r.governorateId == _governorateId).toList();

    // المدن (القرى تتبع مدينة)
    final cities = regions.where((r) => r.parentId == null).toList();
    final villages = regions.where((r) => r.parentId != null).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('أضف خدمة للدليل'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowRight),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── خيار التحكم: للمسجّلين فقط ───
            _buildManageOption(auth),

            const SizedBox(height: 4),

            // ─── نوع الخدمة ───
            _Section(
              icon: LucideIcons.tags,
              title: 'نوع الخدمة',
              child: app.categories.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('لا توجد أقسام — اسحب للتحديث',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textMuted)),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: app.categories.map((c) {
                        final sel = _categoryId == c.id;
                        return _PickChip(
                          label: c.name,
                          icon: AppIcon(c.icon,
                              size: 14,
                              color: sel ? Colors.white : Color(c.colorValue)),
                          selected: sel,
                          onTap: () => setState(() {
                            _categoryId = c.id;
                            // الحقول تتغيّر مع القسم — أفرغ القيم الغريبة
                            _pruneFields(c.fields);
                          }),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 14),

            // ─── الموقع (محافظة ← مدينة ← قرية) ───
            _Section(
              icon: LucideIcons.mapPin,
              title: 'الموقع',
              subtitle: 'المحافظة مطلوبة',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // المحافظة
                  _Dropdown<int>(
                    label: 'المحافظة *',
                    value: _governorateId,
                    items: app.governorates
                        .map((g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(g.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _governorateId = v;
                      _regionId = null;
                    }),
                    prefixIcon: LucideIcons.map,
                  ),

                  const SizedBox(height: 12),

                  // المدينة
                  _Dropdown<int>(
                    label: 'المدينة',
                    value: _regionId != null &&
                            cities.any((c) => c.id == _regionId)
                        ? _regionId
                        : null,
                    items: cities
                        .map((r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(r.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _regionId = v),
                    prefixIcon: LucideIcons.building,
                    enabled: _governorateId != null,
                  ),

                  if (villages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    // القرية — اختيارها يعبّئ المدينة تلقائياً
                    _Dropdown<int>(
                      label: 'القرية (اختياري)',
                      value: _regionId != null &&
                              villages.any((c) => c.id == _regionId)
                          ? _regionId
                          : null,
                      items: villages
                          .map((r) => DropdownMenuItem(
                                value: r.id,
                                child: Text(r.name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _regionId = v;
                          // اختيار القرية يعبّئ مدينتها تلقائياً
                          if (v != null) {
                            final village = villages.firstWhere(
                              (e) => e.id == v,
                              orElse: () => villages.first,
                            );
                            if (village.parentId != null) {
                              // المنطقة المختارة هي القرية نفسها
                              _regionId = village.id;
                            }
                          }
                        });
                      },
                      prefixIcon: LucideIcons.home,
                      enabled: _governorateId != null,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'اختيار القرية يعبّئ المدينة والمحافظة تلقائياً',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ─── بيانات الخدمة ───
            _Section(
              icon: LucideIcons.fileText,
              title: 'بيانات الخدمة',
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'اسم الخدمة *',
                      hintText: 'مثال: صيدلية الشفاء',
                      prefixIcon: Icon(LucideIcons.store, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: '09XXXXXXXX',
                      prefixIcon: Icon(LucideIcons.phone, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      hintText: 'الشارع والمنطقة',
                      prefixIcon: Icon(LucideIcons.navigation, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      hintText: 'أي تفاصيل إضافية',
                      prefixIcon: Icon(LucideIcons.pencil, size: 18),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),

            // ─── الحقول الخاصة بالقسم المختار ───
            if (_fieldsFor(app).isNotEmpty) ...[
              const SizedBox(height: 14),
              _Section(
                icon: LucideIcons.listChecks,
                title: 'بيانات إضافية',
                child: DynamicFields(
                  fields: _fieldsFor(app),
                  values: _fieldValues,
                  onChanged: (k, v) => setState(() => _fieldValues[k] = v),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppTheme.closedBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.closed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertCircle,
                        size: 16, color: AppTheme.closed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.closed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.send, size: 18),
              label: Text(_sending ? 'جاري الإرسال…' : 'إرسال الطلب'),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// ══════════════════════════════════════════════════════════
  /// خيار «أريد التحكم في خدمتي وتحديث حالتها من حسابي»
  /// يظهر للمستخدم المسجّل فقط — الزائر لا يراه إطلاقاً
  /// ══════════════════════════════════════════════════════════
  Widget _buildManageOption(AuthProvider auth) {
    // ─── زائر: لا خيار تحكم، بل تنبيه بسيط ───
    if (!auth.isLoggedIn) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.info, size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'ستُراجَع خدمتك من الإدارة ثم تُنشر في الدليل. '
                'سجّل الدخول إن أردت التحكّم بحالتها لاحقاً.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ─── مسجّل: خيار التحكم ───
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: _wantManage ? AppTheme.primary : AppTheme.border,
          width: _wantManage ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _wantManage = !_wantManage),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _wantManage
                        ? AppTheme.primary
                        : AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.settings2,
                    size: 17,
                    color: _wantManage ? Colors.white : AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أريد التحكم في خدمتي وتحديث حالتها من حسابي',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'ستظهر الخدمة في «خدماتي» لتتمكن من تبديل حالتها وأوقات دوامها',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _wantManage,
                  onChanged: (v) => setState(() => _wantManage = v),
                  activeTrackColor: AppTheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'اسم الخدمة مطلوب');
      return;
    }
    if (_categoryId == null) {
      setState(() => _error = 'اختر نوع الخدمة');
      return;
    }
    if (_governorateId == null) {
      setState(() => _error = 'يجب اختيار المحافظة');
      return;
    }

    final phone = _phone.text.trim();
    if (phone.isNotEmpty && !RegExp(r'^0\d{8,9}$').hasMatch(phone)) {
      setState(() => _error = 'رقم الهاتف غير صالح');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _api.createRequest(
        name: name,
        categoryId: _categoryId!,
        governorateId: _governorateId,
        regionId: _regionId,
        address: _address.text.trim(),
        phone: phone,
        note: _note.text.trim(),
        // المسجّل فقط يمكنه طلب ربط الخدمة بحسابه للتحكّم بها
        wantManage: _wantManage,
        // الحقول الخاصة بالقسم (مثل الاختصاص للأطباء)
        fields: _fieldValues,
      );

      if (!mounted) return;
      setState(() => _sending = false);

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.openBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.checkCircle,
                size: 28, color: AppTheme.open),
          ),
          title: const Text('تم إرسال الطلب'),
          content: const Text(
            'سيُراجع الطلب من قِبَل الإدارة وستُضاف الخدمة للدليل بعد الموافقة.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(minimumSize: Size.zero),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is ApiException ? e.message : 'تعذّر إرسال الطلب';
      });
    }
  }
}

// ═══════════════ ودجات مساعدة ═══════════════
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: AppTheme.primary),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 7),
                Text(
                  subtitle!,
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  const _PickChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData prefixIcon;
  final bool enabled;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.prefixIcon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(prefixIcon, size: 18),
        filled: enabled,
        fillColor: enabled ? AppTheme.surface : AppTheme.background,
      ),
      borderRadius: BorderRadius.circular(AppTheme.radius),
      icon: const Icon(LucideIcons.chevronDown, size: 18),
      style: const TextStyle(
        fontSize: 13.5,
        color: AppTheme.textPrimary,
      ),
      dropdownColor: AppTheme.surface,
    );
  }
}

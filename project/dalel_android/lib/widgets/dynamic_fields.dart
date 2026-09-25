import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/models.dart';
import '../config/theme.dart';

/* ══════════════════════════════════════════════════════════════
 *  الحقول الديناميكية — تُرسم حسب تعريفات القسم
 *  نفس المنطق المستخدم في الويب:
 *    • قائمة اختيار → منتقي قابل للبحث يعرض الأيقونة + النص
 *    • نص / نص طويل / رقم / نعم-لا → حقول إدخال عادية
 * ══════════════════════════════════════════════════════════════ */

/// يحوّل اسم أيقونة Lucide إلى أيقونة Flutter
/// (يستخدم أسماء الحزم القديمة المتوافقة مع lucide_icons 0.257)
class _FieldIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const _FieldIcon(this.name, {this.size = 16, this.color});

  static const Map<String, IconData> _map = {
    'check': LucideIcons.check,
    'x': LucideIcons.x,
    'hash': LucideIcons.hash,
    'type': LucideIcons.type,
    'stethoscope': LucideIcons.stethoscope,
    'pill': LucideIcons.pill,
    'fuel': LucideIcons.fuel,
    'bus': LucideIcons.bus,
    'car': LucideIcons.car,
    'truck': LucideIcons.truck,
    'heart': LucideIcons.heart,
    'brain': LucideIcons.brain,
    'bone': LucideIcons.bone,
    'eye': LucideIcons.eye,
    'ear': LucideIcons.ear,
    'baby': LucideIcons.baby,
    'dumbbell': LucideIcons.dumbbell,
    'activity': LucideIcons.activity,
    'circle-dot': LucideIcons.circleDot,
    'list': LucideIcons.list,
    'tag': LucideIcons.tag,
    'info': LucideIcons.info,
    'star': LucideIcons.star,
    'clock': LucideIcons.clock,
    'map-pin': LucideIcons.mapPin,
    'store': LucideIcons.store,
    'shopping-bag': LucideIcons.shoppingBag,
    'utensils': LucideIcons.utensils,
    'coffee': LucideIcons.coffee,
    'home': LucideIcons.home,
    'building': LucideIcons.building,
    'users': LucideIcons.users,
    'user': LucideIcons.user,
    'phone': LucideIcons.phone,
    'calendar': LucideIcons.calendar,
    'zap': LucideIcons.zap,
    'droplet': LucideIcons.droplet,
    'sparkles': LucideIcons.sparkles,
    'crown': LucideIcons.crown,
    'gift': LucideIcons.gift,
    'megaphone': LucideIcons.megaphone,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _map[name] ?? LucideIcons.circleDot;
    return Icon(icon, size: size, color: color);
  }
}

/* ══════════════════════════════════════════════════════════════
 *  منتقي خيار قابل للبحث
 * ══════════════════════════════════════════════════════════════ */

class OptionPicker extends StatefulWidget {
  final List<FieldOption> options;
  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final String fallbackIcon;

  const OptionPicker({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.placeholder = 'ابحث واختر…',
    this.fallbackIcon = 'circle-dot',
  });

  @override
  State<OptionPicker> createState() => _OptionPickerState();
}

class _OptionPickerState extends State<OptionPicker> {
  final _search = TextEditingController();

  FieldOption? get _selected {
    for (final o in widget.options) {
      if (o.value == widget.value || o.id.toString() == widget.value) return o;
    }
    return null;
  }

  Future<void> _open() async {
    final picked = await showModalBottomSheet<FieldOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OptionSheet(
        options: widget.options,
        current: widget.value,
        title: widget.placeholder,
        fallbackIcon: widget.fallbackIcon,
      ),
    );
    if (picked != null) {
      widget.onChanged(picked.value.isNotEmpty ? picked.value : picked.id.toString());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              _FieldIcon(sel?.icon ?? widget.fallbackIcon,
                  size: 17, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sel?.label ?? widget.placeholder,
                  style: TextStyle(
                    fontSize: 14,
                    color: sel != null ? AppTheme.textPrimary : AppTheme.textMuted,
                    fontWeight: sel != null ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronDown,
                  size: 16, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// نافذة البحث والاختيار
class _OptionSheet extends StatefulWidget {
  final List<FieldOption> options;
  final String current;
  final String title;
  final String fallbackIcon;

  const _OptionSheet({
    required this.options,
    required this.current,
    required this.title,
    required this.fallbackIcon,
  });

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  final _ctrl = TextEditingController();
  String _q = '';

  List<FieldOption> get _filtered {
    if (_q.trim().isEmpty) return widget.options;
    final n = _q.trim().toLowerCase();
    return widget.options
        .where((o) => o.label.toLowerCase().contains(n))
        .toList();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: false,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'بحث سريع…',
                  prefixIcon:
                      const Icon(LucideIcons.search, size: 18, color: AppTheme.textMuted),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _q = '');
                          },
                        ),
                ),
              ),
            ),
            Flexible(
              child: list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text('لا توجد نتائج مطابقة',
                          style: TextStyle(color: AppTheme.textMuted)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (_, i) {
                        final o = list[i];
                        final isSel = o.value == widget.current ||
                            o.id.toString() == widget.current;
                        return ListTile(
                          leading: _FieldIcon(o.icon.isEmpty ? widget.fallbackIcon : o.icon,
                              size: 18,
                              color: isSel ? AppTheme.primary : AppTheme.textMuted),
                          title: Text(
                            o.label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight:
                                  isSel ? FontWeight.w800 : FontWeight.w500,
                              color: isSel ? AppTheme.primary : AppTheme.textPrimary,
                            ),
                          ),
                          trailing: isSel
                              ? const Icon(LucideIcons.check,
                                  size: 17, color: AppTheme.primary)
                              : null,
                          onTap: () => Navigator.pop(context, o),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/* ══════════════════════════════════════════════════════════════
 *  مولّد الحقول الديناميكية
 * ══════════════════════════════════════════════════════════════ */

class DynamicFields extends StatelessWidget {
  final List<CategoryField> fields;
  final Map<String, dynamic> values;
  final void Function(String key, dynamic value) onChanged;

  const DynamicFields({
    super.key,
    required this.fields,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: fields.map((f) => _buildField(f)).toList(),
    );
  }

  Widget _buildField(CategoryField f) {
    final val = values[f.key];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                f.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (f.required)
                const Text(' *',
                    style: TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 7),

          // ─── قائمة اختيار ───
          if (f.isSelect)
            OptionPicker(
              options: f.options,
              value: val?.toString() ?? '',
              onChanged: (v) => onChanged(f.key, v),
              placeholder: f.placeholder.isNotEmpty
                  ? f.placeholder
                  : 'اختر ${f.label}…',
            ),

          // ─── نعم / لا ───
          if (f.isBoolean)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppTheme.border),
              ),
              child: SwitchListTile(
                value: val == true || val == '1' || val == 1,
                onChanged: (v) => onChanged(f.key, v),
                title: Text(
                  f.placeholder.isNotEmpty ? f.placeholder : 'نعم',
                  style: const TextStyle(fontSize: 14),
                ),
                activeTrackColor: AppTheme.primary,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
              ),
            ),

          // ─── نص طويل ───
          if (f.isTextarea)
            TextFormField(
              initialValue: val?.toString() ?? '',
              maxLines: 3,
              decoration: InputDecoration(hintText: f.placeholder),
              onChanged: (v) => onChanged(f.key, v),
            ),

          // ─── رقم ───
          if (f.isNumber)
            TextFormField(
              initialValue: val?.toString() ?? '',
              keyboardType: TextInputType.number,
              // الوحدة تظهر داخل الحقل (ل.س) فيعرف المستخدم المطلوب بلا شرح
              decoration: InputDecoration(
                hintText: f.placeholder,
                suffixText: f.suffix.isEmpty ? null : f.suffix,
              ),
              onChanged: (v) => onChanged(f.key, v),
            ),

          // ─── نص قصير ───
          if (!f.isSelect && !f.isBoolean && !f.isTextarea && !f.isNumber)
            TextFormField(
              initialValue: val?.toString() ?? '',
              decoration: InputDecoration(hintText: f.placeholder),
              onChanged: (v) => onChanged(f.key, v),
            ),

          if (f.help.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              f.help,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/* ══════════════════════════════════════════════════════════════
 *  عرض قيم الحقول المحلولة (تفاصيل الخدمة)
 * ══════════════════════════════════════════════════════════════ */

class ResolvedFieldList extends StatelessWidget {
  final List<ResolvedField> fields;

  const ResolvedFieldList({super.key, required this.fields});

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();

    return Column(
      children: fields
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldIcon(f.icon.isEmpty ? 'circle-dot' : f.icon,
                        size: 16, color: AppTheme.primary),
                    const SizedBox(width: 9),
                    Text(
                      '${f.label}: ',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        f.display,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

/// شرائح صغيرة لعرض الحقول داخل البطاقة
class ResolvedFieldChips extends StatelessWidget {
  final List<ResolvedField> fields;
  final int? limit;

  const ResolvedFieldChips({super.key, required this.fields, this.limit});

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();
    final shown = limit == null ? fields : fields.take(limit!).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: shown
          .map((f) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (f.icon.isNotEmpty)
                      _FieldIcon(f.icon, size: 12, color: AppTheme.primary),
                    if (f.icon.isNotEmpty) const SizedBox(width: 4),
                    Text(
                      f.display,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

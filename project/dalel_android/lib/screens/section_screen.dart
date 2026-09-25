import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../config/constants.dart';
import '../config/icons.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/widgets.dart';
import 'service_detail_screen.dart';
import 'request_service_screen.dart';

/// ══════════════════════════════════════════════════════════════
/// شاشة القسم — تنقّل على مستويين
///   المستوى ١: بطاقات التجميع (منطقة / اختصاص / نوع مركبة)
///   المستوى ٢: خدمات المجموعة المختارة فقط
/// ══════════════════════════════════════════════════════════════
class SectionScreen extends StatefulWidget {
  final Category category;

  const SectionScreen({super.key, required this.category});

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
  final cfg = SectionConfig.all;

  // ─── الفلاتر ───
  int? _govId;
  int? _regionId;
  int? _specialtyId;
  /// نطاق المنطقة: 'city' (مدينة) | 'rural' (ريف) | null (الكل)
  String? _zone;
  String _status = 'all';
  String _search = '';
  String? _groupKey;

  /// قيم الفلاتر الثانوية المُسنَدة للقسم — مفتاح الفلتر ← القيمة المختارة
  final Map<String, String> _secState = {};

  /// 'card' | 'list'
  late String _layout;

  // ─── البيانات ───
  List<Service> _all = [];
  List<Service> _visible = [];
  Service? _picked;
  bool _loading = true;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();

  /// القسم من **مزوّد البيانات** لا من الصورة التي وصلت مع الشاشة.
  ///
  /// المزوّد يعيد جلب `/api/meta` (بالفلاتر) عند التشغيل، فلو بقي القسم
  /// صورةً جامدة لما ظهر تغيير المدير للفلاتر حتى يُغلق المستخدم التطبيق.
  /// عند البناء تُقرأ أحدث نسخة، وغيابها (اختبارات) يرجع إلى `widget.category`.
  Category get _cat {
    try {
      return context.read<AppProvider>().categoryBySlug(widget.category.slug) ??
          widget.category;
    } catch (_) {
      return widget.category;
    }
  }

  SectionConfig get _info => SectionConfig.of(_cat.slug);

  /// ═══════════════ الفلاتر المُسنَدة من لوحة التحكم ═══════════════
  /// المدير يُنشئ فلاتر في المكتبة (المناطق · الاختصاص · نوع المركبة …)
  /// ثم يُسنِد لكل قسم فلتره الأساسي — وهو الذي يبني بطاقات المستوى الأول.
  /// `null` تعني خادماً قديماً أو قسماً بلا فلاتر، فيُستخدم التجميع
  /// الاحتياطي المضمّن في التطبيق (SectionConfig) بلا أي تراجع.
  CategoryFilterLink? get _primaryFilter => _cat.primaryFilter;
  List<CategoryFilterLink> get _secondaryFilters => _cat.secondaryFilters;

  /// هل التجميع الأساسي على المناطق؟ (يُغيّر صياغة العنوان ورأس النتائج)
  bool get _groupIsRegion {
    final f = _primaryFilter;
    if (f != null) return f.sourceType == 'region';
    return _info.groupBy != 'specialty' && _info.groupBy != 'meta';
  }

  /// قيمة الخدمة في فلتر مُعطى — أساس التجميع والتطابق.
  /// تعمل بالمنطقة أو الاختصاص أو أي حقل من حقول القسم (يقرأها من `meta`
  /// كما يفعل الخادم، وتقع على `fields` المحلولة إن لم تكن في meta).
  String _valueOf(Service s, CategoryFilterLink f) {
    switch (f.sourceType) {
      case 'specialty':
        return s.specialtyId == null ? '' : '${s.specialtyId}';
      case 'field':
        final v = (s.meta[f.sourceKey] ?? '').toString().trim();
        if (v.isNotEmpty) return v;
        for (final rf in s.fields) {
          if (rf.key == f.sourceKey) return rf.value.trim();
        }
        return '';
      case 'region':
      default:
        return s.regionId == null ? '' : '${s.regionId}';
    }
  }

  /// اسم اختصاص الخدمة — لا نعرض مُعرّفاً رقمياً خاماً أبداً
  String _specialtyLabel(Service s) {
    final raw = (s.meta['specialty_name'] ?? s.metaVal('specialty') ?? '')
        .toString()
        .trim();
    final resolved = _cat.fields
        .where((f) => f.key == 'specialty')
        .expand((f) => f.options)
        .where((o) => o.value == raw || o.id.toString() == raw || o.label == raw)
        .map((o) => o.label)
        .firstOrNull;
    if (resolved != null && resolved.isNotEmpty) return resolved;
    // الاختصاص غير معروف — نُعيد التسمية الافتراضية بدل رقم خام
    if (raw.isNotEmpty && !RegExp(r'^\d+$').hasMatch(raw)) return raw;
    return 'عام';
  }

  @override
  void initState() {
    super.initState();
    _layout = _info.defaultLayout;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final app = context.read<AppProvider>();

      // تحديث يدوي: أعِد جلب /api/meta أيضاً — فيظهر أي تغيير في فلاتر
      // الأقسام فوراً. لو طلبنا الخدمات فقط لبقيت الفلاتر كما كانت حتى
      // إعادة تشغيل التطبيق.
      if (force) {
        try {
          await app.sync(force: true);
        } catch (_) {
          // فشل تحديث الإعدادات لا يمنع تحديث الخدمات
        }
      }

      final list = await app.loadSection(_cat.slug, forceNetwork: force);
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// هل تجتاز الخدمة الفلاتر المُضيِّقة؟ (بلا فلتر المجموعة المختارة)
  /// منطق واحد تستخدمه القائمة وبطاقات التجميع معاً — فلا تتباعد
  /// أعداد البطاقات عن النتائج الفعلية.
  ///
  /// `ignoreSecondary`: يُستخدم عند بناء خيارات فلتر ثانوي — فلا يُطبَّق
  /// على خياراته، وإلا بقي الخيار المختار **وحده** في القائمة فلم يستطع
  /// الزائر التبديل إلى قيمة أخرى إلا بإلغاء الفلتر أولاً.
  bool _passes(Service s, {CategoryFilterLink? ignoreSecondary}) {
    if (_govId != null && s.governorateId != _govId) return false;
    if (_zone != null && s.regionZone != _zone) return false;
    if (_regionId != null && s.regionId != _regionId) return false;
    if (_specialtyId != null && s.specialtyId != _specialtyId) return false;
    if (_status == 'open' && !s.isOpen) return false;
    if (_status == 'closed' && s.isOpen) return false;
    if (_status == 'duty' && !s.onDuty) return false;
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty &&
        !s.name.toLowerCase().contains(q) &&
        !s.address.toLowerCase().contains(q)) return false;

    // الفلاتر الثانوية التي أسنَدها المدير للقسم
    for (final f in _secondaryFilters) {
      // المقارنة بالمفتاح لا بالهوية: القائمة تُبنى في كل نداء
      if (ignoreSecondary != null && f.key == ignoreSecondary.key) continue;
      final want = _secState[f.key];
      if (want == null || want.isEmpty) continue;
      if (_valueOf(s, f) != want) return false;
    }
    return true;
  }

  void _applyFilters() {
    var list = _all.where(_passes).toList();

    // فلترة المجموعة المختارة
    if (_groupKey != null) {
      list = list.where((s) => _keyOf(s) == _groupKey).toList();
    }

    setState(() => _visible = list);
  }

  /// مفتاح تجميع الخدمة — من الفلتر الأساسي المُسنَد للقسم.
  /// وإن لم يُسنَد فلتر (خادم قديم) نرجع إلى إعداد القسم المضمّن.
  String _keyOf(Service s) {
    final f = _primaryFilter;
    if (f == null) {
      switch (_info.groupBy) {
        case 'specialty':
          return s.specialtyId == null ? 'sp-none' : 'sp-${s.specialtyId}';
        case 'meta':
          final v = s.metaVal(_info.metaKey ?? 'vehicle');
          return (v == null || v.isEmpty) ? 'mt-none' : 'mt-$v';
        default:
          return s.regionId == null ? 'rg-none' : 'rg-${s.regionId}';
      }
    }
    final v = _valueOf(s, f);
    final p = f.sourceType == 'specialty'
        ? 'sp'
        : (f.sourceType == 'field' ? 'mt' : 'rg');
    return '$p-${v.isEmpty ? 'none' : v}';
  }

  /// تسمية بطاقة المجموعة — من الفلتر الأساسي المُسنَد للقسم
  String _labelOf(Service s) {
    final f = _primaryFilter;
    if (f == null) {
      switch (_info.groupBy) {
        case 'specialty':
          return _specialtyLabel(s);
        case 'meta':
          return s.metaVal(_info.metaKey ?? 'vehicle') ?? 'أخرى';
        default:
          return s.regionName ?? 'غير محدد';
      }
    }
    switch (f.sourceType) {
      case 'specialty':
        return _specialtyLabel(s);
      case 'field':
        final v = _valueOf(s, f);
        // خدمة بلا قيمة للحقل تُجمَّع «غير محدد» ولا تُخفى
        return v.isEmpty ? 'غير محدد' : v;
      case 'region':
      default:
        return s.regionName ?? 'غير محدد';
    }
  }

  /// بناء بطاقات التجميع (المستوى ١) — من الفلتر الأساسي المُسنَد للقسم.
  /// الترتيب مطابق للخادم: الأكثر «تعمل الآن» ثم الأكثر عدداً ثم أبجدياً.
  List<_Group> _buildGroups() {
    final map = <String, _Group>{};
    for (final s in _all) {
      if (!_passes(s)) continue;
      final key = _keyOf(s);
      final g = map.putIfAbsent(
          key, () => _Group(key: key, label: _labelOf(s), count: 0, open: 0));
      g.count++;
      if (s.isOpen) g.open++;
    }

    return map.values.toList()
      ..sort((a, b) {
        // «غير محدد» آخر القائمة دائماً — كما يفعل الخادم، فيتطابق
        // ترتيب بطاقات التطبيق مع ترتيب الويب
        final an = a.key.endsWith('-none');
        final bn = b.key.endsWith('-none');
        if (an != bn) return an ? 1 : -1;
        if (a.open != b.open) return b.open.compareTo(a.open);
        if (a.count != b.count) return b.count.compareTo(a.count);
        return a.label.compareTo(b.label);
      });
  }

  /// أيقونة بطاقة المجموعة — من أيقونة الفلتر الذي اختارها المدير،
  /// وإلا فنوع المصدر (مناطق · اختصاص · مركبات).
  Widget _groupIcon(_Group g, {bool selected = false}) {
    final c = selected ? Colors.white : AppTheme.textSecondary;
    final f = _primaryFilter;
    if (f != null && f.icon.isNotEmpty) {
      return Icon(AppIcons.get(f.icon), size: 15, color: c);
    }
    final kind = f?.sourceType ?? _info.groupBy;
    switch (kind) {
      case 'specialty':
        return Icon(LucideIcons.stethoscope, size: 15, color: c);
      case 'field':
      case 'meta':
        return _vehicleIcon(g.label, selected: selected);
      default:
        return Icon(LucideIcons.mapPin, size: 15, color: c);
    }
  }

  /// نص فلتر ثانوي على الشريحة: «الاختصاص: أسنان» أو «الاختصاص: الكل»
  String _secLabel(CategoryFilterLink f) {
    final cur = _secState[f.key] ?? '';
    if (cur.isEmpty) return '${f.label}: الكل';
    for (final s in _all) {
      if (_valueOf(s, f) == cur) {
        return '${f.label}: ${_filterValueLabel(s, f)}';
      }
    }
    return '${f.label}: $cur';
  }

  /// تسمية قيمة الخدمة في فلتر ثانوي (بلا تغيير حالة العرض)
  String _filterValueLabel(Service s, CategoryFilterLink f) {
    switch (f.sourceType) {
      case 'specialty':
        return _specialtyLabel(s);
      case 'field':
        final v = _valueOf(s, f);
        return v.isEmpty ? 'غير محدد' : v;
      default:
        return s.regionName ?? 'غير محدد';
    }
  }

  /// قيم فلتر ثانوي المتاحة فعلاً في هذا القسم — مع عدد كل قيمة
  List<_SecOption> _secOptions(CategoryFilterLink f) {
    final counts = <String, int>{};
    final labels = <String, String>{};
    for (final s in _all) {
      // نبني الخيارات من الخدمات التي تجتاز بقية الفلاتر — عدا هذا الفلتر
      if (!_passes(s, ignoreSecondary: f)) continue;
      final v = _valueOf(s, f);
      final k = v.isEmpty ? '__none' : v;
      counts[k] = (counts[k] ?? 0) + 1;
      labels.putIfAbsent(k, () => v.isEmpty ? 'غير محدد' : _filterValueLabel(s, f));
    }
    return counts.entries
        .map((e) => _SecOption(
              key: e.key,
              label: labels[e.key] ?? e.key,
              count: e.value,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  /// اختيار قيمة فلتر ثانوي (ورقة سفلية)
  Future<void> _pickSecondary(CategoryFilterLink f) async {
    final opts = _secOptions(f);
    final cur = _secState[f.key] ?? '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Icon(AppIcons.get(f.icon), size: 16, color: AppTheme.primary),
                  const SizedBox(width: 7),
                  Text(
                    f.label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            /* حدٌّ صريح بدل Flexible: داخل Column بـmainAxisSize.min يمكن أن
               يرمي Flexible خطأ «قيود ارتفاع غير محدودة» في بعض الأغلفة.
               الحدّ الصريح يجعل الورقة تمرّ في كل الحالات، ومع shrinkWrap
               تصغر القائمة على محتواها ولا تزيد على نصف الشاشة. */
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 10),
                children: [
                  ListTile(
                    dense: true,
                    title: const Text('الكل',
                        style: TextStyle(fontSize: 13.5)),
                    trailing: cur.isEmpty
                        ? const Icon(LucideIcons.check,
                            size: 16, color: AppTheme.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, ''),
                  ),
                  ...opts.map((o) => ListTile(
                        dense: true,
                        title: Text(o.label,
                            style: const TextStyle(fontSize: 13.5)),
                        trailing: Text(
                          '${o.count}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                        selected: cur == o.key,
                        onTap: () => Navigator.pop(
                            ctx, cur == o.key ? '' : o.key),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.isEmpty) {
        _secState.remove(f.key);
      } else {
        _secState[f.key] = picked;
      }
      _groupKey = null;   // القيم تغيّرت — أعِد للبطاقات
      _picked = null;
    });
    _applyFilters();
  }

  /// صف الفلاتر الثانوية — يظهر فقط إن أسنَد المدير أكثر من فلتر للقسم
  Widget _buildSecondaryRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _secondaryFilters
              .map((f) => _FilterChip(
                    label: _secLabel(f),
                    selected: (_secState[f.key] ?? '').isNotEmpty,
                    onTap: () => _pickSecondary(f),
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _selectGroup(String? key) {
    setState(() {
      _groupKey = _groupKey == key ? null : key;
      _picked = null;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final groups = _buildGroups();
    final openNow = _visible.where((s) => s.isOpen).length;

    // البطاقات المربّعة هي الافتراضي للأقسام «المُصغّرة»
    // لكن مفتاح «بطاقات/قائمة» يبقى فاعلاً دائماً
    final useMini = _info.mini && _layout == 'card';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_cat.name),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowRight),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            tooltip: 'تحديث',
            onPressed: () => _load(force: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── شريط البحث ───
          _buildSearch(),

          // ─── صف المحافظات ───
          if (app.governorates.isNotEmpty) _buildGovernorateRow(app),

          // ─── صف النطاق (مدينة/ريف) ───
          if (_govId != null) _buildZoneRow(app),

          // ─── فلاتر الحالة ───
          _buildStatusRow(),

          // ─── الفلاتر الثانوية المُسنَدة للقسم (إن وُجدت) ───
          if (_secondaryFilters.isNotEmpty) _buildSecondaryRow(),

          // ─── شريط العدد وطريقة العرض ───
          _buildToolbar(groups, openNow),

          // ─── المحتوى ───
          Expanded(
            child: _loading
                ? const LoadingList()
                : _error != null
                    ? EmptyState(
                        icon: LucideIcons.cloudOff,
                        title: 'تعذّر تحميل البيانات',
                        subtitle: _error,
                      )
                    : _buildBody(groups, useMini),
          ),
        ],
      ),
    );
  }

  // ═══════════════ البحث ═══════════════
  Widget _buildSearch() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      color: AppTheme.surface,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) {
          _search = v;
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: 'ابحث بالاسم أو العنوان…',
          hintStyle: const TextStyle(fontSize: 13.5),
          prefixIcon: const Icon(LucideIcons.search, size: 18),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(LucideIcons.x, size: 17),
                  onPressed: () {
                    _searchCtrl.clear();
                    _search = '';
                    _applyFilters();
                  },
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // ═══════════════ صف المحافظات ═══════════════
  Widget _buildGovernorateRow(AppProvider app) {
    /// ────────────────────────────────────────────────
    /// العدّاد يجب أن يعكس القسم الحالي فقط.
    /// servicesCount القادم من الخادم يعدّ كل خدمات المحافظة
    /// (صيدليات + أطباء + كازيات + …) — لذا نحسبه محلياً
    /// من الخدمات المُحمَّلة لهذا القسم (_all).
    /// ────────────────────────────────────────────────
    int countOf(int? gid) => _all
        .where((s) =>
            (gid == null || s.governorateId == gid) &&
            (_zone == null || s.regionZone == _zone))
        .length;

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'كل المحافظات',
              trailing: '${countOf(null)}',
              selected: _govId == null,
              onTap: () {
                setState(() {
                  _govId = null;
                  _regionId = null;
                  _groupKey = null;
                  _picked = null;
                });
                _applyFilters();
              },
            ),
            ...app.governorates.map((g) {
              final n = countOf(g.id);
              final disabled = n == 0;
              return _FilterChip(
                label: g.name,
                trailing: '$n',
                selected: _govId == g.id,
                // المحافظات بلا خدمات في هذا القسم تظهر باهتة
                dimmed: disabled,
                onTap: () {
                  setState(() {
                    _govId = _govId == g.id ? null : g.id;
                    _regionId = null;
                    _groupKey = null;
                    _picked = null;
                  });
                  _applyFilters();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ═══════════════ صف النطاق ═══════════════
  Widget _buildZoneRow(AppProvider app) {
    // عدّاد لكل نطاق — محسوب من خدمات القسم الحالي فقط
    int countOf(String? z) => _all
        .where((s) =>
            (_govId == null || s.governorateId == _govId) &&
            (z == null || s.regionZone == z))
        .length;

    const zones = [
      (label: 'كل المناطق', value: null),
      (label: 'مدينة', value: 'city'),
      (label: 'ريف', value: 'rural'),
    ];

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final z in zones)
              _FilterChip(
                label: z.label,
                // كان يقارن _status خطأً — الآن يقارن _zone
                selected: _zone == z.value,
                trailing: '${countOf(z.value)}',
                onTap: () {
                  setState(() {
                    // تبديل: الضغط على المحدَّد يُلغيه
                    _zone = (_zone == z.value) ? null : z.value;
                    _regionId = null;
                    _groupKey = null;
                    _picked = null;
                  });
                  _applyFilters();
                },
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ فلاتر الحالة ═══════════════
  Widget _buildStatusRow() {
    const opts = [
      (v: 'all', l: 'الكل'),
      (v: 'open', l: 'تعمل الآن'),
      (v: 'closed', l: 'مغلقة'),
      (v: 'duty', l: 'مناوبة'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: opts
              .map((o) => _StatusChip(
                    label: o.l,
                    value: o.v,
                    selected: _status == o.v,
                    onTap: () {
                      setState(() => _status = o.v);
                      _applyFilters();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ═══════════════ شريط الأدوات ═══════════════
  Widget _buildToolbar(List<_Group> groups, int openNow) {
    final total = _groupKey == null ? _all.length : _visible.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(
        children: [
          Icon(LucideIcons.layers, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            '$total',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _info.unitPlural,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (openNow > 0) ...[
            const SizedBox(width: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppTheme.openBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                          color: AppTheme.open, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(
                    '$openNow تعمل الآن',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.open,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          // ─── مفتاح طريقة العرض ───
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LayoutButton(
                  icon: LucideIcons.layoutGrid,
                  selected: _layout == 'card',
                  tooltip: 'بطاقات',
                  onTap: () => setState(() => _layout = 'card'),
                ),
                _LayoutButton(
                  icon: LucideIcons.list,
                  selected: _layout == 'list',
                  tooltip: 'قائمة',
                  onTap: () => setState(() => _layout = 'list'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════ المحتوى ═══════════════
  Widget _buildBody(List<_Group> groups, bool useMini) {
    // المستوى الأول: بطاقات التجميع فقط
    if (_groupKey == null) {
      // قسم بلا خدمات أصلاً — رسالة مختلفة عن «الفلاتر حجبت النتائج»،
      // وإلا بقي الزائر أمام «لا توجد نتائج مطابقة» وهو لم يفلتر شيئاً
      if (_all.isEmpty) {
        return EmptyState(
          icon: LucideIcons.inbox,
          title: 'لا توجد خدمات بعد',
          subtitle: 'لم تُضَف خدمات إلى «${_cat.name}» حتى الآن',
        );
      }
      if (groups.isEmpty) {
        return const EmptyState(
          icon: LucideIcons.search,
          title: 'لا توجد نتائج مطابقة',
          subtitle: 'جرّب تغيير الفلاتر أو البحث',
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                _groupIcon(_Group(key: '', label: '', count: 0)),
                const SizedBox(width: 6),
                Text(
                  // عنوان المجموعة = اسم الفلتر الذي أسنَده المدير لهذا القسم
                  _primaryFilter?.label ??
                      (_info.groupBy == 'specialty'
                          ? 'الاختصاصات'
                          : _info.groupBy == 'meta'
                              ? 'نوع المركبة'
                              : 'المناطق'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: groups.map((g) {
              return GroupCard(
                title: g.label,
                count: g.count,
                selected: false,
                icon: _groupIcon(g),
                onTap: () => _selectGroup(g.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
        ],
      );
    }

    // المستوى الثاني: خدمات المجموعة المختارة فقط
    final group = groups.firstWhere(
      (g) => g.key == _groupKey,
      orElse: () => _Group(key: _groupKey!, label: '', count: 0, open: 0),
    );

    if (_visible.isEmpty) {
      return EmptyState(
        icon: LucideIcons.search,
        title: 'لا توجد ${_info.unitPlural} مطابقة في «${group.label}»',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      children: [
        // رأس النتيجة
        Container(
          margin: const EdgeInsets.only(bottom: 11),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.primaryLight),
          ),
          child: Row(
            children: [
              _groupIcon(group, selected: false),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _groupIsRegion ? 'خدمات ${group.label}' : group.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_visible.length}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _selectGroup(null),
                child: const Icon(LucideIcons.x,
                    size: 16, color: AppTheme.primary),
              ),
            ],
          ),
        ),

        // بطاقات مربّعة + لوحة سفلية
        if (useMini) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.86,
            ),
            itemCount: _visible.length,
            itemBuilder: (context, i) => MiniServiceCard(
              service: _visible[i],
              selected: _picked?.id == _visible[i].id,
              onTap: () => setState(() => _picked = _visible[i]),
            ),
          ),
          const SizedBox(height: 14),
          if (_picked != null)
            ServicePanel(
              service: _picked!,
              onClose: () => setState(() => _picked = null),
            )
          else
            _panelHint(),
        ] else ...[
          // قائمة أو شبكة
          _layout == 'list'
              ? Column(
                  children: _visible
                      .map(
                        (s) => ServiceListTile(
                          service: s,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ServiceDetailScreen(service: s)),
                          ),
                          onCall: () => _call(s),
                          onWhatsapp: () => _whatsapp(s),
                        ),
                      )
                      .toList(),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: _visible.length,
                  itemBuilder: (context, i) => _GridCard(
                    service: _visible[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ServiceDetailScreen(service: _visible[i])),
                    ),
                  ),
                ),
        ],

        const SizedBox(height: 18),
      ],
    );
  }

  Widget _panelHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👆', style: TextStyle(fontSize: 17)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'اضغط على أي ${_info.unit} من الأعلى لعرض بياناتها كاملةً هنا',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }


  static Widget _vehicleIcon(String label, {bool selected = false}) {
    final l = label.toLowerCase();
    final c = selected ? Colors.white : AppTheme.textSecondary;
    if (l.contains('إسعاف') || l.contains('اسعاف') || l.contains('ambulance')) {
      return AmbulanceIcon(size: 15, color: c);
    }
    if (l.contains('باص') || l.contains('حافلة'))
      return Icon(LucideIcons.bus, size: 15, color: c);
    if (l.contains('سرفيس') || l.contains('تكسي'))
      return Icon(LucideIcons.car, size: 15, color: c);
    if (l.contains('شحن') || l.contains('نقل'))
      return Icon(LucideIcons.truck, size: 15, color: c);
    return Icon(LucideIcons.car, size: 15, color: c);
  }

  // ═══════════════ الاتصال ═══════════════
  Future<void> _call(Service s) async {
    final uri = Uri.parse('tel:${s.phone}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(Service s) async {
    final n = s.whatsappReady;
    if (n.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$n');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// ═══════════════ لوحة بيانات الخدمة (المستوى الثاني) ═══════════════
class ServicePanel extends StatelessWidget {
  final Service service;
  final VoidCallback onClose;

  const ServicePanel({super.key, required this.service, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border:
            Border.all(color: AppTheme.primary.withOpacity(0.35), width: 1.5),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // العنوان
          Container(
            padding: const EdgeInsets.fromLTRB(15, 13, 10, 13),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(service: service),
                if (service.statusSublabel.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock,
                          size: 13, color: AppTheme.textMuted),
                      const SizedBox(width: 5),
                      Text(
                        service.statusSublabel,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 13),
                const Divider(height: 1),
                const SizedBox(height: 13),

                if (service.fullRegionLabel.isNotEmpty)
                  _PanelRow(
                      icon: LucideIcons.mapPin, text: service.fullRegionLabel),
                if (service.address.isNotEmpty)
                  _PanelRow(
                      icon: LucideIcons.navigation, text: service.address),
                if (service.note.isNotEmpty)
                  _PanelRow(icon: LucideIcons.fileText, text: service.note),
                if (service.ownerName != null && service.ownerName!.isNotEmpty)
                  _PanelRow(icon: LucideIcons.user, text: service.ownerName!),

                const SizedBox(height: 15),

                // أزرار الإجراء
                Row(
                  children: [
                    Expanded(
                      child: _PanelAction(
                        icon: LucideIcons.phone,
                        label: 'اتصال',
                        color: AppTheme.open,
                        number: service.phone,
                        scheme: 'tel:',
                      ),
                    ),
                    if (service.whatsappReady.isNotEmpty) ...[
                      const SizedBox(width: 9),
                      Expanded(
                        child: _PanelAction(
                          icon: LucideIcons.messageCircle,
                          label: 'واتساب',
                          color: const Color(0xFF25D366),
                          number: service.whatsappReady,
                          scheme: 'https://wa.me/',
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 9),

                // زر التفاصيل الكاملة
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ServiceDetailScreen(service: service)),
                  ),
                  icon: const Icon(LucideIcons.info, size: 16),
                  label: const Text('التفاصيل الكاملة'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PanelRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String number;
  final String scheme;

  const _PanelAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.number,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse('$scheme$number');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri,
                mode: scheme.startsWith('http')
                    ? LaunchMode.externalApplication
                    : LaunchMode.platformDefault);
          }
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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

class _GridCard extends StatelessWidget {
  final Service service;
  final VoidCallback onTap;

  const _GridCard({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(catColor(service));
    return Container(
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
            padding: const EdgeInsets.all(11),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: AppIcon(service.categoryIcon, size: 20, color: color),
                ),
                const SizedBox(height: 9),
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                StatusBadge(service: service, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════ شرائح الفلترة ═══════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final String? trailing;
  final bool selected;
  /// يظهر باهتاً حين لا تتوفر نتائج (مثلاً محافظة بلا خدمات في هذا القسم)
  final bool dimmed;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.trailing,
    required this.selected,
    this.dimmed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary
                  : (dimmed ? AppTheme.background : AppTheme.surface),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppTheme.primary
                    : (dimmed ? AppTheme.border.withOpacity(0.55) : AppTheme.border),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : (dimmed ? AppTheme.textMuted : AppTheme.textPrimary),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(0.25)
                          : AppTheme.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      trailing!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Colors.white
                            : (dimmed
                                ? AppTheme.textMuted.withOpacity(0.65)
                                : AppTheme.textMuted),
                      ),
                    ),
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

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (value) {
      case 'open':
        c = AppTheme.open;
        break;
      case 'closed':
        c = AppTheme.closed;
        break;
      case 'duty':
        c = AppTheme.duty;
        break;
      default:
        c = AppTheme.primary;
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
            decoration: BoxDecoration(
              color: selected ? c : AppTheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? c : AppTheme.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayoutButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _LayoutButton({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 30,
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// مجموعة تجميع
/// قيمة متاحة في فلتر ثانوي (للورقة السفلية)
class _SecOption {
  final String key;
  final String label;
  final int count;

  const _SecOption({
    required this.key,
    required this.label,
    required this.count,
  });
}

class _Group {
  final String key;
  final String label;
  int count;

  /// كم خدمة فيها تعمل الآن — يُقدَّم الترتيب عليها كما يفعل الخادم
  int open;

  _Group({
    required this.key,
    required this.label,
    required this.count,
    this.open = 0,
  });
}

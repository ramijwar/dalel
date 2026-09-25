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

  /// 'card' | 'list'
  late String _layout;

  // ─── البيانات ───
  List<Service> _all = [];
  List<Service> _visible = [];
  Service? _picked;
  bool _loading = true;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();

  SectionConfig get _info => SectionConfig.of(widget.category.slug);

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
      final list =
          await app.loadSection(widget.category.slug, forceNetwork: force);
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

  void _applyFilters() {
    final q = _search.trim().toLowerCase();

    var list = _all.where((s) {
      if (_govId != null && s.governorateId != _govId) return false;
      if (_zone != null && s.regionZone != _zone) return false;
      if (_regionId != null && s.regionId != _regionId) return false;
      if (_specialtyId != null && s.specialtyId != _specialtyId) return false;
      if (_status == 'open' && !s.isOpen) return false;
      if (_status == 'closed' && s.isOpen) return false;
      if (_status == 'duty' && !s.onDuty) return false;
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !s.address.toLowerCase().contains(q)) return false;
      return true;
    }).toList();

    // فلترة المجموعة المختارة
    if (_groupKey != null) {
      list = list.where((s) => _keyOf(s) == _groupKey).toList();
    }

    setState(() => _visible = list);
  }

  /// مفتاح تجميع الخدمة حسب نوع القسم
  String _keyOf(Service s) {
    switch (_info.groupBy) {
      case 'specialty':
        return 'sp-${s.specialtyId ?? 0}';
      case 'meta':
        return 'mt-${s.metaVal(_info.metaKey ?? 'vehicle') ?? 'أخرى'}';
      default:
        return 'rg-${s.regionId ?? 0}';
    }
  }

  String _labelOf(Service s) {
    switch (_info.groupBy) {
      case 'specialty':
        /* meta.specialty قد يكون اسماً («أمراض داخلية») في البيانات
           القديمة أو مُعرّف خيار («5») في الجديدة. نفضّل الحقل
           المحلول من الخادم، ولا نعرض رقماً خاماً أبداً. */
        final raw = (s.meta['specialty_name'] ?? s.metaVal('specialty') ?? '')
            .toString()
            .trim();
        final resolved = widget.category.fields
            .where((f) => f.key == 'specialty')
            .expand((f) => f.options)
            .where((o) =>
                o.value == raw ||
                o.id.toString() == raw ||
                o.label == raw)
            .map((o) => o.label)
            .firstOrNull;
        if (resolved != null && resolved.isNotEmpty) return resolved;
        // لا نعرض مُعرّفاً رقمياً خاماً أبداً («9» مثلاً) — الاختصاص غير معروف
        // فنُعيد التسمية الافتراضية. كان النمط السابق `^\d+\$` يطابق رقماً
        // متبوعاً بعلامة $ حرفية، فتمرّ الأرقام الخام إلى الواجهة رغم الحماية.
        if (raw.isNotEmpty && !RegExp(r'^\d+$').hasMatch(raw)) return raw;
        return 'عام';
      case 'meta':
        return s.metaVal(_info.metaKey ?? 'vehicle') ?? 'أخرى';
      default:
        return s.regionName ?? 'غير محددة';
    }
  }

  /// بناء بطاقات التجميع (المستوى ١)
  List<_Group> _buildGroups() {
    final map = <String, _Group>{};
    for (final s in _all) {
      // طبّق الفلاتر عدا المجموعة
      if (_govId != null && s.governorateId != _govId) continue;
      if (_zone != null && s.regionZone != _zone) continue;
      if (_regionId != null && s.regionId != _regionId) continue;
      if (_specialtyId != null && s.specialtyId != _specialtyId) continue;
      if (_status == 'open' && !s.isOpen) continue;
      if (_status == 'closed' && s.isOpen) continue;
      if (_status == 'duty' && !s.onDuty) continue;
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        if (!s.name.toLowerCase().contains(q) &&
            !s.address.toLowerCase().contains(q)) {
          continue;
        }
      }

      final key = _keyOf(s);
      map.putIfAbsent(
          key, () => _Group(key: key, label: _labelOf(s), count: 0));
      map[key]!.count++;
    }

    final groups = map.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return groups;
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
        title: Text(widget.category.name),
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
                const Icon(LucideIcons.mapPin,
                    size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  _info.groupBy == 'specialty'
                      ? 'الاختصاصات'
                      : _info.groupBy == 'meta'
                          ? 'نوع المركبة'
                          : 'المناطق',
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
              final icon = _info.groupBy == 'specialty'
                  ? const Icon(LucideIcons.stethoscope,
                      size: 15, color: AppTheme.textSecondary)
                  : _info.groupBy == 'meta'
                      ? _vehicleIcon(g.label)
                      : const Icon(LucideIcons.mapPin,
                          size: 15, color: AppTheme.textSecondary);
              return GroupCard(
                title: g.label,
                count: g.count,
                selected: false,
                icon: icon,
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
      orElse: () => _Group(key: _groupKey!, label: '', count: 0),
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
              const Icon(LucideIcons.mapPin, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _info.groupBy == 'region'
                      ? 'خدمات ${group.label}'
                      : group.label,
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
class _Group {
  final String key;
  final String label;
  int count;

  _Group({required this.key, required this.label, required this.count});
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../widgets/widgets.dart';
import 'service_detail_screen.dart';

/// ══════════════════════════════════════════════════════════════
/// شاشة البحث — تبحث في قاعدة البيانات المحلية (تعمل بدون إنترنت)
/// ══════════════════════════════════════════════════════════════
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _db = DatabaseService.instance;

  List<Service> _results = [];
  List<String> _recent = [];
  bool _searching = false;
  bool _hasQuery = false;
  String? _statusFilter;
  int? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _ctrl.addListener(() {
      final q = _ctrl.text.trim();
      if (q.length >= 2) {
        _search(q);
      } else if (_hasQuery) {
        setState(() {
          _hasQuery = false;
          _results = [];
        });
      }
    });
  }

  Future<void> _loadRecent() async {
    final r = await _db.getRecentSearches();
    if (mounted) setState(() => _recent = r);
  }

  Future<void> _search(String q) async {
    setState(() {
      _searching = true;
      _hasQuery = true;
    });

    final list = await _db.queryServices(
      search: q,
      categoryId: _categoryFilter,
      status: _statusFilter,
      limit: AppConfig.localQueryLimit,
    );

    if (!mounted) return;
    setState(() {
      _results = list;
      _searching = false;
    });
    await _db.addRecentSearch(q);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('البحث'),
        toolbarHeight: 74,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border, height: 1),
        ),
      ),
      body: Column(
        children: [
          // ─── حقل البحث ───
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: TextField(
              controller: _ctrl,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                if (v.trim().length >= 2) _search(v.trim());
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن صيدلية، طبيب، كازية…',
                hintStyle: const TextStyle(fontSize: 13.5),
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 17),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() {
                            _hasQuery = false;
                            _results = [];
                          });
                        },
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),

          // ─── فلاتر سريعة ───
          if (_hasQuery)
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _MiniFilter(
                            label: 'الكل',
                            selected: _statusFilter == null &&
                                _categoryFilter == null,
                            onTap: () {
                              setState(() {
                                _statusFilter = null;
                                _categoryFilter = null;
                              });
                              _search(_ctrl.text.trim());
                            },
                          ),
                          _MiniFilter(
                            label: 'تعمل الآن',
                            selected: _statusFilter == 'open',
                            color: AppTheme.open,
                            onTap: () {
                              setState(() => _statusFilter =
                                  _statusFilter == 'open' ? null : 'open');
                              _search(_ctrl.text.trim());
                            },
                          ),
                          ...app.categories.map((c) => _MiniFilter(
                                label: c.name,
                                selected: _categoryFilter == c.id,
                                onTap: () {
                                  setState(() {
                                    _categoryFilter =
                                        _categoryFilter == c.id ? null : c.id;
                                    _statusFilter = null;
                                  });
                                  _search(_ctrl.text.trim());
                                },
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ─── النتائج ───
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasQuery) {
      if (_recent.isEmpty) {
        return const EmptyState(
          icon: LucideIcons.search,
          title: 'ابحث في الدليل',
          subtitle: 'اكتب اسم الخدمة أو المنطقة للبحث — يعمل بدون إنترنت',
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clock,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              const Text(
                'عمليات بحث أخيرة',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await _db.clearRecentSearches();
                  _loadRecent();
                },
                child: const Text('مسح', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            children: _recent
                .map((q) => ActionChip(
                      label: Text(q, style: const TextStyle(fontSize: 12.5)),
                      onPressed: () {
                        _ctrl.text = q;
                        _search(q);
                      },
                      backgroundColor: AppTheme.surface,
                      side: const BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ))
                .toList(),
          ),
        ],
      );
    }

    if (_searching) return const LoadingList();

    if (_results.isEmpty) {
      return EmptyState(
        icon: LucideIcons.search,
        title: 'لا توجد نتائج لـ «${_ctrl.text.trim()}»',
        subtitle: 'جرّب كلمات مختلفة أو تحقّق من الإملاء',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final s = _results[i];
        return ServiceListTile(
          service: s,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: s)),
          ),
          onCall: () => _launch('tel:${s.phone}'),
          onWhatsapp: s.whatsappReady.isEmpty
              ? null
              : () =>
                  _launch('https://wa.me/${s.whatsappReady}', external: true),
        );
      },
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

class _MiniFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _MiniFilter({
    required this.label,
    required this.selected,
    this.color = AppTheme.primary,
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
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
            decoration: BoxDecoration(
              color: selected ? color : AppTheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? color : AppTheme.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

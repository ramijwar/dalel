import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme.dart';
import '../config/icons.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';
import 'service_detail_screen.dart';

/// ══════════════════════════════════════════════════════════════
/// لوحة المالك — تبويبات مُنمّقة: خدماتي / طلباتي
/// تحكّم بالحالة (تبديل بالسحب) + المناوبة + جدول الدوام
/// ══════════════════════════════════════════════════════════════
class OwnerDashboardScreen extends StatefulWidget {
  final int initialTab;

  const OwnerDashboardScreen({super.key, this.initialTab = 0});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _api = ApiService.instance;

  List<Service> _services = [];
  List<ServiceRequest> _requests = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _tabs =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.myServices(),
        _api.myRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _services = results[0] as List<Service>;
        _requests = results[1] as List<ServiceRequest>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'تعذّر تحميل البيانات';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('لوحة المالك'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowRight),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.briefcase, size: 16),
                  const SizedBox(width: 6),
                  const Text('خدماتي'),
                  if (_services.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _TabBadge(count: _services.length),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.inbox, size: 16),
                  const SizedBox(width: 6),
                  const Text('طلباتي'),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _TabBadge(count: _requests.length),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: LucideIcons.cloudOff,
                  title: 'تعذّر التحميل',
                  subtitle: _error,
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildServices(),
                    _buildRequests(),
                  ],
                ),
    );
  }

  // ═══════════════ تبويب خدماتي ═══════════════
  Widget _buildServices() {
    if (_services.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.briefcase,
        title: 'لا تملك خدمات بعد',
        subtitle: 'أرسل طلب إضافة خدمة من الشاشة الرئيسية',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      itemCount: _services.length,
      itemBuilder: (context, i) => _OwnerServiceCard(
        service: _services[i],
        busy: _busy.contains(_services[i].id),
        onToggle: (open) => _toggleStatus(_services[i], open),
        onDuty: () => _toggleDuty(_services[i]),
        onSchedule: () => _editSchedule(_services[i]),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ServiceDetailScreen(service: _services[i])),
        ),
      ),
    );
  }

  // ═══════════════ تبويب طلباتي ═══════════════
  Widget _buildRequests() {
    if (_requests.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.inbox,
        title: 'لا توجد طلبات',
        subtitle: 'ستظهر طلبات إضافة الخدمات التي ترسلها هنا',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      itemCount: _requests.length,
      itemBuilder: (context, i) {
        final r = _requests[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _StatusPill(
                      label: r.statusLabel, color: Color(r.statusColor)),
                ],
              ),
              if (r.categoryName != null) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(LucideIcons.tag,
                        size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      r.categoryName!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
              if (r.regionName != null || r.governorateName != null) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin,
                        size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      [r.regionName, r.governorateName]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(' — '),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
              if (r.rejectReason != null && r.rejectReason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.closedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.alertCircle,
                          size: 13, color: AppTheme.closed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.rejectReason!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.closed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (r.createdAt != null) ...[
                const SizedBox(height: 7),
                Text(
                  r.createdAt!,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ═══════════════ تبديل الحالة ═══════════════
  Future<void> _toggleStatus(Service s, bool open) async {
    setState(() => _busy.add(s.id));
    try {
      final updated = await _api.ownerStatus(
        s.id,
        mode: open ? 'open' : 'closed',
        hours: open ? 6 : null,
      );
      _replace(updated);
      _snack(open ? 'تم فتح الخدمة' : 'تم إغلاق الخدمة', success: true);
    } catch (e) {
      _snack(e is ApiException ? e.message : 'تعذّر تحديث الحالة');
    }
    if (mounted) setState(() => _busy.remove(s.id));
  }

  Future<void> _toggleDuty(Service s) async {
    setState(() => _busy.add(s.id));
    try {
      final updated = await _api.ownerStatus(
        s.id,
        mode: 'open',
        onDuty: !s.onDuty,
        dutyHours: 12,
      );
      _replace(updated);
      _snack(
        s.onDuty ? 'أُلغيت المناوبة' : 'تم تفعيل المناوبة',
        success: true,
      );
    } catch (e) {
      _snack(e is ApiException ? e.message : 'تعذّر تحديث المناوبة');
    }
    if (mounted) setState(() => _busy.remove(s.id));
  }

  void _replace(Service updated) {
    final i = _services.indexWhere((e) => e.id == updated.id);
    if (i >= 0 && mounted) {
      setState(() => _services[i] = updated);
    }
  }

  // ═══════════════ جدول الدوام ═══════════════
  Future<void> _editSchedule(Service s) async {
    final rows = s.schedule.isEmpty
        ? List.generate(7, (d) => ScheduleRow(day: d, isOpen: d != 5))
        : List<ScheduleRow>.from(s.schedule);

    final result = await showModalBottomSheet<List<ScheduleRow>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ScheduleSheet(service: s, initial: rows),
    );

    if (result == null) return;

    setState(() => _busy.add(s.id));
    try {
      final updated = await _api.ownerSchedule(s.id, result);
      _replace(updated);
      if (mounted) _snack('تم حفظ أوقات الدوام', success: true);
    } catch (e) {
      _snack(e is ApiException ? e.message : 'تعذّر حفظ الدوام');
    }
    if (mounted) setState(() => _busy.remove(s.id));
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppTheme.open : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
        margin: const EdgeInsets.all(14),
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  final int count;

  const _TabBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// ═══════════════ بطاقة خدمة المالك ═══════════════
class _OwnerServiceCard extends StatelessWidget {
  final Service service;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDuty;
  final VoidCallback onSchedule;
  final VoidCallback onTap;

  const _OwnerServiceCard({
    required this.service,
    required this.busy,
    required this.onToggle,
    required this.onDuty,
    required this.onSchedule,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          // الرأس
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AppIcon(service.categoryIcon,
                          size: 21, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service.categoryName,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(service: service),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // عناصر التحكم
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                // تبديل الحالة بالسحب
                Row(
                  children: [
                    const Icon(LucideIcons.power,
                        size: 15, color: AppTheme.textSecondary),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'حالة الخدمة',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Switch(
                        value: service.isOpen,
                        onChanged: onToggle,
                        activeTrackColor: AppTheme.open,
                      ),
                  ],
                ),

                // المناوبة (للأقسام الداعمة فقط)
                if (service.categorySlug == 'pharmacies') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock,
                          size: 15, color: AppTheme.textSecondary),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'مناوبة',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: service.onDuty,
                        onChanged: busy ? null : (_) => onDuty(),
                        activeTrackColor: AppTheme.duty,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),

                // زر جدول الدوام
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onSchedule,
                    icon: const Icon(LucideIcons.calendarClock, size: 16),
                    label: const Text('أوقات الدوام'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
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

/// ═══════════════ لوحة جدول الدوام ═══════════════
class _ScheduleSheet extends StatefulWidget {
  final Service service;
  final List<ScheduleRow> initial;

  const _ScheduleSheet({required this.service, required this.initial});

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late List<ScheduleRow> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // تأكد من وجود ٧ أيام
    final byDay = {for (final r in widget.initial) r.day: r};
    _rows = List.generate(
      7,
      (d) => byDay[d] ?? ScheduleRow(day: d, isOpen: d != 5),
    );
  }

  Future<void> _pickTime(int i, bool isFrom) async {
    final row = _rows[i];
    final parts = (isFrom ? row.from : row.to).split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0,
      ),
    );
    if (t == null) return;
    final str =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() {
      _rows[i] = ScheduleRow(
        day: row.day,
        isOpen: row.isOpen,
        from: isFrom ? str : row.from,
        to: isFrom ? row.to : str,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendarClock,
                        size: 19, color: AppTheme.primary),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'أوقات الدوام',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 19),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 18),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: 7,
                  itemBuilder: (context, i) {
                    final r = _rows[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 58,
                            child: Text(
                              r.dayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Switch(
                            value: r.isOpen,
                            onChanged: (v) => setState(() => _rows[i] =
                                ScheduleRow(
                                    day: r.day,
                                    isOpen: v,
                                    from: r.from,
                                    to: r.to)),
                            activeTrackColor: AppTheme.open,
                          ),
                          const Spacer(),
                          if (r.isOpen) ...[
                            _TimeBox(
                              time: r.from,
                              onTap: () => _pickTime(i, true),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Text('–',
                                  style: TextStyle(color: AppTheme.textMuted)),
                            ),
                            _TimeBox(
                              time: r.to,
                              onTap: () => _pickTime(i, false),
                            ),
                          ] else
                            const Text(
                              'مغلقة',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.closed,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, _rows),
                        icon: _saving
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.save, size: 17),
                        label: const Text('حفظ الدوام'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String time;
  final VoidCallback onTap;

  const _TimeBox({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryLight),
          ),
          child: Text(
            time,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

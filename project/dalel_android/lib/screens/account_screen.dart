import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';
import 'owner_dashboard_screen.dart';
import 'request_service_screen.dart';
import 'service_detail_screen.dart';

/// ══════════════════════════════════════════════════════════════
/// شاشة الحساب — الملف الشخصي ولوحة المالك والمحفوظات
/// ══════════════════════════════════════════════════════════════
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<Service> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final ids = await DatabaseService.instance.getFavorites();
    final list = <Service>[];
    for (final id in ids) {
      final s = await DatabaseService.instance.getService(id);
      if (s != null) list.add(s);
    }
    if (mounted) setState(() => _favorites = list);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final app = context.watch<AppProvider>();

    if (!auth.isLoggedIn) return _buildGuest(auth);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () async => _loadFavorites(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ─── رأس الحساب ───
              _buildHeader(auth.user!),
              const SizedBox(height: 14),

              // ─── الإجراءات السريعة ───
              _buildQuickActions(),
              const SizedBox(height: 16),

              // ─── طلبات بانتظار موافقة المدير (عرض فقط) ───
              if (auth.user!.isAdmin) ...[
                const _AdminPendingRequests(),
                const SizedBox(height: 16),
              ],

              // ─── المحفوظات ───
              _buildFavorites(),

              const SizedBox(height: 16),

              // ─── معلومات التطبيق ───
              _buildAppInfo(app),

              const SizedBox(height: 16),

              // ─── تسجيل الخروج ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(auth),
                  icon: const Icon(LucideIcons.logOut, size: 17),
                  label: const Text('تسجيل الخروج'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: BorderSide(color: AppTheme.danger.withOpacity(0.4)),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════ زائر ═══════════════
  Widget _buildGuest(AuthProvider auth) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.userCircle,
                    size: 44, color: AppTheme.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'مرحباً بك',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'سجّل الدخول لإدارة خدماتك ومتابعة طلباتك',
                style: TextStyle(
                    fontSize: 13.5, color: AppTheme.textMuted, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(LucideIcons.logIn, size: 18),
                  label: const Text('تسجيل الدخول'),
                ),
              ),
              const SizedBox(height: 22),

              // محفوظات الزائر
              if (_favorites.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'المحفوظات',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ..._favorites.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: ServiceListTile(
                        service: s,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ServiceDetailScreen(service: s)),
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════ رأس الحساب ═══════════════
  Widget _buildHeader(User u) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      u.initial,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.fullName.isNotEmpty ? u.fullName : 'مستخدم',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        u.phoneIntl.isNotEmpty ? u.phoneIntl : u.phone,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                if (u.isAdmin)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'مدير',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ الإجراءات السريعة ═══════════════
  Widget _buildQuickActions() {
    final items = [
      (
        icon: LucideIcons.briefcase,
        label: 'خدماتي',
        sub: 'تبديل الحالة والدوام',
        color: const Color(0xFF0EA5E9),
        onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OwnerDashboardScreen()),
            ),
      ),
      (
        icon: LucideIcons.inbox,
        label: 'طلباتي',
        sub: 'متابعة حالة الطلبات',
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const OwnerDashboardScreen(initialTab: 1)),
            ),
      ),
      (
        icon: LucideIcons.plusCircle,
        label: 'أضف خدمة',
        sub: 'أرسل طلب إضافة',
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RequestServiceScreen()),
            ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items
            .map((it) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _QuickCard(
                      icon: it.icon,
                      label: it.label,
                      sub: it.sub,
                      color: it.color,
                      onTap: it.onTap,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ═══════════════ المحفوظات ═══════════════
  Widget _buildFavorites() {
    if (_favorites.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(LucideIcons.bookmark,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 7),
              Text(
                'المحفوظات (${_favorites.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: _favorites.map((s) {
              return Dismissible(
                key: Key('fav-${s.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsetsDirectional.only(start: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: const Icon(LucideIcons.trash2,
                      color: AppTheme.danger, size: 20),
                ),
                onDismissed: (_) async {
                  await DatabaseService.instance.toggleFavorite(s.id);
                  _loadFavorites();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('أُزيلت من المحفوظات')),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: ServiceListTile(
                    service: s,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ServiceDetailScreen(service: s)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ═══════════════ معلومات التطبيق ═══════════════
  Widget _buildAppInfo(AppProvider app) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const _InfoLine(
            icon: LucideIcons.tag,
            label: 'إصدار التطبيق',
            staticValue: '1.1.0',
          ),
          const Divider(height: 18),
          _InfoLine(
            icon: LucideIcons.database,
            label: 'الخدمات المحفوظة محلياً',
            value: () => Future.value(app.totalServices),
          ),
          const Divider(height: 18),
          _InfoLine(
            icon: LucideIcons.refreshCw,
            label: 'آخر مزامنة',
            isSync: true,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(AuthProvider auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger, minimumSize: Size.zero),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await auth.logout();
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style:
                    const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<int> Function()? value;
  final bool isSync;
  final String? staticValue;

  const _InfoLine({
    required this.icon,
    required this.label,
    this.value,
    this.isSync = false,
    this.staticValue,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ),
        if (isSync)
          Text(
            app.lastSync == null
                ? 'لم تتم بعد'
                : '${app.lastSync!.hour.toString().padLeft(2, '0')}:${app.lastSync!.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          )
        else if (value != null)
          FutureBuilder<int>(
            future: value!(),
            builder: (_, snap) => Text(
              snap.data?.toString() ?? '—',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          )
        else if (staticValue != null)
          Text(
            staticValue!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
      ],
    );
  }
}

/// ══════════════════════════════════════════════════════════════
/// قسم «طلبات بانتظار الموافقة» — يظهر للمدير فقط
/// تنبيه وعرض فقط: الموافقة/الرفض يتمّان من لوحة التحكم على الويب
/// ══════════════════════════════════════════════════════════════
class _AdminPendingRequests extends StatefulWidget {
  const _AdminPendingRequests();

  @override
  State<_AdminPendingRequests> createState() => _AdminPendingRequestsState();
}

class _AdminPendingRequestsState extends State<_AdminPendingRequests> {
  final _api = ApiService.instance;
  List<ServiceRequest>? _items;
  String? _error;

  static const Color _amber = Color(0xFFD97706);
  static const Color _amberBg = Color(0xFFFFF7ED);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await _api.adminPendingRequests();
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الطلبات — تحقق من الاتصال');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _header(),
          _body(),
        ],
      ),
    );
  }

  // ─── رأس القسم: عنوان + شارة العدد + تحديث ───
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _amberBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(LucideIcons.inbox, size: 17, color: _amber),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلبات بانتظار الموافقة',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'الموافقة تتم من لوحة التحكم على الويب',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _badge(),
          IconButton(
            onPressed: _load,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            color: AppTheme.textMuted,
            tooltip: 'تحديث',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ─── شارة العدد ───
  Widget _badge() {
    final items = _items;
    if (items == null) {
      return const SizedBox(
        width: 15,
        height: 15,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(color: AppTheme.openBg, shape: BoxShape.circle),
        child: const Icon(LucideIcons.check, size: 13, color: AppTheme.open),
      );
    }
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _amber,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${items.length}',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  // ─── المحتوى: تحميل / خطأ / فارغ / قائمة ───
  Widget _body() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 13),
        child: Column(
          children: [
            Text(_error!,
                style: const TextStyle(fontSize: 12.5, color: AppTheme.danger)),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(LucideIcons.rotateCcw, size: 14),
              label: const Text('إعادة المحاولة'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    final items = _items;
    if (items == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(14, 2, 14, 14),
        child: Row(
          children: [
            Icon(LucideIcons.checkCircle, size: 15, color: AppTheme.open),
            SizedBox(width: 7),
            Text(
              'لا توجد طلبات معلّقة — كل شيء مُراجَع',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Divider(height: 1, color: AppTheme.border),
        ...items.map(_tile),
        const Divider(height: 1, color: AppTheme.border),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, 11),
          child: Row(
            children: [
              Icon(LucideIcons.info, size: 13, color: AppTheme.textMuted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'اضغط على أي طلب لعرض تفاصيله — اعتماده من لوحة الويب',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── صفّ طلب واحد (عرض فقط) ───
  Widget _tile(ServiceRequest r) {
    final cat = r.categoryName ?? 'خدمة';
    final reg = r.regionName ?? 'بلا منطقة';
    final date = (r.createdAt ?? '').split(' ').first;

    return InkWell(
      onTap: () => _showDetails(r),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(LucideIcons.fileText, size: 16, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$cat • $reg • $date',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _amberBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'قيد المراجعة',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _amber,
                    ),
                  ),
                ),
                if (r.wantToManage) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'يريد إدارتها',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronLeft, size: 15, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  // ─── تفاصيل الطلب (قراءة فقط) ───
  void _showDetails(ServiceRequest r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.fileText, size: 18, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _amberBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'قيد المراجعة',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _amber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _row('نوع الخدمة', r.categoryName ?? '—'),
              _row('المنطقة', r.regionName ?? '—'),
              _row('المحافظة', r.governorateName ?? '—'),
              if (r.address.isNotEmpty) _row('العنوان', r.address),
              if (r.phone.isNotEmpty)
                _row('الهاتف', r.phone, ltr: true),
              if (r.note.isNotEmpty) _row('ملاحظات', r.note),
              if (r.userName != null && r.userName!.isNotEmpty)
                _row('أرسله', r.userName!),
              _row('تاريخ الإرسال', r.createdAt ?? '—'),
              if (r.wantToManage) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.userCheck, size: 15, color: AppTheme.primaryDark),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'صاحب الطلب يريد إدارة الخدمة بعد اعتمادها (سيصبح مالكها)',
                          style: TextStyle(fontSize: 12, color: AppTheme.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _amberBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.monitor, size: 15, color: _amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الموافقة أو الرفض يتمّان من لوحة التحكم في تطبيق الويب',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _amber),
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

  Widget _row(String label, String value, {bool ltr = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

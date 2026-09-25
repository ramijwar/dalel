import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';

/// ══════════════════════════════════════════════════════════════
/// شاشة الدخول — تبويبات مُنمّقة: تسجيل الدخول / حساب جديد
/// ══════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // ─── دخول ───
  final _loginPhone = TextEditingController();
  final _loginPass = TextEditingController();
  bool _obscureLogin = true;

  // ─── تسجيل ───
  final _regPhone = TextEditingController();
  final _regPass = TextEditingController();
  final _regName = TextEditingController();
  final _regBirth = TextEditingController();
  bool _obscureReg = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginPhone.dispose();
    _loginPass.dispose();
    _regPhone.dispose();
    _regPass.dispose();
    _regName.dispose();
    _regBirth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 34),

              // ─── الشعار ───
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.mapPin,
                    size: 36, color: Colors.white),
              ),
              const SizedBox(height: 17),
              const Text(
                'دليل الدير',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'سجّل الدخول لإدارة خدماتك',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),

              const SizedBox(height: 28),

              // ─── البطاقة والتبويبات ───
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  children: [
                    // شريط التبويبات المُنمّق
                    Container(
                      margin: const EdgeInsets.all(6),
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabs,
                        indicator: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppTheme.textMuted,
                        labelStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: const [
                          Tab(
                            icon: Icon(LucideIcons.logIn, size: 16),
                            text: 'دخول',
                            iconMargin: EdgeInsets.only(bottom: 2),
                          ),
                          Tab(
                            icon: Icon(LucideIcons.userPlus, size: 16),
                            text: 'حساب جديد',
                            iconMargin: EdgeInsets.only(bottom: 2),
                          ),
                        ],
                      ),
                    ),

                    // محتوى التبويبات
                    SizedBox(
                      height: _tabs.index == 0 ? 300 : 400,
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _buildLogin(auth),
                          _buildRegister(auth),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.arrowRight, size: 16),
                label: const Text('المتابعة كزائر'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════ تبويب الدخول ═══════════════
  Widget _buildLogin(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _loginPhone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              hintText: '09XXXXXXXX',
              prefixIcon: Icon(LucideIcons.phone, size: 18),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: _loginPass,
            obscureText: _obscureLogin,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: const Icon(LucideIcons.lock, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLogin ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 17,
                ),
                onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (auth.error != null) _errorBox(auth.error!),
          const Spacer(),
          FilledButton.icon(
            onPressed: auth.loading ? null : () => _doLogin(auth),
            icon: auth.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(LucideIcons.logIn, size: 18),
            label: Text(auth.loading ? 'جاري الدخول…' : 'تسجيل الدخول'),
          ),
        ],
      ),
    );
  }

  // ═══════════════ تبويب التسجيل ═══════════════
  Widget _buildRegister(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _regName,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'الاسم الكامل',
              prefixIcon: Icon(LucideIcons.user, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regPhone,
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
            controller: _regPass,
            obscureText: _obscureReg,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: const Icon(LucideIcons.lock, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureReg ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 17,
                ),
                onPressed: () => setState(() => _obscureReg = !_obscureReg),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regBirth,
            readOnly: true,
            onTap: () => _pickBirthDate(),
            decoration: const InputDecoration(
              labelText: 'تاريخ الميلاد (اختياري)',
              prefixIcon: Icon(LucideIcons.calendar, size: 18),
              suffixIcon: Icon(LucideIcons.chevronDown, size: 17),
            ),
          ),
          const SizedBox(height: 14),
          if (auth.error != null) _errorBox(auth.error!),
          const Spacer(),
          FilledButton.icon(
            onPressed: auth.loading ? null : () => _doRegister(auth),
            icon: auth.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(LucideIcons.userPlus, size: 18),
            label: Text(auth.loading ? 'جاري الإنشاء…' : 'إنشاء حساب'),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.closedBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.closed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, size: 15, color: AppTheme.closed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.closed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: now,
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (d != null) {
      _regBirth.text =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _doLogin(AuthProvider auth) async {
    final phone = _loginPhone.text.trim();
    final pass = _loginPass.text;

    if (phone.isEmpty) {
      _snack('أدخل رقم الهاتف');
      return;
    }
    if (pass.isEmpty) {
      _snack('أدخل كلمة المرور');
      return;
    }

    auth.clearError();
    final ok = await auth.login(phone, pass);
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      _snack('تم تسجيل الدخول بنجاح', success: true);
    }
  }

  Future<void> _doRegister(AuthProvider auth) async {
    final name = _regName.text.trim();
    final phone = _regPhone.text.trim();
    final pass = _regPass.text;
    final birth = _regBirth.text.trim();

    if (name.isEmpty) {
      _snack('أدخل الاسم الكامل');
      return;
    }
    if (phone.isEmpty) {
      _snack('أدخل رقم الهاتف');
      return;
    }
    if (pass.length < 6) {
      _snack('كلمة المرور يجب أن تكون ٦ أحرف على الأقل');
      return;
    }

    auth.clearError();
    final ok = await auth.register(
      phone: phone,
      password: pass,
      fullName: name,
      birthDate: birth.isEmpty ? null : birth,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      _snack('تم إنشاء الحساب بنجاح', success: true);
    }
  }

  void _snack(String msg, {bool success = false}) {
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// نظام التصميم — خلفية بيضاء مع لمسات أزرق فاتح
/// (مطابق لتصميم موقع الويب: أبيض + أزرق فاتح، وليس وضع ليلي)
class AppTheme {
  AppTheme._();

  // ─── الألوان الأساسية ───
  static const Color primary = Color(0xFF0EA5E9);
  static const Color primaryDark = Color(0xFF0284C7);
  static const Color primaryLight = Color(0xFFE0F2FE);
  static const Color primarySoft = Color(0xFFF0F9FF);

  static const Color accent = Color(0xFF38BDF8);
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF8FAFC);

  // ─── النصوص ───
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // ─── الحدود └───
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  // ─── حالات ───
  static const Color open = Color(0xFF16A34A);
  static const Color openBg = Color(0xFFDCFCE7);
  static const Color closed = Color(0xFFDC2626);
  static const Color closedBg = Color(0xFFFEE2E2);
  static const Color duty = Color(0xFF8B5E3C);
  static const Color dutyBg = Color(0xFFF5E6D3);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  static const double radiusSm = 10;
  static const double radius = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 26;

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryLight,
        secondary: accent,
        surface: surface,
        onSurface: textPrimary,
        error: danger,
        outline: border,
      ),

      // ─── شريط التطبيق ───
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
      ),

      // ─── البطاقات ───
      cardTheme: CardTheme(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── الأزرار ───
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: border,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          textStyle:
              GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          textStyle:
              GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle:
              GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      // ─── حقول الإدخال (مُنمّقة بحدود وحشو وحالة تركيز) ───
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: danger, width: 2),
        ),
        labelStyle: GoogleFonts.cairo(fontSize: 14, color: textSecondary),
        hintStyle: GoogleFonts.cairo(fontSize: 14, color: textMuted),
        helperStyle: GoogleFonts.cairo(fontSize: 12, color: textMuted),
        errorStyle: GoogleFonts.cairo(fontSize: 12, color: danger),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
      ),

      // ─── الشرائح والتبويبات ───
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        labelStyle: GoogleFonts.cairo(fontSize: 13, color: textPrimary),
        secondaryLabelStyle:
            GoogleFonts.cairo(fontSize: 13, color: Colors.white),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ─── شريط التنقل السفلي ───
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.06),
        indicatorColor: primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.cairo(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primary : textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? primary : textMuted, size: 23);
        }),
      ),

      dividerTheme:
          const DividerThemeData(color: border, thickness: 1, space: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: GoogleFonts.cairo(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm)),
      ),

      // ─── مربعات الحوار ───
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg)),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        contentTextStyle: GoogleFonts.cairo(fontSize: 14, color: textSecondary),
      ),

      // ─── أشرطة التقدم └───
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primaryLight,
      ),

      // ─── التبديلات ───
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? open : borderStrong),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      textTheme: GoogleFonts.cairoTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }

  /// ظل ناعم للبطاقات
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];

  /// ظل أقوى للعناصر المرتفعة
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.09),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}

/// امتدادات مساعدة للنصوص
extension TextStyleX on TextStyle {
  TextStyle get muted => copyWith(color: AppTheme.textMuted);
  TextStyle get secondary => copyWith(color: AppTheme.textSecondary);
  TextStyle w(FontWeight w) => copyWith(fontWeight: w);
  TextStyle size(double s) => copyWith(fontSize: s);
}

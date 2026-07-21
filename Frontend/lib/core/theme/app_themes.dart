import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — the single source of truth for the app's look & feel.
/// Every screen should pull colors/radius/spacing from here (via Theme.of
/// context) instead of hardcoding its own values.
class AppColors {
  // ✅ مقياس الأخضر الكامل (50-800) - نفس البالتة المطلوبة بالضبط. مصدر
  // وحيد لأي درجة أخضر بالتطبيق بدل ما نلوّن قيم عشوائية بكل شاشة.
  static const Color green50 = Color(0xFFEEF7F0);
  static const Color green100 = Color(0xFFD4EBD9);
  static const Color green200 = Color(0xFFAAD8B4);
  static const Color green300 = Color(0xFF7CBD8A);
  static const Color green400 = Color(0xFF4F9A5F);
  static const Color green500 = Color(0xFF2D7A3E);
  static const Color green600 = Color(0xFF166534);
  static const Color green700 = Color(0xFF0E4A25);
  static const Color green800 = Color(0xFF08391B);

  static const Color brand = green600;
  static const Color brandDark = green700;
  // أخضر ثانوي فاتح - للينكات/الأيقونات الثانوية (مش أزرار أساسية).
  static const Color secondaryBrand = green500;
  // خلفية الحالة "النشطة" بالقوائم الجانبية (nav item مختار) - نعناعي فاتح.
  static const Color secondaryContainer = green100;
  static const Color onSecondaryContainer = green700;
  // برتقالي - لأزرار الإجراء السريع (إضافة للسلة).
  static const Color accent = Color(0xFFFF6B35);
  // بني/كرملي دافئ - لشارات "عرض خاص" ونحوها، منفصل عن accent قصدًا.
  static const Color tertiary = Color(0xFF9A2F00);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFBA1A1A);

  static const Color lightBackground = Color(0xFFF7F9FB);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceLow = Color(0xFFF2F4F6);
  static const Color lightBorder = Color(0xFFE7E9EC);
  static const Color lightOutlineVariant = Color(0xFFBFC9C4);

  static const Color darkBackground = Color(0xFF0F1722);
  static const Color darkSurface = Color(0xFF1A2430);
  static const Color darkBorder = Color(0xFF2A3644);
}

class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

const _pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    TargetPlatform.linux: ZoomPageTransitionsBuilder(),
    TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
  },
);

OutlineInputBorder _inputBorder(Color color, {double width = 1.4}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );

final ThemeData appLightTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkSparkle.splashFactory,
  pageTransitionsTheme: _pageTransitions,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.light,
    error: AppColors.error,
  ),
  primaryColor: AppColors.brand,
  scaffoldBackgroundColor: AppColors.lightBackground,
  textTheme: GoogleFonts.cairoTextTheme().apply(
    bodyColor: const Color(0xFF1B1F23),
    displayColor: const Color(0xFF1B1F23),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.brand,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.cairo(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.lightSurface,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: const BorderSide(color: AppColors.lightBorder),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
      minimumSize: const Size(64, 54),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 0,
      textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.brand,
      minimumSize: const Size(64, 54),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      side: const BorderSide(color: AppColors.brand, width: 1.4),
      textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.brand,
      textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurface,
    // ✅ shade600 بدل shade500 - shade500 عالخلفية البيضاء نسبة تباينه تحت
    // حد WCAG AA (4.5:1)، بيخلي الـ placeholder شبه مختفي.
    hintStyle: GoogleFonts.cairo(color: Colors.grey.shade600, fontSize: 14),
    labelStyle: GoogleFonts.cairo(color: Colors.grey.shade700, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _inputBorder(AppColors.lightBorder),
    enabledBorder: _inputBorder(AppColors.lightBorder),
    focusedBorder: _inputBorder(AppColors.brand, width: 1.8),
    errorBorder: _inputBorder(AppColors.error),
    focusedErrorBorder: _inputBorder(AppColors.error, width: 1.8),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.brand.withValues(alpha: 0.08),
    selectedColor: AppColors.brand,
    labelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    side: BorderSide.none,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.lightSurface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    titleTextStyle: GoogleFonts.cairo(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1B1F23),
    ),
    contentTextStyle: GoogleFonts.cairo(
      fontSize: 14,
      color: const Color(0xFF44494F),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF1B1F23),
    contentTextStyle: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.lightSurface,
    selectedItemColor: AppColors.brand,
    unselectedItemColor: Colors.grey.shade500,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? AppColors.brand : null,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.brand.withValues(alpha: 0.4)
          : null,
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.selected) ? AppColors.brand : null,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.brand
          : Colors.grey.shade400,
    ),
  ),
  tabBarTheme: TabBarThemeData(
    labelColor: AppColors.brand,
    unselectedLabelColor: Colors.grey.shade500,
    indicatorColor: AppColors.brand,
    labelStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
    unselectedLabelStyle: GoogleFonts.cairo(fontSize: 14),
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.lightBorder,
    thickness: 1,
    space: 1,
  ),
  visualDensity: VisualDensity.standard,
);

final ThemeData appDarkTheme = ThemeData(
  useMaterial3: true,
  splashFactory: InkSparkle.splashFactory,
  pageTransitionsTheme: _pageTransitions,
  brightness: Brightness.dark,
  primaryColor: AppColors.brand,
  scaffoldBackgroundColor: AppColors.darkBackground,
  cardColor: AppColors.darkSurface,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.dark,
    error: AppColors.error,
  ).copyWith(surface: AppColors.darkSurface, onSurface: Colors.white),
  textTheme: GoogleFonts.cairoTextTheme(
    ThemeData.dark().textTheme,
  ).apply(bodyColor: Colors.white, displayColor: Colors.white),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.brandDark,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.cairo(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.darkSurface,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: const BorderSide(color: AppColors.darkBorder),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      minimumSize: const Size(64, 54),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      elevation: 0,
      textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size(64, 54),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      side: const BorderSide(color: AppColors.brand, width: 1.4),
      textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF6FE39B),
      textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurface,
    hintStyle: GoogleFonts.cairo(color: Colors.white38, fontSize: 14),
    labelStyle: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _inputBorder(AppColors.darkBorder),
    enabledBorder: _inputBorder(AppColors.darkBorder),
    focusedBorder: _inputBorder(AppColors.brand, width: 1.8),
    errorBorder: _inputBorder(AppColors.error),
    focusedErrorBorder: _inputBorder(AppColors.error, width: 1.8),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.darkSurface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    titleTextStyle: GoogleFonts.cairo(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
    contentTextStyle: GoogleFonts.cairo(fontSize: 14, color: Colors.white70),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.darkSurface,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF2A3644),
    contentTextStyle: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.darkSurface,
    selectedItemColor: const Color(0xFF6FE39B),
    unselectedItemColor: Colors.white54,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.brand,
  ),
  tabBarTheme: TabBarThemeData(
    labelColor: Colors.white,
    unselectedLabelColor: Colors.white54,
    indicatorColor: AppColors.brand,
    labelStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
    unselectedLabelStyle: GoogleFonts.cairo(fontSize: 14),
  ),
  dividerColor: AppColors.darkBorder,
  dividerTheme: const DividerThemeData(
    color: AppColors.darkBorder,
    thickness: 1,
    space: 1,
  ),
  visualDensity: VisualDensity.standard,
);

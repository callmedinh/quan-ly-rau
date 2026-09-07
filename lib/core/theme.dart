import 'package:flutter/material.dart';

/// Central palette — designed for high contrast + elderly readability.
class AppColors {
  AppColors._();

  /// Primary green (rau / tiền lời)
  static const Color primary = Color(0xFF2D6A4F);
  static const Color primaryDark = Color(0xFF1B4332);
  static const Color primaryLight = Color(0xFF95D5B2);
  static const Color primaryBg = Color(0xFFD8F3DC);

  /// Warm accents
  static const Color accent = Color(0xFFF4A261); // nút liên hệ / CTA phụ
  static const Color accentDark = Color(0xFFE76F51);
  static const Color gold = Color(0xFFE9C46A);

  /// Neutrals
  static const Color background = Color(0xFFF4F7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF16281D); // chữ chính
  static const Color inkSoft = Color(0xFF4E6B5A); // chữ phụ

  static const Color danger = Color(0xFFC0392B); // nợ / lỗ
  static const Color dangerBg = Color(0xFFFDEBEA);
  static const Color info = Color(0xFF2F6FB2);
  static const Color infoBg = Color(0xFFE8F1FA);
}

/// Text styles — every style deliberately >= 16–18pt; numbers >= 24pt.
class AppStyles {
  AppStyles._();

  static const double bodySize = 18;

  /// AppBar / screen title.
  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.2,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: bodySize,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
    height: 1.35,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: bodySize,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const TextStyle hint = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.inkSoft,
  );

  /// Big money numbers (>= 24pt).
  static const TextStyle amount = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.1,
  );

  static const TextStyle amountSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.1,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  );
}

ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryBg,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.accent,
    onSecondary: AppColors.ink,
    secondaryContainer: Color(0xFFFFE8D6),
    onSecondaryContainer: AppColors.accentDark,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.inkSoft,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkRipple.splashFactory,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppStyles.title,
      iconTheme: IconThemeData(size: 30, color: AppColors.ink),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(
        fontSize: 20,
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w500,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger, width: 3),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primaryBg,
      height: 78,
      elevation: 6,
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      iconTheme: WidgetStatePropertyAll(
        const IconThemeData(size: 32, color: AppColors.inkSoft),
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primaryDark,
      contentTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFDDE6DE),
      thickness: 1,
      space: 1,
    ),
  );
}

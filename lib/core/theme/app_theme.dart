import 'package:flutter/material.dart';

/// Brand color tokens — disinkronkan dengan `src/styles/theme.css` di frontend web.
abstract class AppColors {
  static const brand50 = Color(0xFFFDF2F2);
  static const brand100 = Color(0xFFFBE0E0);
  static const brand200 = Color(0xFFF5C2C2);
  static const brand500 = Color(0xFF9A1F1F);
  static const brand600 = Color(0xFF7A1618);
  static const brand700 = Color(0xFF5C1012);

  static const gold100 = Color(0xFFFDF3D8);
  static const gold500 = Color(0xFFC9A227);
  static const gold600 = Color(0xFFAB8720);

  static const success50 = Color(0xFFF0FDF4);
  static const success600 = Color(0xFF16A34A);
  static const success700 = Color(0xFF15803D);

  static const danger50 = Color(0xFFFEF2F2);
  static const danger100 = Color(0xFFFEE2E2);
  static const danger600 = Color(0xFFDC2626);
  static const danger700 = Color(0xFFB91C1C);

  static const neutral50 = Color(0xFFF8FAFC);
  static const neutral100 = Color(0xFFF1F5F9);
  static const neutral200 = Color(0xFFE2E8F0);
  static const neutral300 = Color(0xFFCBD5E1);
  static const neutral400 = Color(0xFF94A3B8);
  static const neutral500 = Color(0xFF64748B);
  static const neutral600 = Color(0xFF475569);
  static const neutral700 = Color(0xFF334155);
  static const neutral900 = Color(0xFF0F172A);
}

abstract class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand500,
      brightness: Brightness.light,
      primary: AppColors.brand500,
      onPrimary: Colors.white,
      secondary: AppColors.gold600,
      onSecondary: Colors.white,
      error: AppColors.danger600,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.neutral900,
    );

    final radius16 = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.neutral50,
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: AppColors.neutral700,
            displayColor: AppColors.neutral900,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.neutral900,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.neutral400, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.neutral500, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: const BorderSide(color: AppColors.brand500, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: const BorderSide(color: AppColors.danger600),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: const BorderSide(color: AppColors.danger600, width: 1.6),
        ),
        errorStyle: const TextStyle(color: AppColors.danger700, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand500,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brand500.withOpacity(0.4),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.neutral700,
          side: const BorderSide(color: AppColors.neutral200),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand600,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.neutral50,
          border: OutlineInputBorder(borderRadius: radius16),
        ),
      ),
    );
  }
}

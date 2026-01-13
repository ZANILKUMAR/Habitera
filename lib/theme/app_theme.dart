import 'package:flutter/material.dart';

class AppColors {
  // Neutral palette - calm and premium
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF9F9F9);
  static const Color neutral100 = Color(0xFFF3F3F3);
  static const Color neutral200 = Color(0xFFE8E8E8);
  static const Color neutral300 = Color(0xFFDEDEDE);
  static const Color neutral400 = Color(0xFFC4C4C4);
  static const Color neutral500 = Color(0xFF8B8B8B);
  static const Color neutral600 = Color(0xFF5A5A5A);
  static const Color neutral700 = Color(0xFF3C3C3C);
  static const Color neutral800 = Color(0xFF242424);
  static const Color neutral900 = Color(0xFF0F0F0F);

  // Soft accent colors for habits
  static const Color red = Color(0xFFFF6B6B);
  static const Color orange = Color(0xFFFFA94D);
  static const Color yellow = Color(0xFFFFD93D);
  static const Color green = Color(0xFF6BCB77);
  static const Color blue = Color(0xFF4D96FF);
  static const Color purple = Color(0xFFA78BFA);
  static const Color pink = Color(0xFFFF88CC);
  static const Color teal = Color(0xFF4ECDC4);

  // Semantic
  static const Color success = Color(0xFF6BCB77);
  static const Color warning = Color(0xFFFFA94D);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF4D96FF);

  static const List<Color> habitColors = [
    red,
    orange,
    yellow,
    green,
    blue,
    purple,
    pink,
    teal,
  ];
}

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: AppColors.neutral50,
        onSurface: AppColors.neutral900,
        primary: AppColors.neutral900,
        secondary: AppColors.neutral600,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.neutral0,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.neutral0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.neutral900,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.neutral50,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.neutral200,
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neutral900,
          foregroundColor: AppColors.neutral0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.neutral900,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.neutral900,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.neutral900,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.neutral600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.neutral300,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.neutral300,
            width: 1,
          ),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.neutral800,
        onSurface: AppColors.neutral0,
        primary: AppColors.neutral0,
        secondary: AppColors.neutral300,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.neutral900,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.neutral900,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.neutral0,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.neutral800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.neutral700,
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neutral0,
          foregroundColor: AppColors.neutral900,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.neutral0,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.neutral0,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.neutral0,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.neutral400,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral700,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.neutral600,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.neutral600,
            width: 1,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AppColors {
  static const cerulean = Color(0xFF007BA7);
  static const ceruleanDark = Color(0xFF075A78);
  static const navy = Color(0xFF04364A);
  static const sky = Color(0xFF54B9D3);
  static const ice = Color(0xFFF3F9FB);
  static const pale = Color(0xFFE5F3F7);
  static const border = Color(0xFFD5E8EE);
  static const text = Color(0xFF17343F);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.cerulean,
    brightness: Brightness.light,
    primary: AppColors.ceruleanDark,
    secondary: AppColors.cerulean,
    surface: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ice,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ice,
      foregroundColor: AppColors.navy,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: AppColors.ceruleanDark),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cerulean, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ceruleanDark,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.ceruleanDark,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.text),
      bodyMedium: TextStyle(color: AppColors.text),
      titleLarge: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold),
    ),
  );
}

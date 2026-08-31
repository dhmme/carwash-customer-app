import 'package:flutter/material.dart';

class AppColors {
  static const cerulean = Color(0xFF20A7D1);
  static const ceruleanDark = Color(0xFF087EA4);
  static const navy = Color(0xFF041F2A);
  static const sky = Color(0xFF66C6DF);
  static const ice = Color(0xFF071E28);
  static const pale = Color(0xFF123B4A);
  static const surface = Color(0xFF0D2D3A);
  static const border = Color(0xFF215364);
  static const text = Color(0xFFEAF7FA);
  static const muted = Color(0xFFA9CBD5);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.cerulean,
    brightness: Brightness.dark,
    primary: AppColors.cerulean,
    secondary: AppColors.cerulean,
    surface: AppColors.surface,
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
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.sky),
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
        backgroundColor: AppColors.cerulean,
        foregroundColor: AppColors.navy,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.cerulean,
      foregroundColor: AppColors.navy,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.text),
      bodyMedium: TextStyle(color: AppColors.text),
      titleLarge: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
      bodySmall: TextStyle(color: AppColors.muted),
    ),
    dividerColor: AppColors.border,
    iconTheme: const IconThemeData(color: AppColors.sky),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.pale,
      selectedColor: AppColors.ceruleanDark,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(color: AppColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

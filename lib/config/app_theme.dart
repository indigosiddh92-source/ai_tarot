import 'package:flutter/material.dart';

/// Мистический минимализм: тёмный фон, фиолетовая основа,
/// золотой акцент. Цвета заданы константами с готовой прозрачностью,
/// без устаревших хелперов вроде withOpacity.
class AppTheme {
  const AppTheme._();

  static const Color background = Color(0xFF0E0B16);
  static const Color surface = Color(0xFF1A1424);
  static const Color purple = Color(0xFF7C5CD6);
  static const Color gold = Color(0xFFE7C06A);

  static const Color textSoft = Color(0x99FFFFFF);
  static const Color textFaint = Color(0x61FFFFFF);
  static const Color hairline = Color(0x14FFFFFF);

  static const Color goldTint = Color(0x14E7C06A);
  static const Color goldEdge = Color(0x59E7C06A);
  static const Color dangerTint = Color(0x14FF5252);
  static const Color dangerEdge = Color(0x59FF5252);
  static const Color danger = Color(0xFFFF5252);

  static ThemeData get dark {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.dark,
    ).copyWith(
      surface: background,
      primary: purple,
      secondary: gold,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textFaint),
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: purple, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: goldEdge),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: hairline, space: 32),
    );
  }
}

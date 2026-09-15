import 'package:flutter/material.dart';

/// Material 3 seed theme for Lumen Desk (dark-first design).
class AppTheme {
  static const seed = Colors.indigo;

  static Color profileAccent(String name) {
    switch (name) {
      case 'admin':
        return Colors.indigoAccent;
      case 'kid':
        return Colors.teal;
      default:
        return Colors.amber;
    }
  }

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        sliderTheme: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.onlyForDiscrete,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        sliderTheme: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.onlyForDiscrete,
        ),
      );
}

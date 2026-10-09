import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF050607);
  static const sidebar = Color(0xFF090B0F);
  static const surface = Color(0xFF101318);
  static const surface2 = Color(0xFF171B22);
  static const surface3 = Color(0xFF1D222B);
  static const red = Color(0xFFE50914);
  static const redSoft = Color(0xFF351014);
  static const green = Color(0xFF36E0A0);
  static const cyan = Color(0xFF52C7FF);
  static const amber = Color(0xFFFFB84D);
  static const purple = Color(0xFFA78BFA);
  static const muted = Color(0xFF8D96A5);
  static const border = Color(0xFF222832);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: const ColorScheme.dark(
        primary: red,
        secondary: green,
        surface: surface,
        error: Color(0xFFFF5A63),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFFF5F7FA),
        displayColor: const Color(0xFFF5F7FA),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4A515F), width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFFD8DCE4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF232933),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: red,
        thumbColor: red,
        inactiveTrackColor: Color(0xFF2A303A),
      ),
    );
  }
}

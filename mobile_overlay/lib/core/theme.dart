import 'package:flutter/material.dart';

class AppTheme {
  // ProfitGPS premium identity — light business workspace with navy framing.
  static const midnight = Color(0xFF061B31);
  static const midnight2 = Color(0xFF0A2A49);
  static const background = Color(0xFFF5F7FA);
  static const sidebar = Color(0xFF061B31);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF7F9FC);
  static const surface3 = Color(0xFFEEF3F8);
  static const primary = Color(0xFF176BFF);
  static const primarySoft = Color(0xFFE8F1FF);
  static const emerald = Color(0xFF0CA86E);
  static const green = emerald;
  static const cyan = Color(0xFF2D86FF);
  static const gold = Color(0xFFD5A234);
  static const amber = gold;
  static const purple = Color(0xFF7556D8);
  static const danger = Color(0xFFE54C5B);
  static const red = danger;
  static const redSoft = Color(0xFFFFEEF0);
  static const muted = Color(0xFF66788A);
  static const border = Color(0xFFDCE5EE);

  static const warmBackground = background;
  static const warmSurface = surface;
  static const lightGrey = Color(0xFFF1F5F9);
  static const ink = Color(0xFF0C1D30);
  static const lightMuted = muted;
  static const lightBorder = border;

  static BoxDecoration lightCardDecoration({double radius = 16}) => BoxDecoration(
        color: warmSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: lightBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0C061B31), blurRadius: 16, offset: Offset(0, 5)),
        ],
      );

  // Kept as dark() for source compatibility; the approved mobile baseline is
  // intentionally a light business workspace with navy navigation/header.
  static ThemeData dark() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dialogTheme: const DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: emerald,
        surface: surface,
        error: danger,
        onSurface: ink,
        onPrimary: Colors.white,
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: midnight,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: const Color(0x12061B31),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(color: muted),
        prefixIconColor: const Color(0xFF5F7185),
        suffixIconColor: const Color(0xFF5F7185),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: border),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primary)),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFF42566B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: midnight,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: border,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: primarySoft,
        labelStyle: const TextStyle(color: ink),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: muted,
        indicatorColor: primary,
        dividerColor: border,
      ),
      checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primary : Colors.white)),
    );
  }
}

import 'package:flutter/material.dart';

class AppTheme {
  static const midnight = Color(0xFF071A2D);
  static const midnight2 = Color(0xFF0A2743);
  static const background = Color(0xFF071A2D);
  static const sidebar = Color(0xFF06172A);
  static const surface = Color(0xFF10263D);
  static const surface2 = Color(0xFF16324F);
  static const surface3 = Color(0xFF1C3A58);
  static const primary = Color(0xFF246BFE);
  static const primarySoft = Color(0xFF153B78);
  static const emerald = Color(0xFF12A66A);
  static const green = emerald;
  static const cyan = Color(0xFF3D8BFF);
  static const gold = Color(0xFFD9A441);
  static const amber = gold;
  static const purple = Color(0xFF7565D8);
  static const danger = Color(0xFFDF4C5C);
  static const red = danger;
  static const redSoft = Color(0xFF3B1D26);
  static const muted = Color(0xFF9EB0C3);
  static const border = Color(0xFF28445F);
  static const warmBackground = Color(0xFFF7F6F2);
  static const warmSurface = Color(0xFFFFFFFF);
  static const lightGrey = Color(0xFFF1F4F7);
  static const ink = Color(0xFF0B1B2D);
  static const lightMuted = Color(0xFF65758A);
  static const lightBorder = Color(0xFFE1E7EE);

  static BoxDecoration lightCardDecoration({double radius = 18}) => BoxDecoration(
        color: warmSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: lightBorder),
        boxShadow: const [BoxShadow(color: Color(0x0D071A2D), blurRadius: 18, offset: Offset(0, 6))],
      );

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: const ColorScheme.dark(primary: primary, secondary: emerald, surface: surface, error: danger),
      textTheme: base.textTheme.apply(bodyColor: const Color(0xFFF7FAFD), displayColor: const Color(0xFFF7FAFD)),
      appBarTheme: const AppBarTheme(backgroundColor: midnight, foregroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
      cardTheme: CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero, shadowColor: Colors.black38, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: border))),
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primary, width: 1.2)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 46), side: const BorderSide(color: border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)))),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: const Color(0xFFDCE7F2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      snackBarTheme: const SnackBarThemeData(backgroundColor: Color(0xFF10263D), contentTextStyle: TextStyle(color: Colors.white)),
      sliderTheme: const SliderThemeData(activeTrackColor: primary, thumbColor: primary, inactiveTrackColor: Color(0xFF28445F)),
      chipTheme: base.chipTheme.copyWith(selectedColor: primarySoft, side: const BorderSide(color: border)),
    );
  }
}

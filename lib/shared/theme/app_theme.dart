import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const background = Color(0xFFECECEC);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF0E7490);
  static const primaryDark = Color(0xFF0A5A6E);
  static const text = Color(0xFF111111);
  static const muted = Color(0xFF444444);
  static const border = Color(0xFF111111);
  static const borderLight = Color(0xFFCCCCCC);
  static const danger = Color(0xFFB91C1C);
  static const success = Color(0xFF15803D);

  static ThemeData light({Color brandColor = primary}) {
    final brandDark = Color.lerp(brandColor, Colors.black, 0.22)!;
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: brandColor,
      onPrimary: Colors.white,
      secondary: brandDark,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: background,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: border, width: 2)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: brandColor, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: border, width: 2),
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandColor,
          shape: const RoundedRectangleBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: brandColor,
        backgroundColor: surface,
        side: const BorderSide(color: border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(const RoundedRectangleBorder()),
          side: WidgetStateProperty.resolveWith(
            (_) => const BorderSide(color: border, width: 2),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

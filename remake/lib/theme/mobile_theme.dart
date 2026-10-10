import 'package:flutter/material.dart';

/// Presentation palette, deliberately separate from the source EGA table.
abstract final class MobileTheme {
  static const background = Color(0xFFFBF8F0);
  static const surface = Color(0xFFFFFCF5);
  static const ink = Color(0xFF112E50);
  static const muted = Color(0xFF56677C);
  static const line = Color(0xFFE6DDCE);
  static const mint = Color(0xFF359C91);
  static const mintLight = Color(0xFFE2F3EB);
  static const gold = Color(0xFFFFD16F);
  static const goldLine = Color(0xFFE6AA42);
  static const blue = Color(0xFF3D9CE8);
  static const danger = Color(0xFFB64651);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'LoreSans',
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: mint,
      surface: surface,
      onSurface: ink,
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: ink, fontSize: 15, height: 1.5),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: line),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: ink,
        minimumSize: const Size(48, 48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: line),
      ),
    ),
  );

  static BoxDecoration card({Color? color, bool selected = false}) =>
      BoxDecoration(
        color: color ?? (selected ? mintLight : surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? mint : line,
          width: selected ? 2 : 1,
        ),
      );
}

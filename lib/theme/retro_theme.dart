import 'package:flutter/material.dart';

/// 1993년 당시 DOS VGA 16색 팔레트 및 레트로 스타일 정의
class RetroTheme {
  // Classic 16-color VGA Palette
  static const Color black = Color(0xFF000000);
  static const Color blue = Color(0xFF0000AA);
  static const Color green = Color(0xFF00AA00);
  static const Color cyan = Color(0xFF00AAAA);
  static const Color red = Color(0xFFAA0000);
  static const Color magenta = Color(0xFFAA00AA);
  static const Color brown = Color(0xFFAA5500);
  static const Color lightGray = Color(0xFFAAAAAA);
  static const Color darkGray = Color(0xFF555555);
  static const Color lightBlue = Color(0xFF5555FF);
  static const Color lightGreen = Color(0xFF55FF55);
  static const Color lightCyan = Color(0xFF55FFFF);
  static const Color lightRed = Color(0xFFFF5555);
  static const Color lightMagenta = Color(0xFFFF55FF);
  static const Color yellow = Color(0xFFFFFF55);
  static const Color white = Color(0xFFFFFFFF);

  // Backgrounds & Borders
  static const Color background = Color(0xFF000010);
  static const Color viewportBg = Color(0xFF050515);
  static const Color panelBg = Color(0xFF000022);
  static const Color borderColor = Color(0xFF5555FF);
  static const Color borderHighlight = Color(0xFF55FFFF);

  // Typography
  static const TextStyle dosFont = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    height: 1.25,
    letterSpacing: 0.5,
    color: white,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle headerFont = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    color: yellow,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle logFont = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    height: 1.3,
    color: lightCyan,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle alertFont = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    color: lightRed,
    fontWeight: FontWeight.bold,
  );
}

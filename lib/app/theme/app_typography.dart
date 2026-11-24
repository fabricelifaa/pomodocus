import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const family = 'Manrope';

  static const tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(Color ink, Color muted) {
    TextStyle s(double size, FontWeight w, {Color? c, double? h, double? ls}) =>
        TextStyle(
          fontFamily: family,
          fontSize: size,
          fontWeight: w,
          color: c ?? ink,
          height: h,
          letterSpacing: ls,
        );
    return TextTheme(
      displayLarge: s(72, FontWeight.w700, h: 1, ls: -2),
      displayMedium: s(48, FontWeight.w700, h: 1.05, ls: -1.2),
      displaySmall: s(36, FontWeight.w700, h: 1.1, ls: -0.8),
      headlineMedium: s(28, FontWeight.w800, h: 1.15, ls: -0.6),
      headlineSmall: s(22, FontWeight.w700, h: 1.2, ls: -0.3),
      titleLarge: s(20, FontWeight.w700, h: 1.25, ls: -0.2),
      titleMedium: s(16, FontWeight.w700, h: 1.3),
      titleSmall: s(14, FontWeight.w700, h: 1.3),
      bodyLarge: s(16, FontWeight.w500, h: 1.45),
      bodyMedium: s(14, FontWeight.w500, h: 1.45),
      bodySmall: s(12.5, FontWeight.w500, c: muted, h: 1.4),
      labelLarge: s(14, FontWeight.w700, ls: 0.1),
      labelMedium: s(12, FontWeight.w600, ls: 0.2),
      labelSmall: s(11, FontWeight.w700, c: muted, ls: 1.2),
    );
  }
}

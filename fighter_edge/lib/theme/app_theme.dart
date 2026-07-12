import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Spacing tokens (4pt scale).
class Insets {
  Insets._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
}

class Radii {
  Radii._();
  static const double card = 20;
  static const double button = 14;
  static const double chip = 100;
}

class AppTheme {
  AppTheme._();

  /// Condensed athletic font for headings / big numbers.
  static TextStyle display(double size,
      {FontWeight weight = FontWeight.w700, Color? color, double? spacing}) {
    return GoogleFonts.oswald(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      letterSpacing: spacing,
      height: 1.05,
    );
  }

  /// Body / UI font.
  static TextStyle body(double size,
      {FontWeight weight = FontWeight.w500, Color? color, double? spacing}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      letterSpacing: spacing,
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerColor: AppColors.border,
      splashColor: AppColors.primarySoft,
      highlightColor: Colors.transparent,
    );
  }
}

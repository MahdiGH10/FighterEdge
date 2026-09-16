import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App-wide accessibility adaptation for FIGHTER EDGE.
///
/// Most of the app uses explicit brand text styles through `AppType`, so the
/// native accessibility switches need a single place to be interpreted instead
/// of scattered one-off checks. Widgets can use [adjustStyle] and the color
/// helpers when they need context-aware presentation, while [builder] applies
/// the same intent to Material widgets that read from Theme.
class AppAccessibility {
  AppAccessibility._();

  static Widget builder(BuildContext context, Widget? child) {
    final media = MediaQuery.maybeOf(context);
    final boldText = media?.boldText ?? false;
    final highContrast = media?.highContrast ?? false;

    if (!boldText && !highContrast) return child ?? const SizedBox.shrink();

    final base = Theme.of(context);
    final colorScheme = highContrast
        ? base.colorScheme.copyWith(
            onSurface: AppColors.textPrimary,
            onSurfaceVariant: AppColors.textPrimary,
            outline: AppColors.borderStrong,
            outlineVariant: AppColors.textSecondary,
          )
        : base.colorScheme;

    return Theme(
      data: base.copyWith(
        colorScheme: colorScheme,
        textTheme: _adjustTextTheme(base.textTheme, boldText: boldText),
        primaryTextTheme:
            _adjustTextTheme(base.primaryTextTheme, boldText: boldText),
        dividerColor: highContrast ? AppColors.borderStrong : base.dividerColor,
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  static TextStyle adjustStyle(BuildContext context, TextStyle style) {
    final boldText = MediaQuery.boldTextOf(context);
    final highContrast = MediaQuery.highContrastOf(context);
    return style.copyWith(
      fontWeight: boldText ? _stronger(style.fontWeight) : style.fontWeight,
      color: highContrast ? _highContrastColor(style.color) : style.color,
    );
  }

  static Color textSecondary(BuildContext context) =>
      MediaQuery.highContrastOf(context)
          ? AppColors.textPrimary
          : AppColors.textSecondary;

  static Color textMuted(BuildContext context) =>
      MediaQuery.highContrastOf(context)
          ? AppColors.textSecondary
          : AppColors.textMuted;

  static Color border(BuildContext context) =>
      MediaQuery.highContrastOf(context)
          ? AppColors.borderStrong
          : AppColors.border;

  static Color accentText(BuildContext context) =>
      MediaQuery.highContrastOf(context)
          ? AppColors.primaryBright
          : AppColors.accentText;

  /// The only role we intentionally clamp. The round timer numeral is a
  /// dashboard-sized object, not paragraph text; at 200% it would crowd out the
  /// actual controls. Body, labels, chips and forms keep the user's full scale.
  static TextScaler heroNumeralScaler(BuildContext context) {
    final requested = MediaQuery.textScalerOf(context).scale(1);
    return TextScaler.linear(requested.clamp(1.0, 1.25));
  }

  static TextTheme _adjustTextTheme(
    TextTheme theme, {
    required bool boldText,
  }) {
    if (!boldText) return theme;
    return theme.copyWith(
      displayLarge: _adjustThemeStyle(theme.displayLarge),
      displayMedium: _adjustThemeStyle(theme.displayMedium),
      displaySmall: _adjustThemeStyle(theme.displaySmall),
      headlineLarge: _adjustThemeStyle(theme.headlineLarge),
      headlineMedium: _adjustThemeStyle(theme.headlineMedium),
      headlineSmall: _adjustThemeStyle(theme.headlineSmall),
      titleLarge: _adjustThemeStyle(theme.titleLarge),
      titleMedium: _adjustThemeStyle(theme.titleMedium),
      titleSmall: _adjustThemeStyle(theme.titleSmall),
      bodyLarge: _adjustThemeStyle(theme.bodyLarge),
      bodyMedium: _adjustThemeStyle(theme.bodyMedium),
      bodySmall: _adjustThemeStyle(theme.bodySmall),
      labelLarge: _adjustThemeStyle(theme.labelLarge),
      labelMedium: _adjustThemeStyle(theme.labelMedium),
      labelSmall: _adjustThemeStyle(theme.labelSmall),
    );
  }

  static TextStyle? _adjustThemeStyle(TextStyle? style) {
    if (style == null) return null;
    return style.copyWith(fontWeight: _stronger(style.fontWeight));
  }

  static FontWeight _stronger(FontWeight? weight) {
    final value = weight?.value ?? FontWeight.w500.value;
    final stronger = (value + 100).clamp(400, 700);
    return FontWeight.values.firstWhere(
      (candidate) => candidate.value == stronger,
      orElse: () => FontWeight.w700,
    );
  }

  static Color? _highContrastColor(Color? color) {
    if (color == null) return null;
    if (color == AppColors.textSecondary) return AppColors.textPrimary;
    if (color == AppColors.textMuted) return AppColors.textSecondary;
    if (color == AppColors.border) return AppColors.borderStrong;
    return color;
  }
}

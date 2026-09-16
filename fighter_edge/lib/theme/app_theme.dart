import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Spacing tokens (4pt scale).
class Insets {
  Insets._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;
}

class Radii {
  Radii._();
  static const double card = 16;
  static const double button = 14;
  static const double chip = 100;
  static const double nav = 24;
}

/// A [Curve] driven by a real spring simulation.
///
/// Cubic curves always take exactly their allotted time and ease out the same
/// way regardless of distance; a spring settles like a physical object, which
/// is most of what "fluid" means on iOS. The simulation is normalized so it
/// starts at 0 and lands exactly on 1.
class SpringCurve extends Curve {
  SpringCurve({double stiffness = 380, double damping = 28, double mass = 1})
      : _simulation = SpringSimulation(
          SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
          0,
          1,
          0,
        );

  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) {
    // Normalize: the simulation approaches 1 asymptotically, so rescale by its
    // value at t=1 to guarantee the animation actually arrives.
    final end = _simulation.x(1);
    if (end == 0) return t;
    return _simulation.x(t) / end;
  }
}

class MotionTokens {
  MotionTokens._();

  // Durations
  static const Duration press = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration reveal = Duration(milliseconds: 380);

  /// Per-item offset for staggered entrances. A stagger is one shared duration
  /// with offset *delays* — not, as before, different durations starting
  /// together, which made everything move at once and finish raggedly.
  static const Duration stagger = Duration(milliseconds: 40);

  /// Legacy emphasized cubic. Retained for the page transition; new work should
  /// reach for [snap] or [settle].
  static const Curve emphasized = Cubic(0.2, 0.8, 0.2, 1);

  /// Crisp and quick — chips, toggles, tab switches.
  static final Curve snap = SpringCurve(stiffness: 380, damping: 28);

  /// Softer arrival — cards, sheets, reveals.
  static final Curve settle = SpringCurve(stiffness: 220, damping: 30);
}

class AppTheme {
  AppTheme._();

  /// Condensed athletic font for headings / big numbers.
  ///
  /// Prefer a named role on [AppType]: `AppType.title1()`, `AppType.display()`.
  /// Sizes passed here snap to the nearest role.
  @Deprecated('Use a named role on AppType instead of passing a size.')
  static TextStyle display(double size,
      {FontWeight weight = FontWeight.w700, Color? color, double? spacing}) {
    if (size <= 19) return AppType.title2(color: color, spacing: spacing);
    if (size <= 25) return AppType.title1(color: color, spacing: spacing);
    if (size <= 40) return AppType.largeTitle(color: color, spacing: spacing);
    if (size <= 56) return AppType.display(color: color, spacing: spacing);
    return AppType.heroNumeral(color: color, spacing: spacing);
  }

  /// Body / UI font.
  ///
  /// Prefer a named role on [AppType]: `AppType.body()`, `AppType.subhead()`.
  /// Sizes passed here snap to the nearest role.
  @Deprecated('Use a named role on AppType instead of passing a size.')
  static TextStyle body(double size,
      {FontWeight weight = FontWeight.w500, Color? color, double? spacing}) {
    if (size <= 11) {
      return AppType.micro(weight: weight, color: color, spacing: spacing);
    }
    if (size <= 13) {
      return AppType.subhead(weight: weight, color: color, spacing: spacing);
    }
    if (size <= 15) {
      return AppType.callout(weight: weight, color: color, spacing: spacing);
    }
    return AppType.body(weight: weight, color: color, spacing: spacing);
  }

  static ColorScheme _colorScheme() {
    return const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.premium,
      onSecondary: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.backgroundRaised,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceAlt,
      surfaceContainerHighest: AppColors.surfaceElevated,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderStrong,
      error: AppColors.negative,
      onError: Colors.white,
    );
  }

  /// The full Material text theme, mapped onto the app's roles so Material
  /// widgets inherit the system instead of falling back to defaults.
  static TextTheme _textTheme() {
    return TextTheme(
      displayLarge: AppType.display(),
      displayMedium: AppType.largeTitle(),
      displaySmall: AppType.largeTitle(),
      headlineLarge: AppType.largeTitle(),
      headlineMedium: AppType.title1(),
      headlineSmall: AppType.title1(),
      titleLarge: AppType.title1(),
      titleMedium: AppType.title2(),
      titleSmall: AppType.headline(),
      bodyLarge: AppType.body(),
      bodyMedium: AppType.callout(),
      bodySmall: AppType.subhead(),
      labelLarge: AppType.headline(),
      labelMedium: AppType.subhead(),
      labelSmall: AppType.micro(),
    );
  }

  static ThemeData dark() {
    final scheme = _colorScheme();
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      textTheme: _textTheme(),
      primaryTextTheme: _textTheme(),
      dividerColor: AppColors.border,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        space: 1,
        thickness: 1,
      ),
      // The ink ripple is a Material signature, and on dark premium surfaces it
      // reads as an Android tell. Every tappable surface in the app now answers
      // with PressScale (press-down scale + haptic) instead, so the ripple is
      // switched off globally rather than fought widget by widget.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FighterEdgePageTransitionsBuilder(),
          TargetPlatform.iOS: _FighterEdgePageTransitionsBuilder(),
          TargetPlatform.macOS: _FighterEdgePageTransitionsBuilder(),
          TargetPlatform.windows: _FighterEdgePageTransitionsBuilder(),
          TargetPlatform.linux: _FighterEdgePageTransitionsBuilder(),
        },
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}

class _FighterEdgePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FighterEdgePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == Navigator.defaultRouteName ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: MotionTokens.emphasized,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

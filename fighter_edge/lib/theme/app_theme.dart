import 'package:flutter/material.dart';

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
  static const double card = 16;
  static const double button = 14;
  static const double chip = 100;
  static const double nav = 24;
}

class MotionTokens {
  MotionTokens._();
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration reveal = Duration(milliseconds: 420);
  static const Curve emphasized = Cubic(0.2, 0.8, 0.2, 1);
}

class AppTheme {
  AppTheme._();

  /// Condensed athletic font for headings / big numbers.
  static TextStyle display(double size,
      {FontWeight weight = FontWeight.w700, Color? color, double? spacing}) {
    return TextStyle(
      fontFamily: 'Oswald',
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
    return TextStyle(
      fontFamily: 'Inter',
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
        error: AppColors.negative,
      ),
      textTheme: base.textTheme
          .apply(
            fontFamily: 'Inter',
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            displayLarge: display(32),
            displayMedium: display(28),
            displaySmall: display(24),
          ),
      dividerColor: AppColors.border,
      splashColor: AppColors.primarySoft,
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

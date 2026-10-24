import 'package:flutter/widgets.dart';

/// How much of the V2 glass look a device gets.
enum GlassLevel {
  /// Real blur on the navigation layer (nav, collapsed header, sheets), tinted
  /// hero cards on the static glow.
  full,

  /// No blur anywhere. Navigation uses a near-opaque tint; hero cards keep the
  /// tint, rim and inner light, which never needed a blur.
  tinted,

  /// Opaque surfaces and no glow. Same layout.
  solid;

  /// True when this level draws a real backdrop blur.
  bool get blurs => this == full;

  /// True when hero cards draw their translucent tint.
  bool get tints => this != solid;

  /// The lower of two levels.
  GlassLevel orLower(GlassLevel other) => index >= other.index ? this : other;
}

/// Decides the [GlassLevel] from the user's setting, the system accessibility
/// flags and what the device proved it can draw.
///
/// Flutter exposes no "reduce transparency" flag, so `MediaQuery.highContrast`
/// stands in for it, next to the app's own setting.
///
/// | Cause | Level |
/// |---|---|
/// | none | [GlassLevel.full] |
/// | frame probe saw p90 raster above 16 ms | [GlassLevel.tinted] (drops the blur, the expensive part) |
/// | "Reduce transparency" setting | [GlassLevel.solid] |
/// | high contrast | [GlassLevel.solid] |
///
/// Causes combine by taking the lowest level.
@immutable
class GlassPolicy {
  const GlassPolicy({this.reduceTransparency = false, this.slowFrames = false});

  /// The "Reduce transparency" setting.
  final bool reduceTransparency;

  /// The frame probe measured p90 raster time above its threshold.
  final bool slowFrames;

  /// The level these inputs give. Pure, so it is easy to test.
  GlassLevel resolve({required bool highContrast}) {
    var level = GlassLevel.full;
    if (slowFrames) level = level.orLower(GlassLevel.tinted);
    if (reduceTransparency || highContrast) level = GlassLevel.solid;
    return level;
  }

  @override
  bool operator ==(Object other) =>
      other is GlassPolicy &&
      other.reduceTransparency == reduceTransparency &&
      other.slowFrames == slowFrames;

  @override
  int get hashCode => Object.hash(reduceTransparency, slowFrames);

  /// The level for [context]: the app-wide [GlassPolicyScope] (or the default
  /// policy when there is none, as in a bare widget test) and the current
  /// `MediaQuery.highContrast`.
  static GlassLevel of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<GlassPolicyScope>();
    return (scope?.policy ?? const GlassPolicy()).resolve(
      highContrast: MediaQuery.maybeHighContrastOf(context) ?? false,
    );
  }
}

/// Carries the app-wide [GlassPolicy] down the tree. The host that listens to
/// the settings and the frame probe is [GlassPolicyHost].
class GlassPolicyScope extends InheritedWidget {
  const GlassPolicyScope({
    super.key,
    required this.policy,
    required super.child,
  });

  final GlassPolicy policy;

  @override
  bool updateShouldNotify(GlassPolicyScope oldWidget) =>
      oldWidget.policy != policy;
}

/// Hard limits of the glass budget. A budget is a rule about how the surfaces
/// are used, so it lives next to the policy.
class GlassBudget {
  GlassBudget._();

  /// Blur sigma of the navigation layer. One value for all of it, never
  /// animated.
  static const double blurSigma = 16;

  /// The most real blurs on one screen: bottom nav, collapsed header and one
  /// sheet (or a session control bar). Debug builds report the fourth.
  static const int maxBlursOnScreen = 3;

  /// Frames the probe watches, and the raster time that counts as slow.
  static const int probeFrames = 120;
  static const Duration slowRasterP90 = Duration(milliseconds: 16);
}

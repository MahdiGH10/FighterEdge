import 'package:flutter/material.dart';

import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';

/// Wraps a tappable surface so it responds on press-*down*, not on release.
///
/// Respond on pointer-down: waiting for touch-up to show feedback feels dead.
/// This replaces Material's ink ripple across the app — a ripple is a Material
/// signature, and on dark premium surfaces it reads as an Android tell. A short
/// scale plus a haptic says the same thing in the platform-neutral way both
/// iOS and this brand want.
///
/// The scale is deliberately small (0.97) and the timing short. Under
/// `MediaQuery.disableAnimationsOf` the scale is dropped entirely — reduced
/// motion means no transform, not a slower one. The haptic still fires: it is
/// feedback, not animation.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale applied while pressed. 1.0 disables the effect.
  final double pressedScale;

  /// Haptic fired on tap. Defaults to [AppHaptics.tap]; pass a different one
  /// for commits or selections, or null for surfaces that shouldn't buzz.
  final VoidCallback? haptic;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.haptic = AppHaptics.tap,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    widget.haptic?.call();
    widget.onTap!.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onTap != null;
    final scale =
        (!enabled || reduceMotion || !_pressed) ? 1.0 : widget.pressedScale;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      // Cancel-by-dragging-away is part of the tap contract: pressing, sliding
      // off, and releasing must not fire the action, and the surface must
      // visibly let go.
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTap: enabled ? _handleTap : null,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: scale,
        duration: reduceMotion ? Duration.zero : MotionTokens.press,
        curve: MotionTokens.snap,
        child: widget.child,
      ),
    );
  }
}

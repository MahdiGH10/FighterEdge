import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Wraps a tappable surface so it responds on press-*down*, not on release.
///
/// From the `apple-design` skill, §1 (Response): "Respond on pointer-down, not
/// on release. Waiting for click/touch-up to show feedback feels dead."
/// Flutter's `InkWell` ripple already does this, but the custom card surfaces
/// in this app are built on `GestureDetector`/`Ink` and give no feedback until
/// the tap completes.
///
/// The scale is deliberately small (0.97) and the timing short. Under
/// `MediaQuery.disableAnimationsOf` the scale is dropped entirely — reduced
/// motion means no transform, not a slower one.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// Scale applied while pressed. 1.0 disables the effect.
  final double pressedScale;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
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

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onTap != null;
    final scale = (!enabled || reduceMotion || !_pressed)
        ? 1.0
        : widget.pressedScale;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      // Cancel-by-dragging-away is part of the tap contract (apple-design §10):
      // pressing, sliding off, and releasing must not fire the action, and the
      // surface must visibly let go.
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: scale,
        duration: reduceMotion ? Duration.zero : MotionTokens.fast,
        curve: MotionTokens.emphasized,
        child: widget.child,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_accessibility.dart';
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
///
/// ## Keyboard
///
/// An enabled surface is a tab stop. Enter and Space activate it once per key
/// press (holding the key does not repeat, so a held Enter cannot submit twice).
/// While focus came from the keyboard, a ring in the accent text role outlines
/// the surface; a touch or mouse press hides it again. A surface with no
/// [onTap] is not focusable.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale applied while pressed. 1.0 disables the effect.
  final double pressedScale;

  /// Haptic fired on tap. Defaults to [AppHaptics.tap]; pass a different one
  /// for commits or selections, or null for surfaces that shouldn't buzz.
  final VoidCallback? haptic;

  /// Corner radius of the keyboard focus ring. Match the surface's own shape:
  /// [Radii.tile] for a chip, [Radii.card] for a card.
  final BorderRadius focusBorderRadius;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.haptic = AppHaptics.tap,
    this.focusBorderRadius =
        const BorderRadius.all(Radius.circular(Radii.button)),
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  /// Enter and Space, on every platform. Repeats are excluded so a held key
  /// activates once.
  static const Map<ShortcutActivator, Intent> _activationKeys = {
    SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
        ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter, includeRepeats: false):
        ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
        ActivateIntent(),
  };

  final FocusNode _focusNode = FocusNode(debugLabel: 'PressScale');
  bool _pressed = false;
  bool _keyboardFocused = false;

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
      if (widget.onTap != null) _handleTap();
      return null;
    }),
  };

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// A held Enter or Space reaches the app-wide default shortcuts as repeat
  /// events, which would activate the surface again and again. Consume them
  /// while this surface has focus.
  KeyEventResult _swallowActivationRepeats(FocusNode _, KeyEvent event) {
    final activationKey = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space;
    if (event is KeyRepeatEvent &&
        activationKey &&
        _focusNode.hasPrimaryFocus) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setKeyboardFocused(bool value) {
    if (_keyboardFocused == value) return;
    setState(() => _keyboardFocused = value);
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
    final showRing = enabled && _keyboardFocused;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _swallowActivationRepeats,
      child: FocusableActionDetector(
        focusNode: _focusNode,
        enabled: enabled,
        shortcuts: _activationKeys,
        actions: _actions,
        onShowFocusHighlight: _setKeyboardFocused,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          // Cancel-by-dragging-away is part of the tap contract: pressing, sliding
          // off, and releasing must not fire the action, and the surface must
          // visibly let go.
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTap: enabled ? _handleTap : null,
          onLongPress: widget.onLongPress,
          // Always present, so focus moving on or off never rebuilds the child's
          // subtree. It only paints while the keyboard has focus.
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: widget.focusBorderRadius,
              border: showRing
                  ? Border.all(
                      color: AppAccessibility.accentText(context),
                      width: FocusTokens.ringWidth,
                    )
                  : null,
            ),
            child: AnimatedScale(
              scale: scale,
              duration: reduceMotion ? Duration.zero : MotionTokens.press,
              curve: MotionTokens.snap,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// A number that counts to its value instead of appearing at it.
///
/// Reserved for moments where the number *arriving* is the event — the first
/// EdgeFuel target, a completed session total, a streak extending. On a value
/// that merely happens to be on screen it is noise, and the contract is
/// explicit that motion must explain a relationship.
///
/// Deliberately **not** spring-driven. A spring overshoots, and a calorie
/// target that flies past 2750 to 2790 before settling has told the user
/// something false. Real quantities decelerate into place; only affordances
/// get to bounce.
///
/// Honours `MediaQuery.disableAnimationsOf`: with animations off the final
/// value renders immediately, with no intermediate frames.
class AnimatedCount extends StatelessWidget {
  /// The value to land on. Changing it animates from the previous value.
  final double value;

  /// Renders the number. Receives the *interpolated* value each frame, so this
  /// is where rounding and unit suffixes belong (`(v) => '${v.round()} kcal'`).
  final String Function(double value) formatter;

  final TextStyle? style;
  final TextAlign? textAlign;

  /// How long the count takes. Defaults to [MotionTokens.reveal] — long enough
  /// to register as a count, short enough not to delay the screen.
  final Duration duration;

  /// Start from this value on first build instead of from [value]. Passing 0
  /// makes the number count up on entrance; leaving it null means the first
  /// build is static and only later *changes* animate.
  final double? from;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.textAlign,
    this.duration = MotionTokens.reveal,
    this.from,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(formatter(value), style: style, textAlign: textAlign);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: from ?? value, end: value),
      duration: duration,
      // Decelerate, not spring: the value must never overshoot what it means.
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => Text(
        formatter(current),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

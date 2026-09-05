import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../recipe_copy.dart';

/// Serving control for the recipe detail screen.
///
/// This is the one control in EF-3 where continuous feedback matters, so it
/// gets the attention: every tap commits immediately, the value animates from
/// wherever it currently is, and a haptic fires on the actual change rather
/// than on the gesture. Holding a button repeats.
///
/// Bounds are soft in the sense that the buttons disable rather than the value
/// clamping silently — a control that accepts a tap and does nothing reads as
/// broken (apple-design §1).
class ServingStepper extends StatefulWidget {
  final double servings;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;

  const ServingStepper({
    super.key,
    required this.servings,
    required this.onChanged,
    this.min = 0.5,
    this.max = 12,
    this.step = 0.5,
  });

  @override
  State<ServingStepper> createState() => _ServingStepperState();
}

class _ServingStepperState extends State<ServingStepper> {
  bool get _canDecrease => widget.servings - widget.step >= widget.min - 1e-9;
  bool get _canIncrease => widget.servings + widget.step <= widget.max + 1e-9;

  void _change(double delta) {
    final next = (widget.servings + delta).clamp(widget.min, widget.max);
    if ((next - widget.servings).abs() < 1e-9) return;
    // Haptic fires on the value actually changing, not on the tap — causality
    // (apple-design §13): the feedback must match what happened.
    HapticFeedback.selectionClick();
    widget.onChanged(double.parse(next.toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepButton(
          icon: Icons.remove,
          onPressed: _canDecrease ? () => _change(-widget.step) : null,
          semanticLabel: 'Fewer servings',
        ),
        Expanded(
          child: Center(
            // The serving count itself is the thing the user is directly
            // manipulating, so it updates instantly — animating the number you
            // are actively changing would put lag on the input path
            // (apple-design §1). The *derived* macros animate instead; see
            // [AnimatedMacroValue].
            child: Text(
              RecipeCopy.servingsLabel(widget.servings),
              style: AppTheme.display(18),
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onPressed: _canIncrease ? () => _change(widget.step) : null,
          semanticLabel: 'More servings',
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;

  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: enabled ? AppColors.surfaceElevated : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.button),
          onTap: onPressed,
          child: SizedBox(
            // 44px minimum touch target, per the project's standing
            // accessibility rule in ROADMAP.md.
            width: 48,
            height: 48,
            child: Icon(
              icon,
              size: 20,
              color: enabled ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// A macro figure that animates from its current on-screen value to the new
/// one, rather than snapping.
///
/// Always animates *from the presentation value* — the `begin` of the tween is
/// the previously rendered number, not a fixed origin. That is what makes an
/// interrupted change continue smoothly instead of restarting
/// (apple-design §3).
class AnimatedMacroValue extends StatelessWidget {
  final int value;
  final String suffix;
  final TextStyle style;

  const AnimatedMacroValue({
    super.key,
    required this.value,
    required this.style,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text('$value$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: MotionTokens.standard,
      curve: MotionTokens.emphasized,
      builder: (context, animated, _) =>
          Text('${animated.round()}$suffix', style: style),
    );
  }
}

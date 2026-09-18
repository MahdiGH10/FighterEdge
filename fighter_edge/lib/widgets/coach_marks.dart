import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'primary_button.dart';

/// One stop on a coach-mark tour: the widget to light up and what to say
/// about it.
class CoachMarkStep {
  /// Attached to the widget being explained. Steps whose target is not on
  /// screen when their turn comes are skipped rather than pointing at nothing.
  final GlobalKey target;
  final String title;
  final String body;

  const CoachMarkStep({
    required this.target,
    required this.title,
    required this.body,
  });
}

/// Runs a tour over the whole app.
///
/// Resolves to true when the user reached the end and false when they skipped.
/// Either way the tour is over — callers should record it as seen, because a
/// tour that comes back after being dismissed is a nag, not a guide.
Future<bool> showCoachMarks(BuildContext context, List<CoachMarkStep> steps) {
  final completer = Completer<bool>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => CoachMarkLayer(
      steps: steps,
      onFinish: (completed) {
        entry.remove();
        if (!completer.isCompleted) completer.complete(completed);
      },
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return completer.future;
}

/// The overlay itself. Public so tests and the component gallery can host it
/// directly; app code should call [showCoachMarks].
class CoachMarkLayer extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final ValueChanged<bool> onFinish;

  const CoachMarkLayer({
    super.key,
    required this.steps,
    required this.onFinish,
  });

  @override
  State<CoachMarkLayer> createState() => _CoachMarkLayerState();
}

class _CoachMarkLayerState extends State<CoachMarkLayer> {
  int _index = -1;

  @override
  void initState() {
    super.initState();
    // Targets are measured from the laid-out tree, so start after a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(0));
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  Future<void> _goTo(int index) async {
    var next = index;
    while (next < widget.steps.length &&
        widget.steps[next].target.currentContext == null) {
      next++;
    }
    if (next >= widget.steps.length) {
      widget.onFinish(_index >= 0);
      return;
    }
    // Bring a target that sits in a scroll view into view before lighting it.
    final targetContext = widget.steps[next].target.currentContext!;
    await Scrollable.ensureVisible(
      targetContext,
      duration: _reduceMotion ? Duration.zero : MotionTokens.fast,
      alignment: .2,
    );
    if (!mounted) return;
    setState(() => _index = next);
  }

  void _next() {
    final isLast = _index == widget.steps.length - 1;
    if (isLast) {
      AppHaptics.success();
      widget.onFinish(true);
      return;
    }
    AppHaptics.selection();
    _goTo(_index + 1);
  }

  Rect? _targetRect(CoachMarkStep step) {
    final targetBox =
        step.target.currentContext?.findRenderObject() as RenderBox?;
    final layerBox = context.findRenderObject() as RenderBox?;
    if (targetBox == null || !targetBox.attached || layerBox == null) {
      return null;
    }
    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: layerBox);
    return topLeft & targetBox.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = _index >= 0 ? widget.steps[_index] : null;
    final rect = step == null ? null : _targetRect(step);
    final hole = rect?.inflate(Insets.sm);

    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(
            children: [
              // Swallows taps: the tour is short and linear, and a stray tap
              // on the app underneath would leave it pointing at a stale spot.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: hole == null
                      ? const ColoredBox(color: AppColors.scrim)
                      : TweenAnimationBuilder<Rect?>(
                          tween: RectTween(end: hole),
                          duration: _reduceMotion
                              ? Duration.zero
                              : MotionTokens.standard,
                          curve: MotionTokens.settle,
                          builder: (context, value, _) => CustomPaint(
                            size: size,
                            painter: _ScrimPainter(hole: value ?? hole),
                          ),
                        ),
                ),
              ),
              if (step != null && hole != null)
                _Caption(
                  key: ValueKey(_index),
                  step: step,
                  index: _index,
                  count: widget.steps.length,
                  hole: hole,
                  screen: size,
                  onNext: _next,
                  onSkip: () => widget.onFinish(false),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  final Rect hole;
  const _ScrimPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      hole,
      const Radius.circular(Radii.card),
    );
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);
    canvas.drawPath(scrim, Paint()..color = AppColors.scrim);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}

class _Caption extends StatelessWidget {
  final CoachMarkStep step;
  final int index;
  final int count;
  final Rect hole;
  final Size screen;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _Caption({
    super.key,
    required this.step,
    required this.index,
    required this.count,
    required this.hole,
    required this.screen,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = index == count - 1;
    // Sit on whichever side of the target has more room, so the caption never
    // covers the thing it is talking about.
    final below = hole.center.dy < screen.height / 2;
    final card = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      liveRegion: true,
      label: '${step.title}. Step ${index + 1} of $count',
      child: Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: AppAccessibility.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1} of $count',
              style: AppType.micro(color: AppAccessibility.textMuted(context)),
            ),
            const SizedBox(height: Insets.xs),
            Text(step.title, style: AppType.title2()),
            const SizedBox(height: Insets.xs),
            Text(
              step.body,
              style: AppType.callout(
                  color: AppAccessibility.textSecondary(context)),
            ),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                if (!isLast)
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        AppAccessibility.minTouchTarget,
                        AppAccessibility.minTouchTarget,
                      ),
                    ),
                    child: Text(
                      'Skip tour',
                      style: AppType.callout(
                        weight: FontWeight.w600,
                        color: AppAccessibility.textSecondary(context),
                      ),
                    ),
                  ),
                const Spacer(),
                PrimaryButton(
                  isLast ? 'Got it' : 'Next',
                  onPressed: onNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final reveal = MediaQuery.disableAnimationsOf(context)
        ? card
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: MotionTokens.fast,
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: card,
          );

    return Positioned(
      left: Insets.lg,
      right: Insets.lg,
      top: below ? hole.bottom + Insets.md : null,
      bottom: below ? null : screen.height - hole.top + Insets.md,
      child: reveal,
    );
  }
}

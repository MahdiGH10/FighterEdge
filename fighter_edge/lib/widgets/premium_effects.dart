import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// The app's ground: one flat colour behind every screen.
///
/// It used to paint a red radial glow top-right and a cool one bottom-left.
/// That was decoration that explained nothing, repeated on every screen, and
/// it is the single most template-looking thing the app had. Depth now comes
/// from the surface ramp (`background` < `surface` < `surfaceAlt`), the way
/// the colour contract describes.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.background, child: child);
  }
}

/// Small entrance motion with an accessibility-safe static path.
///
/// A stagger is one shared [duration] with an offset *start* per item — set
/// [index] and each item waits `index * MotionTokens.stagger` before moving.
/// Varying the duration instead (the app's previous approach) starts everything
/// at once and merely finishes raggedly, which reads as jitter rather than
/// sequence.
class PremiumReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double distance;

  /// Position in a staggered group. 0 starts immediately.
  final int index;

  const PremiumReveal({
    super.key,
    required this.child,
    this.duration = MotionTokens.reveal,
    this.distance = 12,
    this.index = 0,
  });

  @override
  State<PremiumReveal> createState() => _PremiumRevealState();
}

class _PremiumRevealState extends State<PremiumReveal> {
  bool _started = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final delay = MotionTokens.stagger * widget.index;
    if (delay == Duration.zero) {
      _started = true;
    } else {
      _timer = Timer(delay, () {
        if (mounted) setState(() => _started = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _started ? 1.0 : 0.0),
      duration: widget.duration,
      curve: MotionTokens.settle,
      child: widget.child,
      builder: (context, value, builtChild) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, widget.distance * (1 - value)),
          child: builtChild,
        ),
      ),
    );
  }
}

class PremiumBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const PremiumBadge(this.label, {super.key, this.icon = Icons.bolt_rounded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: AppColors.primary.withValues(alpha: .34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryBright),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: AppType.micro(
              weight: FontWeight.w800,
              color: AppColors.primaryBright,
              spacing: .8,
            ),
          ),
        ],
      ),
    );
  }
}

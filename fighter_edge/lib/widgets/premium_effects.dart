import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../theme/app_icons.dart';
import '../theme/glass_policy.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// The app's ground: near-black with a soft, static glow.
///
/// The glow is the thing the glass sits on: a crimson core fading to ember at
/// the top edge, a cool violet-blue pool bottom-left and a violet touch
/// bottom-right ([GlassColors]). It is painted once, inside its own
/// [RepaintBoundary], and never animates, so scrolling content above it does
/// not re-raster it.
///
/// At [GlassLevel.solid] (Reduce transparency, high contrast) the glow is
/// gone and the ground is the flat `background` colour.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!GlassPolicy.of(context).tints) {
      return ColoredBox(color: AppColors.background, child: child);
    }
    return Stack(
      children: [
        const Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _GlowPainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  /// An elliptical radial gradient: centre at ([cx], [cy]) and radii
  /// ([rx], [ry]), all as fractions of the box, like CSS `radial-gradient`.
  static Paint _glow(Size size, double cx, double cy, double rx, double ry,
      List<Color> colors, List<double> stops) {
    final matrix =
        Matrix4.translationValues(cx * size.width, cy * size.height, 0)
          ..scale(rx * size.width, ry * size.height, 1);
    return Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1,
        colors,
        stops,
        TileMode.clamp,
        matrix.storage,
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.background);
    // Top: crimson core, ember halo, gone by 66%.
    canvas.drawRect(
      rect,
      _glow(
        size,
        .5,
        -.14,
        1.2,
        .52,
        [
          GlassColors.glowTop,
          GlassColors.glowEmber,
          GlassColors.glowTop.withValues(alpha: 0),
        ],
        const [0, .3, .66],
      ),
    );
    // Bottom left: the cool pool that makes the crimson above read richer.
    canvas.drawRect(
      rect,
      _glow(
          size,
          0,
          1.02,
          .85,
          .38,
          [GlassColors.glowLow, GlassColors.glowLow.withValues(alpha: 0)],
          const [0, .72]),
    );
    // Bottom right: a violet touch.
    canvas.drawRect(
      rect,
      _glow(
          size,
          1.04,
          .84,
          .55,
          .26,
          [GlassColors.glowViolet, GlassColors.glowViolet.withValues(alpha: 0)],
          const [0, .72]),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => false;
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

  const PremiumBadge(this.label, {super.key, this.icon = AppIcons.lightning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm + Insets.xxs, vertical: Insets.xs + Insets.xxs),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: AppColors.primary.withValues(alpha: .34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryBright),
          const SizedBox(width: Insets.xs),
          Text(
            label,
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

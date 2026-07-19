import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A restrained fight-night backdrop inspired by animated web gradients,
/// implemented as native Flutter decoration so it stays fast on mobile.
class PremiumBackground extends StatelessWidget {
  final Widget child;

  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111118),
            AppColors.background,
            Color(0xFF0C090D),
          ],
          stops: [0, .48, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(child: CustomPaint(painter: _GlowPainter())),
          child,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final redGlow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x30E63328), Color(0x00E63328)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * .92, size.height * .08),
        radius: size.width * .72,
      ));
    canvas.drawCircle(
      Offset(size.width * .92, size.height * .08),
      size.width * .72,
      redGlow,
    );

    final coolGlow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x162E365C), Color(0x002E365C)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * .05, size.height * .62),
        radius: size.width * .75,
      ));
    canvas.drawCircle(
      Offset(size.width * .05, size.height * .62),
      size.width * .75,
      coolGlow,
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => false;
}

/// React-Bits-style gradient typography without a web shader dependency.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.colors = const [Colors.white, Color(0xFFFFB5AF)],
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(colors: colors)
          .createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style),
    );
  }
}

/// Small entrance motion with an accessibility-safe static path.
class PremiumReveal extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double distance;

  const PremiumReveal({
    super.key,
    required this.child,
    this.duration = MotionTokens.reveal,
    this.distance = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: MotionTokens.emphasized,
      child: child,
      builder: (context, value, builtChild) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, distance * (1 - value)),
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
            style: AppTheme.body(
              10,
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

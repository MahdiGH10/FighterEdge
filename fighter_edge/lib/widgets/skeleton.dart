import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A loading placeholder shaped like the content it stands in for.
///
/// A centred spinner says "wait" and nothing else; a skeleton says what is
/// coming and where, so the page does not jump when it lands. The whole group
/// breathes on one shared animation rather than each block on its own.
class Skeleton extends StatefulWidget {
  final Widget child;
  const Skeleton({super.key, required this.child});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: hold still at the resting shade instead of pulsing.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      excludeSemantics: true,
      child: FadeTransition(
        opacity: Tween<double>(begin: .45, end: 1).animate(
          CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
        ),
        child: widget.child,
      ),
    );
  }
}

/// One block inside a [Skeleton].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = Radii.button,
  });

  /// A line of text at body size.
  const SkeletonBox.line({super.key, this.width})
      : height = Insets.lg,
        radius = Insets.xs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

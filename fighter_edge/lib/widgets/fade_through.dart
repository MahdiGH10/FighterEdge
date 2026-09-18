import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The in-place form of `AppPageTransitions.fadeThrough`, for swapping peers
/// that are not routes — the tabs of the home shell.
///
/// Only the incoming page animates. The outgoing one leaves on the same frame
/// instead of cross-fading, which keeps exactly one copy of each page in the
/// tree: a cross-fade holds both, and a quick Home → Train → Home would mount
/// two dashboards and their GlobalKeys at once.
class FadeThrough extends StatelessWidget {
  /// Changing this replays the entrance.
  final Object switchKey;
  final Widget child;

  const FadeThrough({
    super.key,
    required this.switchKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return KeyedSubtree(key: ValueKey(switchKey), child: child);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(switchKey),
      tween: Tween(begin: 0, end: 1),
      duration: MotionTokens.standard,
      curve: MotionTokens.settle,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        // Same fractional arrival as the route version, so a tab switch and a
        // peer route read as the same kind of move.
        child: Transform.scale(scale: .98 + .02 * t, child: child),
      ),
    );
  }
}

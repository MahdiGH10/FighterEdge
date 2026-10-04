import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The in-place form of `AppPageTransitions.fadeThrough`, for swapping peers
/// that are not routes — the tabs of the home shell.
///
/// The child stays mounted across switches: changing [switchKey] only replays
/// the entrance (a fade and a 2% rise in scale) over the same subtree. The
/// shell keeps its tabs in an `IndexedStack` underneath, so a tab keeps its
/// scroll position and its own selections when the athlete comes back.
/// (The previous version re-keyed the subtree on every switch, which rebuilt
/// the page from scratch and lost all of that.)
class FadeThrough extends StatefulWidget {
  /// Changing this replays the entrance.
  final Object switchKey;
  final Widget child;

  const FadeThrough({
    super.key,
    required this.switchKey,
    required this.child,
  });

  @override
  State<FadeThrough> createState() => _FadeThroughState();
}

class _FadeThroughState extends State<FadeThrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionTokens.standard,
  )..forward();

  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: MotionTokens.settle);
  late final Animation<double> _scale =
      Tween<double>(begin: .98, end: 1).animate(_curve);

  @override
  void didUpdateWidget(FadeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.switchKey != widget.switchKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _curve,
      // Same fractional arrival as the route version, so a tab switch and a
      // peer route read as the same kind of move.
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

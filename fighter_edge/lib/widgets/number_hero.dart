import 'package:flutter/material.dart';

/// A number that flies from a summary card to the screen that details it.
///
/// A plain [Hero] would scale the destination's pixels into the source's box,
/// so a 22pt figure growing into a 52pt one would visibly stretch. This flies
/// real text instead, interpolating the style, so the number stays crisp and
/// simply grows — the user sees the value they tapped become the page's
/// subject.
class NumberHero extends StatelessWidget {
  final Object tag;

  /// What the number reads, and how, at this end of the flight.
  final String text;
  final TextStyle style;

  /// What sits here when nothing is flying. Usually a [Text] or an
  /// `AnimatedCount` showing [text] in [style].
  final Widget child;

  const NumberHero({
    super.key,
    required this.tag,
    required this.text,
    required this.style,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: _shuttle,
      child: _Payload(text: text, style: style, child: child),
    );
  }

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final from = (fromContext.widget as Hero).child as _Payload;
    final to = (toContext.widget as Hero).child as _Payload;
    // The animation always runs 0 → 1 from the pushed route's point of view;
    // on a pop, "from" is the detail page, so the ends swap.
    final (start, end) =
        direction == HeroFlightDirection.push ? (from, to) : (to, from);
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            end.text,
            maxLines: 1,
            softWrap: false,
            style: TextStyle.lerp(start.style, end.style, animation.value),
          ),
        ),
      ),
    );
  }
}

class _Payload extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Widget child;

  const _Payload({
    required this.text,
    required this.style,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}

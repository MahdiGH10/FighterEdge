import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/glass_policy.dart';

/// Which edge of a [GlassSurface] faces the content that scrolls under it.
/// The hairline and the inner light run along that edge.
enum GlassEdge { top, bottom }

/// Counts the real blurs that are live, so a fourth one is reported in debug
/// builds instead of showing up as a slow frame on a cheap phone.
///
/// Only blurs that can be seen count: a [GlassSurface] on a hidden tab (its
/// [TickerMode] is off) or at the tinted and solid levels draws no blur.
class GlassBlurBudget {
  GlassBlurBudget._();

  static int _live = 0;

  /// How many blurs are live now.
  static int get live => _live;

  static void _acquire() {
    _live++;
    // Reported, not thrown: this runs inside a lifecycle method, and throwing
    // there leaves the framework's own bookkeeping half done.
    if (kDebugMode && _live > GlassBudget.maxBlursOnScreen) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError(
            'Glass budget exceeded: $_live backdrop blurs are live, at most '
            '${GlassBudget.maxBlursOnScreen} are allowed (nav, collapsed '
            'header, one sheet). Use GlassCard, which has no blur, for '
            'anything inside a list or a card.',
          ),
          library: 'glass surface',
        ),
      );
    }
  }

  static void _release() => _live--;

  /// Resets the count between tests.
  @visibleForTesting
  static void debugReset() => _live = 0;
}

/// A navigation-layer surface: the bottom nav, a collapsed header, a sheet.
///
/// At [GlassLevel.full] it blurs what scrolls under it (sigma 16, bounded to
/// its own box so nothing bleeds in from outside) and lays a tint, a hairline
/// and an inner light over the blur. At [GlassLevel.tinted] the blur is gone
/// and the tint is nearly opaque. At [GlassLevel.solid] it is an opaque
/// surface. The layout is the same at all three.
///
/// Rules, from the V2 glass spec:
///
/// * Only where content scrolls underneath. A card, a list row or a tile uses
///   [GlassCard] or a solid surface, never this.
/// * At most [GlassBudget.maxBlursOnScreen] at once; [GlassBlurBudget] reports
///   the next one in debug builds.
/// * Never animated. Show or hide the whole surface; do not fade it, resize it
///   under a running blur, or animate the sigma.
/// * Needs a [BackdropGroup] above it (the home shell has one) so the blurs of
///   one screen share a single copy of the backdrop. Without one it still
///   works, it is just not shared.
/// * Small text on it follows [GlassColors.allowsText].
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.kind,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.edge,
    this.level,
  }) : assert(
          kind == GlassKind.nav || kind == GlassKind.sheet,
          'GlassSurface is for the navigation layer. Hero cards use GlassCard.',
        );

  /// [GlassKind.nav] (bar, header) or [GlassKind.sheet].
  final GlassKind kind;
  final Widget child;
  final BorderRadius borderRadius;

  /// The edge facing the content. Defaults to the top.
  final GlassEdge? edge;

  /// Forces a level instead of asking [GlassPolicy.of]. For tests and goldens.
  final GlassLevel? level;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  GlassLevel _level = GlassLevel.full;
  bool _blurring = false;
  bool _counted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(GlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolve();
  }

  void _resolve() {
    _level = widget.level ?? GlassPolicy.of(context);
    _blurring = _level.blurs && TickerMode.valuesOf(context).enabled;
    if (_blurring && !_counted) {
      GlassBlurBudget._acquire();
      _counted = true;
    } else if (!_blurring && _counted) {
      GlassBlurBudget._release();
      _counted = false;
    }
  }

  @override
  void dispose() {
    if (_counted) GlassBlurBudget._release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSheet = widget.kind == GlassKind.sheet;
    final edge = widget.edge ?? GlassEdge.top;
    final highContrast = MediaQuery.highContrastOf(context);

    final Color fill;
    final Color rim;
    final Color innerLight;
    switch (_level) {
      case GlassLevel.full:
        fill = isSheet ? GlassColors.sheetFill : GlassColors.navFill;
        rim = isSheet ? GlassColors.sheetRim : GlassColors.navHairline;
        innerLight =
            isSheet ? GlassColors.sheetInnerLight : GlassColors.navInnerLight;
      case GlassLevel.tinted:
        fill =
            isSheet ? GlassColors.sheetFillTinted : GlassColors.navFillTinted;
        rim = isSheet ? GlassColors.sheetRim : GlassColors.navHairline;
        innerLight =
            isSheet ? GlassColors.sheetInnerLight : GlassColors.navInnerLight;
      case GlassLevel.solid:
        fill = GlassColors.solidFill(widget.kind);
        rim =
            isSheet ? AppColors.borderStrong : AppAccessibility.border(context);
        innerLight = AppColors.transparent;
    }

    Widget body = CustomPaint(
      foregroundPainter: _EdgePainter(
        edge: edge,
        borderRadius: widget.borderRadius,
        rim: highContrast && _level != GlassLevel.solid
            ? AppColors.borderStrong
            : rim,
        innerLight: innerLight,
      ),
      child: ColoredBox(color: fill, child: widget.child),
    );

    if (_blurring) {
      body = BackdropFilter.grouped(
        filterConfig: const ImageFilterConfig.blur(
          sigmaX: GlassBudget.blurSigma,
          sigmaY: GlassBudget.blurSigma,
          bounded: true,
        ),
        child: body,
      );
    }
    // Always clipped: a backdrop filter without a clip covers the whole
    // screen, and a sheet needs its rounded corners either way.
    return ClipRRect(borderRadius: widget.borderRadius, child: body);
  }
}

/// The 1px hairline along the content-facing edge, following the rounded
/// corners of a sheet, and the faint inner light just inside it.
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.edge,
    required this.borderRadius,
    required this.rim,
    required this.innerLight,
  });

  final GlassEdge edge;
  final BorderRadius borderRadius;
  final Color rim;
  final Color innerLight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    final radius = edge == GlassEdge.top
        ? math.max(rrect.tlRadiusY, rrect.trRadiusY)
        : math.max(rrect.blRadiusY, rrect.brRadiusY);
    // Only the strip that holds the edge and its two corner arcs.
    final band = math.max(radius, 2.0);
    canvas.save();
    canvas.clipRect(
      edge == GlassEdge.top
          ? Rect.fromLTWH(0, 0, size.width, band)
          : Rect.fromLTWH(0, size.height - band, size.width, band),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (innerLight.a > 0) {
      canvas.drawRRect(rrect.deflate(1.5), paint..color = innerLight);
    }
    canvas.drawRRect(rrect.deflate(.5), paint..color = rim);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edge != edge ||
      old.borderRadius != borderRadius ||
      old.rim != rim ||
      old.innerLight != innerLight;
}

/// The colour of a [GlassCard].
enum GlassTone {
  /// Warm tint: the Today card, the weekly target, a review recommendation.
  ember(GlassKind.hero),

  /// Cool tint for secondary cards.
  cool(GlassKind.hero),

  /// Gold: trial and Pro surfaces only.
  gold(GlassKind.heroGold);

  const GlassTone(this.kind);

  /// The contrast kind text on this tone must follow.
  final GlassKind kind;

  GlassHeroPalette get palette => switch (this) {
        ember => GlassColors.heroEmber,
        cool => GlassColors.heroCool,
        gold => GlassColors.heroGold,
      };
}

/// A hero card in the tinted glass look: a translucent tint over the static
/// glow, a 1px gradient rim and an inner light. **No backdrop blur**, so it
/// costs one painter and works on any phone.
///
/// Use it for a handful of hero blocks (Today, weekly target, review
/// recommendation). Lists and text blocks stay crisp and solid.
///
/// At [GlassLevel.solid] it is a [AppColors.surfaceAlt] card with a 1px line.
/// Small text on it follows [GlassColors.allowsText] for [GlassTone.kind].
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.tone = GlassTone.ember,
    this.padding = const EdgeInsets.all(Insets.xl),
    this.radius = Radii.hero,
    this.level,
  });

  final Widget child;
  final GlassTone tone;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Forces a level instead of asking [GlassPolicy.of]. For tests and goldens.
  final GlassLevel? level;

  @override
  Widget build(BuildContext context) {
    final resolved = level ?? GlassPolicy.of(context);
    final content = Padding(padding: padding, child: child);
    if (!resolved.tints) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: GlassColors.solidFill(tone.kind),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: MediaQuery.highContrastOf(context)
                ? AppColors.borderStrong
                : GlassColors.solidLine,
          ),
        ),
        child: content,
      );
    }
    return CustomPaint(
      painter: _HeroPainter(palette: tone.palette, radius: radius),
      child: content,
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter({required this.palette, required this.radius});

  final GlassHeroPalette palette;
  final double radius;

  /// A CSS-style linear gradient: [degrees] clockwise from "up", spanning the
  /// box corner to corner.
  static ui.Gradient _linear(
      Rect r, double degrees, List<Color> colors, List<double> stops) {
    final a = degrees * math.pi / 180;
    final dir = Offset(math.sin(a), -math.cos(a));
    final length = (r.width * dir.dx).abs() + (r.height * dir.dy).abs();
    return ui.Gradient.linear(
      r.center - dir * (length / 2),
      r.center + dir * (length / 2),
      colors,
      stops,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final p = palette;

    canvas.save();
    canvas.clipRRect(rrect);

    // 1. Base and the 158 degree tint.
    canvas.drawRect(rect, Paint()..color = p.base);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = _linear(
          rect,
          158,
          [p.tintStart, p.tintMid, p.tintEnd],
          GlassColors.heroTintStops,
        ),
    );

    // 2. The top-left highlight: an ellipse 130% by 70% of the box, fading out
    //    at 55% of its radius.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          [p.highlight, p.highlight.withValues(alpha: 0)],
          const [0, .55],
          TileMode.clamp,
          (Matrix4.diagonal3Values(size.width * 1.3, size.height * .7, 1))
              .storage,
        ),
    );

    // 3. Inner light: a hairline along the top, a warm glow along the bottom.
    final top = Paint()
      ..color = p.innerLightTop
      ..strokeWidth = 1;
    canvas.drawLine(Offset(radius, .5), Offset(size.width - radius, .5), top);
    final glow = math.min(28.0, size.height);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - glow, size.width, glow),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height - glow),
          Offset(0, size.height),
          [p.innerLightBottom.withValues(alpha: 0), p.innerLightBottom],
        ),
    );
    canvas.restore();

    // 4. The 1px rim, 135 degrees: bright top-left, warm bottom-right.
    final rimRect = rect.deflate(.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rimRect, Radius.circular(radius - .5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = _linear(
          rimRect,
          135,
          [p.rimStart, p.rimMid, p.rimFade, p.rimEnd],
          GlassColors.heroRimStops,
        ),
    );
  }

  @override
  bool shouldRepaint(_HeroPainter old) =>
      old.palette != palette || old.radius != radius;
}

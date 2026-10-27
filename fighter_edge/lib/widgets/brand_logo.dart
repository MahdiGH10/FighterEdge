import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// The Fighter Edge mark: the kicking fighter, red ring and FE monogram, on a
/// transparent background (built from the logo SVG, see tool/brand).
class BrandMark extends StatelessWidget {
  static const asset = 'assets/brand/logo_mark.png';

  final double size;
  const BrandMark({super.key, required this.size});

  static const _image = AssetImage(asset);

  /// Decodes the mark before the first frame, so the splash can show it on
  /// frame one instead of popping in over the native splash. Never throws.
  static Future<void> preload() {
    final done = Completer<void>();
    final stream = _image.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void finish() {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete();
    }

    listener = ImageStreamListener((_, __) => finish(),
        onError: (Object _, StackTrace? __) => finish());
    stream.addListener(listener);
    return done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: _image,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Fighter Edge',
    );
  }
}

/// "FIGHTER EDGE" and, optionally, the tagline under it.
class BrandWordmark extends StatelessWidget {
  final double scale;
  final bool showTagline;
  const BrandWordmark({super.key, this.scale = 1, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: 'FIGHTER ',
                  style: AppType.scaledDisplay(28 * scale, spacing: 1.5)),
              TextSpan(
                  text: 'EDGE',
                  style: AppType.scaledDisplay(28 * scale,
                      color: AppColors.accentText, spacing: 1.5)),
            ],
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: Insets.xs * scale),
          Text('YOUR EDGE. EVERY DAY.',
              style: AppType.scaledBody(11 * scale,
                  weight: FontWeight.w600,
                  color: AppColors.textMuted,
                  spacing: 2)),
        ],
      ],
    );
  }
}

/// The FIGHTER EDGE logo used on auth screens: the mark over the wordmark.
class BrandLogo extends StatelessWidget {
  final double scale;
  final bool showTagline;
  const BrandLogo({super.key, this.scale = 1, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BrandMark(size: LayoutTokens.brandMark * scale),
        SizedBox(height: Insets.md + Insets.xxs * scale),
        BrandWordmark(scale: scale, showTagline: showTagline),
      ],
    );
  }
}

/// The first screen of the app, and the one the athlete sees while it starts.
///
/// It continues the native splash (the same mark on the same colour, centred)
/// instead of replacing it: the mark is on screen from the first frame and
/// never moves, then the name and tagline settle in underneath. Once the app
/// is ready the next screen replaces it, so [animate] is only true for the
/// first showing; later showings of the splash (waiting for sign-in) are the
/// finished picture, so the logo never replays its entrance.
class BrandSplash extends StatefulWidget {
  final bool animate;
  const BrandSplash({super.key, this.animate = true});

  /// The mark's size on screen: half the shorter side, within limits.
  static double markSize(Size screen) =>
      (screen.shortestSide * 0.5).clamp(160.0, 240.0);

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  static const _entrance = Duration(milliseconds: 900);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _entrance);
  late final Animation<double> _name = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion, or a repeat showing: the finished picture, no entrance.
    final still = !widget.animate || MediaQuery.disableAnimationsOf(context);
    if (still) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = BrandSplash.markSize(MediaQuery.sizeOf(context));
    return Scaffold(
      // Exactly the native splash colour, so nothing flashes between them.
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            // Dead centre, as in the native splash: this never moves.
            Center(child: BrandMark(size: size)),
            // The name sits just below the mark without pushing it up.
            Positioned(
              left: 0,
              right: 0,
              top: constraints.maxHeight / 2 + size / 2 + Insets.lg,
              child: AnimatedBuilder(
                animation: _name,
                builder: (context, child) => Opacity(
                  opacity: _name.value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - _name.value) * 10),
                    child: child,
                  ),
                ),
                child: const ExcludeSemantics(child: BrandWordmark()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_accessibility.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_haptics.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/premium_effects.dart';
import '../../widgets/primary_button.dart';

/// What the app is for, before it starts asking questions.
///
/// Three pages, each one promise the product actually keeps (all three map to
/// shipped features), so the setup questions that follow read as "building the
/// thing you just saw" rather than a form standing between the user and it.
class WelcomePages extends StatefulWidget {
  /// Called when the user is ready for setup, by finishing or by skipping.
  final VoidCallback onDone;

  const WelcomePages({super.key, required this.onDone});

  @override
  State<WelcomePages> createState() => _WelcomePagesState();
}

class _WelcomePage {
  final IconData icon;
  final String title;
  final String body;
  final List<String> proof;

  const _WelcomePage({
    required this.icon,
    required this.title,
    required this.body,
    required this.proof,
  });
}

const _pages = [
  _WelcomePage(
    icon: Icons.sports_mma,
    title: 'Your camp, organised.',
    body: 'Training week, weight and fuel in one place — built around the '
        'days you can actually train.',
    proof: ['Weekly plan', 'Session log', 'Round timer'],
  ),
  _WelcomePage(
    icon: Icons.bolt,
    title: 'Fuel that matches the work.',
    body: 'EdgeFuel sets your calories and macros from your body and your '
        'training load, then keeps score as you log.',
    proof: ['Daily target', 'Macro split', 'Meal log'],
  ),
  _WelcomePage(
    icon: Icons.trending_up,
    title: 'Watch the edge build.',
    body: 'Streaks, your weight trend and session history show progress '
        'week over week — not just today.',
    proof: ['Streaks', 'Weight trend', 'History'],
  ),
];

class _WelcomePagesState extends State<WelcomePages> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      AppHaptics.tap();
      widget.onDone();
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(_page + 1);
    } else {
      _controller.nextPage(
        duration: MotionTokens.standard,
        curve: MotionTokens.settle,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.lg, Insets.lg, Insets.lg, Insets.xl),
            child: Column(
              children: [
                Row(
                  children: [
                    const BrandLogo(scale: .7),
                    const Spacer(),
                    // Hidden on the last page, where the primary button
                    // already does the same thing.
                    if (!_isLast)
                      TextButton(
                        onPressed: widget.onDone,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(
                            AppAccessibility.minTouchTarget,
                            AppAccessibility.minTouchTarget,
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: AppType.callout(
                            weight: FontWeight.w600,
                            color: AppAccessibility.textSecondary(context),
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) {
                      AppHaptics.selection();
                      setState(() => _page = i);
                    },
                    itemBuilder: (context, i) => _WelcomePageView(
                      page: _pages[i],
                      // Keyed on activation so the entrance replays each time
                      // a page arrives, instead of only on first build.
                      key: ValueKey('welcome-$i-${i == _page}'),
                    ),
                  ),
                ),
                _PageDots(count: _pages.length, current: _page),
                const SizedBox(height: Insets.xl),
                PrimaryButton(
                  _isLast ? 'Build my plan' : 'Continue',
                  icon: _isLast ? Icons.flag : Icons.arrow_forward,
                  expand: true,
                  onPressed: _next,
                ),
                const SizedBox(height: Insets.md),
                Text(
                  'About 2 minutes · 7 quick questions',
                  textAlign: TextAlign.center,
                  style: AppType.subhead(
                      color: AppAccessibility.textMuted(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePageView extends StatelessWidget {
  final _WelcomePage page;
  const _WelcomePageView({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumReveal(child: _Emblem(icon: page.icon)),
              const SizedBox(height: Insets.xxl),
              PremiumReveal(
                index: 1,
                child: Text(page.title, style: AppType.largeTitle()),
              ),
              const SizedBox(height: Insets.md),
              PremiumReveal(
                index: 2,
                child: Text(
                  page.body,
                  style: AppType.body(
                      color: AppAccessibility.textSecondary(context)),
                ),
              ),
              const SizedBox(height: Insets.xl),
              PremiumReveal(
                index: 3,
                child: Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: [
                    for (final label in page.proof) _ProofChip(label: label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page's one image: an icon in a lit ring. Deliberately not an
/// illustration — the product's own numbers are the visuals later on, and a
/// stock illustration here would promise a different app.
class _Emblem extends StatelessWidget {
  final IconData icon;
  const _Emblem({required this.icon});

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: const [
          BoxShadow(color: AppColors.primaryGlow, blurRadius: 36),
        ],
      ),
      child: Icon(icon, color: AppColors.primaryBright, size: _size / 2.4),
    );
  }
}

class _ProofChip extends StatelessWidget {
  final String label;
  const _ProofChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.md, vertical: Insets.xs + Insets.xxs),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: AppAccessibility.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 14, color: AppColors.positive),
          const SizedBox(width: Insets.xs),
          Text(label, style: AppType.subhead(weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MotionTokens.fast;
    return Semantics(
      label: 'Page ${current + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              curve: MotionTokens.snap,
              margin: const EdgeInsets.symmetric(horizontal: Insets.xs),
              width: i == current ? Insets.xl : Insets.sm,
              height: Insets.sm,
              decoration: BoxDecoration(
                color: i == current ? AppColors.primary : AppColors.track,
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
            ),
        ],
      ),
    );
  }
}

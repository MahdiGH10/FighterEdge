import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';

import '../../theme/app_accessibility.dart';
import '../../l10n/gen/app_localizations.dart';
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
  const _WelcomePage(this.icon);
}

const _pages = [
  _WelcomePage(AppIcons.boxingGlove),
  _WelcomePage(AppIcons.lightning),
  _WelcomePage(AppIcons.trendUp),
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
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.lg, Insets.lg, Insets.lg, Insets.xl),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: _page == 0
                                ? const BrandLogo(scale: .7)
                                : const SizedBox.shrink())),
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
                          L.of(context).welcomeSkip,
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
                      number: i + 1,
                      // Keyed on activation so the entrance replays each time
                      // a page arrives, instead of only on first build.
                      key: ValueKey('welcome-$i-${i == _page}'),
                    ),
                  ),
                ),
                _PageDots(count: _pages.length, current: _page),
                const SizedBox(height: Insets.xl),
                PrimaryButton(
                  _isLast
                      ? L.of(context).welcomeBuildPlan
                      : L.of(context).setupContinue,
                  icon: _isLast ? AppIconsFill.flag : AppIcons.arrowRight,
                  expand: true,
                  onPressed: _next,
                ),
                const SizedBox(height: Insets.md),
                Text(
                  L.of(context).welcomeDuration,
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
  final int number;
  const _WelcomePageView({super.key, required this.page, required this.number});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final title = switch (number) {
      1 => l.welcomeCampTitle,
      2 => l.welcomeFuelTitle,
      _ => l.welcomeProgressTitle,
    };
    final body = switch (number) {
      1 => l.welcomeCampBody,
      2 => l.welcomeFuelBody,
      _ => l.welcomeProgressBody,
    };
    final proof = switch (number) {
      1 => [l.welcomeWeeklyPlan, l.welcomeSessionLog, l.welcomeWeighIns],
      2 => [l.welcomeDailyTarget, l.welcomeMacroSplit, l.welcomeMealLog],
      _ => [l.welcomeStreaks, l.welcomeWeightTrend, l.welcomeHistory],
    };
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                  child: Text('0$number',
                      style: AppType.heroNumeral(color: AppColors.textMuted))),
              const SizedBox(height: Insets.xxl),
              PremiumReveal(
                index: 1,
                child: Text(title, style: AppType.largeTitle()),
              ),
              const SizedBox(height: Insets.md),
              PremiumReveal(
                index: 2,
                child: Text(
                  body,
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
                    for (final label in proof) _ProofChip(label: label),
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

class _ProofChip extends StatelessWidget {
  final String label;
  const _ProofChip({required this.label});
  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppType.subhead(color: AppColors.textSecondary));
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
      label: L.of(context).welcomePage(current + 1, count),
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

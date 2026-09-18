import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/animated_count.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/filter_chips.dart';
import '../widgets/password_strength_meter.dart';
import '../widgets/premium_effects.dart';
import '../widgets/press_scale.dart';
import '../widgets/primary_button.dart';
import '../widgets/progress_ring.dart';
import '../widgets/stat_card.dart';

/// Debug-only component gallery used by Phase 3 golden tests.
///
/// Keep this screen focused on shared primitives. Feature-specific examples
/// belong in their own tests once Phase 4 starts moving screens.
class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: ComponentGalleryCanvas());
  }
}

class ComponentGalleryCanvas extends StatelessWidget {
  const ComponentGalleryCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return const PremiumBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GalleryHeader(),
              SizedBox(height: Insets.xl),
              _GallerySection(
                title: 'Buttons',
                child: _ButtonStates(),
              ),
              SizedBox(height: Insets.lg),
              _GallerySection(
                title: 'Cards',
                child: _CardStates(),
              ),
              SizedBox(height: Insets.lg),
              _GallerySection(
                title: 'Selectors',
                child: _SelectorStates(),
              ),
              SizedBox(height: Insets.lg),
              _GallerySection(
                title: 'Password Strength',
                child: _PasswordStrengthStates(),
              ),
              SizedBox(height: Insets.lg),
              _GallerySection(
                title: 'Motion and Status',
                child: _MotionStates(),
              ),
              SizedBox(height: Insets.lg),
              _GallerySection(
                title: 'Navigation',
                child: _NavigationStates(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FIGHTER EDGE',
          style: AppType.micro(
            color: AppColors.accentText,
            weight: FontWeight.w800,
            spacing: 0.8,
          ),
        ),
        const SizedBox(height: Insets.sm),
        Text('Component Gallery', style: AppType.largeTitle()),
        const SizedBox(height: Insets.sm),
        Text(
          'Shared UI states for golden tests before the Phase 4 screen pass.',
          style: AppType.callout(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _GallerySection extends StatelessWidget {
  final String title;
  final Widget child;

  const _GallerySection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: AppType.micro(
                  color: AppColors.textMuted,
                  weight: FontWeight.w700,
                  spacing: 0.8)),
          const SizedBox(height: Insets.md),
          child,
        ],
      ),
    );
  }
}

class _ButtonStates extends StatelessWidget {
  const _ButtonStates();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          'Start Session',
          icon: Icons.play_arrow_rounded,
          expand: true,
          onPressed: () {},
        ),
        const SizedBox(height: Insets.sm),
        const PrimaryButton(
          'Saving',
          icon: Icons.lock_rounded,
          expand: true,
        ),
        const SizedBox(height: Insets.sm),
        GhostButton(
          'Review Plan',
          icon: Icons.insights_rounded,
          expand: true,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _CardStates extends StatelessWidget {
  const _CardStates();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Weight',
                value: '77.2',
                unit: 'kg',
                delta: '-0.4 this week',
                deltaIcon: Icons.trending_down_rounded,
                accent: AppColors.primary,
                onTap: () {},
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: StatCard(
                label: 'Fuel',
                value: '680',
                unit: 'kcal',
                delta: 'left today',
                deltaColor: AppColors.accentText,
                accent: AppColors.premium,
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        AppCard(
          elevated: true,
          accent: AppColors.primary,
          onTap: () {},
          child: Row(
            children: [
              const ProgressRing(
                progress: .72,
                size: 52,
                strokeWidth: 5,
                child: Icon(Icons.flash_on_rounded,
                    color: AppColors.primaryBright, size: 20),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today\'s Focus', style: AppType.title2()),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Footwork, fuel timing, and clean recovery.',
                      style: AppType.callout(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectorStates extends StatelessWidget {
  const _SelectorStates();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterChips(
          options: const ['Week', 'Month', 'Camp'],
          selectedIndex: 1,
          scrollable: false,
          onSelected: (_) {},
        ),
        const SizedBox(height: Insets.md),
        FilterChips(
          options: const ['Boxing', 'Wrestling', 'BJJ', 'Recovery'],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ],
    );
  }
}

class _PasswordStrengthStates extends StatelessWidget {
  const _PasswordStrengthStates();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PasswordStrengthMeter(password: 'jab'),
        PasswordStrengthMeter(password: 'password'),
        PasswordStrengthMeter(password: 'southpaw1234'),
        PasswordStrengthMeter(password: 'Southpaw-Jab-42'),
      ],
    );
  }
}

class _MotionStates extends StatelessWidget {
  const _MotionStates();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const PremiumBadge('Pro'),
        const PremiumBadge('Camp mode', icon: Icons.sports_mma_rounded),
        PressScale(
          onTap: () {},
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(Radii.button),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg,
                vertical: Insets.md,
              ),
              child: Text('Press state target', style: AppType.subhead()),
            ),
          ),
        ),
        // Renders as its settled value here: the gallery golden disables
        // animations, which is exactly the reduced-motion path this must honour.
        AnimatedCount(
          value: 2750,
          from: 0,
          formatter: (v) => '${v.round()} kcal',
          style: AppType.title2().copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _NavigationStates extends StatelessWidget {
  const _NavigationStates();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AppBottomNav(
          currentIndex: 1,
          onTap: (_) {},
          items: const [
            NavItem(Icons.home_rounded, 'Home'),
            NavItem(Icons.fitness_center_rounded, 'Train'),
            NavItem(Icons.local_fire_department_rounded, 'Fuel'),
            NavItem(Icons.person_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }
}

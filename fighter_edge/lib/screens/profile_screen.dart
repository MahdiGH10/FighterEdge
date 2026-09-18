import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../state/app_state.dart';
import '../state/streak_controller.dart';
import '../state/streak_engine.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import '../widgets/press_scale.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import 'dashboard_screen.dart';
import 'paywall_screen.dart';
import 'round_timer_screen.dart';
import 'settings_screen.dart';
import 'weight_tracker_screen.dart';

class ProfileScreen extends StatelessWidget {
  final bool asTab;
  const ProfileScreen({super.key, this.asTab = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final streak = context.watch<StreakController>();
    final streakDays = StreakEngine.streakDays(
      StreakEngine.completedDateKeys(state.sessions),
      protectedDateKeys: streak.protectedDateKeys,
    );
    final weight = state.latestWeight;
    final auth = context.watch<AuthController>();
    final user = auth.user;
    // Height lives in the EdgeFuel setup draft — it is the only place the app
    // actually asks for it. Absent until the user completes nutrition setup.
    final heightCm = context.watch<EdgeFuelController>().draft?.heightCm;
    final largeText = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.4;

    final displayName =
        (user?.displayName.isNotEmpty ?? false) ? user!.displayName : 'Fighter';
    // The camp goal replaces the old hard-coded weight-class division: weight
    // class was deliberately removed from the product, so it must not reappear
    // as an identity label here.
    final goalLine = (user?.goal.isNotEmpty ?? false) ? user!.goal : null;
    final measurements = [
      if (heightCm != null) '${heightCm.round()} cm',
      if (weight > 0) '${weight.toStringAsFixed(1)} ${state.weightUnitLabel}',
    ].join(' · ');

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayName, style: AppType.title1()),
        if (goalLine != null) ...[
          const SizedBox(height: Insets.xxs),
          Text(goalLine,
              style: AppType.subhead(
                  weight: FontWeight.w500,
                  color: AppAccessibility.textSecondary(context))),
        ],
        if (measurements.isNotEmpty) ...[
          const SizedBox(height: Insets.xxs),
          Text(measurements,
              style: AppType.subhead(
                  weight: FontWeight.w500,
                  color: AppAccessibility.textMuted(context))),
        ],
      ],
    );
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        if (largeText)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FighterAvatar(size: 64),
              const SizedBox(height: Insets.md),
              details,
            ],
          )
        else
          Row(
            children: [
              const FighterAvatar(size: 64),
              const SizedBox(width: Insets.lg),
              Expanded(child: details),
            ],
          ),
        const SizedBox(height: Insets.xl),
        const SectionHeader('Subscription'),
        _SubscriptionCard(auth: auth),
        const SizedBox(height: Insets.xl),
        const SectionHeader('Tools'),
        const AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ToolRow(
                icon: Icons.timer_outlined,
                title: 'Round Timer',
                subtitle: 'Open intervals for sparring, MMA, boxing or BJJ',
                route: AppRoutes.roundTimer,
                screen: RoundTimerScreen(),
              ),
              Divider(height: 1, thickness: 1, color: AppColors.border),
              _ToolRow(
                icon: Icons.monitor_weight_outlined,
                title: 'Weight Tracker',
                subtitle: 'Log weigh-ins and monitor the cut or gain',
                route: AppRoutes.weightTracker,
                screen: WeightTrackerScreen(),
              ),
              Divider(height: 1, thickness: 1, color: AppColors.border),
              _ToolRow(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Units, safety, reminders and account controls',
                route: AppRoutes.settings,
                screen: SettingsScreen(),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        const SectionHeader('Stats'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _StatRow('Sessions Completed', '${state.completedSessionCount}'),
              _divider(),
              _StatRow('Current Streak', '$streakDays days'),
              _divider(),
              _StatRow(
                  'Training Days / Week', '${user?.weeklyTrainingDays ?? 0}'),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        GhostButton(
          'Sign Out',
          icon: Icons.logout,
          expand: true,
          onPressed: () async {
            await auth.signOut();
            if (context.mounted) {
              Navigator.of(context).popUntil((r) => r.isFirst);
            }
          },
        ),
      ],
    );
    if (asTab) {
      return ScreenScaffold.tab(title: 'Profile', body: body);
    }
    return ScreenScaffold(title: 'Profile', showBack: true, body: body);
  }

  static Widget _divider() =>
      const Divider(height: 1, thickness: 1, color: AppColors.border);
}

class _ToolRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Widget screen;

  const _ToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () => AppNavigation.push(
        context,
        route,
        fallbackBuilder: (_) => screen,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.callout(weight: FontWeight.w800)),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    subtitle,
                    style: AppType.subhead(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Plan badge + upgrade/manage entry point.
class _SubscriptionCard extends StatelessWidget {
  final AuthController auth;
  const _SubscriptionCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final isPro = auth.isPro;
    return AppCard(
      onTap: () => AppNavigation.push(
        context,
        AppRoutes.paywall,
        fallbackBuilder: (_) => const PaywallScreen(),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(isPro ? Icons.verified : Icons.bolt,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isPro ? 'FighterEdge Pro' : 'Free Plan',
                    style: AppType.callout(weight: FontWeight.w700)),
                const SizedBox(height: Insets.xxs),
                Text(
                    isPro
                        ? 'All features unlocked'
                        : 'Upgrade to unlock everything',
                    style: AppType.subhead(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (!isPro)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Text('UPGRADE',
                  style: AppType.micro(
                      weight: FontWeight.w700, color: Colors.white)),
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.md + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppType.callout(
                  weight: FontWeight.w500, color: AppColors.textSecondary)),
          Text(value, style: AppType.callout(weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

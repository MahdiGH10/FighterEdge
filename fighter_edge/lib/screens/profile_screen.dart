import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_icons.dart';

import '../controllers/auth_controller.dart';
import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../l10n/decimal_format.dart';
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
import '../widgets/grouped_list.dart';
import '../l10n/gen/app_localizations.dart';
import '../widgets/section_header.dart';
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
      state.trainingDayKeys,
      protectedDateKeys: streak.protectedDateKeys,
      now: state.now,
    );
    final weight = state.latestWeight;
    final auth = context.watch<AuthController>();
    final user = auth.user;
    // Height lives in the EdgeFuel setup draft — it is the only place the app
    // actually asks for it. Absent until the user completes nutrition setup.
    final heightCm = context.watch<EdgeFuelController>().draft?.heightCm;
    final largeText = AppAccessibility.isLargeText(context);

    final displayName =
        (user?.displayName.isNotEmpty ?? false) ? user!.displayName : 'Fighter';
    // The camp goal replaces the old hard-coded weight-class division: weight
    // class was deliberately removed from the product, so it must not reappear
    // as an identity label here.
    final goalLine = (user?.goal.isNotEmpty ?? false) ? user!.goal : null;
    final measurements = [
      if (heightCm != null) '${heightCm.round()} cm',
      if (weight > 0)
        '${formatFixedDecimal(state.displayWeight(weight), Localizations.localeOf(context).toString())} '
            '${state.weightUnitLabel}',
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
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.none, Insets.lg, Insets.xxl),
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
        const GroupedList(
          children: [
            _ToolRow(
              title: 'Round timer',
              subtitle: 'Open intervals for sparring, MMA, boxing or BJJ',
              route: AppRoutes.roundTimer,
              screen: RoundTimerScreen(),
            ),
            _ToolRow(
              title: 'Weight tracker',
              subtitle: 'Log weigh-ins and monitor the cut or gain',
              route: AppRoutes.weightTracker,
              screen: WeightTrackerScreen(),
            ),
            _ToolRow(
              title: 'Settings',
              subtitle: 'Units, safety, reminders and account controls',
              route: AppRoutes.settings,
              screen: SettingsScreen(),
            ),
          ],
        ),
        const SizedBox(height: Insets.xl),
        const SectionHeader('Stats'),
        GroupedList(
          children: [
            _StatRow('Sessions completed', '${state.completedSessionCount}'),
            _StatRow('Current streak',
                '$streakDays ${L.of(context).dashboardStatDays(streakDays)}'),
            _StatRow(
                'Training days / week', '${user?.weeklyTrainingDays ?? 0}'),
          ],
        ),
        const SizedBox(height: Insets.xl),
        GhostButton(
          'Sign out',
          icon: AppIcons.signOut,
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
}

class _ToolRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String route;
  final Widget screen;

  const _ToolRow({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return GroupedRow(
        title: title,
        subtitle: subtitle,
        onTap: () =>
            AppNavigation.push(context, route, fallbackBuilder: (_) => screen));
  }
}

/// Plan badge + upgrade/manage entry point.
class _SubscriptionCard extends StatelessWidget {
  final AuthController auth;
  const _SubscriptionCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final isPro = auth.isPro;
    final l = L.of(context);
    return GroupedList(children: [
      GroupedRow(
        title: isPro ? 'FighterEdge Pro' : l.profileFreePlan,
        subtitle: isPro ? l.profileProActive : l.profileProDescription,
        trailing: Text(isPro ? l.profileManage : l.profileUpgrade,
            style: AppType.subhead(
                color: AppColors.premium, weight: FontWeight.w600)),
        onTap: () => AppNavigation.push(context, AppRoutes.paywall,
            extra: const PaywallRouteArgs(trigger: PaywallTrigger.profile),
            fallbackBuilder: (_) =>
                const PaywallScreen(trigger: PaywallTrigger.profile)),
      )
    ]);
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return GroupedRow(
        title: label,
        trailing: Text(value, style: AppType.callout(weight: FontWeight.w700)));
  }
}

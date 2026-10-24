import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_icons.dart';

import '../controllers/auth_controller.dart';
import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../l10n/decimal_format.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../state/app_state.dart';
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
import 'settings_screen.dart';
import 'weight_tracker_screen.dart';

class ProfileScreen extends StatelessWidget {
  final bool asTab;
  const ProfileScreen({super.key, this.asTab = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
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
    final body = Builder(
      builder: (context) => ListView(
        padding: EdgeInsets.fromLTRB(
            Insets.lg,
            MediaQuery.paddingOf(context).top,
            Insets.lg,
            ScreenScaffold.tabBottomPadding(context)),
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
          const SectionHeader('Training'),
          GroupedList(
            children: [
              GroupedRow(
                title: 'Training days',
                subtitle: '${user?.weeklyTrainingDays ?? 0} days each week',
              ),
              _ToolRow(
                title: 'Weight tracker',
                subtitle: 'Your weigh-ins and weight history',
                route: AppRoutes.weightTracker,
                screen: WeightTrackerScreen(),
              ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader('Preferences, privacy and account'),
          const GroupedList(
            children: [
              _ToolRow(
                title: 'Settings',
                subtitle: 'Units, reminders, data and account controls',
                route: AppRoutes.settings,
                screen: SettingsScreen(),
              ),
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
      ),
    );
    if (asTab) {
      return ScreenScaffold.tab(
          title: 'Profile', scrollsUnderHeader: true, body: body);
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

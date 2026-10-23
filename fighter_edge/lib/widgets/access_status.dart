import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../l10n/gen/app_localizations.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../screens/paywall_screen.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'trial_chip.dart';

/// The account's subscription state on Home, in one line: a gold
/// "Trial · N days left" chip during the store trial, or the read-only banner
/// once access has ended. Nothing for a paid or unconfirmed account.
///
/// It only reads [AuthController.accessState], so it can never show a state
/// the server has not confirmed.
class AccessStatus extends StatelessWidget {
  const AccessStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final access = auth.accessState;
    final effective = access.effective;
    if (effective == null) return const SizedBox.shrink();
    if (effective.isTrial) {
      final days = effective.trialDaysLeft(clock.now());
      if (days == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TrialChip(
            daysLeft: days,
            onTap: () => _openPaywall(context, PaywallTrigger.direct),
          ),
        ),
      );
    }
    // Read-only: but a purchase the store already accepted is "activating",
    // not "ended", while the server catches up.
    if (access.isReadOnly && !auth.billingState.isPro) {
      return const Padding(
        padding: EdgeInsets.only(bottom: Insets.md),
        child: ReadOnlyBanner(),
      );
    }
    return const SizedBox.shrink();
  }
}

void _openPaywall(BuildContext context, PaywallTrigger trigger) {
  AppNavigation.push<void>(
    context,
    AppRoutes.paywall,
    extra: PaywallRouteArgs(trigger: trigger),
    fallbackBuilder: (_) => PaywallScreen(trigger: trigger),
  );
}

/// "Your data is saved. Subscribe to keep training." with a way to the
/// paywall. Calm, not an error: nothing was lost.
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // At large text the button drops under the message instead of squeezing
    // it.
    final stacked = AppAccessibility.isLargeText(context);
    const icon = Icon(AppIcons.lockSimple,
        color: AppColors.premium, size: IconSizes.row);
    final message = Text(
      l.readOnlyBanner,
      style: AppType.subhead(color: AppColors.textPrimary),
    );
    final action = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.premium,
        minimumSize: const Size(
            AppAccessibility.minTouchTarget, AppAccessibility.minTouchTarget),
      ),
      onPressed: () => _openPaywall(context, PaywallTrigger.readOnly),
      child: Text(l.readOnlyBannerCta),
    );
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.premiumSoft,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: AppColors.premium),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.md, Insets.xs, Insets.xs, Insets.xs),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        icon,
                        const SizedBox(width: Insets.sm),
                        Expanded(child: message),
                      ],
                    ),
                    action,
                  ],
                )
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: Insets.sm),
                    Expanded(child: message),
                    action,
                  ],
                ),
        ),
      ),
    );
  }
}

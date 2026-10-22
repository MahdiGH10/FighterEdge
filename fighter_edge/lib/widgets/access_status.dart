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
import 'press_scale.dart';

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
          child: TrialChip(daysLeft: days),
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

/// "Trial · N days left". Gold is for paid and trial surfaces only.
class TrialChip extends StatelessWidget {
  const TrialChip({super.key, required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final label = L.of(context).trialChipDaysLeft(daysLeft);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        onTap: () => _openPaywall(context, PaywallTrigger.direct),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppAccessibility.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.premiumSoft,
                borderRadius: BorderRadius.circular(Radii.chip),
                border: Border.all(color: AppColors.premium),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md, vertical: Insets.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIconsFill.sealCheck,
                        color: AppColors.premium, size: IconSizes.inline),
                    const SizedBox(width: Insets.xs),
                    Flexible(
                      child: Text(label,
                          style: AppType.subhead(
                              weight: FontWeight.w800,
                              color: AppColors.premium)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Your data is saved. Subscribe to keep training." with a way to the
/// paywall. Calm, not an error: nothing was lost.
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
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
          child: Row(
            children: [
              const Icon(AppIcons.lockSimple,
                  color: AppColors.premium, size: IconSizes.row),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  l.readOnlyBanner,
                  style: AppType.subhead(color: AppColors.textPrimary),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.premium,
                  minimumSize: const Size(AppAccessibility.minTouchTarget,
                      AppAccessibility.minTouchTarget),
                ),
                onPressed: () => _openPaywall(context, PaywallTrigger.readOnly),
                child: Text(l.readOnlyBannerCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

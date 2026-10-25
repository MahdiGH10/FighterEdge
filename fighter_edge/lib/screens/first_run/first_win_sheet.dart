import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../features/edge_fuel/presentation/controllers/nutrition_mode_controller.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/premium_effects.dart';
import '../../widgets/primary_button.dart';
import '../notifications/notification_primer_sheet.dart';

/// Marks the first logged meal, and only then asks about reminders.
///
/// The ask waits for this moment on purpose: before the user has done
/// anything, "can we remind you?" is a request for trust not yet earned. Right
/// after a win it reads as an offer to help repeat it. The ask itself is the
/// notification primer, shown once this sheet has closed.
Future<void> showFirstWinSheet(BuildContext context) async {
  await showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const FirstWinSheet(),
  );
  if (!context.mounted || !shouldShowNotificationPrimer(context)) return;
  await showNotificationPrimer(context);
}

class FirstWinSheet extends StatelessWidget {
  const FirstWinSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final secondary = AppAccessibility.textSecondary(context);
    final numbers = context.watch<NutritionModeController>().numbersVisible;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PremiumReveal(child: _WinBadge()),
            const SizedBox(height: Insets.lg),
            PremiumReveal(
              index: 1,
              child: Text('First meal logged.', style: AppType.largeTitle()),
            ),
            const SizedBox(height: Insets.sm),
            PremiumReveal(
              index: 2,
              child: Text(
                numbers
                    ? "You're on the board. Every meal you log shows how today "
                        'stacks up against your target.'
                    : "You're on the board. Keep logging what you eat.",
                style: AppType.body(color: secondary),
              ),
            ),
            const SizedBox(height: Insets.xl),
            PrimaryButton(
              'Keep going',
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WinBadge extends StatelessWidget {
  const _WinBadge();

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: AppColors.positiveSoft,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.positive),
      ),
      child: const Icon(AppIcons.check, color: AppColors.positive),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/first_run_controller.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_haptics.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/premium_effects.dart';
import '../../widgets/primary_button.dart';

/// Marks the first logged meal, and only then asks about reminders.
///
/// The ask waits for this moment on purpose: before the user has done
/// anything, "can we remind you?" is a request for trust not yet earned. Right
/// after a win it reads as an offer to help repeat it.
Future<void> showFirstWinSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
    ),
    builder: (_) => const FirstWinSheet(),
  );
}

class FirstWinSheet extends StatelessWidget {
  const FirstWinSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final firstRun = context.read<FirstRunController>();
    // Someone who already switched reminders on in Settings has answered.
    final askReminders = !state.campReminders && !firstRun.remindersAsked;
    final secondary = AppAccessibility.textSecondary(context);

    void close({required bool remind}) {
      if (askReminders) {
        firstRun.markRemindersAsked();
        if (remind) {
          AppHaptics.commit();
          state.setCampReminders(true);
        }
      }
      Navigator.of(context).pop();
    }

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
                "You're on the board. Every meal you log shows how today "
                'stacks up against your target.',
                style: AppType.body(color: secondary),
              ),
            ),
            const SizedBox(height: Insets.xl),
            if (askReminders) ...[
              Text('Want a nudge on training days?', style: AppType.headline()),
              const SizedBox(height: Insets.xs),
              Text(
                'We’ll remind you to train and log on the days you picked. '
                'Change it anytime in Settings.',
                style: AppType.callout(color: secondary),
              ),
              const SizedBox(height: Insets.lg),
              PrimaryButton(
                'Remind me',
                icon: Icons.notifications_active_outlined,
                expand: true,
                onPressed: () => close(remind: true),
              ),
              const SizedBox(height: Insets.sm),
              GhostButton(
                'Not now',
                expand: true,
                onPressed: () => close(remind: false),
              ),
            ] else
              PrimaryButton(
                'Keep going',
                expand: true,
                onPressed: () => close(remind: false),
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
      child: const Icon(Icons.check_rounded, color: AppColors.positive),
    );
  }
}

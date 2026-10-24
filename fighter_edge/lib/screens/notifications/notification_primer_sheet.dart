import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../notifications/domain/notification_channel.dart';
import '../../notifications/notification_controller.dart';
import '../../state/first_run_controller.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_haptics.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/primary_button.dart';

/// Whether the primer is still worth showing: reminders can fire here, this
/// account has not been asked, and the session reminder is not already on.
bool shouldShowNotificationPrimer(BuildContext context) {
  final notifications = context.read<NotificationController>();
  final firstRun = context.read<FirstRunController>();
  return notifications.isAvailable &&
      !firstRun.remindersAsked &&
      !notifications.settings.isEnabled(NotificationChannel.sessionReminder);
}

/// Asks, once, whether to send a reminder before the next session. The OS
/// permission prompt only appears after a yes, and the question is never
/// asked again whatever the answer; Settings has the switch from then on.
Future<void> showNotificationPrimer(BuildContext context) {
  // Counted as asked the moment it is shown, so a swipe away is an answer too.
  context.read<FirstRunController>().markRemindersAsked();
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const NotificationPrimerSheet(),
  );
}

class NotificationPrimerSheet extends StatelessWidget {
  const NotificationPrimerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final notifications = context.read<NotificationController>();

    Future<void> answer({required bool yes}) async {
      final navigator = Navigator.of(context);
      if (yes) {
        AppHaptics.commit();
        // The sheet closes first: the system prompt appears over the app,
        // and a refusal leaves Settings to explain, not this sheet.
        navigator.pop();
        await notifications.enableSessionReminders();
      } else {
        navigator.pop();
      }
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.notifPrimerTitle, style: AppType.title1()),
            const SizedBox(height: Insets.sm),
            Text(
              l.notifPrimerBody,
              style:
                  AppType.body(color: AppAccessibility.textSecondary(context)),
            ),
            const SizedBox(height: Insets.xl),
            PrimaryButton(
              l.notifPrimerYes,
              icon: AppIcons.bellRinging,
              expand: true,
              onPressed: () => answer(yes: true),
            ),
            const SizedBox(height: Insets.sm),
            GhostButton(
              l.notifPrimerNo,
              expand: true,
              onPressed: () => answer(yes: false),
            ),
          ],
        ),
      ),
    );
  }
}

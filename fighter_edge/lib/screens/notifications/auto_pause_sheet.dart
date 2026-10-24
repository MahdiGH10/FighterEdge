import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../notifications/domain/notification_channel.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/primary_button.dart';

/// The one gentle question after a channel went quiet because its last few
/// notifications went unopened: keep it, or turn it off.
///
/// Returns true to keep, false to turn off, null when dismissed (the channel
/// stays paused and the question comes back the next time the app opens).
Future<bool?> showAutoPauseSheet(
  BuildContext context,
  NotificationChannel channel,
) {
  return showGlassSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AutoPauseSheet(channel: channel),
  );
}

class AutoPauseSheet extends StatelessWidget {
  const AutoPauseSheet({super.key, required this.channel});

  final NotificationChannel channel;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final body = switch (channel) {
      NotificationChannel.sessionReminder => l.notifAutoPauseBodySession,
      NotificationChannel.weeklyReview => l.notifAutoPauseBodyReview,
      _ => l.notifAutoPauseBodyGeneric,
    };
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.notifAutoPauseTitle, style: AppType.title1()),
            const SizedBox(height: Insets.sm),
            Text(
              body,
              style:
                  AppType.body(color: AppAccessibility.textSecondary(context)),
            ),
            const SizedBox(height: Insets.xl),
            PrimaryButton(
              l.notifAutoPauseKeep,
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Insets.sm),
            GhostButton(
              l.notifAutoPauseOff,
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

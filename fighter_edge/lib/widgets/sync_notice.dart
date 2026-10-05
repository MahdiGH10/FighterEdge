import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../state/sync_tracker.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// One line that appears only while a change was refused by the server, with
/// a way to send it again. Shared by Home and Fuel so the athlete hears about
/// it wherever they are, in the same words.
///
/// Amber, not red: nothing is lost on the device, it just hasn't reached the
/// account yet.
class SyncNotice extends StatelessWidget {
  /// Space below the notice when it shows; nothing when it doesn't.
  final double bottomSpacing;

  const SyncNotice({super.key, this.bottomSpacing = Insets.md});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncTracker>();
    if (!sync.hasFailure && !sync.isRetrying) return const SizedBox.shrink();
    final l = L.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.md, Insets.xs, Insets.xs, Insets.xs),
            child: Row(
              children: [
                const Icon(AppIcons.cloudSlash,
                    color: AppColors.warning, size: IconSizes.row),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    l.syncNotSaved,
                    style: AppType.subhead(color: AppColors.textPrimary),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    minimumSize: const Size(AppAccessibility.minTouchTarget,
                        AppAccessibility.minTouchTarget),
                  ),
                  onPressed: sync.isRetrying ? null : sync.retry,
                  child: Text(sync.isRetrying ? l.syncRetrying : l.syncRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

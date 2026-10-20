import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'primary_button.dart';
import 'stat_card.dart';

/// This week against the weekly target: "3 of 5 done", what is next, and the
/// week streak. Tapping it opens the week to act on. Rest days are not in the
/// numbers: only planned sessions count, and nothing here ever says "missed".
class WeeklyTargetCard extends StatelessWidget {
  const WeeklyTargetCard({
    super.key,
    required this.completed,
    required this.planned,
    required this.target,
    required this.streakWeeks,
    this.nextDay,
    this.nextTitle,
    required this.onOpenWeek,
    this.onOpenReview,
  });

  final int completed;
  final int planned;

  /// Sessions that make the week count; below [planned] on busy weeks.
  final int target;
  final int streakWeeks;

  /// The next session this week ("Thu", "Skill session"), if any.
  final String? nextDay;
  final String? nextTitle;
  final VoidCallback onOpenWeek;

  /// Set on review days while the week has not been reviewed.
  final VoidCallback? onOpenReview;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final secondary = AppAccessibility.textSecondary(context);
    final headline = planned == 0
        ? l.weeklyCardRestWeek
        : l.weeklyCardProgress(completed, planned);
    final next = nextDay != null && nextTitle != null
        ? l.weeklyCardNext(nextDay!, nextTitle!)
        : planned == 0
            ? l.weeklyCardRestWeekHint
            : completed >= planned
                ? l.weeklyCardAllDone
                : l.weeklyCardNothingLeft;
    final progress = planned == 0 ? 0.0 : (completed / planned).clamp(0.0, 1.0);
    final details = [
      if (planned > 0 && target < planned) l.weeklyCardTarget(target),
      if (streakWeeks > 0) l.weeklyCardStreak(streakWeeks),
    ];
    return AppCard(
      onTap: onOpenWeek,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.weeklyCardTitle.toUpperCase(),
              style: AppType.micro(color: AppAccessibility.textMuted(context))),
          const SizedBox(height: Insets.xs),
          Text(headline, style: AppType.title1()),
          const SizedBox(height: Insets.xs),
          Text(next, style: AppType.callout(color: secondary)),
          if (planned > 0) ...[
            const SizedBox(height: Insets.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(Insets.xs),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: Insets.sm,
                backgroundColor: AppColors.track,
                color: AppColors.primary,
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Text(details.join(' · '), style: AppType.subhead(color: secondary)),
          ],
          if (onOpenReview != null) ...[
            const SizedBox(height: Insets.md),
            GhostButton(l.weeklyCardReview,
                expand: true, onPressed: onOpenReview),
          ],
        ],
      ),
    );
  }
}

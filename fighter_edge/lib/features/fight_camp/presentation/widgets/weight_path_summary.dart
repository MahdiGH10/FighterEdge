import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/stat_card.dart';
import '../../domain/weight_path.dart';
import '../fight_camp_controller.dart';
import '../fight_camp_copy.dart';

/// Three numbers first, then what they mean (pattern brief, pattern 2):
/// trend weight, limit and what is left, then the path status in words.
class WeightPathSummary extends StatelessWidget {
  final FightCampStatus status;
  final FightCampCopy copy;

  const WeightPathSummary(
      {super.key, required this.status, required this.copy});

  @override
  Widget build(BuildContext context) {
    final l = copy.l;
    final trend = status.trend.trendKg;
    final limit = status.camp.weightLimitKg;
    final path = status.path;
    final (tone, icon) = switch (path.status) {
      WeightPathStatus.onTrack || WeightPathStatus.atWeight => (
          AppColors.positive,
          Icons.check_circle_outline
        ),
      WeightPathStatus.needsSupervision => (
          AppColors.warning,
          Icons.warning_amber_rounded
        ),
      WeightPathStatus.notSafe => (AppColors.negative, Icons.block),
      WeightPathStatus.needsMoreData || WeightPathStatus.notSupported => (
          AppAccessibility.textSecondary(context),
          Icons.info_outline
        ),
    };
    final message = copy.pathMessage(path);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.fightPathTitle, style: AppType.headline()),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.xl,
            runSpacing: Insets.md,
            children: [
              _Number(
                label: l.fightPathNow,
                value: trend == null ? '—' : copy.weight(trend),
                unit: copy.unit,
              ),
              _Number(
                label: l.fightPathLimit,
                value: copy.weight(limit),
                unit: copy.unit,
              ),
              _Number(
                label: l.fightPathToGo,
                value: trend == null
                    ? '—'
                    : copy.weight(math.max(0, trend - limit)),
                unit: copy.unit,
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(icon, size: IconSizes.row, color: tone),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(message, style: AppType.callout()),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            l.fightPathSource,
            style: AppType.subhead(color: AppAccessibility.textMuted(context)),
          ),
        ],
      ),
    );
  }
}

class _Number extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _Number({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value $unit',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppType.subhead(
                  color: AppAccessibility.textSecondary(context))),
          const SizedBox(height: Insets.xxs),
          Text.rich(TextSpan(children: [
            TextSpan(text: value, style: AppType.title1()),
            TextSpan(
                text: ' $unit',
                style: AppType.subhead(
                    color: AppAccessibility.textSecondary(context))),
          ])),
        ],
      ),
    );
  }
}

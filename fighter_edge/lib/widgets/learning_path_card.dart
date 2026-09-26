import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../training/drills/drill.dart';
import '../training/drills/learning_path.dart';
import 'primary_button.dart';
import 'stat_card.dart';

String learningDisciplineLabel(L l, DrillDiscipline discipline) =>
    switch (discipline) {
      DrillDiscipline.striking => l.learningStriking,
      DrillDiscipline.wrestling => l.learningWrestling,
      DrillDiscipline.bjj => l.learningBjj,
      DrillDiscipline.clinch => l.learningClinch,
    };

String _disciplineHint(L l, DrillDiscipline discipline) => switch (discipline) {
      DrillDiscipline.striking => l.learningStrikingHint,
      DrillDiscipline.wrestling => l.learningWrestlingHint,
      DrillDiscipline.bjj => l.learningBjjHint,
      DrillDiscipline.clinch => l.learningClinchHint,
    };

/// One guided recommendation, above the independently browsable library.
class LearningPathCard extends StatelessWidget {
  final DrillDiscipline? discipline;
  final Map<String, DrillProgress> progress;
  final bool isPro;
  final ValueChanged<DrillDiscipline> onChoose;
  final VoidCallback onChange;
  final ValueChanged<PathRecommendation> onOpen;

  const LearningPathCard(
      {super.key,
      required this.discipline,
      required this.progress,
      required this.isPro,
      required this.onChoose,
      required this.onChange,
      required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final selected = discipline;
    final secondary = AppAccessibility.textSecondary(context);
    final buttonStyle = TextButton.styleFrom(
      minimumSize: const Size.fromHeight(AppAccessibility.minTouchTarget),
      foregroundColor: AppColors.textPrimary,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
    );
    if (selected == null) {
      return AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.learningStart, style: AppType.title2()),
        const SizedBox(height: Insets.sm),
        Text(l.learningChoose, style: AppType.headline()),
        Text(l.learningChooseHint, style: AppType.subhead(color: secondary)),
        const SizedBox(height: Insets.sm),
        for (final discipline in DrillDiscipline.values)
          TextButton(
              key: ValueKey('choose-path-${discipline.name}'),
              style: buttonStyle,
              onPressed: () => onChoose(discipline),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(learningDisciplineLabel(l, discipline),
                        style: AppType.callout(weight: FontWeight.w700)),
                    Text(_disciplineHint(l, discipline),
                        style: AppType.subhead(color: secondary)),
                  ])),
      ]));
    }
    final path = LearningPath.forDiscipline(selected);
    final status = pathProgress(path, progress);
    final next = nextDrill(path, progress, isPro: isPro);
    final stage = switch (status.stage) {
      LearningStage.foundations => l.learningFoundations,
      LearningStage.building => l.learningBuilding,
      LearningStage.sharp => l.learningSharp,
    };
    return AppCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.learningStart, style: AppType.title2()),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(learningDisciplineLabel(l, selected),
                style: AppType.headline()),
            TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(AppAccessibility.minTouchTarget,
                      AppAccessibility.minTouchTarget),
                  foregroundColor: AppColors.textPrimary,
                ),
                onPressed: onChange,
                child: Text(l.learningChange,
                    style: AppType.subhead(color: secondary))),
          ]),
      Text(_disciplineHint(l, selected),
          style: AppType.subhead(color: secondary)),
      const SizedBox(height: Insets.lg),
      Text(stage, style: AppType.callout(weight: FontWeight.w700)),
      Text(l.learningCount(status.completed, status.total),
          style: AppType.subhead(color: secondary)),
      const SizedBox(height: Insets.sm),
      Semantics(
        container: true,
        child: LinearProgressIndicator(
            value: status.fraction,
            minHeight: Insets.xs,
            backgroundColor: AppColors.track,
            color: AppColors.textSecondary,
            semanticsLabel: l.learningCount(status.completed, status.total)),
      ),
      const SizedBox(height: Insets.sm),
      Text(l.learningProgressHint, style: AppType.subhead(color: secondary)),
      const SizedBox(height: Insets.lg),
      if (next == null) ...[
        Text(l.learningComplete, style: AppType.headline()),
        Text(l.learningCompleteHint, style: AppType.callout(color: secondary)),
      ] else ...[
        Text(next.drill.title, style: AppType.headline()),
        const SizedBox(height: Insets.xs),
        Text(next.drill.summary, style: AppType.callout(color: secondary)),
        const SizedBox(height: Insets.md),
        if (next.locked) ...[
          Text(l.learningLocked,
              style: AppType.subhead(color: AppColors.premium)),
          const SizedBox(height: Insets.sm),
          Semantics(
            container: true,
            child: GhostButton(l.learningViewPro,
                icon: Icons.lock_outline,
                expand: true,
                onPressed: () => onOpen(next)),
          ),
        ] else
          Semantics(
            container: true,
            child: PrimaryButton(l.learningLearn(next.drill.title),
                expand: true, onPressed: () => onOpen(next)),
          ),
      ],
    ]));
  }
}

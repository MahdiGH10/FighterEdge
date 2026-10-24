import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../routing/app_navigation.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_accessibility.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/press_scale.dart';
import '../../daily_snapshot/presentation/daily_snapshot_builder.dart';
import '../../edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../../edge_fuel/presentation/controllers/nutrition_mode_controller.dart';
import '../../edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';
import '../../fight_camp/presentation/fight_camp_controller.dart';
import '../../training_plan/presentation/plan_controller.dart';
import '../../../state/app_state.dart';
import '../domain/corner_brief.dart';

/// The Corner Brief on Home: the one line the app calculates for today, as a
/// plain row under the session, no card. When the line is "set up EdgeFuel",
/// tapping it opens the setup.
class CornerLineRow extends StatelessWidget {
  const CornerLineRow({super.key});

  @override
  Widget build(BuildContext context) {
    // The corner line is a food and weight cue; nutrition paused, no line.
    if (!context.watch<NutritionModeController>().visible) {
      return const SizedBox.shrink();
    }
    final l = L.of(context);
    final state = context.watch<AppState>();
    final plan = context.watch<PlanController>();
    final fightCamp = context.watch<FightCampController>();
    final fuel = context.watch<EdgeFuelController>();

    final today =
        buildDailySnapshot(state, plan, fightCamp, fuelDraft: fuel.draft);
    // Fuel can be showing another day; the line is only ever about today.
    final day = fuel.isToday ? fuel.day : null;
    final line =
        CornerBriefCalculator.line(today: today, target: fuel.target, day: day);

    final lineText = Text(cornerCueText(l, line),
        style: AppType.callout(color: AppAccessibility.textSecondary(context)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.clipboardText,
              size: IconSizes.inline,
              color: AppAccessibility.textMuted(context)),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  header: true,
                  child: Text(l.cornerBriefTitle,
                      style: AppType.micro(
                          weight: FontWeight.w800,
                          color: AppAccessibility.textMuted(context))),
                ),
                const SizedBox(height: Insets.xxs),
                if (line.cue == CornerCue.setUpFuel)
                  Semantics(
                    button: true,
                    child: PressScale(
                      onTap: () => AppNavigation.push(
                          context, AppRoutes.fuelSetup,
                          fallbackBuilder: (_) => const EdgeFuelSetupScreen()),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: Insets.xs),
                        child: lineText,
                      ),
                    ),
                  )
                else
                  lineText,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The calculated line, in words.
String cornerCueText(L l, CornerLine line) => switch (line.cue) {
      CornerCue.seeProfessional => l.cornerCueSeeProfessional,
      CornerCue.setUpFuel => l.cornerCueSetUpFuel,
      CornerCue.firstMeal => l.cornerCueFirstMeal,
      CornerCue.protein => l.cornerCueProtein(line.amount ?? 0),
      CornerCue.carbsBeforeTraining =>
        l.cornerCueCarbsBeforeTraining(line.amount ?? 0),
      CornerCue.carbs => l.cornerCueCarbs(line.amount ?? 0),
      CornerCue.calories => l.cornerCueCalories(line.amount ?? 0),
      CornerCue.onTrack => l.cornerCueOnTrack,
    };

import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../state/app_state.dart';
import '../domain/fight_camp.dart';
import '../domain/fight_week_plan.dart';
import '../domain/weight_cut_policy.dart';
import '../domain/weight_path.dart';
import 'fight_camp_controller.dart';

/// Words for fight-camp numbers. Every number comes from the domain; this
/// only formats it in the athlete's unit and language.
class FightCampCopy {
  FightCampCopy(this.l, this.units, this.locale);

  final L l;
  final AppState units;
  final String locale;

  String weight(double kg) => units.displayWeight(kg).toStringAsFixed(1);

  String get unit => units.weightUnitLabel;

  String date(DateTime date) => DateFormat.MMMEd(locale)
      .format(DateTime(date.year, date.month, date.day));

  /// Day and month only, in the locale's order ("8/30", "30.8.").
  String shortDate(DateTime date) =>
      DateFormat.Md(locale).format(DateTime(date.year, date.month, date.day));

  String category(CompetitionCategory category) => switch (category) {
        CompetitionCategory.grappling => l.fightCategoryGrappling,
        CompetitionCategory.amateurStriking => l.fightCategoryAmateur,
        CompetitionCategory.olympic => l.fightCategoryOlympic,
        CompetitionCategory.professional => l.fightCategoryPro,
      };

  String categoryHint(CompetitionCategory category) => switch (category) {
        CompetitionCategory.grappling => l.fightCategoryGrapplingHint,
        CompetitionCategory.amateurStriking => l.fightCategoryAmateurHint,
        CompetitionCategory.olympic => l.fightCategoryOlympicHint,
        CompetitionCategory.professional => l.fightCategoryProHint,
      };

  /// The full explanation of a weight path, for the setup screen.
  String pathMessage(WeightPath path) => switch (path.status) {
        WeightPathStatus.onTrack => path.weeklyLossKg > 0 &&
                path.fightWeekEntryKg != null
            ? l.fightPathOnPace(
                weight(path.weeklyLossKg), weight(path.fightWeekEntryKg!), unit)
            : l.fightPathHold,
        WeightPathStatus.needsSupervision =>
          l.fightPathSupervision(weight(path.lightestSafeLimitKg!), unit),
        WeightPathStatus.notSafe =>
          l.fightPathNotSafe(weight(path.lightestSafeLimitKg!), unit),
        WeightPathStatus.atWeight => l.fightPathAtWeight,
        WeightPathStatus.needsMoreData => l.fightPathNeedsWeight,
        WeightPathStatus.notSupported => l.fightPathAdultsOnly,
      };

  /// One line for the dashboard: the full message when it is short, a
  /// pointer to the setup screen when it is a warning.
  String pathLine(WeightPath path) => switch (path.status) {
        WeightPathStatus.needsSupervision => l.fightPathShortSupervision,
        WeightPathStatus.notSafe => l.fightPathShortNotSafe,
        _ => pathMessage(path),
      };

  /// Where the athlete is in the camp, in words.
  String phaseLine(FightCampStatus status, DateTime today) {
    final camp = status.camp;
    return switch (status.phase) {
      CampPhase.camp =>
        l.fightPhaseCamp(camp.campWeekOn(today)!, camp.campWeeks),
      CampPhase.fightWeek => status.daysToWeighIn == 0
          ? (status.daysToFight == 0
              ? l.fightPhaseFightDay
              : l.fightPhaseWeighIn)
          : l.fightPhaseFightWeek(camp.fightWeekDayOn(today)!),
      CampPhase.refuel =>
        status.daysToFight == 0 ? l.fightPhaseFightDay : l.fightPhaseRefuel,
      CampPhase.offCamp => l.fightPhaseBeforeCamp(date(camp.fightWeekStart
          .subtract(Duration(days: (camp.campWeeks - 1) * 7)))),
      CampPhase.postFight => l.fightDone,
    };
  }

  /// What fight week asks for, in one message. Warnings reuse the weight
  /// path's words, adjusted for a week that has already started.
  String fightWeekMessage(FightWeekPlan plan) {
    final path = plan.path;
    final start = plan.cutStart;
    return switch (plan.status) {
      WeightPathStatus.needsSupervision =>
        l.fightWeekSupervision(weight(path.lightestSafeLimitKg!), unit),
      WeightPathStatus.notSafe => pathMessage(path),
      WeightPathStatus.notSupported => l.fightPathAdultsOnly,
      _ => switch (plan.cut) {
          FightWeekCut.lowFibreAndCarbs when start != null =>
            l.fightWeekCarbs(weight(plan.acuteLossKg), unit, date(start)),
          FightWeekCut.lowFibre when start != null =>
            l.fightWeekFibre(weight(plan.acuteLossKg), unit, date(start)),
          FightWeekCut.notPlanned => l.fightWeekNeedsWeight,
          _ => l.fightWeekNoCut,
        },
    };
  }

  String stepTitle(FightWeekStep step) => switch (step) {
        FightWeekStep.eatToPlan => l.fightStepEat,
        FightWeekStep.lowFibre => l.fightStepFibre,
        FightWeekStep.lowerCarbs => l.fightStepCarbs,
        FightWeekStep.weighIn => l.fightStepWeighIn,
        FightWeekStep.refuel => l.fightStepRefuel,
        FightWeekStep.fight => l.fightStepFight,
      };

  String stepBody(FightWeekStep step) => switch (step) {
        FightWeekStep.eatToPlan => l.fightStepEatBody,
        FightWeekStep.lowFibre =>
          l.fightStepFibreBody(WeightCutPolicy.lowFibreMaxGramsPerDay),
        FightWeekStep.lowerCarbs => l.fightStepCarbsBody,
        FightWeekStep.weighIn => l.fightStepWeighInBody,
        FightWeekStep.refuel => l.fightStepRefuelBody,
        FightWeekStep.fight => l.fightStepFightBody,
      };

  /// A fluid range in the athlete's units: "1–1.5 L", "34–51 fl oz".
  String fluidRange(double minLitres, double maxLitres) {
    if (units.useMetricUnits) {
      final f = NumberFormat('0.#', locale);
      return '${f.format(minLitres)}–${f.format(maxLitres)} L';
    }
    const flOzPerLitre = 33.814;
    return '${(minLitres * flOzPerLitre).round()}–'
        '${(maxLitres * flOzPerLitre).round()} fl oz';
  }

  String grams(int grams) =>
      '${NumberFormat.decimalPattern(locale).format(grams)} g';

  String gramsRange(int min, int max) =>
      '${NumberFormat.decimalPattern(locale).format(min)}–'
      '${NumberFormat.decimalPattern(locale).format(max)} g';
}

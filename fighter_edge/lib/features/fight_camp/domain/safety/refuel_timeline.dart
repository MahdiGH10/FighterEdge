import '../calendar.dart';
import '../fight_camp.dart';
import '../weight_cut_policy.dart';
import 'cut_safety_screen.dart';
import 'fighter_safety_flags.dart';

/// The stretches after the scale, in order (ISSN 2025 points 12-15).
enum RefuelWindow {
  /// The first two hours after the weigh-in.
  firstTwoHours,

  /// Hours three to six.
  threeToSixHours,

  /// From six hours on, until fight day.
  sixHoursPlus,

  /// Fight day, before the bout.
  fightDay,
}

/// What a window focuses on. Information only: the UI turns each into copy.
enum RefuelFocus {
  oralRehydrationSolution,
  fastCarbs,
  limitFibreAndFat,

  /// Coffee, citrus, tomato, fizzy drinks, chocolate, peppermint, garlic,
  /// onion, fatty, spicy or fried food (ISSN 0-2 h list).
  avoidGutIrritants,

  electrolyteFluids,
  simpleStarches,
  carbRichMeals,
  moderateProtein,
  littleFat,
  smallFrequentMeals,
  noNewFoods,

  /// Carbohydrate in the hours before the bout.
  preBoutCarbs,

  proteinEachMeal,

  /// Little or no fat in the last hours before the bout.
  lowFatBeforeBout,
}

enum RefuelCheck {
  logWeightRegain,
  urineColour,
  gutComfort,

  /// Tell the event's medical staff about any symptom.
  reportSymptoms,
}

/// Amounts for one window. Every field is null unless
/// [FighterSafetyFlags.refuelVolumes] is on.
// dietitian sign-off pending: every amount here.
class RefuelAmounts {
  const RefuelAmounts({
    this.minLitresPerHour,
    this.maxLitresPerHour,
    this.maxCarbGramsPerHour,
    this.totalCarbMinGrams,
    this.totalCarbMaxGrams,
    this.proteinMinGramsPerMeal,
    this.proteinMaxGramsPerMeal,
    this.lowFatHoursBeforeBout,
  });

  /// Oral rehydration solution, litres an hour.
  final double? minLitresPerHour;
  final double? maxLitresPerHour;

  final int? maxCarbGramsPerHour;

  /// Carbohydrate for the whole window, rounded to 10 g and worked out at
  /// the weight limit, the weight the fighter weighs in at.
  final int? totalCarbMinGrams;
  final int? totalCarbMaxGrams;

  final int? proteinMinGramsPerMeal;
  final int? proteinMaxGramsPerMeal;

  final int? lowFatHoursBeforeBout;
}

class RefuelStep {
  const RefuelStep({
    required this.window,
    required this.focus,
    required this.checks,
    this.amounts,
  });

  final RefuelWindow window;
  final List<RefuelFocus> focus;
  final List<RefuelCheck> checks;

  /// Null unless [FighterSafetyFlags.refuelVolumes] is on.
  final RefuelAmounts? amounts;

  /// Hours after the weigh-in the window starts; null for [RefuelWindow.fightDay].
  int? get startHour => switch (window) {
        RefuelWindow.firstTwoHours => 0,
        RefuelWindow.threeToSixHours => 2,
        RefuelWindow.sixHoursPlus => 6,
        RefuelWindow.fightDay => null,
      };
}

/// The fight-day numbers from the ISSN 2025 worked example, as given in the
/// combat research §3. The refuel numbers before fight day live in
/// [WeightCutPolicy].
// dietitian sign-off pending: every number in this class.
class RefuelPolicy {
  const RefuelPolicy._();

  /// "1-4 g/kg" of carbohydrate in the hours before the bout.
  static const double fightDayMinCarbGramsPerKg = 1;
  static const double fightDayMaxCarbGramsPerKg = 4;

  /// "20-30 g" of protein a meal.
  static const int fightDayMinProteinGrams = 20;
  static const int fightDayMaxProteinGrams = 30;

  /// No fat for "about 3 h" before the bout.
  static const int fightDayLowFatHours = 3;
}

/// Refuel after the scale, window by window: what to eat and drink and what
/// to check, with amounts only behind [FighterSafetyFlags.refuelVolumes].
/// Information for healthy adults, not a plan for the cut itself, which the
/// app never makes (rule 3).
///
/// Pure Dart: no clock, no platform, no network.
// dietitian sign-off pending: windows, focus lists and amounts.
class RefuelTimeline {
  const RefuelTimeline._(this.steps, {required this.showsAmounts});

  final List<RefuelStep> steps;

  /// True when the steps carry [RefuelAmounts].
  final bool showsAmounts;

  RefuelStep? step(RefuelWindow window) =>
      steps.where((s) => s.window == window).firstOrNull;

  /// Null for anyone without a valid adult age (rule 4).
  ///
  /// [hoursWeighInToFight] trims the windows to the time there is. When it
  /// is unknown, a same-day weigh-in gets only the first two hours and
  /// fight day; a weigh-in on an earlier day gets every window.
  static RefuelTimeline? build({
    required FightCamp camp,
    required int? ageYears,
    int? hoursWeighInToFight,
    FighterSafetyFlags flags = FighterSafetyFlags.off,
  }) {
    if (!CutSafetyScreen.cutToolsAllowedForAge(ageYears)) return null;
    final sameDay = daysBetween(camp.weighInDate, camp.fightDate) == 0;
    final gap = hoursWeighInToFight;
    bool fits(int startHour) {
      if (startHour == 0) return true;
      if (gap != null) return gap > startHour;
      return !sameDay;
    }

    final amounts = flags.refuelVolumes;
    final limit = camp.weightLimitKg;
    int grams(double perKg) => (limit * perKg / 10).round() * 10;

    return RefuelTimeline._(
      [
        RefuelStep(
          window: RefuelWindow.firstTwoHours,
          focus: const [
            RefuelFocus.oralRehydrationSolution,
            RefuelFocus.fastCarbs,
            RefuelFocus.limitFibreAndFat,
            RefuelFocus.avoidGutIrritants,
          ],
          checks: const [RefuelCheck.logWeightRegain],
          amounts: amounts
              ? const RefuelAmounts(
                  minLitresPerHour: WeightCutPolicy.refuelMinLitresPerHour,
                  maxLitresPerHour: WeightCutPolicy.refuelMaxLitresPerHour,
                  maxCarbGramsPerHour:
                      WeightCutPolicy.refuelMaxCarbGramsPerHour,
                )
              : null,
        ),
        if (fits(2))
          RefuelStep(
            window: RefuelWindow.threeToSixHours,
            focus: const [
              RefuelFocus.electrolyteFluids,
              RefuelFocus.simpleStarches,
              RefuelFocus.limitFibreAndFat,
            ],
            checks: const [RefuelCheck.urineColour],
            amounts: amounts
                ? const RefuelAmounts(
                    maxCarbGramsPerHour:
                        WeightCutPolicy.refuelMaxCarbGramsPerHour,
                  )
                : null,
          ),
        if (fits(6))
          RefuelStep(
            window: RefuelWindow.sixHoursPlus,
            focus: const [
              RefuelFocus.carbRichMeals,
              RefuelFocus.moderateProtein,
              RefuelFocus.littleFat,
              RefuelFocus.smallFrequentMeals,
              RefuelFocus.noNewFoods,
            ],
            checks: const [RefuelCheck.gutComfort, RefuelCheck.logWeightRegain],
            // The 4-7 g/kg total is for the time between weigh-in and
            // fight, so only when that is at least a night.
            amounts: amounts && !sameDay
                ? RefuelAmounts(
                    totalCarbMinGrams:
                        grams(WeightCutPolicy.refuelMinCarbGramsPerKg),
                    totalCarbMaxGrams:
                        grams(WeightCutPolicy.refuelMaxCarbGramsPerKg),
                  )
                : null,
          ),
        RefuelStep(
          window: RefuelWindow.fightDay,
          focus: const [
            RefuelFocus.preBoutCarbs,
            RefuelFocus.proteinEachMeal,
            RefuelFocus.lowFatBeforeBout,
            RefuelFocus.noNewFoods,
          ],
          checks: const [RefuelCheck.reportSymptoms],
          amounts: amounts
              ? RefuelAmounts(
                  totalCarbMinGrams:
                      grams(RefuelPolicy.fightDayMinCarbGramsPerKg),
                  totalCarbMaxGrams:
                      grams(RefuelPolicy.fightDayMaxCarbGramsPerKg),
                  proteinMinGramsPerMeal: RefuelPolicy.fightDayMinProteinGrams,
                  proteinMaxGramsPerMeal: RefuelPolicy.fightDayMaxProteinGrams,
                  lowFatHoursBeforeBout: RefuelPolicy.fightDayLowFatHours,
                )
              : null,
        ),
      ],
      showsAmounts: amounts,
    );
  }
}

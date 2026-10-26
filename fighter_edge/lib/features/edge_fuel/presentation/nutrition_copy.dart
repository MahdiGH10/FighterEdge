import '../domain/models/nutrition_enums.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Human-readable copy for EdgeFuel domain enums and the machine-readable
/// reason/warning codes the calculator returns. Kept separate from the
/// domain layer (which must stay pure Dart and localization-agnostic) and
/// from individual screens (several screens need the same labels).
class NutritionCopy {
  NutritionCopy._();

  static String goalLabelL(L l, NutritionGoal goal) => switch (goal) {
        NutritionGoal.loseFat => l.onboardingLoseFat,
        NutritionGoal.maintain => l.setupGoalMaintainLabel,
        NutritionGoal.gainMuscle => l.onboardingGainMuscle,
      };

  static String goalDescriptionL(L l, NutritionGoal goal) => switch (goal) {
        NutritionGoal.loseFat => l.setupGoalLoseDescription,
        NutritionGoal.maintain => l.setupGoalMaintainDescription,
        NutritionGoal.gainMuscle => l.setupGoalGainDescription,
      };

  static String equationLabelL(L l, EquationProfile profile) =>
      switch (profile) {
        EquationProfile.higherOffset => l.setupEquationHigher,
        EquationProfile.lowerOffset => l.setupEquationLower,
        EquationProfile.neutral => l.setupEquationNeutral,
      };

  static String equationDescriptionL(L l, EquationProfile profile) =>
      switch (profile) {
        EquationProfile.higherOffset => l.setupEquationHigherHint,
        EquationProfile.lowerOffset => l.setupEquationLowerHint,
        EquationProfile.neutral => l.setupEquationNeutralHint,
      };

  static String activityLabelL(L l, ActivityLevel level) => switch (level) {
        ActivityLevel.veryLow => l.setupActivityVeryLow,
        ActivityLevel.light => l.setupActivityLight,
        ActivityLevel.moderate => l.setupActivityModerate,
        ActivityLevel.high => l.setupActivityHigh,
        ActivityLevel.veryHigh => l.setupActivityVeryHigh,
      };

  static String activityDescriptionL(L l, ActivityLevel level) =>
      switch (level) {
        ActivityLevel.veryLow => l.setupActivityVeryLowHint,
        ActivityLevel.light => l.setupActivityLightHint,
        ActivityLevel.moderate => l.setupActivityModerateHint,
        ActivityLevel.high => l.setupActivityHighHint,
        ActivityLevel.veryHigh => l.setupActivityVeryHighHint,
      };

  static String paceLabelL(L l, GoalPace pace) => switch (pace) {
        GoalPace.gentle => l.fuelPaceGentle,
        GoalPace.standard || GoalPace.gainStandard => l.fuelPaceStandard,
        GoalPace.upperLimit => l.fuelPaceUpper,
        GoalPace.conservative => l.fuelPaceConservative,
      };

  static String paceDescriptionL(L l, GoalPace pace) => switch (pace) {
        GoalPace.gentle => l.fuelPaceGentleHint,
        GoalPace.standard => l.fuelPaceStandardHint,
        GoalPace.upperLimit => l.fuelPaceUpperHint,
        GoalPace.conservative => l.fuelPaceConservativeHint,
        GoalPace.gainStandard => l.fuelPaceGainHint,
      };

  static String confidenceLabelL(L l, ConfidenceLabel confidence) =>
      switch (confidence) {
        ConfidenceLabel.high => l.fuelConfidenceHigh,
        ConfidenceLabel.medium => l.fuelConfidenceMedium,
        ConfidenceLabel.low => l.fuelConfidenceLow,
      };

  static String reasonL(L l, String code) => switch (code) {
        'screeningUnanswered' => l.setupReasonScreeningUnanswered,
        'screeningNeedsReview' => l.setupReasonScreeningNeedsReview,
        'underAge' => l.setupReasonUnderAge,
        'invalidVitals' => l.setupReasonInvalidVitals,
        'underweightForFatLoss' => l.setupReasonUnderweight,
        'invalidFatLossTarget' => l.setupReasonInvalidFatLoss,
        'invalidMuscleGainTarget' => l.setupReasonInvalidMuscleGain,
        'missingTargetWeight' => l.setupReasonMissingTarget,
        'missingGoalPace' => l.setupReasonMissingPace,
        'rmrCalculationOutOfRange' => l.setupReasonRmrRange,
        'pregnantOrBreastfeeding' => l.setupHealthPregnant,
        'eatingDisorderHistoryOrSymptoms' => l.setupHealthEatingDisorder,
        'diabetesRequiringMedication' => l.setupHealthDiabetes,
        'kidneyDisease' => l.setupHealthKidney,
        'seriousLiverDisease' => l.setupHealthLiver,
        'otherClinicianManagedDiet' => l.setupHealthOtherDiet,
        _ => l.setupReviewNeeded,
      };

  static String warningL(L l, String code) => switch (code) {
        'goalPaceReducedToProtectRmr' => l.fuelWarningRmr,
        'goalPaceReducedForCarbPerformanceFloor' => l.fuelWarningCarbs,
        'carbFloorConflictsWithProteinTarget' => l.fuelWarningProtein,
        'carbGramsClampedToZero' => l.fuelWarningZeroCarbs,
        _ => l.fuelReviewWorthKnowing,
      };

  static String goalLabel(NutritionGoal goal) => switch (goal) {
        NutritionGoal.loseFat => 'Lose fat',
        NutritionGoal.maintain => 'Maintain',
        NutritionGoal.gainMuscle => 'Gain muscle',
      };

  static String goalDescription(NutritionGoal goal) => switch (goal) {
        NutritionGoal.loseFat =>
          'Reduce body fat while preserving strength and training quality.',
        NutritionGoal.maintain =>
          'Hold your current weight and support consistent performance.',
        NutritionGoal.gainMuscle =>
          'Build muscle with a controlled calorie surplus.',
      };

  // Mifflin–St Jeor has one constant for male physiology (+5) and one for
  // female physiology (−161). The labels say that plainly instead of hiding it
  // behind "Equation A/B" — a user cannot choose between options they cannot
  // understand.
  static String equationLabel(EquationProfile profile) => switch (profile) {
        EquationProfile.higherOffset => 'Male physiology',
        EquationProfile.lowerOffset => 'Female physiology',
        EquationProfile.neutral => 'Prefer not to say',
      };

  static String equationDescription(EquationProfile profile) =>
      switch (profile) {
        EquationProfile.higherOffset => 'The standard formula for male bodies.',
        EquationProfile.lowerOffset =>
          'The standard formula for female bodies.',
        EquationProfile.neutral =>
          "We'll use the midpoint and show a slightly wider range.",
      };

  /// Why the question is asked at all. The two formulas sit about 83 kcal a
  /// day either side of the midpoint, so this is a fine-tune, not a gate.
  static const equationExplainer =
      'Calorie formulas differ slightly between male and female physiology — '
      'about 80 kcal a day either way. It only fine-tunes your estimate, so '
      "skip it if you'd rather.";

  static String activityLabel(ActivityLevel level) => switch (level) {
        ActivityLevel.veryLow => 'Very low',
        ActivityLevel.light => 'Light',
        ActivityLevel.moderate => 'Moderate',
        ActivityLevel.high => 'High',
        ActivityLevel.veryHigh => 'Very high',
      };

  static String activityDescription(ActivityLevel level) => switch (level) {
        ActivityLevel.veryLow => 'Mostly sitting — desk job, minimal walking.',
        ActivityLevel.light =>
          'On your feet sometimes — teaching, light retail, short walks.',
        ActivityLevel.moderate =>
          'Regularly active — physical job, daily walking, errands on foot.',
        ActivityLevel.high =>
          'Very active day-to-day — physical labor, long shifts on your feet.',
        ActivityLevel.veryHigh =>
          'Constant movement — manual labor, courier work, farming.',
      };

  static String paceLabel(GoalPace pace) => switch (pace) {
        GoalPace.gentle => 'Gentle',
        GoalPace.standard => 'Standard',
        GoalPace.upperLimit => 'Upper limit',
        GoalPace.conservative => 'Conservative',
        GoalPace.gainStandard => 'Standard',
      };

  static String paceDescription(GoalPace pace) => switch (pace) {
        GoalPace.gentle => '~0.25% body weight per week.',
        GoalPace.standard => '~0.5% body weight per week — recommended.',
        GoalPace.upperLimit =>
          '~0.75% body weight per week, the automated limit.',
        GoalPace.conservative => '~0.10–0.25% body weight per week.',
        GoalPace.gainStandard =>
          '~0.25–0.50% body weight per week — recommended.',
      };

  static List<GoalPace> pacesFor(NutritionGoal goal) => switch (goal) {
        NutritionGoal.loseFat => const [
            GoalPace.gentle,
            GoalPace.standard,
            GoalPace.upperLimit,
          ],
        NutritionGoal.gainMuscle => const [
            GoalPace.conservative,
            GoalPace.gainStandard,
          ],
        NutritionGoal.maintain => const [],
      };

  static String confidenceLabel(ConfidenceLabel confidence) =>
      switch (confidence) {
        ConfidenceLabel.high => 'High confidence',
        ConfidenceLabel.medium => 'Medium confidence',
        ConfidenceLabel.low => 'Low confidence',
      };

  static const Map<String, String> _reasons = {
    'screeningUnanswered':
        'Review the health questions before an automated target can be shown.',
    'screeningNeedsReview':
        'Please check with a qualified professional before an automated plan.',
    'underAge': 'Automated plans are only available to adults 18 and over.',
    'invalidVitals': "Height, weight, or age don't look like valid numbers.",
    'underweightForFatLoss':
        'Your current stats indicate an underweight range, so an automated fat-loss plan is blocked.',
    'invalidFatLossTarget':
        'Your target weight should be below your current weight for a fat-loss plan.',
    'invalidMuscleGainTarget':
        'Your target weight should be above your current weight for a muscle-gain plan.',
    'missingTargetWeight': 'A target weight is needed for this goal.',
    'missingGoalPace': 'A pace is needed for this goal.',
    'rmrCalculationOutOfRange':
        "Your inputs produced an estimate outside a safe range — double-check height, weight, and age.",
    'pregnantOrBreastfeeding': 'Pregnant or breastfeeding',
    'eatingDisorderHistoryOrSymptoms': 'Eating-disorder history or symptoms',
    'diabetesRequiringMedication': 'Diabetes requiring medication',
    'kidneyDisease': 'Kidney disease',
    'seriousLiverDisease': 'Serious liver disease',
    'otherClinicianManagedDiet': 'Another clinician-managed diet',
  };

  static String reason(String code) => _reasons[code] ?? code;

  static const Map<String, String> _warnings = {
    'goalPaceReducedToProtectRmr':
        'Your pace was reduced so your target never drops below your estimated resting energy.',
    'goalPaceReducedForCarbPerformanceFloor':
        'Your deficit was reduced to keep enough carbohydrate for high training load.',
    'carbFloorConflictsWithProteinTarget':
        'Even at maintenance calories, this protein target leaves little room for carbohydrate — consider a lower protein target or lighter training load.',
    'carbGramsClampedToZero':
        'Carbohydrate grams were clamped to zero after fat and protein were allocated.',
  };

  static String warning(String code) => _warnings[code] ?? code;
}

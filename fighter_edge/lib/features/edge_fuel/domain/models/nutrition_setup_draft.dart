import 'nutrition_enums.dart';
import 'nutrition_profile.dart';

/// Mutable, resumable state for the six-step EdgeFuel setup wizard (master
/// prompt §6). Every field is nullable/optional because the wizard fills
/// them in one step at a time — this is deliberately looser than the strict
/// [NutritionProfile] the calculator requires. Autosaved after every step so
/// closing the app mid-setup resumes exactly where the user left off.
///
/// Food-preference fields are collected here (step 5) even though nothing
/// consumes them until the recipe system (a later sprint) — capturing them
/// now means EF-3 doesn't need a second onboarding pass.
class NutritionSetupDraft {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final int currentStep; // 0-5, the step the wizard should resume on
  final bool confirmed; // true once the Review step has been submitted

  // Step 1 — Goal
  final NutritionGoal? goal;

  // Step 2 — Body inputs
  final int? ageYears;
  final double? heightCm;
  final double? currentWeightKg;
  final double? targetWeightKg;
  final EquationProfile? equationProfile;

  // Step 3 — Normal activity
  final ActivityLevel? normalActivityLevel;

  // Step 4 — Training
  final int? weeklyTrainingDays;
  final GoalPace? goalPace;

  // Step 5 — Food preferences (stored for later sprints, not used by EF-1)
  final String? dietType;
  final List<String> allergens;
  final List<String> dislikedFoods;
  final int? mealsPerDay;
  final String? budgetBand;
  final String? cookingTimeBand;

  final double? bodyFatPercent;
  final NutritionSafetyFlags safetyFlags;

  const NutritionSetupDraft({
    this.schemaVersion = currentSchemaVersion,
    this.currentStep = 0,
    this.confirmed = false,
    this.goal,
    this.ageYears,
    this.heightCm,
    this.currentWeightKg,
    this.targetWeightKg,
    this.equationProfile,
    this.normalActivityLevel,
    this.weeklyTrainingDays,
    this.goalPace,
    this.dietType,
    this.allergens = const [],
    this.dislikedFoods = const [],
    this.mealsPerDay,
    this.budgetBand,
    this.cookingTimeBand,
    this.bodyFatPercent,
    this.safetyFlags = const NutritionSafetyFlags(),
  });

  const NutritionSetupDraft.empty() : this();

  /// Whether every field the calculator requires is present. Does not imply
  /// the values are *valid* — [NutritionSafetyPolicy] still checks that.
  bool get hasRequiredCalculatorInputs {
    if (goal == null ||
        ageYears == null ||
        heightCm == null ||
        currentWeightKg == null ||
        equationProfile == null ||
        normalActivityLevel == null) {
      return false;
    }
    if (goal != NutritionGoal.maintain) {
      return targetWeightKg != null && goalPace != null;
    }
    return true;
  }

  /// Builds the strict, immutable [NutritionProfile] the calculator needs,
  /// or null if required fields are still missing.
  NutritionProfile? toProfile() {
    if (!hasRequiredCalculatorInputs) return null;
    return NutritionProfile(
      goal: goal!,
      ageYears: ageYears!,
      heightCm: heightCm!,
      currentWeightKg: currentWeightKg!,
      targetWeightKg: targetWeightKg,
      equationProfile: equationProfile!,
      activityLevel: normalActivityLevel!,
      goalPace: goalPace,
      bodyFatPercent: bodyFatPercent,
      safetyFlags: safetyFlags,
    );
  }

  NutritionSetupDraft copyWith({
    int? currentStep,
    bool? confirmed,
    NutritionGoal? goal,
    int? ageYears,
    double? heightCm,
    double? currentWeightKg,
    double? targetWeightKg,
    EquationProfile? equationProfile,
    ActivityLevel? normalActivityLevel,
    int? weeklyTrainingDays,
    GoalPace? goalPace,
    String? dietType,
    List<String>? allergens,
    List<String>? dislikedFoods,
    int? mealsPerDay,
    String? budgetBand,
    String? cookingTimeBand,
    double? bodyFatPercent,
    NutritionSafetyFlags? safetyFlags,
  }) {
    return NutritionSetupDraft(
      schemaVersion: schemaVersion,
      currentStep: currentStep ?? this.currentStep,
      confirmed: confirmed ?? this.confirmed,
      goal: goal ?? this.goal,
      ageYears: ageYears ?? this.ageYears,
      heightCm: heightCm ?? this.heightCm,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      equationProfile: equationProfile ?? this.equationProfile,
      normalActivityLevel: normalActivityLevel ?? this.normalActivityLevel,
      weeklyTrainingDays: weeklyTrainingDays ?? this.weeklyTrainingDays,
      goalPace: goalPace ?? this.goalPace,
      dietType: dietType ?? this.dietType,
      allergens: allergens ?? this.allergens,
      dislikedFoods: dislikedFoods ?? this.dislikedFoods,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      budgetBand: budgetBand ?? this.budgetBand,
      cookingTimeBand: cookingTimeBand ?? this.cookingTimeBand,
      bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      safetyFlags: safetyFlags ?? this.safetyFlags,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'currentStep': currentStep,
        'confirmed': confirmed,
        'goal': goal?.name,
        'ageYears': ageYears,
        'heightCm': heightCm,
        'currentWeightKg': currentWeightKg,
        'targetWeightKg': targetWeightKg,
        'equationProfile': equationProfile?.name,
        'normalActivityLevel': normalActivityLevel?.name,
        'weeklyTrainingDays': weeklyTrainingDays,
        'goalPace': goalPace?.name,
        'dietType': dietType,
        'allergens': allergens,
        'dislikedFoods': dislikedFoods,
        'mealsPerDay': mealsPerDay,
        'budgetBand': budgetBand,
        'cookingTimeBand': cookingTimeBand,
        'bodyFatPercent': bodyFatPercent,
        'safetyFlags': safetyFlags.toJson(),
      };

  factory NutritionSetupDraft.fromJson(Map<String, dynamic> json) {
    return NutritionSetupDraft(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      currentStep: (json['currentStep'] as num?)?.toInt() ?? 0,
      confirmed: json['confirmed'] as bool? ?? false,
      goal: enumFromName(NutritionGoal.values, json['goal']),
      ageYears: (json['ageYears'] as num?)?.toInt(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      currentWeightKg: (json['currentWeightKg'] as num?)?.toDouble(),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      equationProfile:
          enumFromName(EquationProfile.values, json['equationProfile']),
      normalActivityLevel:
          enumFromName(ActivityLevel.values, json['normalActivityLevel']),
      weeklyTrainingDays: (json['weeklyTrainingDays'] as num?)?.toInt(),
      goalPace: enumFromName(GoalPace.values, json['goalPace']),
      dietType: json['dietType'] as String?,
      allergens: List<String>.from(json['allergens'] as List? ?? const []),
      dislikedFoods:
          List<String>.from(json['dislikedFoods'] as List? ?? const []),
      mealsPerDay: (json['mealsPerDay'] as num?)?.toInt(),
      budgetBand: json['budgetBand'] as String?,
      cookingTimeBand: json['cookingTimeBand'] as String?,
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
      safetyFlags: json['safetyFlags'] is Map
          ? NutritionSafetyFlags.fromJson(
              Map<String, dynamic>.from(json['safetyFlags'] as Map))
          : const NutritionSafetyFlags(),
    );
  }
}

import 'nutrition_enums.dart';

/// Minimum-necessary clinical safety flags (master prompt §6, "Validation
/// and safety"). Store only booleans — never narrative medical detail.
class NutritionSafetyFlags {
  final bool pregnantOrBreastfeeding;
  final bool eatingDisorderHistoryOrSymptoms;
  final bool diabetesRequiringMedication;
  final bool kidneyDisease;
  final bool seriousLiverDisease;
  final bool otherClinicianManagedDiet;

  const NutritionSafetyFlags({
    this.pregnantOrBreastfeeding = false,
    this.eatingDisorderHistoryOrSymptoms = false,
    this.diabetesRequiringMedication = false,
    this.kidneyDisease = false,
    this.seriousLiverDisease = false,
    this.otherClinicianManagedDiet = false,
  });

  bool get any =>
      pregnantOrBreastfeeding ||
      eatingDisorderHistoryOrSymptoms ||
      diabetesRequiringMedication ||
      kidneyDisease ||
      seriousLiverDisease ||
      otherClinicianManagedDiet;

  NutritionSafetyFlags copyWith({
    bool? pregnantOrBreastfeeding,
    bool? eatingDisorderHistoryOrSymptoms,
    bool? diabetesRequiringMedication,
    bool? kidneyDisease,
    bool? seriousLiverDisease,
    bool? otherClinicianManagedDiet,
  }) {
    return NutritionSafetyFlags(
      pregnantOrBreastfeeding:
          pregnantOrBreastfeeding ?? this.pregnantOrBreastfeeding,
      eatingDisorderHistoryOrSymptoms: eatingDisorderHistoryOrSymptoms ??
          this.eatingDisorderHistoryOrSymptoms,
      diabetesRequiringMedication:
          diabetesRequiringMedication ?? this.diabetesRequiringMedication,
      kidneyDisease: kidneyDisease ?? this.kidneyDisease,
      seriousLiverDisease: seriousLiverDisease ?? this.seriousLiverDisease,
      otherClinicianManagedDiet:
          otherClinicianManagedDiet ?? this.otherClinicianManagedDiet,
    );
  }

  Map<String, dynamic> toJson() => {
        'pregnantOrBreastfeeding': pregnantOrBreastfeeding,
        'eatingDisorderHistoryOrSymptoms': eatingDisorderHistoryOrSymptoms,
        'diabetesRequiringMedication': diabetesRequiringMedication,
        'kidneyDisease': kidneyDisease,
        'seriousLiverDisease': seriousLiverDisease,
        'otherClinicianManagedDiet': otherClinicianManagedDiet,
      };

  factory NutritionSafetyFlags.fromJson(Map<String, dynamic> json) {
    return NutritionSafetyFlags(
      pregnantOrBreastfeeding:
          json['pregnantOrBreastfeeding'] as bool? ?? false,
      eatingDisorderHistoryOrSymptoms:
          json['eatingDisorderHistoryOrSymptoms'] as bool? ?? false,
      diabetesRequiringMedication:
          json['diabetesRequiringMedication'] as bool? ?? false,
      kidneyDisease: json['kidneyDisease'] as bool? ?? false,
      seriousLiverDisease: json['seriousLiverDisease'] as bool? ?? false,
      otherClinicianManagedDiet:
          json['otherClinicianManagedDiet'] as bool? ?? false,
    );
  }
}

/// Immutable input to [NutritionTargetCalculator]. All values are already in
/// metric units (kg, cm) — convert imperial input at the UI boundary using
/// `units.dart` before constructing this.
class NutritionProfile {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final NutritionGoal goal;
  final int ageYears;
  final double heightCm;
  final double currentWeightKg;

  /// Required for [NutritionGoal.loseFat] and [NutritionGoal.gainMuscle];
  /// ignored for [NutritionGoal.maintain].
  final double? targetWeightKg;
  final EquationProfile equationProfile;
  final ActivityLevel activityLevel;

  /// Required for loseFat/gainMuscle; ignored for maintain (adjustment is
  /// always 0% for maintenance, master prompt §7.4).
  final GoalPace? goalPace;

  /// Only supplied if the user already knows it — never estimated.
  final double? bodyFatPercent;
  final NutritionSafetyFlags safetyFlags;

  const NutritionProfile({
    required this.goal,
    required this.ageYears,
    required this.heightCm,
    required this.currentWeightKg,
    required this.equationProfile,
    required this.activityLevel,
    this.schemaVersion = currentSchemaVersion,
    this.targetWeightKg,
    this.goalPace,
    this.bodyFatPercent,
    this.safetyFlags = const NutritionSafetyFlags(),
  });

  NutritionProfile copyWith({
    NutritionGoal? goal,
    int? ageYears,
    double? heightCm,
    double? currentWeightKg,
    double? targetWeightKg,
    EquationProfile? equationProfile,
    ActivityLevel? activityLevel,
    GoalPace? goalPace,
    double? bodyFatPercent,
    NutritionSafetyFlags? safetyFlags,
  }) {
    return NutritionProfile(
      schemaVersion: schemaVersion,
      goal: goal ?? this.goal,
      ageYears: ageYears ?? this.ageYears,
      heightCm: heightCm ?? this.heightCm,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      equationProfile: equationProfile ?? this.equationProfile,
      activityLevel: activityLevel ?? this.activityLevel,
      goalPace: goalPace ?? this.goalPace,
      bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      safetyFlags: safetyFlags ?? this.safetyFlags,
    );
  }
}

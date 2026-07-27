import '../billing/subscription.dart';

/// Provider-agnostic domain user. Firebase/Supabase/etc. map into this shape
/// so the rest of the app never depends on a specific auth SDK.
class AppUser {
  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final Plan plan;
  final DateTime createdAt;
  final bool onboardingComplete;
  final String goal;
  final String experienceLevel;
  final int weeklyTrainingDays;
  final double? startingWeightKg;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.plan,
    required this.createdAt,
    this.emailVerified = false,
    this.onboardingComplete = false,
    this.goal = '',
    this.experienceLevel = '',
    this.weeklyTrainingDays = 4,
    this.startingWeightKg,
  });

  bool get isPro => plan == Plan.pro;

  AppUser copyWith({
    String? displayName,
    bool? emailVerified,
    Plan? plan,
    bool? onboardingComplete,
    String? goal,
    String? experienceLevel,
    int? weeklyTrainingDays,
    double? startingWeightKg,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
      plan: plan ?? this.plan,
      createdAt: createdAt,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      weeklyTrainingDays: weeklyTrainingDays ?? this.weeklyTrainingDays,
      startingWeightKg: startingWeightKg ?? this.startingWeightKg,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'emailVerified': emailVerified,
        'plan': plan.name,
        'createdAt': createdAt.toIso8601String(),
        'onboardingComplete': onboardingComplete,
        'goal': goal,
        'experienceLevel': experienceLevel,
        'weeklyTrainingDays': weeklyTrainingDays,
        'startingWeightKg': startingWeightKg,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: (json['displayName'] as String?) ?? '',
        emailVerified: (json['emailVerified'] as bool?) ?? false,
        plan: Plan.values.firstWhere(
          (p) => p.name == json['plan'],
          orElse: () => Plan.free,
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        onboardingComplete: (json['onboardingComplete'] as bool?) ?? false,
        goal: (json['goal'] as String?) ?? '',
        experienceLevel: (json['experienceLevel'] as String?) ?? '',
        weeklyTrainingDays: (json['weeklyTrainingDays'] as num?)?.toInt() ?? 4,
        startingWeightKg: (json['startingWeightKg'] as num?)?.toDouble(),
      );
}

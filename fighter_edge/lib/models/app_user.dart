import 'package:clock/clock.dart';

import '../billing/subscription.dart';
import 'dev_message.dart';

/// Provider-agnostic domain user. Firebase/Supabase/etc. map into this shape
/// so the rest of the app never depends on a specific auth SDK.
class AppUser {
  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final Plan plan;

  /// Server-owned subscription metadata. The client never writes these fields
  /// in production; they are mirrored from RevenueCat webhooks for UX and
  /// offline display only.
  final DateTime? planExpiresAt;
  final bool planWillRenew;
  final String? billingProvider;
  final String? billingManagementUrl;
  final DateTime createdAt;
  final bool onboardingComplete;
  final String goal;
  final String experienceLevel;
  final int weeklyTrainingDays;
  final double? startingWeightKg;

  /// A one-off note from the developer, set on the profile document by the
  /// developer and never written by the client.
  final DevMessage? devMessage;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.plan,
    required this.createdAt,
    this.planExpiresAt,
    this.planWillRenew = false,
    this.billingProvider,
    this.billingManagementUrl,
    this.emailVerified = false,
    this.onboardingComplete = false,
    this.goal = '',
    this.experienceLevel = '',
    this.weeklyTrainingDays = 4,
    this.startingWeightKg,
    this.devMessage,
  });

  /// Expiry-aware, like the server (audit M-4): a Pro plan whose recorded
  /// expiry has passed (beyond [Entitlements.expiryLeeway]) no longer counts,
  /// even if the EXPIRATION webhook never arrived. No recorded expiry means
  /// a lifetime purchase or a manual grant.
  bool get isPro => isProAt(clock.now());

  bool isProAt(DateTime now) {
    if (plan != Plan.pro) return false;
    final expires = planExpiresAt;
    return expires == null ||
        expires.add(Entitlements.expiryLeeway).isAfter(now);
  }

  AppUser copyWith({
    String? displayName,
    bool? emailVerified,
    Plan? plan,
    DateTime? planExpiresAt,
    bool? planWillRenew,
    String? billingProvider,
    String? billingManagementUrl,
    bool? onboardingComplete,
    String? goal,
    String? experienceLevel,
    int? weeklyTrainingDays,
    double? startingWeightKg,
    DevMessage? devMessage,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
      plan: plan ?? this.plan,
      createdAt: createdAt,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
      planWillRenew: planWillRenew ?? this.planWillRenew,
      billingProvider: billingProvider ?? this.billingProvider,
      billingManagementUrl: billingManagementUrl ?? this.billingManagementUrl,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      weeklyTrainingDays: weeklyTrainingDays ?? this.weeklyTrainingDays,
      startingWeightKg: startingWeightKg ?? this.startingWeightKg,
      devMessage: devMessage ?? this.devMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'emailVerified': emailVerified,
        'plan': plan.name,
        'planExpiresAt': planExpiresAt?.toIso8601String(),
        'planWillRenew': planWillRenew,
        'billingProvider': billingProvider,
        'billingManagementUrl': billingManagementUrl,
        'createdAt': createdAt.toIso8601String(),
        'onboardingComplete': onboardingComplete,
        'goal': goal,
        'experienceLevel': experienceLevel,
        'weeklyTrainingDays': weeklyTrainingDays,
        'startingWeightKg': startingWeightKg,
        'devMessage': devMessage?.toJson(),
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
        planExpiresAt:
            DateTime.tryParse(json['planExpiresAt'] as String? ?? ''),
        planWillRenew: (json['planWillRenew'] as bool?) ?? false,
        billingProvider: json['billingProvider'] as String?,
        billingManagementUrl: json['billingManagementUrl'] as String?,
        onboardingComplete: (json['onboardingComplete'] as bool?) ?? false,
        goal: (json['goal'] as String?) ?? '',
        experienceLevel: (json['experienceLevel'] as String?) ?? '',
        weeklyTrainingDays: (json['weeklyTrainingDays'] as num?)?.toInt() ?? 4,
        startingWeightKg: (json['startingWeightKg'] as num?)?.toDouble(),
        devMessage: DevMessage.fromJson(
          (json['devMessage'] as Map?)?.cast<String, dynamic>(),
        ),
      );
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Subscription tiers. The client reads this entitlement state, but paid-plan
/// changes must come from a trusted billing backend/webhook.
enum Plan { free, pro }

extension PlanInfo on Plan {
  String get label => switch (this) {
        Plan.free => 'Free',
        Plan.pro => 'Pro',
      };

  Color get color => switch (this) {
        Plan.free => AppColors.textSecondary,
        Plan.pro => AppColors.primary,
      };
}

/// The gate-able capabilities of the app.
enum Feature {
  cornerCoach,
  advancedTimerStyles,
  unlimitedWeightHistory,
  nutritionAnalytics,
  fullTechniqueLibrary,

  /// EdgeFuel premium recipes (master prompt §10). Deliberately distinct from
  /// [nutritionAnalytics] rather than folded into one vague nutrition gate —
  /// §10 requires separate entitlement cases so each can be reasoned about,
  /// priced, and server-verified on its own.
  edgeFuelPremiumRecipes,

  /// "Ask EdgeFuel Coach" (master prompt §13.1). The one AI surface in this
  /// release — gated like every other Pro feature rather than given away
  /// free, which is also what keeps per-user AI spend bounded.
  edgeFuelAiCoach,
}

extension FeatureInfo on Feature {
  /// Human-readable name shown on the paywall.
  String get title => switch (this) {
        Feature.cornerCoach => 'Corner Coach',
        Feature.advancedTimerStyles => 'All Timer Presets',
        Feature.unlimitedWeightHistory => 'Unlimited Weight History',
        Feature.nutritionAnalytics => 'Nutrition Analytics',
        Feature.fullTechniqueLibrary => 'Full Technique Library',
        Feature.edgeFuelPremiumRecipes => 'Full Recipe Library',
        Feature.edgeFuelAiCoach => 'AI Plan Coach',
      };
}

/// Central entitlement rules. Free users get a usable but limited app;
/// everything below is unlocked by Pro.
class Entitlements {
  Entitlements._();

  /// Features that require Pro. Anything not listed is available to everyone.
  static const Set<Feature> _proOnly = {
    Feature.cornerCoach,
    Feature.advancedTimerStyles,
    Feature.unlimitedWeightHistory,
    Feature.nutritionAnalytics,
    Feature.fullTechniqueLibrary,
    Feature.edgeFuelPremiumRecipes,
    Feature.edgeFuelAiCoach,
  };

  /// Free-tier hard limits enforced in the UI/business logic.
  static const int freeWeightHistoryLimit = 5;
  static const int freeTechniqueLimit = 3;
  static const int freeTimerStyleCount = 1;

  static bool isProOnly(Feature f) => _proOnly.contains(f);

  static bool allows(Plan plan, Feature f) => plan == Plan.pro || !isProOnly(f);
}

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
///
/// This list is also the paywall: each Pro feature carries its own paywall
/// copy below, and the paywall renders exactly these. A benefit that is not a
/// real, gated feature cannot be advertised — which is the point. (An
/// earlier paywall sold timer presets and weight history that were free
/// anyway, and analytics that did not exist.)
enum Feature {
  /// The AI Fighter Brief and "Ask EdgeFuel Coach" (master prompt §13.1).
  /// Gated like every Pro feature, which also keeps per-user AI spend
  /// bounded.
  edgeFuelAiCoach,

  /// EdgeFuel premium recipes (master prompt §10) — its own entitlement case
  /// so it can be reasoned about, priced, and server-verified on its own.
  edgeFuelPremiumRecipes,

  /// Every drill in the library beyond the free starters.
  fullTechniqueLibrary,

  /// Tactical and recovery cues on each rest in the round timer.
  cornerCoach,
}

extension FeatureInfo on Feature {
  /// Human-readable name shown on the paywall and lock states.
  String get title => switch (this) {
        Feature.edgeFuelAiCoach => 'AI Fighter Brief',
        Feature.edgeFuelPremiumRecipes => 'Full Recipe Library',
        Feature.fullTechniqueLibrary => 'Full Drill Library',
        Feature.cornerCoach => 'Corner Cues',
      };

  /// One line on what the feature actually does, for the paywall.
  String get pitch => switch (this) {
        Feature.edgeFuelAiCoach => 'A daily next-action brief and a plain-'
            'language plan coach, grounded in your own numbers',
        Feature.edgeFuelPremiumRecipes => 'Every recipe, scaled to your '
            'servings and checked against your allergens',
        Feature.fullTechniqueLibrary => 'Every drill across striking, '
            'wrestling, BJJ and clinch, with a way to drill each one',
        Feature.cornerCoach => 'A tactical and a recovery cue on every rest '
            'in the round timer',
      };

  IconData get icon => switch (this) {
        Feature.edgeFuelAiCoach => Icons.auto_awesome,
        Feature.edgeFuelPremiumRecipes => Icons.restaurant_menu,
        Feature.fullTechniqueLibrary => Icons.sports_martial_arts,
        Feature.cornerCoach => Icons.record_voice_over,
      };
}

/// Central entitlement rules. Free users get a usable but limited app;
/// everything below is unlocked by Pro.
class Entitlements {
  Entitlements._();

  /// Features that require Pro. Anything not listed is available to everyone.
  static const Set<Feature> _proOnly = {
    Feature.edgeFuelAiCoach,
    Feature.edgeFuelPremiumRecipes,
    Feature.fullTechniqueLibrary,
    Feature.cornerCoach,
  };

  static bool isProOnly(Feature f) => _proOnly.contains(f);

  static bool allows(Plan plan, Feature f) => plan == Plan.pro || !isProOnly(f);

  /// How long past a recorded expiry Pro still counts, covering store
  /// renewal lag. Mirrors ENTITLEMENT_LEEWAY_MS in functions/src/billing.ts.
  static const Duration expiryLeeway = Duration(hours: 1);
}

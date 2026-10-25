import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

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

/// The kind of store period behind the server-fed entitlement, mirrored from
/// `billing.proPeriod` in `users/{uid}` (written only by the RevenueCat
/// webhook). Unknown values from the server parse to null, never to a trial.
enum ProPeriod { trial, intro, normal }

extension ProPeriodParsing on ProPeriod {
  /// Parses the server's `TRIAL` / `INTRO` / `NORMAL` code; null otherwise.
  static ProPeriod? fromServer(Object? value) => switch (value) {
        'TRIAL' => ProPeriod.trial,
        'INTRO' => ProPeriod.intro,
        'NORMAL' => ProPeriod.normal,
        _ => null,
      };
}

/// What the signed-in athlete may do right now, derived only from the
/// server-fed entitlement (`plan`, `billing.expiresAtMs`, `billing.proPeriod`)
/// that the RevenueCat webhook writes. The client never produces `trial` or
/// `active` by itself: a store purchase result is not an input here.
///
/// The paid app has one level of access. During the store trial and while
/// subscribed everything works; otherwise the account is [readOnly]: data
/// stays saved and viewable, new logging asks for a subscription.
enum AccessKind { trial, active, readOnly, unknown }

class AccessState {
  const AccessState._(this.kind, {this.trialEndsAt, this.lastKnown});

  /// In the store trial, which ends at [endsAt] (server-reported expiry).
  const AccessState.trial(DateTime endsAt)
      : this._(AccessKind.trial, trialEndsAt: endsAt);

  /// Subscribed.
  const AccessState.active() : this._(AccessKind.active);

  /// Trial ended, cancelled and lapsed, or never started.
  const AccessState.readOnly() : this._(AccessKind.readOnly);

  /// The server entitlement could not be confirmed (offline with no cached
  /// profile). [lastKnown] is the last confirmed state held in memory this
  /// session, if any. It is never written to disk.
  const AccessState.unknown({AccessState? lastKnown})
      : this._(AccessKind.unknown, lastKnown: lastKnown);

  final AccessKind kind;
  final DateTime? trialEndsAt;
  final AccessState? lastKnown;

  bool get isTrial => kind == AccessKind.trial;
  bool get isActive => kind == AccessKind.active;
  bool get isReadOnly => kind == AccessKind.readOnly;
  bool get isUnknown => kind == AccessKind.unknown;

  /// The state to act on: itself, or for [unknown] the last confirmed one.
  AccessState? get effective => isUnknown ? lastKnown?.effective : this;

  /// Paid features (corner cues, recipes, drills) are available. Strict: an
  /// unknown state with nothing cached unlocks nothing.
  bool get hasPaidAccess {
    final state = effective;
    return state != null && (state.isTrial || state.isActive);
  }

  /// New data may be written. Lenient only for [unknown] with nothing cached:
  /// failing to reach the server must never lock an athlete out of logging
  /// their own training. (Entitlement-priced server resources check
  /// `hasActivePro` on the server regardless.)
  bool get canWrite {
    final state = effective;
    return state == null ? isUnknown : state.hasPaidAccess;
  }

  /// Whole days left in the trial at [now], rounded up and never negative;
  /// null when not in a trial.
  int? trialDaysLeft(DateTime now) {
    final state = effective;
    final ends = state?.trialEndsAt;
    if (state == null || !state.isTrial || ends == null) return null;
    final left = ends.difference(now);
    if (left <= Duration.zero) return 0;
    return (left.inHours / 24).ceil();
  }

  /// Derives access from the server-fed entitlement.
  ///
  /// [confirmed] is false when the profile could not be read from the server
  /// or its cache. A Pro plan counts until `expiresAt` plus
  /// [Entitlements.expiryLeeway], matching the server's `hasActivePro`.
  factory AccessState.derive({
    required Plan plan,
    required DateTime now,
    DateTime? expiresAt,
    ProPeriod? period,
    bool confirmed = true,
    AccessState? lastKnown,
  }) {
    if (!confirmed) return AccessState.unknown(lastKnown: lastKnown);
    final paid = plan == Plan.pro &&
        (expiresAt == null ||
            expiresAt.add(Entitlements.expiryLeeway).isAfter(now));
    if (!paid) return const AccessState.readOnly();
    if (period == ProPeriod.trial && expiresAt != null) {
      return AccessState.trial(expiresAt);
    }
    return const AccessState.active();
  }

  @override
  bool operator ==(Object other) =>
      other is AccessState &&
      other.kind == kind &&
      other.trialEndsAt == trialEndsAt &&
      other.lastKnown == lastKnown;

  @override
  int get hashCode => Object.hash(kind, trialEndsAt, lastKnown);

  @override
  String toString() =>
      'AccessState($kind${trialEndsAt != null ? ', ends $trialEndsAt' : ''})';
}

/// The gate-able capabilities of the app.
///
/// Entitlement keys for gated UI. The paywall lists only benefits that ship;
/// the recipe key remains reserved until reviewed recipes are published.
enum Feature {
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
        Feature.edgeFuelPremiumRecipes => 'Full Recipe Library',
        Feature.fullTechniqueLibrary => 'Full Drill Library',
        Feature.cornerCoach => 'Corner Cues',
      };

  /// One line on what the feature actually does, for the paywall.
  String get pitch => switch (this) {
        Feature.edgeFuelPremiumRecipes => 'Every recipe, scaled to your '
            'servings and checked against your allergens',
        Feature.fullTechniqueLibrary => 'Every drill across striking, '
            'wrestling, BJJ and clinch, with a way to drill each one',
        Feature.cornerCoach => 'A tactical and a recovery cue on every rest '
            'in the round timer',
      };

  IconData get icon => switch (this) {
        Feature.edgeFuelPremiumRecipes => AppIcons.forkKnife,
        Feature.fullTechniqueLibrary => AppIcons.handFist,
        Feature.cornerCoach => AppIcons.megaphoneSimple,
      };
}

/// Central entitlement rules. In the paid app every [Feature] belongs to the
/// paid state (store trial or subscription); a read-only account keeps its
/// data but not these. The decision comes from [AccessState], which is built
/// only from the server-fed entitlement.
class Entitlements {
  Entitlements._();

  /// Whether [f] needs paid access. Every feature does in the paid app, so
  /// the paywall still lists exactly the gated features.
  static bool isProOnly(Feature f) => true;

  /// Whether [access] unlocks [f].
  static bool allowsAccess(AccessState access, Feature f) =>
      !isProOnly(f) || access.hasPaidAccess;

  /// Plan-based convenience for callers that only hold a [Plan].
  static bool allows(Plan plan, Feature f) => !isProOnly(f) || plan == Plan.pro;

  /// How long past a recorded expiry Pro still counts, covering store
  /// renewal lag. Mirrors ENTITLEMENT_LEEWAY_MS in functions/src/billing.ts.
  static const Duration expiryLeeway = Duration(hours: 1);
}

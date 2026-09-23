import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Product events that are safe to send to Firebase Analytics.
///
/// Event names and parameters are intentionally an allow-list. Do not add
/// body measurements, nutrition values, free-form AI text, email addresses,
/// Firebase UIDs, or other health data here.
enum TelemetryEvent {
  paywallViewed,
  premiumCtaTapped,
  subscriptionCheckoutStarted,
  subscriptionPurchaseResult,
  purchaseRestoreResult,
  fighterBriefPreviewViewed,
  aiRequestResult,

  // Activation and habit funnel. Parameters are enums, small counts and 0/1
  // flags only — never a body measurement, a food, or anything typed.
  onboardingStepViewed,
  onboardingCompleted,
  planRevealed,
  trainingLogged,
  mealLogged,
  reactionDrillFinished,
  reminderPromptResult,
  weekTargetMet,
  streakFreezeApplied,
}

extension TelemetryEventName on TelemetryEvent {
  String get eventName => switch (this) {
        TelemetryEvent.paywallViewed => 'paywall_viewed',
        TelemetryEvent.premiumCtaTapped => 'premium_cta_tapped',
        TelemetryEvent.subscriptionCheckoutStarted =>
          'subscription_checkout_started',
        TelemetryEvent.subscriptionPurchaseResult =>
          'subscription_purchase_result',
        TelemetryEvent.purchaseRestoreResult => 'purchase_restore_result',
        TelemetryEvent.fighterBriefPreviewViewed =>
          'fighter_brief_preview_viewed',
        TelemetryEvent.aiRequestResult => 'ai_request_result',
        TelemetryEvent.onboardingStepViewed => 'onboarding_step_viewed',
        TelemetryEvent.onboardingCompleted => 'onboarding_completed',
        TelemetryEvent.planRevealed => 'plan_revealed',
        TelemetryEvent.trainingLogged => 'training_logged',
        TelemetryEvent.mealLogged => 'meal_logged',
        TelemetryEvent.reactionDrillFinished => 'reaction_drill_finished',
        TelemetryEvent.reminderPromptResult => 'reminder_prompt_result',
        TelemetryEvent.weekTargetMet => 'week_target_met',
        TelemetryEvent.streakFreezeApplied => 'streak_freeze_applied',
      };
}

/// Small seam that keeps product code independent of an analytics vendor.
abstract interface class Telemetry {
  void track(
    TelemetryEvent event, {
    Map<String, Object> parameters,
  });

  /// Reads the app-level provider when available and falls back to a no-op.
  /// Standalone widget tests can therefore render any screen without wiring a
  /// production analytics SDK.
  static Telemetry fromContext(BuildContext context) {
    try {
      return Provider.of<Telemetry>(context, listen: false);
    } on Object {
      return const NoopTelemetry();
    }
  }
}

/// Safe default for tests, local/offline mode, and unsupported platforms.
class NoopTelemetry implements Telemetry {
  const NoopTelemetry();

  @override
  void track(
    TelemetryEvent event, {
    Map<String, Object> parameters = const {},
  }) {}
}

/// Captures events in memory for unit/widget tests without touching Firebase.
class MemoryTelemetry implements Telemetry {
  final List<TelemetryRecord> records = [];

  @override
  void track(
    TelemetryEvent event, {
    Map<String, Object> parameters = const {},
  }) {
    records.add(TelemetryRecord(
      event,
      Map.unmodifiable(safeTelemetryParameters(event, parameters)),
    ));
  }
}

class TelemetryRecord {
  final TelemetryEvent event;
  final Map<String, Object> parameters;

  const TelemetryRecord(this.event, this.parameters);
}

/// Firebase Analytics adapter. It only accepts the typed, allow-listed event
/// names above and drops any invalid parameter values before they leave the
/// process. SDK errors are intentionally swallowed so analytics can never
/// block authentication, billing, or nutrition flows.
class FirebaseTelemetry implements Telemetry {
  final FirebaseAnalytics _analytics;

  FirebaseTelemetry({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  @override
  void track(
    TelemetryEvent event, {
    Map<String, Object> parameters = const {},
  }) {
    if (kDebugMode && parameters.keys.any(_looksSensitive)) {
      throw ArgumentError('Sensitive telemetry parameter rejected.');
    }
    final safeParameters = safeTelemetryParameters(event, parameters);
    unawaited(
      _analytics
          .logEvent(name: event.eventName, parameters: safeParameters)
          .catchError((_) {}),
    );
  }
}

/// The final privacy boundary for analytics. Each event accepts only fixed
/// codes or bounded counts. An accidental meal name, message, measurement or
/// user identifier is discarded even if it is sent under a familiar key.
Map<String, Object> safeTelemetryParameters(
  TelemetryEvent event,
  Map<String, Object> parameters,
) =>
    {
      for (final entry in parameters.entries)
        if (_isSafeEventValue(event, entry.key, entry.value))
          entry.key: entry.value,
    };

bool _oneOf(Object value, Set<String> codes) =>
    value is String && codes.contains(value);

bool _flag(Object value) => value is int && (value == 0 || value == 1);

bool _isSafeEventValue(TelemetryEvent event, String key, Object value) {
  switch (event) {
    case TelemetryEvent.paywallViewed:
      if (key == 'feature') {
        return _oneOf(value, const {
          'direct',
          'edgeFuelAiCoach',
          'edgeFuelPremiumRecipes',
          'fullTechniqueLibrary',
          'cornerCoach',
        });
      }
      if (key == 'trigger') {
        return _oneOf(value, const {
          'direct',
          'plan_ready',
          'settings',
          'profile',
          'corner_coach',
          'technique_library',
          'fighter_brief',
          'coach',
          'premium_recipe',
        });
      }
      return false;
    case TelemetryEvent.premiumCtaTapped:
      if (key == 'surface') {
        return _oneOf(value, const {
          'plan_ready',
          'paywall_waitlist',
          'fighter_brief_preview',
        });
      }
      if (key == 'access') return _oneOf(value, const {'free', 'pro'});
      return false;
    case TelemetryEvent.subscriptionCheckoutStarted:
      if (key == 'billing_period') {
        return _oneOf(value, const {'monthly', 'annual'});
      }
      return false;
    case TelemetryEvent.subscriptionPurchaseResult:
      if (key == 'billing_period') {
        return _oneOf(value, const {'monthly', 'annual'});
      }
      if (key == 'status') return _oneOf(value, const {'active', 'pending'});
      return false;
    case TelemetryEvent.purchaseRestoreResult:
      if (key == 'status') return _oneOf(value, const {'active', 'none'});
      return false;
    case TelemetryEvent.fighterBriefPreviewViewed:
      if (key == 'access') return _oneOf(value, const {'free', 'pro'});
      return false;
    case TelemetryEvent.aiRequestResult:
      if (key == 'task') return _oneOf(value, const {'chat', 'fighter_brief'});
      if (key == 'status') {
        return _oneOf(value, const {
          'success',
          'quota_reached',
          'entitlement_required',
          'unavailable',
        });
      }
      return false;
    case TelemetryEvent.onboardingStepViewed:
      if (key == 'step') return value is int && value >= 1 && value <= 7;
      return false;
    case TelemetryEvent.onboardingCompleted:
      if (key == 'days_per_week') {
        return value is int && value >= 1 && value <= 7;
      }
      if (key == 'goal') {
        return _oneOf(value, const {
          'camp_structure',
          'lose_weight',
          'gain_muscle',
          'technique',
          'competition',
          'other',
        });
      }
      if (key == 'detailed') return _flag(value);
      return false;
    case TelemetryEvent.trainingLogged:
      if (key == 'source') {
        return _oneOf(value, const {'planned', 'timer', 'reaction', 'manual'});
      }
      if (key == 'is_first') return _flag(value);
      return false;
    case TelemetryEvent.mealLogged:
      if (key == 'first_today') return _flag(value);
      return false;
    case TelemetryEvent.reactionDrillFinished:
      if (key == 'discipline') {
        return _oneOf(value, const {'grappling', 'striking', 'mma'});
      }
      if (key == 'level') {
        return _oneOf(value, const {
          'beginner',
          'intermediate',
          'advanced',
          'advancedPlus',
        });
      }
      return false;
    case TelemetryEvent.reminderPromptResult:
      if (key == 'granted') return _flag(value);
      return false;
    case TelemetryEvent.weekTargetMet:
      if (key == 'streak_weeks') {
        return _oneOf(value, const {'1', '2_3', '4_7', '8_plus'});
      }
      return false;
    case TelemetryEvent.planRevealed:
    case TelemetryEvent.streakFreezeApplied:
      return false;
  }
}

bool _looksSensitive(String key) {
  final normalized = key.toLowerCase();
  return normalized.contains('email') ||
      normalized.contains('uid') ||
      normalized.contains('weight') ||
      normalized.contains('height') ||
      normalized.contains('calorie') ||
      normalized.contains('protein') ||
      normalized.contains('prompt') ||
      normalized.contains('text');
}

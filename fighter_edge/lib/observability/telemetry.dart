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
}

extension on TelemetryEvent {
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
    records.add(TelemetryRecord(event, Map.unmodifiable(parameters)));
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
    final safeParameters = <String, Object>{};
    for (final entry in parameters.entries) {
      if (_isSafeKey(entry.key) && _isSafeValue(entry.value)) {
        safeParameters[entry.key] = entry.value;
      }
    }
    unawaited(
      _analytics
          .logEvent(name: event.eventName, parameters: safeParameters)
          .catchError((_) {}),
    );
  }
}

bool _isSafeKey(String key) =>
    key == 'surface' ||
    key == 'feature' ||
    key == 'billing_period' ||
    key == 'status' ||
    key == 'access' ||
    key == 'task';

bool _isSafeValue(Object value) =>
    value is String || value is int || value is double;

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

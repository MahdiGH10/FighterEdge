import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../observability/error_reporter.dart';
import '../observability/telemetry.dart';

/// What the athlete agreed to. Advertising purposes are never granted here:
/// there are no ads yet, and when there are, they get their own
/// Google-certified consent flow (UMP) rather than riding on this one.
@immutable
class ConsentChoices {
  /// Anonymous product analytics (Firebase Analytics).
  final bool analytics;

  /// Crash and error reports (Crashlytics).
  final bool crashReports;

  const ConsentChoices({required this.analytics, required this.crashReports});

  static const none = ConsentChoices(analytics: false, crashReports: false);
  static const all = ConsentChoices(analytics: true, crashReports: true);
}

/// Where a consent decision takes effect: the analytics and crash SDKs.
abstract interface class ConsentSink {
  Future<void> apply(ConsentChoices choices);
}

class NoopConsentSink implements ConsentSink {
  const NoopConsentSink();

  @override
  Future<void> apply(ConsentChoices choices) async {}
}

/// Applies consent to Firebase. Collection is off by default in the native
/// manifests (see AndroidManifest.xml and Info.plist), so nothing is sent
/// before the athlete decides. Consent Mode v2 signals are set explicitly:
/// analytics storage follows the choice, and every advertising signal stays
/// denied.
class FirebaseConsentSink implements ConsentSink {
  FirebaseConsentSink({
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
    this.crashlyticsSupported = true,
  })  : _analytics = analytics ?? FirebaseAnalytics.instance,
        _crashlytics = crashlyticsSupported
            ? (crashlytics ?? FirebaseCrashlytics.instance)
            : null;

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics? _crashlytics;
  final bool crashlyticsSupported;

  @override
  Future<void> apply(ConsentChoices choices) async {
    try {
      await _analytics.setConsent(
        analyticsStorageConsentGranted: choices.analytics,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
      await _analytics.setAnalyticsCollectionEnabled(choices.analytics);
    } catch (_) {
      // Analytics must never block the app; the Dart-side gate below still
      // drops events without consent.
    }
    try {
      await _crashlytics?.setCrashlyticsCollectionEnabled(choices.crashReports);
    } catch (_) {}
  }
}

/// Holds and persists the athlete's privacy choices for this device.
///
/// GDPR/TTDSG (the app ships in Germany) require consent before analytics
/// identifiers are used (audit M-2). Until a choice is made, [choices] is
/// [ConsentChoices.none] and [needsDecision] asks the UI to prompt once.
class ConsentController extends ChangeNotifier {
  ConsentController({ConsentSink sink = const NoopConsentSink()})
      : _sink = sink;

  /// Already decided, for tests and surfaces that must not prompt.
  ConsentController.decided(
    ConsentChoices choices, {
    ConsentSink sink = const NoopConsentSink(),
  })  : _sink = sink,
        _choices = choices,
        _decided = true,
        _loaded = true;

  static const _decidedKey = 'privacy.consentDecided';
  static const _analyticsKey = 'privacy.analytics';
  static const _crashKey = 'privacy.crashReports';

  final ConsentSink _sink;
  ConsentChoices _choices = ConsentChoices.none;
  bool _decided = false;
  bool _loaded = false;

  ConsentChoices get choices => _choices;
  bool get analyticsAllowed => _choices.analytics;
  bool get crashReportsAllowed => _choices.crashReports;

  /// True once the stored state is read and no choice was ever made.
  bool get needsDecision => _loaded && !_decided;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _decided = prefs.getBool(_decidedKey) ?? false;
      _choices = ConsentChoices(
        analytics: prefs.getBool(_analyticsKey) ?? false,
        crashReports: prefs.getBool(_crashKey) ?? false,
      );
    } catch (_) {
      // No storage: stay undecided and collect nothing.
    }
    _loaded = true;
    notifyListeners();
    await _sink.apply(_choices);
  }

  Future<void> decide(ConsentChoices choices) async {
    _choices = choices;
    _decided = true;
    _loaded = true;
    notifyListeners();
    await _sink.apply(choices);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_decidedKey, true);
      await prefs.setBool(_analyticsKey, choices.analytics);
      await prefs.setBool(_crashKey, choices.crashReports);
    } catch (_) {}
  }

  Future<void> setAnalytics(bool allowed) => decide(
      ConsentChoices(analytics: allowed, crashReports: _choices.crashReports));

  Future<void> setCrashReports(bool allowed) => decide(
      ConsentChoices(analytics: _choices.analytics, crashReports: allowed));
}

/// Drops every event unless analytics consent is given. The SDK is also
/// disabled natively; this keeps the guarantee in Dart, where it is tested.
class ConsentGatedTelemetry implements Telemetry {
  const ConsentGatedTelemetry(this._inner, this._consent);

  final Telemetry _inner;
  final ConsentController _consent;

  @override
  void track(TelemetryEvent event,
      {Map<String, Object> parameters = const {}}) {
    if (_consent.analyticsAllowed) {
      _inner.track(event, parameters: parameters);
    }
  }
}

/// Drops error reports unless crash-report consent is given.
class ConsentGatedErrorReporter implements ErrorReporter {
  const ConsentGatedErrorReporter(this._inner, this._consent);

  final ErrorReporter _inner;
  final ConsentController _consent;

  @override
  void report(Object error, StackTrace stack,
      {String? reason, bool fatal = false}) {
    if (_consent.crashReportsAllowed) {
      _inner.report(error, stack, reason: reason, fatal: fatal);
    }
  }
}

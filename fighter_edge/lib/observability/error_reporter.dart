import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Provider-neutral error reporting seam. Callers must pass only an error,
/// stack, and a short reason; never attach request bodies or health values.
abstract interface class ErrorReporter {
  void report(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  });
}

class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();

  @override
  void report(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) {}
}

/// Firebase Crashlytics adapter. Crash reporting is best-effort and never
/// allowed to change the user-visible failure path.
class FirebaseErrorReporter implements ErrorReporter {
  final FirebaseCrashlytics _crashlytics;

  FirebaseErrorReporter({FirebaseCrashlytics? crashlytics})
      : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  @override
  void report(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) {
    if (kIsWeb) return;
    unawaited(
      _crashlytics
          .recordError(error, stack, reason: reason, fatal: fatal)
          .catchError((_) {}),
    );
  }
}

/// Installs the two Flutter error boundaries after Firebase is initialized.
/// Web and local test runs keep Flutter's normal error presentation.
void installProductionErrorHandlers(ErrorReporter reporter) {
  if (kIsWeb) return;

  FlutterError.onError = (details) {
    reporter.report(
      details.exception,
      details.stack ?? StackTrace.current,
      reason: 'flutter_error',
      fatal: true,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report(error, stack, reason: 'uncaught_async_error', fatal: true);
    return true;
  };
}

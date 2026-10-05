import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The startup steps, in order. A failure names the step, so a boot failure
/// can be told apart in a device log ("Could not start" used to look the same
/// for a missing plugin, a Firebase outage and an auth timeout).
enum BootStage { firebase, appCheck, consent, errorHandlers, auth, services }

/// Why startup stopped: which step, and what kind of error.
///
/// Only a stage name and an error *kind* are kept, never the error message,
/// which can carry account details. Error codes are fixed vocabulary
/// (`channel-error`, `no-app`), so they are safe to log.
class BootFailure implements Exception {
  final BootStage stage;
  final String kind;

  const BootFailure(this.stage, this.kind);

  /// The one line written to the device log. CI's release launch check looks
  /// for the `[boot] failed` prefix.
  String get logLine => '[boot] failed at ${stage.name}: $kind';

  static String classify(Object error) => switch (error) {
        MissingPluginException() => 'missing_plugin',
        FirebaseException(:final code) => 'firebase:$code',
        PlatformException(:final code) => 'platform:$code',
        TimeoutException() => 'timeout',
        _ => 'other',
      };

  @override
  String toString() => logLine;
}

/// Runs one startup step. On failure it logs [BootFailure.logLine] (release
/// builds included) and throws the [BootFailure] in place of the original
/// error.
Future<T> bootStep<T>(BootStage stage, FutureOr<T> Function() step) async {
  try {
    return await step();
  } catch (error) {
    final failure = BootFailure(stage, BootFailure.classify(error));
    debugPrint(failure.logLine);
    throw failure;
  }
}

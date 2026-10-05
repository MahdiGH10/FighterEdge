import 'package:flutter/foundation.dart';

import '../observability/error_reporter.dart';

/// Which of the athlete's changes the server has not accepted.
///
/// Writes used to be fire-and-forget: a rejected save (a rules or quota
/// error, a broken connection that Firestore gave up on) left the screen
/// showing data the account no longer had, and nobody was told (audit
/// 2026-10-04, Phase 0.4). Every write now reports here; while anything is
/// unsaved, `SyncNotice` offers a retry.
///
/// Firestore queues writes while offline instead of failing them, so this is
/// about writes that were *refused*, not about being offline.
class SyncTracker extends ChangeNotifier {
  SyncTracker({ErrorReporter errorReporter = const NoopErrorReporter()})
      : _errorReporter = errorReporter;

  final ErrorReporter _errorReporter;

  /// One pending retry per key, so a write that keeps failing is retried
  /// once, with its latest data, rather than piling up.
  final Map<String, Future<bool> Function()> _failed = {};
  bool _retrying = false;

  bool get hasFailure => _failed.isNotEmpty;
  bool get isRetrying => _retrying;

  /// Runs [write]. On failure it is reported under [reason] (a fixed code,
  /// never user data) and kept under [key] for [retry]. Never throws:
  /// callers are fire-and-forget taps.
  Future<bool> run(
    String key,
    String reason,
    Future<void> Function() write,
  ) async {
    try {
      await write();
      markSaved(key);
      return true;
    } catch (error, stack) {
      _errorReporter.report(error, stack, reason: reason);
      markFailed(key, () => run(key, reason, write));
      return false;
    }
  }

  /// For callers that handle and report the error themselves.
  void markFailed(String key, Future<bool> Function() retry) {
    _failed[key] = retry;
    notifyListeners();
  }

  void markSaved(String key) {
    if (_failed.remove(key) != null) notifyListeners();
  }

  /// Tries every unsaved change again. Each retry re-registers itself if it
  /// fails again.
  Future<void> retry() async {
    if (_retrying || _failed.isEmpty) return;
    final pending = Map.of(_failed);
    _failed.clear();
    _retrying = true;
    notifyListeners();
    for (final attempt in pending.values) {
      await attempt();
    }
    _retrying = false;
    notifyListeners();
  }

  /// A different account (or none) is now signed in: the old account's
  /// failures are not this one's to retry.
  void clear() {
    if (_failed.isEmpty) return;
    _failed.clear();
    notifyListeners();
  }
}

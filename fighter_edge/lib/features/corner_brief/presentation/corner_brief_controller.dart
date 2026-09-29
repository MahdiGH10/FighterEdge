import 'package:flutter/foundation.dart';

import '../../../observability/telemetry.dart';
import '../../daily_snapshot/domain/daily_snapshot.dart';
import '../../edge_fuel/ai/edge_fuel_ai_gateway.dart';
import '../../edge_fuel/ai/edge_fuel_ai_models.dart';
import '../../edge_fuel/domain/models/nutrition_day.dart';
import '../../edge_fuel/domain/models/nutrition_setup_draft.dart';
import '../../edge_fuel/domain/models/nutrition_target.dart';
import '../domain/corner_brief.dart';

/// A written Corner Brief and what it was written from.
@immutable
class WrittenCornerBrief {
  const WrittenCornerBrief({
    required this.lines,
    required this.requiresProfessionalReview,
    required this.basis,
    required this.date,
  });

  final List<CornerBriefLine> lines;
  final bool requiresProfessionalReview;

  /// [cornerBriefBasis] when it was asked for.
  final String basis;

  /// The calendar day it is about.
  final DateTime date;
}

/// Holds the day's Corner Brief (product plan, step 3). App-level, because
/// Home is rebuilt on every tab switch; cleared when the account changes.
///
/// The first brief of a day is always asked for: opening Home never sends
/// anything to the AI provider on its own. After that, [shouldRefresh] says
/// when something new has been logged, so Home can have it rewritten.
class CornerBriefController extends ChangeNotifier {
  CornerBriefController({
    required EdgeFuelAiGateway gateway,
    Telemetry? telemetry,
  })  : _gateway = gateway,
        _telemetry = telemetry ?? const NoopTelemetry();

  final EdgeFuelAiGateway _gateway;
  final Telemetry _telemetry;

  String? _userId;
  WrittenCornerBrief? _brief;
  EdgeFuelAiStatus? _lastStatus;
  DateTime? _lastStatusDate;
  bool _loading = false;
  bool _disposed = false;

  /// Bumped when the account changes, so an answer for the last account is
  /// dropped when it arrives.
  int _generation = 0;

  bool get isLoading => _loading;

  /// How the latest request about [today]'s calendar day ended; null when
  /// none was made today. Yesterday's used-up limit is not today's.
  EdgeFuelAiStatus? lastStatusFor(DateTime today) {
    final date = _lastStatusDate;
    return date != null && _sameDay(date, today) ? _lastStatus : null;
  }

  /// The brief written for [today]'s calendar day, if any.
  WrittenCornerBrief? briefFor(DateTime today) {
    final brief = _brief;
    return brief != null && _sameDay(brief.date, today) ? brief : null;
  }

  /// Whether today's brief should be rewritten for [basis]: there is one,
  /// something was logged since, and the last request worked. A failure
  /// (the day's limit, an outage) waits for the athlete's "Try again"
  /// instead of retrying on every rebuild.
  bool shouldRefresh({required DateTime today, required String basis}) {
    final brief = briefFor(today);
    return brief != null &&
        brief.basis != basis &&
        !_loading &&
        lastStatusFor(today) == EdgeFuelAiStatus.success;
  }

  void setUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _brief = null;
    _lastStatus = null;
    _lastStatusDate = null;
    _loading = false;
    _generation++;
    notifyListeners();
  }

  /// Asks the coach for a brief of [today]. [automatic] marks a rewrite
  /// after a log rather than the athlete's own tap.
  Future<void> request({
    required NutritionTarget target,
    required DailySnapshot today,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    bool automatic = false,
  }) async {
    if (_loading) return;
    final generation = _generation;
    final basis = cornerBriefBasis(today, day);
    _loading = true;
    notifyListeners();

    EdgeFuelAiResult result;
    try {
      result = await _gateway.generateCornerBrief(
        target: target,
        day: day,
        preferences: preferences,
        today: today,
      );
    } catch (_) {
      result = const EdgeFuelAiResult.unavailable();
    }
    if (_disposed || generation != _generation) return;

    final lines = result.response?.lines ?? const <CornerBriefLine>[];
    var status = result.status;
    if (status == EdgeFuelAiStatus.success && lines.isEmpty) {
      // Nothing the app can show: as good as no answer.
      status = EdgeFuelAiStatus.unavailable;
    }
    if (status == EdgeFuelAiStatus.success) {
      _brief = WrittenCornerBrief(
        lines: lines,
        requiresProfessionalReview:
            result.response?.requiresProfessionalReview ?? false,
        basis: basis,
        date: today.date,
      );
    }
    _lastStatus = status;
    _lastStatusDate = today.date;
    _loading = false;
    _telemetry.track(TelemetryEvent.aiRequestResult, parameters: {
      'task': 'corner_brief',
      'status': switch (status) {
        EdgeFuelAiStatus.success => 'success',
        EdgeFuelAiStatus.quotaReached => 'quota_reached',
        EdgeFuelAiStatus.entitlementRequired => 'entitlement_required',
        EdgeFuelAiStatus.consentRequired => 'consent_required',
        EdgeFuelAiStatus.unavailable => 'unavailable',
      },
      'automatic': automatic ? 1 : 0,
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

import 'package:flutter/foundation.dart';

import '../../../ads/reward_ticket_gateway.dart';
import '../../../ads/rewarded_ad_gateway.dart';
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

/// How a free account's "watch a video" attempt ended.
enum RewardedBriefOutcome {
  /// The brief was written.
  written,

  /// Today's rewarded brief was already used.
  usedToday,

  /// The video was closed before the end.
  closedEarly,

  /// No video was available, or the server did not confirm it in time.
  noVideo,

  /// The AI coach consent is missing.
  consentRequired,

  /// The video was earned but the brief could not be written. The reward
  /// waits on the server; trying again later writes it without a video.
  failed,
}

/// The `custom_data` our server expects from AdMob for this reward.
const rewardedBriefCustomData = 'corner_brief';

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
    RewardTicketGateway tickets = const UnavailableRewardTicketGateway(),
    RewardedAdGateway ads = const UnavailableRewardedAdGateway(),
    Duration rewardPollInterval = const Duration(seconds: 2),
    int rewardPollAttempts = 8,
  })  : _gateway = gateway,
        _telemetry = telemetry ?? const NoopTelemetry(),
        _tickets = tickets,
        _ads = ads,
        _rewardPollInterval = rewardPollInterval,
        _rewardPollAttempts = rewardPollAttempts;

  final EdgeFuelAiGateway _gateway;
  final Telemetry _telemetry;
  final RewardTicketGateway _tickets;
  final RewardedAdGateway _ads;

  /// AdMob confirms a watched video to our server a few seconds after it
  /// ends; the brief is asked for until that lands.
  final Duration _rewardPollInterval;
  final int _rewardPollAttempts;

  bool _watching = false;
  DateTime? _rewardUsedOn;

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

  /// A free account's video is being fetched, shown, or confirmed.
  bool get isWatching => _watching;

  /// Whether ads exist in this build at all.
  bool get rewardedAdsAvailable => _ads.isAvailable;

  /// Whether today's one rewarded brief is already spent.
  bool rewardUsedToday(DateTime today) {
    final date = _rewardUsedOn;
    return date != null && _sameDay(date, today);
  }

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
    _watching = false;
    _rewardUsedOn = null;
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
  }) =>
      _write(
        target: target,
        today: today,
        day: day,
        preferences: preferences,
        automatic: automatic,
      );

  /// Free accounts: one video, then today's full brief. The server decides
  /// whether a video can still pay off before one is shown, and only
  /// Google's signed confirmation to our server unlocks the brief.
  Future<RewardedBriefOutcome> watchForBrief({
    required NutritionTarget target,
    required DailySnapshot today,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    if (_watching || _loading) return RewardedBriefOutcome.noVideo;
    final generation = _generation;
    _watching = true;
    notifyListeners();
    try {
      final ticket = await _tickets.start();
      if (_disposed || generation != _generation) {
        return RewardedBriefOutcome.noVideo;
      }
      switch (ticket.status) {
        case RewardTicketStatus.usedToday:
          _rewardUsedOn = today.date;
          return RewardedBriefOutcome.usedToday;
        case RewardTicketStatus.consentRequired:
          return RewardedBriefOutcome.consentRequired;
        case RewardTicketStatus.notEligible:
        case RewardTicketStatus.unavailable:
          return RewardedBriefOutcome.noVideo;
        case RewardTicketStatus.unused:
          break;
        case RewardTicketStatus.ready:
          final video = await _ads.show(
            ssvToken: ticket.token!,
            customData: rewardedBriefCustomData,
          );
          _telemetry.track(TelemetryEvent.rewardedAdResult, parameters: {
            'status': switch (video) {
              RewardedVideoResult.earned => 'earned',
              RewardedVideoResult.closedEarly => 'closed_early',
              RewardedVideoResult.unavailable => 'unavailable',
            },
          });
          if (_disposed || generation != _generation) {
            return RewardedBriefOutcome.noVideo;
          }
          if (video == RewardedVideoResult.closedEarly) {
            return RewardedBriefOutcome.closedEarly;
          }
          if (video == RewardedVideoResult.unavailable) {
            return RewardedBriefOutcome.noVideo;
          }
      }

      for (var attempt = 0; attempt < _rewardPollAttempts; attempt++) {
        if (attempt > 0) await Future<void>.delayed(_rewardPollInterval);
        if (_disposed || generation != _generation) {
          return RewardedBriefOutcome.noVideo;
        }
        final last = attempt == _rewardPollAttempts - 1;
        final status = await _write(
          target: target,
          today: today,
          day: day,
          preferences: preferences,
          rewarded: true,
          // Only the attempt that settles it is counted.
          track: false,
        );
        if (status == EdgeFuelAiStatus.entitlementRequired && !last) continue;
        if (status == null) return RewardedBriefOutcome.failed;
        _trackResult(status, automatic: false, rewarded: true);
        if (status == EdgeFuelAiStatus.success) _rewardUsedOn = today.date;
        return switch (status) {
          EdgeFuelAiStatus.success => RewardedBriefOutcome.written,
          EdgeFuelAiStatus.consentRequired =>
            RewardedBriefOutcome.consentRequired,
          EdgeFuelAiStatus.entitlementRequired => RewardedBriefOutcome.noVideo,
          EdgeFuelAiStatus.quotaReached ||
          EdgeFuelAiStatus.unavailable =>
            RewardedBriefOutcome.failed,
        };
      }
      return RewardedBriefOutcome.noVideo;
    } finally {
      if (!_disposed && generation == _generation) {
        _watching = false;
        notifyListeners();
      }
    }
  }

  Future<EdgeFuelAiStatus?> _write({
    required NutritionTarget target,
    required DailySnapshot today,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    bool automatic = false,
    bool rewarded = false,
    bool track = true,
  }) async {
    if (_loading) return null;
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
    if (_disposed || generation != _generation) return null;

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
    // A rewarded attempt still waiting for Google's confirmation is not a
    // result to show: the card keeps saying the brief is on its way.
    if (!(rewarded && status == EdgeFuelAiStatus.entitlementRequired)) {
      _lastStatus = status;
      _lastStatusDate = today.date;
    }
    _loading = false;
    if (track) _trackResult(status, automatic: automatic, rewarded: rewarded);
    notifyListeners();
    return status;
  }

  void _trackResult(
    EdgeFuelAiStatus status, {
    required bool automatic,
    required bool rewarded,
  }) {
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
      'rewarded': rewarded ? 1 : 0,
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

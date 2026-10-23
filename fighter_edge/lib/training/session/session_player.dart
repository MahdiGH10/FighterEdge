import 'package:clock/clock.dart';

import '../../features/training_plan/domain/models/planned_session.dart';
import '../../features/training_plan/domain/models/session_template.dart';
import '../round_timer/round_timer_engine.dart';

/// A neutral stage in a planned session. Cue keys are supplied by approved
/// templates only; the player never generates coaching content.
class SessionStage {
  const SessionStage(
    this.kind,
    this.length, {
    this.round,
    this.rounds,
    this.isRest = false,
  });

  final BlockKind kind;
  final Duration length;
  final int? round;
  final int? rounds;
  final bool isRest;
}

class SessionPlayerSnapshot {
  const SessionPlayerSnapshot({
    required this.stage,
    required this.stageIndex,
    required this.stageCount,
    required this.remaining,
    required this.elapsed,
    required this.isRunning,
    required this.isDone,
  });

  final SessionStage? stage;
  final int stageIndex;
  final int stageCount;
  final Duration remaining;
  final Duration elapsed;
  final bool isRunning;
  final bool isDone;
}

/// Runs the plan's timed blocks on the wall-time-anchored [RoundTimerEngine].
/// The current launch templates have only an uncoached main block. Warm-up,
/// rounds and cool-down appear only when an approved template supplies them.
class SessionPlayer {
  SessionPlayer(PlannedSession session, {Clock? clock})
      : stages = List.unmodifiable(_stages(session)),
        _engine = RoundTimerEngine(
          rounds: 1,
          work: _length(_stages(session)),
          rest: Duration.zero,
          clock: clock,
        );

  final List<SessionStage> stages;
  final RoundTimerEngine _engine;
  Duration _skipped = Duration.zero;

  static List<SessionStage> _stages(PlannedSession session) {
    final result = <SessionStage>[];
    for (final block in session.blocks) {
      final rounds = block.rounds;
      if (rounds != null && rounds > 0 && (block.workSec ?? 0) > 0) {
        for (var round = 1; round <= rounds; round++) {
          result.add(
            SessionStage(
              block.kind,
              Duration(seconds: block.workSec!),
              round: round,
              rounds: rounds,
            ),
          );
          if (round < rounds && (block.restSec ?? 0) > 0) {
            result.add(
              SessionStage(
                block.kind,
                Duration(seconds: block.restSec!),
                round: round,
                rounds: rounds,
                isRest: true,
              ),
            );
          }
        }
      } else if ((block.minutes ?? 0) > 0) {
        result.add(SessionStage(block.kind, Duration(minutes: block.minutes!)));
      }
    }
    if (result.isEmpty) {
      result.add(
        SessionStage(
          BlockKind.main,
          Duration(
            minutes:
                session.estimatedMinutes > 0 ? session.estimatedMinutes : 1,
          ),
        ),
      );
    }
    return result;
  }

  static Duration _length(List<SessionStage> stages) =>
      stages.fold(Duration.zero, (sum, stage) => sum + stage.length);

  Duration get totalLength => _engine.totalLength;
  Duration get elapsed {
    final value = _engine.elapsed + _skipped;
    return value > totalLength ? totalLength : value;
  }

  bool get isDone => elapsed >= totalLength;
  bool get isRunning => _engine.isRunning && !isDone;

  void start() => _engine.start();
  void pause() => _engine.pause();
  void finish() {
    _engine.pause();
    _skipped = totalLength - _engine.elapsed;
  }

  void skipStage() {
    if (isDone) return;
    final current = snapshot();
    _skipped += current.remaining;
    if (isDone) _engine.pause();
  }

  SessionPlayerSnapshot snapshot() {
    final at = elapsed;
    var start = Duration.zero;
    for (var index = 0; index < stages.length; index++) {
      final end = start + stages[index].length;
      if (at < end) {
        return SessionPlayerSnapshot(
          stage: stages[index],
          stageIndex: index,
          stageCount: stages.length,
          remaining: end - at,
          elapsed: at,
          isRunning: isRunning,
          isDone: false,
        );
      }
      start = end;
    }
    return SessionPlayerSnapshot(
      stage: null,
      stageIndex: stages.length,
      stageCount: stages.length,
      remaining: Duration.zero,
      elapsed: at,
      isRunning: false,
      isDone: true,
    );
  }
}

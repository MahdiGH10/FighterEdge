/// Voice reaction drills: a virtual coach calls unpredictable movements and
/// the athlete reacts.
///
/// Pure Dart on purpose (no Flutter, no platform, no clock) so the vocabulary
/// and every level's timing rules are plain data a unit test can pin down.
/// Randomness lives in [ReactionCueGenerator]; playback lives in the
/// controller.
library;

import 'reaction_timing.dart';

/// One call the coach can make.
class ReactionCommand {
  final String id;

  /// What the athlete reads on screen.
  final String label;

  /// What the voice says. Usually the label; differs only where a written
  /// form would be read oddly aloud.
  final String spoken;

  const ReactionCommand(this.id, this.label, {String? spoken})
      : spoken = spoken ?? label;

  @override
  String toString() => id;
}

/// The coaching team's command vocabulary (the "Combat Sports Drills" sheet).
///
/// Labels stay in English on every locale: they are gym calls, and the voice
/// speaks English.
abstract final class ReactionCommands {
  // Grappling / wrestling.
  static const shoot = ReactionCommand('shoot', 'Shoot');
  static const sprawl = ReactionCommand('sprawl', 'Sprawl');
  static const frontRoll = ReactionCommand('front_roll', 'Front roll');
  static const backRoll = ReactionCommand('back_roll', 'Back roll');
  static const downBlock = ReactionCommand('down_block', 'Down block');
  static const jump = ReactionCommand('jump', 'Jump');
  static const cartwheel = ReactionCommand('cartwheel', 'Cartwheel');

  // Strikes.
  static const jab = ReactionCommand('jab', 'Jab');
  static const hook = ReactionCommand('hook', 'Hook');
  static const cross = ReactionCommand('cross', 'Cross');
  static const backHook = ReactionCommand('back_hook', 'Back hook');
  static const uppercut = ReactionCommand('uppercut', 'Uppercut');
  static const leadUppercut = ReactionCommand('lead_uppercut', 'Lead uppercut');
  static const lowKick = ReactionCommand('low_kick', 'Low kick');
  static const highKick = ReactionCommand('high_kick', 'High kick');
  static const middleKick = ReactionCommand('middle_kick', 'Middle kick');
  static const teep = ReactionCommand('teep', 'Teep');

  // Defense.
  static const kickCheck = ReactionCommand('kick_check', 'Kick check');
  static const slipLeft = ReactionCommand('slip_left', 'Slip left');
  static const slipRight = ReactionCommand('slip_right', 'Slip right');

  // Footwork.
  static const stepLeft = ReactionCommand('step_left', 'Step left');
  static const stepRight = ReactionCommand('step_right', 'Step right');
  static const stepBack = ReactionCommand('step_back', 'Step back');
  static const stepIn = ReactionCommand('step_in', 'Step in');
  static const pivotLeft = ReactionCommand('pivot_left', 'Pivot left');
  static const pivotRight = ReactionCommand('pivot_right', 'Pivot right');

  // MMA level changes.
  static const levelChange = ReactionCommand('level_change', 'Level change');
  static const levelChangeFrontRoll = ReactionCommand(
    'level_change_front_roll',
    'Level change – front roll',
    spoken: 'Level change front roll',
  );
  static const levelChangeBackRoll = ReactionCommand(
    'level_change_back_roll',
    'Level change – back roll',
    spoken: 'Level change back roll',
  );
}

enum ReactionDiscipline {
  grappling,
  striking,
  mma;

  /// The commands this drill draws from, exactly as the coaching sheet lists
  /// them (the MMA column repeats some footwork rows; each command appears
  /// once here).
  List<ReactionCommand> get commands => switch (this) {
        grappling => const [
            ReactionCommands.shoot,
            ReactionCommands.sprawl,
            ReactionCommands.frontRoll,
            ReactionCommands.backRoll,
            ReactionCommands.downBlock,
            ReactionCommands.jump,
            ReactionCommands.cartwheel,
          ],
        striking => const [
            ReactionCommands.jab,
            ReactionCommands.hook,
            ReactionCommands.cross,
            ReactionCommands.kickCheck,
            ReactionCommands.backHook,
            ReactionCommands.uppercut,
            ReactionCommands.leadUppercut,
            ReactionCommands.lowKick,
            ReactionCommands.highKick,
            ReactionCommands.middleKick,
            ReactionCommands.teep,
            ReactionCommands.slipLeft,
            ReactionCommands.slipRight,
            ReactionCommands.stepLeft,
            ReactionCommands.stepRight,
            ReactionCommands.stepBack,
            ReactionCommands.stepIn,
            ReactionCommands.pivotLeft,
            ReactionCommands.pivotRight,
          ],
        mma => const [
            ReactionCommands.jab,
            ReactionCommands.hook,
            ReactionCommands.cross,
            ReactionCommands.backHook,
            ReactionCommands.uppercut,
            ReactionCommands.leadUppercut,
            ReactionCommands.lowKick,
            ReactionCommands.highKick,
            ReactionCommands.middleKick,
            ReactionCommands.teep,
            ReactionCommands.slipLeft,
            ReactionCommands.slipRight,
            ReactionCommands.stepLeft,
            ReactionCommands.stepRight,
            ReactionCommands.stepBack,
            ReactionCommands.stepIn,
            ReactionCommands.pivotLeft,
            ReactionCommands.pivotRight,
            ReactionCommands.levelChange,
            ReactionCommands.shoot,
            ReactionCommands.kickCheck,
            ReactionCommands.sprawl,
            ReactionCommands.levelChangeFrontRoll,
            ReactionCommands.levelChangeBackRoll,
          ],
      };
}

enum ReactionLevel { beginner, intermediate, advanced, advancedPlus }

/// Everything that makes one level of one discipline hard: how many rounds it
/// has and how long they are, how long each call is, and any extra breathing
/// time. The time the athlete gets after each call comes from
/// [ReactionTiming], because it depends on what the call asks for.
///
/// Every gap is measured from the moment the voice *finishes* the call, so
/// a five-move sequence never eats into its own reaction time.
class ReactionDrillSpec {
  final ReactionDiscipline discipline;
  final ReactionLevel level;

  /// Work rounds, each [roundDuration] long, with [restDuration] between.
  final int rounds;
  final Duration roundDuration;
  final Duration restDuration;

  /// Commands per call, inclusive.
  final int minLength;
  final int maxLength;

  /// Extra rest after every few calls; null for none.
  final BlockRest? blockRest;

  const ReactionDrillSpec({
    required this.discipline,
    required this.level,
    required this.rounds,
    required this.roundDuration,
    required this.restDuration,
    required this.minLength,
    required this.maxLength,
    this.blockRest,
  });

  /// All the time spent calling moves, over every round.
  Duration get workDuration => roundDuration * rounds;

  /// The whole drill, rests included.
  Duration get totalDuration => workDuration + restDuration * (rounds - 1);

  /// The reaction time after the voice stops, in ms, as (shortest, longest)
  /// before jitter, movement time not included. What the picker shows.
  (int, int) get reactionMs =>
      ReactionTiming.reactionRangeMs(discipline, level);

  static ReactionDrillSpec of(
    ReactionDiscipline discipline,
    ReactionLevel level,
  ) {
    final t = ReactionTiming.of(level);
    // Wrestling calls are always a single command: rolls and sprawls are
    // whole-body movements, not something to chain mid-sentence. Breathing
    // room between blocks of calls is a wrestling thing too.
    final grappling = discipline == ReactionDiscipline.grappling;
    return ReactionDrillSpec(
      discipline: discipline,
      level: level,
      rounds: ReactionTiming.roundsFor(discipline),
      roundDuration: t.roundWork,
      restDuration: t.roundRest,
      minLength: grappling ? 1 : t.minMoves,
      maxLength: grappling ? 1 : t.maxMoves,
      blockRest: grappling ? t.grapplingBlockRest : null,
    );
  }
}

/// One call from the coach: one or more commands said as a single breath
/// ("Step left, hook!"), then silence for the athlete to move.
class ReactionCue {
  final List<ReactionCommand> commands;

  /// Silence after the voice finishes, before the next call.
  final Duration gapAfter;

  /// The shortest that silence could ever have been: the movement itself
  /// plus a moment to reset. Used to decide whether the call still fits
  /// before the round ends.
  final Duration minGap;

  const ReactionCue(this.commands, this.gapAfter,
      {this.minGap = Duration.zero});

  /// The line the voice speaks: short, clipped, no filler words.
  String get spoken => '${commands.map((c) => c.spoken).join(', ')}!';

  @override
  String toString() => '${commands.join(' > ')} (+${gapAfter.inMilliseconds})';
}

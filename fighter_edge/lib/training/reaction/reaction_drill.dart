/// Voice reaction drills: a virtual coach calls unpredictable movements and
/// the athlete reacts.
///
/// Pure Dart on purpose (no Flutter, no platform, no clock) so the vocabulary
/// and every level's timing rules are plain data a unit test can pin down.
/// Randomness lives in [ReactionCueGenerator]; playback lives in the
/// controller.
library;

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

/// A closed range of milliseconds a timing is drawn from. "About 1 second"
/// becomes 900–1100 ms, so no two gaps are exactly alike.
class MsRange {
  final int min;
  final int max;
  const MsRange(this.min, this.max) : assert(min <= max);

  /// Centered on [ms], give or take [spread].
  const MsRange.about(int ms, {int spread = 100})
      : min = ms - spread,
        max = ms + spread;

  @override
  String toString() => '$min–$max ms';
}

/// Reaction window for calls up to [maxLength] commands long.
class ReactionWindow {
  final int maxLength;
  final MsRange window;
  const ReactionWindow(this.maxLength, this.window);
}

/// Extra recovery after a call at least [minLength] commands long.
class RecoveryPause {
  final int minLength;
  final MsRange pause;
  const RecoveryPause(this.minLength, this.pause);
}

/// Extra rest after every few calls, whatever their length (the wrestling
/// Advanced "3–4 calls, then breathe" rhythm).
class BlockRest {
  final int minCalls;
  final int maxCalls;
  final MsRange rest;
  const BlockRest(this.minCalls, this.maxCalls, this.rest);
}

/// Everything that makes one level of one discipline hard: how long it runs,
/// how long each call is, and how much time the athlete gets after it.
///
/// Every gap is measured from the moment the voice *finishes* the call, so
/// a seven-command sequence never eats into its own reaction time.
class ReactionDrillSpec {
  final ReactionDiscipline discipline;
  final ReactionLevel level;
  final Duration duration;

  /// Commands per call, inclusive.
  final int minLength;
  final int maxLength;

  /// Ordered by [ReactionWindow.maxLength]; the first that fits a call's
  /// length applies.
  final List<ReactionWindow> windows;
  final RecoveryPause? recovery;
  final BlockRest? blockRest;

  const ReactionDrillSpec({
    required this.discipline,
    required this.level,
    required this.duration,
    required this.minLength,
    required this.maxLength,
    required this.windows,
    this.recovery,
    this.blockRest,
  });

  MsRange windowFor(int length) =>
      windows.firstWhere((w) => length <= w.maxLength).window;

  static ReactionDrillSpec of(
    ReactionDiscipline discipline,
    ReactionLevel level,
  ) =>
      discipline == ReactionDiscipline.grappling
          ? _grappling(level)
          : _combinations(discipline, level);

  // Wrestling calls are always a single command: rolls and sprawls are
  // whole-body movements, not something to chain mid-sentence.
  static ReactionDrillSpec _grappling(ReactionLevel level) {
    const d = ReactionDiscipline.grappling;
    return switch (level) {
      ReactionLevel.beginner => ReactionDrillSpec(
          discipline: d,
          level: level,
          duration: const Duration(seconds: 30),
          minLength: 1,
          maxLength: 1,
          windows: const [ReactionWindow(1, MsRange(1000, 1500))],
        ),
      ReactionLevel.intermediate => ReactionDrillSpec(
          discipline: d,
          level: level,
          duration: const Duration(minutes: 1),
          minLength: 1,
          maxLength: 1,
          windows: const [ReactionWindow(1, MsRange.about(1000))],
        ),
      ReactionLevel.advanced => ReactionDrillSpec(
          discipline: d,
          level: level,
          duration: const Duration(minutes: 2),
          minLength: 1,
          maxLength: 1,
          windows: const [ReactionWindow(1, MsRange.about(900))],
          blockRest: const BlockRest(3, 4, MsRange.about(1000)),
        ),
      ReactionLevel.advancedPlus => ReactionDrillSpec(
          discipline: d,
          level: level,
          duration: const Duration(minutes: 2, seconds: 30),
          minLength: 1,
          maxLength: 1,
          windows: const [ReactionWindow(1, MsRange.about(1000))],
        ),
    };
  }

  // Striking and MMA share one progression; only the vocabulary differs.
  static ReactionDrillSpec _combinations(
    ReactionDiscipline d,
    ReactionLevel level,
  ) {
    // Longer calls earn more time to finish the last movement.
    const scaled = [
      ReactionWindow(2, MsRange.about(1000)),
      ReactionWindow(3, MsRange.about(1500)),
      ReactionWindow(5, MsRange.about(2000)),
      ReactionWindow(7, MsRange.about(2500)),
    ];
    return switch (level) {
      ReactionLevel.beginner => ReactionDrillSpec(
          discipline: d,
          level: level,
          duration: const Duration(seconds: 30),
          minLength: 1,
          maxLength: 2,
          windows: const [ReactionWindow(2, MsRange(1000, 1500))],
        ),
      ReactionLevel.intermediate => ReactionDrillSpec(
          discipline: d,
          level: level,
          duration: const Duration(minutes: 1, seconds: 30),
          minLength: 1,
          maxLength: 4,
          windows: const [ReactionWindow(4, MsRange.about(1500, spread: 200))],
          recovery: const RecoveryPause(3, MsRange(1000, 1500)),
        ),
      ReactionLevel.advanced => ReactionDrillSpec(
          discipline: d,
          level: level,
          duration: const Duration(minutes: 2, seconds: 30),
          minLength: 2,
          maxLength: 5,
          windows: scaled,
          recovery: const RecoveryPause(4, MsRange.about(1500, spread: 200)),
        ),
      ReactionLevel.advancedPlus => ReactionDrillSpec(
          discipline: d,
          level: level,
          duration: const Duration(minutes: 1, seconds: 30),
          minLength: 1,
          maxLength: 7,
          windows: scaled,
          recovery: const RecoveryPause(6, MsRange.about(3000, spread: 300)),
        ),
    };
  }
}

/// One call from the coach: one or more commands said as a single breath
/// ("Step left, hook!"), then silence for the athlete to move.
class ReactionCue {
  final List<ReactionCommand> commands;

  /// Silence after the voice finishes, before the next call.
  final Duration gapAfter;

  const ReactionCue(this.commands, this.gapAfter);

  /// The line the voice speaks: short, clipped, no filler words.
  String get spoken => '${commands.map((c) => c.spoken).join(', ')}!';

  @override
  String toString() => '${commands.join(' > ')} (+${gapAfter.inMilliseconds})';
}

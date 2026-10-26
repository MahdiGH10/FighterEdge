/// The reaction drill's timing model: how long an athlete gets after each
/// call, how that scales with the move and the level, and how long the coach
/// takes to say a line.
///
/// Every call is exactly one move, at every level. What makes a level harder
/// is the pace: less time to react, less time allowed for the movement.
///
/// Pure Dart on purpose (no Flutter, no platform, no clock). Every number is
/// a named constant, and every random draw comes from a [Random] the caller
/// passes in, so a seeded [Random] gives the same drill every time.
///
/// ## The model
///
/// ```
/// movement = speed(level) * (moveCost + finishCost)
/// reaction = margin(level)
/// gap      = movement + jittered(reaction)
/// gap     >= movement + 300 ms            (never shorter than the movement)
/// ```
///
/// The gap is measured from the moment the voice *finishes* the call (the
/// controller waits for `say()` to complete), so the time it takes to speak a
/// call never eats into the athlete's time. Only the reaction part is
/// jittered; the time a movement physically takes is never shortened.
///
/// ## Evidence behind the numbers
///
/// * Auditory choice reaction time is about 300 ms, plus about 200 ms to
///   hear the call and decide what it was. The level margins all sit above
///   that 500 ms.
/// * A Muay Thai roundhouse takes about 1.02 s for the whole cycle (about
///   0.65 s of it to get back to stance). A jab or cross reaches the target
///   in about 357 ms, a hook in about 477 ms. These anchor the strike costs.
/// * Amateur rounds are 3 x 2 min for novices and 3 x 3 min for elite
///   athletes, with 1 min rest. These anchor the round lengths.
/// * Random gaps stop athletes anticipating the next call; fixed gaps let
///   them react to the rhythm instead of the voice. This is why the reaction
///   part is jittered (and skewed, see [ReactionTiming.sampleGapMs]).
/// * The grappling costs (sprawl, shoot, rolls, cartwheel) are coaching
///   estimates, coach sign-off pending.
library;

import 'dart:math';

import 'reaction_drill.dart';

/// Extra rest after every few calls (the wrestling "3-4 calls, then breathe"
/// rhythm).
class BlockRest {
  final int minCalls;
  final int maxCalls;
  final Duration rest;
  const BlockRest(this.minCalls, this.maxCalls, this.rest)
      : assert(minCalls <= maxCalls);
}

/// Everything that makes one level harder than the one before it.
class ReactionLevelTiming {
  /// Time to hear the call, decide and start moving. Always above ~500 ms
  /// (choice reaction time plus hear-and-decide).
  final int marginMs;

  /// Multiplier on how long each movement is allowed to take. Below 1 means
  /// the athlete is expected to be quicker than the nominal cost.
  final double speed;

  /// How far the reaction part may stray from nominal, as a fraction
  /// (0.25 is +-25%).
  final double jitter;

  /// One round of work, and the rest between rounds.
  final Duration roundWork;
  final Duration roundRest;

  /// Extra breathing time in wrestling drills, null for none.
  final BlockRest? grapplingBlockRest;

  const ReactionLevelTiming({
    required this.marginMs,
    required this.speed,
    required this.jitter,
    required this.roundWork,
    required this.roundRest,
    this.grapplingBlockRest,
  });

  /// The same level at a different pace: only the two pace numbers change,
  /// the rounds and rests stay.
  ReactionLevelTiming withPace(
          {required int marginMs, required double speed}) =>
      ReactionLevelTiming(
        marginMs: marginMs,
        speed: speed,
        jitter: jitter,
        roundWork: roundWork,
        roundRest: roundRest,
        grapplingBlockRest: grapplingBlockRest,
      );
}

abstract final class ReactionTiming {
  // -- Combo cost: what a move adds inside a call (ms). ----------------------

  // Punches. Jab/cross reach the target in ~357 ms, a hook in ~477 ms; the
  // costs round to that plus a little for the rotation back.
  static const jabMs = 300;
  static const crossMs = 400;
  static const hookMs = 450;
  static const uppercutMs = 450;

  // Kicks. A roundhouse is ~1.02 s end to end; the others scale from it.
  static const teepMs = 800;
  static const lowKickMs = 900;
  static const midKickMs = 1100;
  static const sideKickMs = 1200;
  static const highKickMs = 1250;

  // Movement and defence.
  static const slipMs = 400;
  static const stepMs = 400;
  static const pivotMs = 500;
  static const levelChangeMs = 600;
  static const kickCheckMs = 600;
  static const downBlockMs = 700;
  static const jumpMs = 700;

  // Grappling: coaching estimates, coach sign-off pending.
  static const sprawlMs = 1300;
  static const shootMs = 1800;
  static const frontRollMs = 2500;
  static const cartwheelMs = 2500;
  static const backRollMs = 3000;

  // -- Finish cost: return to guard, once per call (ms). ---------------------

  /// A call that ends on a punch or any movement/defence move.
  static const finishAfterPunchMs = 300;

  /// A call that ends on a kick: the leg has to come back down (about 0.65 s
  /// of the roundhouse cycle is the return, only part of which overlaps the
  /// kick cost above).
  static const finishAfterKickMs = 500;

  /// A call that ends on a grappling move: getting back up to stance after
  /// a sprawl, roll or cartwheel. Coaching estimate, coach sign-off pending.
  /// It is 500 rather than 300 so the worked examples in the plan hold
  /// (front roll about 5.4 s on Beginner and 3.3 s on Advanced+).
  static const finishAfterGrapplingMs = 500;

  /// The gap is never shorter than the movement plus this: even with the
  /// most extreme jitter the athlete has finished moving and has a moment to
  /// reset before the next call.
  static const floorMarginMs = 300;

  // -- Jitter ----------------------------------------------------------------

  /// Chance that a gap gets a long breather on top, which keeps the rhythm
  /// unpredictable.
  static const longGapChance = 0.12;
  static const longGapMinMs = 1000;
  static const longGapMaxMs = 2000;

  /// Exponent that skews the jitter toward shorter gaps: a uniform draw `u`
  /// becomes `u^skew`, which piles up near zero (the short end).
  static const jitterSkew = 2.0;

  // -- Levels ----------------------------------------------------------------

  static const _beginner = ReactionLevelTiming(
    marginMs: 1500,
    speed: 1.3,
    jitter: 0.25,
    roundWork: Duration(minutes: 1),
    roundRest: Duration(minutes: 1),
    grapplingBlockRest: BlockRest(3, 4, Duration(milliseconds: 3000)),
  );
  static const _intermediate = ReactionLevelTiming(
    marginMs: 1100,
    speed: 1.15,
    jitter: 0.25,
    roundWork: Duration(minutes: 2),
    roundRest: Duration(minutes: 1),
    grapplingBlockRest: BlockRest(4, 5, Duration(milliseconds: 2500)),
  );
  static const _advanced = ReactionLevelTiming(
    marginMs: 800,
    speed: 1.0,
    jitter: 0.30,
    roundWork: Duration(minutes: 3),
    roundRest: Duration(minutes: 1),
    grapplingBlockRest: BlockRest(5, 6, Duration(milliseconds: 2000)),
  );
  static const _advancedPlus = ReactionLevelTiming(
    marginMs: 600,
    speed: 0.9,
    jitter: 0.35,
    roundWork: Duration(minutes: 3),
    roundRest: Duration(minutes: 1),
  );

  static ReactionLevelTiming of(ReactionLevel level) => switch (level) {
        ReactionLevel.beginner => _beginner,
        ReactionLevel.intermediate => _intermediate,
        ReactionLevel.advanced => _advanced,
        ReactionLevel.advancedPlus => _advancedPlus,
      };

  // -- Pace ------------------------------------------------------------------

  /// Sprint keeps every level's rounds and rests and tightens the two pace
  /// numbers: less time to react and less time allowed for the movement.
  /// The reaction margin never drops below [sprintMarginFloorMs], so it still
  /// clears choice reaction time plus hear-and-decide.
  static const sprintMarginFactor = 0.8;
  static const sprintSpeedFactor = 0.9;
  static const sprintMarginFloorMs = 500;

  /// The level's timing at [pace]. Steady is the level table itself.
  static ReactionLevelTiming forPace(ReactionLevel level, ReactionPace pace) {
    final t = of(level);
    return switch (pace) {
      ReactionPace.steady => t,
      ReactionPace.sprint => t.withPace(
          marginMs: max(
              sprintMarginFloorMs, (t.marginMs * sprintMarginFactor).round()),
          speed: t.speed * sprintSpeedFactor,
        ),
    };
  }

  /// Rounds per drill: wrestling is short and heavy, so 2; striking and MMA 3.
  static int roundsFor(ReactionDiscipline discipline) =>
      discipline == ReactionDiscipline.grappling ? 2 : 3;

  // -- Costs -----------------------------------------------------------------

  /// What [command] costs to perform. Every command in the catalog is
  /// listed; "Back hook" and the lead uppercut use the closest listed move
  /// (hook, uppercut). "Level change - front/back roll" is a level change
  /// followed by the roll, so it costs both. Anything unknown costs the same
  /// as a mid kick, the middle of the range, so a new command is never
  /// silently free.
  static int moveCostMs(ReactionCommand command) => switch (command.id) {
        'jab' => jabMs,
        'cross' => crossMs,
        'hook' || 'back_hook' => hookMs,
        'uppercut' || 'lead_uppercut' => uppercutMs,
        'teep' => teepMs,
        'low_kick' => lowKickMs,
        'middle_kick' || 'left_kick' || 'right_kick' => midKickMs,
        'side_kick' => sideKickMs,
        'high_kick' => highKickMs,
        'slip_left' || 'slip_right' => slipMs,
        'step_left' || 'step_right' || 'step_back' || 'step_in' => stepMs,
        'pivot_left' || 'pivot_right' => pivotMs,
        'level_change' => levelChangeMs,
        'kick_check' => kickCheckMs,
        'down_block' => downBlockMs,
        'jump' => jumpMs,
        'sprawl' => sprawlMs,
        'shoot' => shootMs,
        'front_roll' => frontRollMs,
        'cartwheel' => cartwheelMs,
        'back_roll' => backRollMs,
        'level_change_front_roll' => levelChangeMs + frontRollMs,
        'level_change_back_roll' => levelChangeMs + backRollMs,
        _ => midKickMs,
      };

  /// The cost of getting back to guard after a call that ends on [last].
  static int finishCostMs(ReactionCommand last) => switch (last.id) {
        'teep' ||
        'low_kick' ||
        'middle_kick' ||
        'left_kick' ||
        'right_kick' ||
        'side_kick' ||
        'high_kick' =>
          finishAfterKickMs,
        'sprawl' ||
        'shoot' ||
        'front_roll' ||
        'cartwheel' ||
        'back_roll' ||
        'level_change_front_roll' ||
        'level_change_back_roll' =>
          finishAfterGrapplingMs,
        _ => finishAfterPunchMs,
      };

  /// How long [command] takes at [level]'s pace. Never jittered.
  static int movementMs(
    ReactionCommand command,
    ReactionLevel level, {
    ReactionPace pace = ReactionPace.steady,
  }) =>
      (forPace(level, pace).speed *
              (moveCostMs(command) + finishCostMs(command)))
          .round();

  /// The athlete's reaction time at [level], before jitter.
  static int reactionMs(
    ReactionLevel level, {
    ReactionPace pace = ReactionPace.steady,
  }) =>
      forPace(level, pace).marginMs;

  /// The gap with no jitter at all: movement plus nominal reaction time.
  static int nominalGapMs(
    ReactionCommand command,
    ReactionLevel level, {
    ReactionPace pace = ReactionPace.steady,
  }) =>
      movementMs(command, level, pace: pace) + reactionMs(level, pace: pace);

  /// The shortest the gap may ever be.
  static int floorMs(
    ReactionCommand command,
    ReactionLevel level, {
    ReactionPace pace = ReactionPace.steady,
  }) =>
      movementMs(command, level, pace: pace) + floorMarginMs;

  /// The gap for a given jitter. [jitterFraction] scales the reaction part
  /// (-0.25 is a quarter shorter); [extraMs] is added to it. The movement
  /// part is untouched and the result is clamped to [floorMs].
  static int gapMs(
    ReactionCommand command,
    ReactionLevel level, {
    double jitterFraction = 0,
    int extraMs = 0,
    ReactionPace pace = ReactionPace.steady,
  }) {
    final movement = movementMs(command, level, pace: pace);
    final reaction = reactionMs(level, pace: pace);
    final gap = movement + (reaction * (1 + jitterFraction)).round() + extraMs;
    return max(gap, movement + floorMarginMs);
  }

  /// One random gap. The jitter is skewed toward *shorter* gaps (most calls
  /// come a bit sooner than nominal), and about one call in eight gets a
  /// 1-2 s breather on top, so the rhythm cannot be learned.
  static int sampleGapMs(
    ReactionCommand command,
    ReactionLevel level,
    Random random, {
    ReactionPace pace = ReactionPace.steady,
  }) {
    final j = of(level).jitter;
    final skewed = pow(random.nextDouble(), jitterSkew).toDouble();
    final fraction = -j + 2 * j * skewed;
    final extra = random.nextDouble() < longGapChance
        ? longGapMinMs + random.nextInt(longGapMaxMs - longGapMinMs + 1)
        : 0;
    return gapMs(command, level,
        jitterFraction: fraction, extraMs: extra, pace: pace);
  }

  /// The reaction time the picker shows for a level, in ms, as (shortest,
  /// longest) once the jitter is applied, without the movement time (which
  /// depends on the move called) and without the occasional long breather.
  static (int, int) reactionRangeMs(
    ReactionLevel level, {
    ReactionPace pace = ReactionPace.steady,
  }) {
    final t = of(level);
    final nominal = reactionMs(level, pace: pace);
    return (
      (nominal * (1 - t.jitter)).round(),
      (nominal * (1 + t.jitter)).round(),
    );
  }
}

/// How long the coach takes to say a line, estimated from its syllables.
///
/// The drill measures real speech (it waits for the voice to finish); this
/// estimate only decides whether a call can finish before the round ends, and
/// how long to wait on an engine that never says it is done.
abstract final class SpeechEstimate {
  /// About 190 ms per syllable at the drill's speaking rate, plus a short
  /// lead-in for the engine.
  static const syllableMs = 190;
  static const leadInMs = 250;

  /// A speech engine that is silent for twice the expected time (plus a
  /// second) is treated as broken.
  static const timeoutFactor = 2;
  static const timeoutSlackMs = 1000;

  /// Counts vowel groups per word ("Level change" is 3). A trailing silent
  /// "e" does not count ("change"), but "-le" does ("middle"). Every word
  /// has at least one.
  static int syllables(String line) {
    var total = 0;
    for (final match in RegExp('[A-Za-z]+').allMatches(line)) {
      total += _wordSyllables(match.group(0)!.toLowerCase());
    }
    return total;
  }

  static int _wordSyllables(String word) {
    // A leading "y" is a consonant ("yes"); elsewhere it is a vowel ("ready").
    final body = word.startsWith('y') ? word.substring(1) : word;
    var count = RegExp('[aeiouy]+').allMatches(body).length;
    if (count > 1 &&
        body.endsWith('e') &&
        !body.endsWith('le') &&
        !body.endsWith('ee')) {
      count--;
    }
    return max(1, count);
  }

  /// Expected time to say [line] once.
  static Duration expected(String line) =>
      Duration(milliseconds: syllables(line) * syllableMs + leadInMs);

  /// The longest to wait for [line] before giving up on the engine.
  static Duration timeout(String line) => Duration(
        milliseconds:
            timeoutFactor * expected(line).inMilliseconds + timeoutSlackMs,
      );
}

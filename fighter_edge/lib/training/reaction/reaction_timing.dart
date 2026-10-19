/// The reaction drill's timing model: how long an athlete gets after each
/// call, how that scales with the call and the level, and how long the coach
/// takes to say a line.
///
/// Pure Dart on purpose (no Flutter, no platform, no clock). Every number is
/// a named constant, and every random draw comes from a [Random] the caller
/// passes in, so a seeded [Random] gives the same drill every time.
///
/// ## The model
///
/// ```
/// movement = speed(level) * (sum(moveCost) + finishCost)
/// reaction = margin(level) + recall(level) * (moves - 1)
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
  /// Time to hear the call, decide and start moving, for the first move of a
  /// call. Always above ~500 ms (choice reaction time plus hear-and-decide).
  final int marginMs;

  /// Multiplier on how long each movement is allowed to take. Below 1 means
  /// the athlete is expected to be quicker than the nominal cost.
  final double speed;

  /// Extra thinking time per move after the first, to hold the sequence in
  /// mind.
  final int recallMs;

  /// How far the reaction part may stray from nominal, as a fraction
  /// (0.25 is +-25%).
  final double jitter;

  /// Moves per call, inclusive (striking and MMA; wrestling is always 1).
  final int minMoves;
  final int maxMoves;

  /// One round of work, and the rest between rounds.
  final Duration roundWork;
  final Duration roundRest;

  /// Extra breathing time in wrestling drills, null for none.
  final BlockRest? grapplingBlockRest;

  const ReactionLevelTiming({
    required this.marginMs,
    required this.speed,
    required this.recallMs,
    required this.jitter,
    required this.minMoves,
    required this.maxMoves,
    required this.roundWork,
    required this.roundRest,
    this.grapplingBlockRest,
  });
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
    recallMs: 300,
    jitter: 0.25,
    minMoves: 1,
    maxMoves: 2,
    roundWork: Duration(minutes: 1),
    roundRest: Duration(minutes: 1),
    grapplingBlockRest: BlockRest(3, 4, Duration(milliseconds: 3000)),
  );
  static const _intermediate = ReactionLevelTiming(
    marginMs: 1100,
    speed: 1.15,
    recallMs: 200,
    jitter: 0.25,
    minMoves: 1,
    maxMoves: 3,
    roundWork: Duration(minutes: 2),
    roundRest: Duration(minutes: 1),
    grapplingBlockRest: BlockRest(4, 5, Duration(milliseconds: 2500)),
  );
  static const _advanced = ReactionLevelTiming(
    marginMs: 800,
    speed: 1.0,
    recallMs: 150,
    jitter: 0.30,
    minMoves: 2,
    maxMoves: 4,
    roundWork: Duration(minutes: 3),
    roundRest: Duration(minutes: 1),
    grapplingBlockRest: BlockRest(5, 6, Duration(milliseconds: 2000)),
  );
  static const _advancedPlus = ReactionLevelTiming(
    marginMs: 600,
    speed: 0.9,
    recallMs: 100,
    jitter: 0.35,
    minMoves: 2,
    maxMoves: 5,
    roundWork: Duration(minutes: 3),
    roundRest: Duration(minutes: 1),
  );

  static ReactionLevelTiming of(ReactionLevel level) => switch (level) {
        ReactionLevel.beginner => _beginner,
        ReactionLevel.intermediate => _intermediate,
        ReactionLevel.advanced => _advanced,
        ReactionLevel.advancedPlus => _advancedPlus,
      };

  /// Rounds per drill: wrestling is short and heavy, so 2; striking and MMA 3.
  static int roundsFor(ReactionDiscipline discipline) =>
      discipline == ReactionDiscipline.grappling ? 2 : 3;

  // -- Costs -----------------------------------------------------------------

  /// What [command] adds inside a call. Every command in the catalog is
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
        'middle_kick' => midKickMs,
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

  /// How long the call's movements take at [level]'s pace. Never jittered.
  static int movementMs(List<ReactionCommand> commands, ReactionLevel level) {
    assert(commands.isNotEmpty);
    final sum = commands.fold<int>(0, (s, c) => s + moveCostMs(c));
    return (of(level).speed * (sum + finishCostMs(commands.last))).round();
  }

  /// The athlete's reaction time at [level] for a call of [moves] moves,
  /// before jitter.
  static int reactionMs(int moves, ReactionLevel level) {
    final t = of(level);
    return t.marginMs + t.recallMs * (moves - 1);
  }

  /// The gap with no jitter at all: movement plus nominal reaction time.
  static int nominalGapMs(
          List<ReactionCommand> commands, ReactionLevel level) =>
      movementMs(commands, level) + reactionMs(commands.length, level);

  /// The shortest the gap may ever be.
  static int floorMs(List<ReactionCommand> commands, ReactionLevel level) =>
      movementMs(commands, level) + floorMarginMs;

  /// The gap for a given jitter. [jitterFraction] scales the reaction part
  /// (-0.25 is a quarter shorter); [extraMs] is added to it. The movement
  /// part is untouched and the result is clamped to [floorMs].
  static int gapMs(
    List<ReactionCommand> commands,
    ReactionLevel level, {
    double jitterFraction = 0,
    int extraMs = 0,
  }) {
    final movement = movementMs(commands, level);
    final reaction = reactionMs(commands.length, level);
    final gap = movement + (reaction * (1 + jitterFraction)).round() + extraMs;
    return max(gap, movement + floorMarginMs);
  }

  /// One random gap. The jitter is skewed toward *shorter* gaps (most calls
  /// come a bit sooner than nominal), and about one call in eight gets a
  /// 1-2 s breather on top, so the rhythm cannot be learned.
  static int sampleGapMs(
    List<ReactionCommand> commands,
    ReactionLevel level,
    Random random,
  ) {
    final j = of(level).jitter;
    final skewed = pow(random.nextDouble(), jitterSkew).toDouble();
    final fraction = -j + 2 * j * skewed;
    final extra = random.nextDouble() < longGapChance
        ? longGapMinMs + random.nextInt(longGapMaxMs - longGapMinMs + 1)
        : 0;
    return gapMs(commands, level, jitterFraction: fraction, extraMs: extra);
  }

  /// The reaction time the picker shows for a drill, in ms, from a
  /// single-move call to the longest call the level makes, before jitter and
  /// without the movement time (which depends on the moves called).
  static (int, int) reactionRangeMs(
    ReactionDiscipline discipline,
    ReactionLevel level,
  ) {
    final t = of(level);
    final grappling = discipline == ReactionDiscipline.grappling;
    final shortest = grappling ? 1 : t.minMoves;
    final longest = grappling ? 1 : t.maxMoves;
    return (reactionMs(shortest, level), reactionMs(longest, level));
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

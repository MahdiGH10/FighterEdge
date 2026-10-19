import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/training/reaction/reaction_cue_generator.dart';
import 'package:fighter_edge/training/reaction/reaction_drill.dart';
import 'package:fighter_edge/training/reaction/reaction_timing.dart';

List<ReactionCue> _cues(ReactionDrillSpec spec, {int seed = 7, int n = 2000}) {
  final generator = ReactionCueGenerator(spec, random: Random(seed));
  return [for (var i = 0; i < n; i++) generator.next()];
}

ReactionDrillSpec _spec(ReactionDiscipline d, ReactionLevel l) =>
    ReactionDrillSpec.of(d, l);

void main() {
  group('Vocabulary matches the coaching sheet', () {
    test('each discipline has its full list, once each', () {
      expect(ReactionDiscipline.grappling.commands.map((c) => c.label), [
        'Shoot',
        'Sprawl',
        'Front roll',
        'Back roll',
        'Down block',
        'Jump',
        'Cartwheel',
      ]);
      expect(ReactionDiscipline.striking.commands, hasLength(19));
      expect(ReactionDiscipline.mma.commands, hasLength(24));
      for (final d in ReactionDiscipline.values) {
        final ids = d.commands.map((c) => c.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: '$d has a repeat');
      }
    });

    test('Teep is in striking and MMA; MMA mixes in wrestling', () {
      expect(ReactionDiscipline.striking.commands,
          contains(ReactionCommands.teep));
      expect(ReactionDiscipline.mma.commands, contains(ReactionCommands.teep));
      expect(
        ReactionDiscipline.mma.commands,
        containsAll([
          ReactionCommands.sprawl,
          ReactionCommands.shoot,
          ReactionCommands.levelChangeFrontRoll,
          ReactionCommands.levelChangeBackRoll,
        ]),
      );
      expect(ReactionDiscipline.striking.commands,
          isNot(contains(ReactionCommands.sprawl)));
    });

    test('the voice gets a short, clipped line with no filler', () {
      const cue = ReactionCue(
        [ReactionCommands.stepLeft, ReactionCommands.hook],
        Duration(seconds: 1),
      );
      expect(cue.spoken, 'Step left, Hook!');
      expect(
        const ReactionCue(
                [ReactionCommands.levelChangeFrontRoll], Duration.zero)
            .spoken,
        'Level change front roll!',
      );
    });
  });

  group('Levels', () {
    test('run the rounds the coaching plan sets', () {
      // Work minutes per level; rest is one minute.
      const work = [1, 2, 3, 3];
      const rounds = {
        ReactionDiscipline.grappling: 2,
        ReactionDiscipline.striking: 3,
        ReactionDiscipline.mma: 3,
      };
      for (final entry in rounds.entries) {
        for (final level in ReactionLevel.values) {
          final spec = _spec(entry.key, level);
          final reason = '${entry.key} $level';
          expect(spec.rounds, entry.value, reason: reason);
          expect(spec.roundDuration, Duration(minutes: work[level.index]),
              reason: reason);
          expect(spec.restDuration, const Duration(minutes: 1), reason: reason);
          expect(spec.workDuration, spec.roundDuration * entry.value);
          expect(
              spec.totalDuration,
              spec.workDuration +
                  const Duration(minutes: 1) * (entry.value - 1),
              reason: reason);
        }
      }
    });

    test('a harder level never runs shorter than an easier one', () {
      for (final d in ReactionDiscipline.values) {
        for (var i = 1; i < ReactionLevel.values.length; i++) {
          final easy = _spec(d, ReactionLevel.values[i - 1]);
          final hard = _spec(d, ReactionLevel.values[i]);
          expect(hard.roundDuration, greaterThanOrEqualTo(easy.roundDuration));
          expect(hard.workDuration, greaterThanOrEqualTo(easy.workDuration));
          expect(hard.maxLength, greaterThanOrEqualTo(easy.maxLength));
          expect(hard.minLength, greaterThanOrEqualTo(easy.minLength));
        }
      }
    });

    test('wrestling calls are always one move', () {
      for (final level in ReactionLevel.values) {
        final cues = _cues(_spec(ReactionDiscipline.grappling, level));
        expect(cues.every((c) => c.commands.length == 1), isTrue);
      }
    });

    test('striking and MMA calls stay within each level length', () {
      const bounds = {
        ReactionLevel.beginner: (1, 2),
        ReactionLevel.intermediate: (1, 3),
        ReactionLevel.advanced: (2, 4),
        ReactionLevel.advancedPlus: (2, 5),
      };
      for (final d in [ReactionDiscipline.striking, ReactionDiscipline.mma]) {
        for (final MapEntry(key: level, value: (lo, hi)) in bounds.entries) {
          final lengths =
              _cues(_spec(d, level)).map((c) => c.commands.length).toSet();
          expect(lengths, {for (var n = lo; n <= hi; n++) n},
              reason: '$d $level uses every length from $lo to $hi');
        }
      }
    });

    test('only wrestling has block rest, and it eases off with the level', () {
      expect(
          _spec(ReactionDiscipline.striking, ReactionLevel.beginner).blockRest,
          isNull);
      expect(_spec(ReactionDiscipline.mma, ReactionLevel.beginner).blockRest,
          isNull);
      final rests = [
        for (final l in ReactionLevel.values)
          _spec(ReactionDiscipline.grappling, l).blockRest,
      ];
      expect(rests.last, isNull);
      for (var i = 1; i < 3; i++) {
        expect(rests[i]!.rest, lessThan(rests[i - 1]!.rest));
        expect(rests[i]!.minCalls, greaterThan(rests[i - 1]!.minCalls));
      }
    });
  });

  group('Timing', () {
    int ms(ReactionCue c) => c.gapAfter.inMilliseconds;

    test('every cue carries the floor, and its gap never goes below it', () {
      for (final d in ReactionDiscipline.values) {
        for (final level in ReactionLevel.values) {
          for (final c in _cues(_spec(d, level), n: 500)) {
            expect(
                c.minGap,
                Duration(
                    milliseconds: ReactionTiming.floorMs(c.commands, level)));
            expect(c.gapAfter, greaterThanOrEqualTo(c.minGap),
                reason: '$d $level $c');
          }
        }
      }
    });

    test('gaps follow the model: movement plus a jittered reaction', () {
      // Wrestling is left out: block rest adds to its gaps (tested below).
      for (final d in [ReactionDiscipline.striking, ReactionDiscipline.mma]) {
        for (final level in ReactionLevel.values) {
          final j = ReactionTiming.of(level).jitter;
          for (final c in _cues(_spec(d, level))) {
            final movement = ReactionTiming.movementMs(c.commands, level);
            final reaction =
                ReactionTiming.reactionMs(c.commands.length, level);
            expect(
                ms(c) - movement,
                inInclusiveRange((reaction * (1 - j)).floor(),
                    (reaction * (1 + j)).ceil() + 2000),
                reason: '$d $level $c');
          }
        }
      }
    });

    test('wrestling rests every few calls at the cadence of its level', () {
      for (final level in [
        ReactionLevel.beginner,
        ReactionLevel.intermediate,
        ReactionLevel.advanced,
      ]) {
        final real = _spec(ReactionDiscipline.grappling, level).blockRest!;
        // The same cadence with a rest too long to mistake for anything else.
        final spec = ReactionDrillSpec(
          discipline: ReactionDiscipline.grappling,
          level: level,
          rounds: 2,
          roundDuration: const Duration(minutes: 1),
          restDuration: const Duration(minutes: 1),
          minLength: 1,
          maxLength: 1,
          blockRest: BlockRest(
              real.minCalls, real.maxCalls, const Duration(minutes: 5)),
        );
        final cues = _cues(spec);
        final restAt = [
          for (var i = 0; i < cues.length; i++)
            if (ms(cues[i]) > 200000) i,
        ];
        expect(restAt, isNotEmpty, reason: '$level');
        expect(restAt.first,
            inInclusiveRange(real.minCalls - 1, real.maxCalls - 1));
        for (var k = 1; k < restAt.length; k++) {
          expect(restAt[k] - restAt[k - 1],
              inInclusiveRange(real.minCalls, real.maxCalls),
              reason: '$level');
        }
        // And the rest is added on top of an ordinary gap.
        for (final i in restAt) {
          final movement = ReactionTiming.movementMs(cues[i].commands, level);
          final reaction = ReactionTiming.reactionMs(1, level);
          expect(ms(cues[i]) - 300000 - movement,
              greaterThanOrEqualTo((reaction * 0.5).floor()));
        }
      }
    });

    test('Advanced+ wrestling has no block rest at all', () {
      const level = ReactionLevel.advancedPlus;
      final top = (ReactionTiming.reactionMs(1, level) * 1.35).ceil() + 2000;
      for (final c in _cues(_spec(ReactionDiscipline.grappling, level))) {
        expect(ms(c) - ReactionTiming.movementMs(c.commands, level),
            lessThanOrEqualTo(top));
      }
    });

    test('a longer or costlier call always gets a longer nominal gap', () {
      for (final level in ReactionLevel.values) {
        final jab = [ReactionCommands.jab];
        final jabCross = [ReactionCommands.jab, ReactionCommands.cross];
        final kick = [ReactionCommands.highKick];
        expect(ReactionTiming.nominalGapMs(jabCross, level),
            greaterThan(ReactionTiming.nominalGapMs(jab, level)));
        expect(ReactionTiming.nominalGapMs(kick, level),
            greaterThan(ReactionTiming.nominalGapMs(jab, level)));
      }
    });
  });

  group('Unpredictability', () {
    List<ReactionCommand> flat(List<ReactionCue> cues) =>
        [for (final c in cues) ...c.commands];

    test('never the same call twice in a row', () {
      for (final d in ReactionDiscipline.values) {
        for (final level in ReactionLevel.values) {
          final moves = flat(_cues(_spec(d, level)));
          for (var i = 1; i < moves.length; i++) {
            expect(moves[i], isNot(same(moves[i - 1])),
                reason: '$d $level at $i');
          }
        }
      }
    });

    test('not the sheet order, and every command comes up early', () {
      final spec = _spec(ReactionDiscipline.grappling, ReactionLevel.beginner);
      final first = flat(_cues(spec, n: 7));
      expect(first.toSet(), spec.discipline.commands.toSet(),
          reason: 'one full pass of the deck covers every command');

      final orders = {
        for (var seed = 0; seed < 50; seed++)
          flat(_cues(spec, seed: seed, n: 7)).map((c) => c.id).join(','),
      };
      final sheetOrder = spec.discipline.commands.map((c) => c.id).join(',');
      expect(orders.length, greaterThan(40),
          reason: 'different runs play different orders');
      expect(orders, isNot(contains(sheetOrder)));
    });

    test('every command is used, with no favorites', () {
      final spec = _spec(ReactionDiscipline.mma, ReactionLevel.advancedPlus);
      final counts = <ReactionCommand, int>{};
      for (final c in flat(_cues(spec))) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
      expect(counts.keys.toSet(), spec.discipline.commands.toSet());
      final values = counts.values;
      expect(values.reduce(max) - values.reduce(min), lessThanOrEqualTo(2),
          reason: 'the deck deals each command once per pass');
    });
  });
}

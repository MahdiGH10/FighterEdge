import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/training/reaction/reaction_cue_generator.dart';
import 'package:fighter_edge/training/reaction/reaction_drill.dart';

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
    test('run for the lengths the coaching plan sets', () {
      const expected = {
        ReactionDiscipline.grappling: [30, 60, 120, 150],
        ReactionDiscipline.striking: [30, 90, 150, 90],
        ReactionDiscipline.mma: [30, 90, 150, 90],
      };
      for (final entry in expected.entries) {
        for (final level in ReactionLevel.values) {
          expect(
            _spec(entry.key, level).duration.inSeconds,
            entry.value[level.index],
            reason: '${entry.key} $level',
          );
        }
      }
    });

    test('wrestling calls are always one move', () {
      for (final level in ReactionLevel.values) {
        final cues = _cues(_spec(ReactionDiscipline.grappling, level));
        expect(cues.every((c) => c.commands.length == 1), isTrue);
      }
    });

    test('striking and MMA calls stay within each level\'s length', () {
      const bounds = {
        ReactionLevel.beginner: (1, 2),
        ReactionLevel.intermediate: (1, 4),
        ReactionLevel.advanced: (2, 5),
        ReactionLevel.advancedPlus: (1, 7),
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
  });

  group('Timing', () {
    int ms(ReactionCue c) => c.gapAfter.inMilliseconds;

    test('beginner never leaves more than 1.5 s between calls', () {
      for (final d in ReactionDiscipline.values) {
        final gaps = _cues(_spec(d, ReactionLevel.beginner)).map(ms);
        expect(gaps.every((g) => g >= 1000 && g <= 1500), isTrue, reason: '$d');
      }
    });

    test('wrestling advanced rests about a second every 3–4 calls', () {
      final cues =
          _cues(_spec(ReactionDiscipline.grappling, ReactionLevel.advanced));
      final restAt = [
        for (var i = 0; i < cues.length; i++)
          if (ms(cues[i]) > 1000) i,
      ];
      // Base gap is 0.8–1.0 s; with the rest it is 1.7–2.1 s.
      for (final i in restAt) {
        expect(ms(cues[i]), inInclusiveRange(1700, 2100));
      }
      for (var k = 1; k < restAt.length; k++) {
        expect(restAt[k] - restAt[k - 1], inInclusiveRange(3, 4));
      }
      expect(restAt.first, inInclusiveRange(2, 3));
    });

    test('advanced striking gives longer calls more time, then a breather', () {
      final cues =
          _cues(_spec(ReactionDiscipline.striking, ReactionLevel.advanced));
      for (final c in cues) {
        final expected = switch (c.commands.length) {
          2 => (900, 1100),
          3 => (1400, 1600),
          _ => (1900 + 1300, 2100 + 1700),
        };
        expect(ms(c), inInclusiveRange(expected.$1, expected.$2),
            reason: '${c.commands.length} moves');
      }
    });

    test('intermediate adds 1–1.5 s after a 3–4 move sequence', () {
      final cues =
          _cues(_spec(ReactionDiscipline.mma, ReactionLevel.intermediate));
      for (final c in cues) {
        final long = c.commands.length >= 3;
        expect(
          ms(c),
          long ? inInclusiveRange(2300, 3200) : inInclusiveRange(1300, 1700),
        );
      }
    });

    test('advanced+ gives about 3 s more after a 6–7 move sequence', () {
      final cues =
          _cues(_spec(ReactionDiscipline.striking, ReactionLevel.advancedPlus));
      final longest = cues.where((c) => c.commands.length >= 6);
      expect(longest, isNotEmpty);
      for (final c in longest) {
        expect(ms(c), inInclusiveRange(2400 + 2700, 2600 + 3300));
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

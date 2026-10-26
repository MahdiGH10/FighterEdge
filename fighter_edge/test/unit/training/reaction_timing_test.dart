import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/training/reaction/reaction_drill.dart';
import 'package:fighter_edge/training/reaction/reaction_timing.dart';

/// A [Random] that replays scripted doubles, so a test can ask for "the
/// shortest possible jitter" or "a long breather" exactly.
class _Scripted implements Random {
  final List<double> _doubles;
  _Scripted(this._doubles);

  @override
  double nextDouble() => _doubles.removeAt(0);
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

const _levels = ReactionLevel.values;

List<ReactionCommand> _all() => {
      for (final d in ReactionDiscipline.values) ...d.commands,
    }.toList();

void main() {
  group('Worked examples (nominal, no jitter, speech excluded)', () {
    int gap(ReactionCommand c, ReactionLevel l) =>
        ReactionTiming.nominalGapMs(c, l);

    test('a front roll gives about 5.4 s on Beginner and 3.3 s on Advanced+',
        () {
      expect(gap(ReactionCommands.frontRoll, ReactionLevel.beginner), 5400);
      expect(gap(ReactionCommands.frontRoll, ReactionLevel.advancedPlus), 3300);
    });

    test('a single jab gives about 2.3 s on Beginner and 1.1 s on Advanced+',
        () {
      // 2280 and 1140 ms.
      expect(gap(ReactionCommands.jab, ReactionLevel.beginner), 2280);
      expect(gap(ReactionCommands.jab, ReactionLevel.advancedPlus), 1140);
    });

    test('a roll never gets the old 1 s', () {
      for (final l in _levels) {
        for (final c in [
          ReactionCommands.frontRoll,
          ReactionCommands.backRoll,
          ReactionCommands.cartwheel,
        ]) {
          expect(gap(c, l), greaterThan(3000), reason: '$c $l');
        }
      }
    });
  });

  group('Combo costs', () {
    test('every command in the catalog has the cost the plan lists', () {
      const expected = {
        'jab': 300,
        'cross': 400,
        'hook': 450,
        'back_hook': 450,
        'uppercut': 450,
        'lead_uppercut': 450,
        'teep': 800,
        'low_kick': 900,
        'middle_kick': 1100,
        'high_kick': 1250,
        'slip_left': 400,
        'slip_right': 400,
        'step_left': 400,
        'step_right': 400,
        'step_back': 400,
        'step_in': 400,
        'pivot_left': 500,
        'pivot_right': 500,
        'level_change': 600,
        'kick_check': 600,
        'down_block': 700,
        'jump': 700,
        'sprawl': 1300,
        'shoot': 1800,
        'front_roll': 2500,
        'cartwheel': 2500,
        'back_roll': 3000,
        'level_change_front_roll': 3100,
        'level_change_back_roll': 3600,
      };
      final catalog = _all();
      expect(catalog.map((c) => c.id).toSet(), expected.keys.toSet(),
          reason: 'a new command needs a cost');
      for (final c in catalog) {
        expect(ReactionTiming.moveCostMs(c), expected[c.id], reason: c.id);
      }
    });

    test('an unknown command is never free', () {
      expect(
          ReactionTiming.moveCostMs(const ReactionCommand('new', 'New')), 1100);
    });

    test('the finish cost follows the move', () {
      expect(ReactionTiming.finishCostMs(ReactionCommands.jab), 300);
      expect(ReactionTiming.finishCostMs(ReactionCommands.stepLeft), 300);
      expect(ReactionTiming.finishCostMs(ReactionCommands.highKick), 500);
      expect(ReactionTiming.finishCostMs(ReactionCommands.teep), 500);
      expect(ReactionTiming.finishCostMs(ReactionCommands.sprawl), 500);
    });

    test('the movement is the move plus its finish at the level\'s pace', () {
      expect(
          ReactionTiming.movementMs(
              ReactionCommands.lowKick, ReactionLevel.advanced),
          900 + 500);
      expect(
          ReactionTiming.movementMs(
              ReactionCommands.lowKick, ReactionLevel.beginner),
          (1.3 * 1400).round());
    });
  });

  group('Levels only ever get harder', () {
    test('margin and speed fall; the rest never shrink', () {
      for (var i = 1; i < _levels.length; i++) {
        final easy = ReactionTiming.of(_levels[i - 1]);
        final hard = ReactionTiming.of(_levels[i]);
        expect(hard.marginMs, lessThan(easy.marginMs));
        expect(hard.speed, lessThan(easy.speed));
        expect(hard.jitter, greaterThanOrEqualTo(easy.jitter));
        expect(hard.roundWork, greaterThanOrEqualTo(easy.roundWork));
      }
    });

    test('every margin clears choice reaction time plus hear-and-decide', () {
      for (final l in _levels) {
        expect(ReactionTiming.of(l).marginMs, greaterThanOrEqualTo(500));
      }
    });

    test('rounds follow the plan', () {
      const work = [1, 2, 3, 3];
      for (final l in _levels) {
        final t = ReactionTiming.of(l);
        expect(t.roundWork, Duration(minutes: work[l.index]));
        expect(t.roundRest, const Duration(minutes: 1));
      }
      expect(ReactionTiming.roundsFor(ReactionDiscipline.grappling), 2);
      expect(ReactionTiming.roundsFor(ReactionDiscipline.striking), 3);
      expect(ReactionTiming.roundsFor(ReactionDiscipline.mma), 3);
    });

    test('wrestling block rest shrinks with the level and ends at Advanced+',
        () {
      final rests = [for (final l in _levels) ReactionTiming.of(l)];
      expect(rests[0].grapplingBlockRest!.rest.inMilliseconds, 3000);
      expect(rests[0].grapplingBlockRest!.minCalls, 3);
      expect(rests[0].grapplingBlockRest!.maxCalls, 4);
      expect(rests[1].grapplingBlockRest!.rest.inMilliseconds, 2500);
      expect(rests[1].grapplingBlockRest!.minCalls, 4);
      expect(rests[1].grapplingBlockRest!.maxCalls, 5);
      expect(rests[2].grapplingBlockRest!.rest.inMilliseconds, 2000);
      expect(rests[2].grapplingBlockRest!.minCalls, 5);
      expect(rests[2].grapplingBlockRest!.maxCalls, 6);
      expect(rests[3].grapplingBlockRest, isNull);
    });

    test('the nominal gap strictly falls with the level, for every move', () {
      for (final c in _all()) {
        for (var i = 1; i < _levels.length; i++) {
          expect(
            ReactionTiming.nominalGapMs(c, _levels[i]),
            lessThan(ReactionTiming.nominalGapMs(c, _levels[i - 1])),
            reason: '$c ${_levels[i]}',
          );
        }
      }
    });

    test('the reaction the picker shows shrinks with the level', () {
      for (var i = 1; i < _levels.length; i++) {
        final easy = ReactionTiming.reactionRangeMs(_levels[i - 1]);
        final hard = ReactionTiming.reactionRangeMs(_levels[i]);
        expect(hard.$1, lessThan(easy.$1), reason: '${_levels[i]}');
        expect(hard.$2, lessThan(easy.$2), reason: '${_levels[i]}');
      }
      // The nominal margin, less and plus the level's jitter.
      expect(
          ReactionTiming.reactionRangeMs(ReactionLevel.beginner), (1125, 1875));
      expect(ReactionTiming.reactionRangeMs(ReactionLevel.advancedPlus),
          (390, 810));
    });
  });

  group('Jitter', () {
    const combos = <ReactionCommand>[
      ReactionCommands.jab,
      ReactionCommands.frontRoll,
      ReactionCommands.highKick,
      ReactionCommands.backRoll,
    ];

    test('the floor holds even with absurd jitter', () {
      for (final combo in combos) {
        for (final l in _levels) {
          final floor = ReactionTiming.floorMs(combo, l);
          expect(floor, ReactionTiming.movementMs(combo, l) + 300);
          for (final f in [-1.0, -2.5, -100.0]) {
            expect(ReactionTiming.gapMs(combo, l, jitterFraction: f), floor,
                reason: '$combo $l $f');
          }
          // And the clamp is not what makes ordinary calls work: the real
          // jitter range stays above the floor by itself.
          final low = ReactionTiming.gapMs(combo, l,
              jitterFraction: -ReactionTiming.of(l).jitter);
          expect(low, greaterThan(floor), reason: '$combo $l');
        }
      }
    });

    test('no sampled gap is ever below the floor', () {
      for (final seed in [1, 2, 3]) {
        final random = Random(seed);
        for (final d in ReactionDiscipline.values) {
          for (final l in _levels) {
            for (var i = 0; i < 400; i++) {
              final combo = d.commands[random.nextInt(d.commands.length)];
              expect(ReactionTiming.sampleGapMs(combo, l, random),
                  greaterThanOrEqualTo(ReactionTiming.floorMs(combo, l)));
            }
          }
        }
      }
    });

    test('jitter never touches the movement time', () {
      for (final combo in combos) {
        for (final l in _levels) {
          final movement = ReactionTiming.movementMs(combo, l);
          final reaction = ReactionTiming.reactionMs(l);
          for (final f in [-0.35, -0.1, 0.0, 0.2, 0.35]) {
            final gap = ReactionTiming.gapMs(combo, l, jitterFraction: f);
            expect(gap - movement, (reaction * (1 + f)).round(),
                reason: '$combo $l $f');
          }
        }
      }
      // The same jitter moves a slow call and a fast call by the same amount.
      const l = ReactionLevel.advanced;
      const slow = ReactionCommands.backRoll;
      const fast = ReactionCommands.jab;
      int shift(ReactionCommand c) =>
          ReactionTiming.gapMs(c, l, jitterFraction: 0.3) -
          ReactionTiming.nominalGapMs(c, l);
      expect(shift(slow), shift(fast));
    });

    test('a sampled gap stays within the level\'s jitter plus the breather',
        () {
      final random = Random(5);
      for (final l in _levels) {
        final j = ReactionTiming.of(l).jitter;
        for (final combo in combos) {
          final movement = ReactionTiming.movementMs(combo, l);
          final reaction = ReactionTiming.reactionMs(l);
          for (var i = 0; i < 500; i++) {
            final reactionPart =
                ReactionTiming.sampleGapMs(combo, l, random) - movement;
            expect(reactionPart,
                greaterThanOrEqualTo((reaction * (1 - j)).floor()));
            expect(reactionPart,
                lessThanOrEqualTo((reaction * (1 + j)).ceil() + 2000));
          }
        }
      }
    });

    test('scripted draws hit the extremes', () {
      const l = ReactionLevel.intermediate;
      const combo = ReactionCommands.jab;
      final movement = ReactionTiming.movementMs(combo, l);
      final reaction = ReactionTiming.reactionMs(l);

      // Shortest: u = 0, no breather.
      expect(ReactionTiming.sampleGapMs(combo, l, _Scripted([0.0, 0.5])),
          movement + (reaction * 0.75).round());
      // Longest jitter: u ~ 1, no breather.
      expect(
        ReactionTiming.sampleGapMs(combo, l, _Scripted([0.999999, 0.5])),
        closeTo(movement + reaction * 1.25, 2),
      );
      // A breather adds 1-2 s on top (nextInt is 0 here, so exactly 1 s).
      expect(ReactionTiming.sampleGapMs(combo, l, _Scripted([0.0, 0.05])),
          movement + (reaction * 0.75).round() + 1000);
      // 12% is the line.
      expect(ReactionTiming.sampleGapMs(combo, l, _Scripted([0.0, 0.119])),
          greaterThan(movement + reaction));
      expect(ReactionTiming.sampleGapMs(combo, l, _Scripted([0.0, 0.121])),
          lessThan(movement + reaction));
    });

    test('the distribution is skewed short, with the odd long breather', () {
      final random = Random(9);
      const l = ReactionLevel.advanced;
      const combo = ReactionCommands.jab;
      final nominal = ReactionTiming.nominalGapMs(combo, l);
      final movement = ReactionTiming.movementMs(combo, l);
      final reaction = ReactionTiming.reactionMs(l);
      final gaps = [
        for (var i = 0; i < 20000; i++)
          ReactionTiming.sampleGapMs(combo, l, random),
      ]..sort();

      final median = gaps[gaps.length ~/ 2];
      expect(median, lessThan(nominal), reason: 'most calls come sooner');
      final longOnes =
          gaps.where((g) => g - movement > reaction * (1 + 0.30)).length;
      expect(longOnes / gaps.length, closeTo(0.12, 0.03));
      final spread = gaps.toSet().length;
      expect(spread, greaterThan(500), reason: 'not metronomic');
    });

    test('a seeded Random always gives the same gaps', () {
      List<int> run(int seed) {
        final random = Random(seed);
        return [
          for (var i = 0; i < 50; i++)
            ReactionTiming.sampleGapMs(
                combos[i % combos.length], _levels[i % _levels.length], random),
        ];
      }

      expect(run(4), run(4));
      expect(run(4), isNot(run(5)));
    });
  });

  group('Speech estimate', () {
    test('counts syllables from vowel groups', () {
      const expected = {
        'Jab': 1,
        'Cross': 1,
        'Hook': 1,
        'Teep': 1,
        'Uppercut': 3,
        'Pivot': 2,
        'Sprawl': 1,
        'Cartwheel': 2,
        'Level change': 3,
        'Middle kick': 3,
        'Get ready!': 3,
        'Step left, Hook!': 3,
        'Low kick': 2,
        'Time!': 1,
        'Rest': 1,
        '': 0,
      };
      for (final e in expected.entries) {
        expect(SpeechEstimate.syllables(e.key), e.value, reason: e.key);
      }
    });

    test('expected is 190 ms a syllable plus a 250 ms lead-in', () {
      expect(
          SpeechEstimate.expected('Jab!'), const Duration(milliseconds: 440));
      expect(SpeechEstimate.expected('Uppercut!'),
          const Duration(milliseconds: 820));
    });

    test('the timeout is twice the estimate plus a second', () {
      expect(SpeechEstimate.timeout('Jab!'),
          const Duration(milliseconds: 2 * 440 + 1000));
    });

    test('every call the drill can make has a sane estimate', () {
      for (final c in _all()) {
        final line = '${c.spoken}!';
        expect(SpeechEstimate.syllables(line), greaterThan(0), reason: line);
        expect(SpeechEstimate.timeout(line),
            greaterThan(SpeechEstimate.expected(line) * 2));
      }
    });
  });
}

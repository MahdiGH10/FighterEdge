import 'dart:math';

import 'reaction_drill.dart';
import 'reaction_timing.dart';

/// Endless, unpredictable calls for one [ReactionDrillSpec].
///
/// Each call is a single move: the drill trains reacting to one thing at a
/// time, not memorizing combinations.
///
/// Commands are dealt from a shuffled deck that refills when it runs out, so
/// every command in the discipline comes up within one pass through the deck
/// (nothing gets starved by bad luck) while the order stays unguessable. The
/// same command is never called twice in a row.
class ReactionCueGenerator {
  final ReactionDrillSpec spec;
  final Random _random;

  final List<ReactionCommand> _deck = [];
  ReactionCommand? _last;
  int _callsInBlock = 0;
  late int _blockSize;

  /// A fresh [Random] per drill by default, so no two drills repeat.
  /// Tests pass a seeded one.
  ReactionCueGenerator(this.spec, {Random? random})
      : _random = random ?? Random() {
    _blockSize = _nextBlockSize();
  }

  ReactionCue next() {
    final command = _deal();

    var gapMs = ReactionTiming.sampleGapMs(command, spec.level, _random,
        pace: spec.pace);
    final block = spec.blockRest;
    if (block != null && ++_callsInBlock >= _blockSize) {
      gapMs += block.rest.inMilliseconds;
      _callsInBlock = 0;
      _blockSize = _nextBlockSize();
    }
    return ReactionCue(
      command,
      Duration(milliseconds: gapMs),
      minGap: Duration(
          milliseconds:
              ReactionTiming.floorMs(command, spec.level, pace: spec.pace)),
    );
  }

  ReactionCommand _deal() {
    if (_deck.isEmpty) {
      _deck
        ..addAll(spec.discipline.commands)
        ..shuffle(_random);
    }
    // A fresh deck can start with the command that just ended the last one.
    // Swap it for any other so the athlete never hears the same call twice
    // in a row.
    if (_deck.last == _last && _deck.length > 1) {
      final swap = _random.nextInt(_deck.length - 1);
      final top = _deck.last;
      _deck[_deck.length - 1] = _deck[swap];
      _deck[swap] = top;
    }
    return _last = _deck.removeLast();
  }

  int _nextBlockSize() {
    final block = spec.blockRest;
    return block == null ? 0 : _between(block.minCalls, block.maxCalls);
  }

  int _between(int min, int max) => min + _random.nextInt(max - min + 1);
}

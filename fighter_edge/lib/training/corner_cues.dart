/// What a corner says between rounds: one tactical note for the round that
/// is about to start, one recovery note for the minute you have now.
///
/// Pure and deterministic — the cue depends only on the timer preset and
/// where the upcoming round falls in the session, so it is testable and
/// never surprising.
class CornerCue {
  final String tactical;
  final String recovery;

  const CornerCue({required this.tactical, required this.recovery});
}

enum RoundStage { early, middle, finalRound }

class CornerCues {
  CornerCues._();

  static RoundStage stageOf({required int upcomingRound, required int rounds}) {
    if (upcomingRound >= rounds) return RoundStage.finalRound;
    if (upcomingRound <= (rounds / 3).ceil()) return RoundStage.early;
    return RoundStage.middle;
  }

  /// [style] is the timer preset name ("Boxing", "MMA", "BJJ"). Unknown
  /// presets fall back to the boxing set.
  static CornerCue forRest({
    required String style,
    required int upcomingRound,
    required int rounds,
  }) {
    final stage = stageOf(upcomingRound: upcomingRound, rounds: rounds);
    final tactics = _tactical[style] ?? _tactical['Boxing']!;
    return CornerCue(
      tactical: tactics[stage]!,
      // Rotates so consecutive rests don't repeat the same line.
      recovery: _recovery[(upcomingRound - 2) % _recovery.length],
    );
  }

  static const _tactical = <String, Map<RoundStage, String>>{
    'Boxing': {
      RoundStage.early: 'Establish the jab. Find your range before you '
          'commit to anything big.',
      RoundStage.middle: 'Go to the body. It brings their hands down and '
          'opens the head later.',
      RoundStage.finalRound: 'Last round: stay behind the jab. Don\'t load '
          'up and walk into a counter.',
    },
    'MMA': {
      RoundStage.early: 'Keep your back off the fence and test their '
          'takedown defence early.',
      RoundStage.middle: 'Mix strikes into level changes. Make them guess '
          'high or low.',
      RoundStage.finalRound: 'Last round: win the final minute. Finish '
          'exchanges in the centre or on top.',
    },
    'BJJ': {
      RoundStage.early: 'Grips first. Win the grip fight before you pull '
          'guard or shoot.',
      RoundStage.middle: 'Frames and elbows in. Protect your position '
          'before you attack.',
      RoundStage.finalRound: 'Last round: stay tight and make safe progress. '
          'Don\'t give up position chasing a finish.',
    },
  };

  static const _recovery = [
    'Breathe in through the nose, long slow breath out. Drop your '
        'shoulders.',
    'Small sip of water, not a gulp.',
    'Shake out your arms and legs. Keep your hands loose.',
    'Slow your breathing first, then think about the plan.',
  ];
}

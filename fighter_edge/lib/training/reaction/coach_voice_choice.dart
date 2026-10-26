import 'reaction_drill.dart';

/// Which voice calls the drill. Pure Dart: the labels and file names are plain
/// data a test can pin down.
enum CoachVoiceChoice {
  /// Recorded coach clips (free Kokoro voices, rendered once and shipped with
  /// the app): human-sounding, offline, and instant.
  usMale('us_male'),
  ukMale('uk_male'),
  usFemale('us_female'),

  /// The phone's own speech engine. Robotic, but it speaks anything and works
  /// if the clips cannot play.
  phone(null);

  /// Folder under `assets/voices/`, or null for the phone's engine.
  final String? folder;
  const CoachVoiceChoice(this.folder);

  bool get usesClips => folder != null;

  /// The voice a new install starts on.
  static const fallback = usMale;

  /// The choice saved as [name], or null if it is unknown.
  static CoachVoiceChoice? byName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// The fixed announcements the drill makes besides the moves.
abstract final class CoachLines {
  static const getReady = 'Get ready!';
  static const rest = 'Rest';
  static const time = 'Time!';

  static const announcements = [getReady, rest, time];

  /// Every line the drill can say: each move of every discipline, then the
  /// announcements. These are the lines that have a recorded clip.
  static final Set<String> all = {
    for (final d in ReactionDiscipline.values)
      for (final c in d.commands) '${c.spoken}!',
    ...announcements,
  };
}

/// Where a recorded clip lives.
abstract final class CoachClipNames {
  /// "Level change front roll!" -> `level_change_front_roll`.
  static String slug(String line) => line
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  /// The asset path relative to `assets/`, as the audio player wants it.
  static String path(CoachVoiceChoice voice, String line) =>
      'voices/${voice.folder}/${slug(line)}.mp3';
}

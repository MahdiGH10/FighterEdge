import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'clip_coach_voice.dart';
import 'coach_voice.dart';
import 'coach_voice_choice.dart';

/// The app's [CoachVoice]: speaks with whichever voice the athlete picked and
/// remembers the pick. The drill depends on the plain [CoachVoice], so it
/// never knows there is a choice.
///
/// Deliberately not a [Listenable] itself: it is handed to the drill as a
/// plain [CoachVoice], and only the picker listens, to [choiceListenable].
class SelectableCoachVoice implements CoachVoice {
  static const preferenceKey = 'coach.voice';

  /// The phone's own engine: the "Phone voice" option and the fallback for
  /// the clip voices.
  final CoachVoice phone;
  final CoachVoice Function(CoachVoiceChoice choice) _clips;

  final Map<CoachVoiceChoice, CoachVoice> _voices = {};
  final _choice = ValueNotifier(CoachVoiceChoice.fallback);
  var _pickedByUser = false;

  SelectableCoachVoice({
    required this.phone,
    required CoachVoice Function(CoachVoiceChoice choice) clips,
  }) : _clips = clips;

  /// Real clips on the audio plugin, with the phone's voice as the fallback.
  factory SelectableCoachVoice.withClips({required CoachVoice phone}) =>
      SelectableCoachVoice(
        phone: phone,
        clips: (choice) => ClipCoachVoice(
          voice: choice,
          player: AudioplayersClipPlayer(),
          fallback: phone,
        ),
      );

  CoachVoiceChoice get choice => _choice.value;

  /// Changes when the athlete picks a voice (or the saved one loads).
  ValueListenable<CoachVoiceChoice> get choiceListenable => _choice;

  CoachVoice get _current => _voices.putIfAbsent(
      choice, () => choice.usesClips ? _clips(choice) : phone);

  /// Reads the saved pick. A pick made before this finishes wins.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = CoachVoiceChoice.byName(prefs.getString(preferenceKey));
      if (saved == null || _pickedByUser || saved == choice) return;
      _choice.value = saved;
    } catch (_) {
      // Remembering the choice is a convenience; the default is fine.
    }
  }

  /// Switches voice and remembers it. Whatever the old voice was saying is
  /// cut off.
  Future<void> select(CoachVoiceChoice choice) async {
    if (choice == this.choice) return;
    _pickedByUser = true;
    await _current.stop();
    _choice.value = choice;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(preferenceKey, choice.name);
    } catch (_) {}
  }

  @override
  bool get isAvailable => _current.isAvailable;

  @override
  Future<void> prepare() => _current.prepare();

  @override
  Future<void> say(String line) => _current.say(line);

  @override
  Future<void> stop() => _current.stop();

  void dispose() {
    for (final v in _voices.values) {
      if (v is ClipCoachVoice) unawaited(v.dispose());
    }
    _choice.dispose();
  }
}

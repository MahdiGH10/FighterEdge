import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'coach_voice.dart';
import 'reaction_timing.dart';

/// [CoachVoice] on the device's own text-to-speech engine: offline, no
/// recordings to ship, and nothing leaves the phone.
class TtsCoachVoice implements CoachVoice {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _available = true;

  // A coach barks; a narrator reads. A little faster and a little lower than
  // the engine's default reads as the former. (0.5 is "normal" on Android and
  // iOS; the web engine's scale differs, where normal is 1.0.)
  static const _rate = kIsWeb ? 1.15 : 0.55;
  static const _pitch = 0.9;

  @override
  bool get isAvailable => _available;

  @override
  Future<void> prepare() async {
    if (_ready) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(1);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // Athletes drill to music: duck it under each call instead of
        // stopping it, and keep speaking with the silent switch on.
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          const [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.duckOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
      _ready = true;
    } catch (_) {
      _available = false;
    }
  }

  @override
  Future<void> say(String line) async {
    if (!_available) return;
    if (!_ready) await prepare();
    try {
      // Upper bound on this line, so a speech engine that never reports
      // completion cannot freeze the drill: twice the time its syllables
      // should take, plus a second. A fixed cut-off would either clip a
      // long call or overlap the next one.
      await _tts.speak(line).timeout(SpeechEstimate.timeout(line));
    } on TimeoutException {
      // Cut a line that ran over, so it cannot talk across the next call.
      await stop();
    } catch (_) {
      // One unheard call is not worth stopping a drill for; the call is on
      // screen regardless.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

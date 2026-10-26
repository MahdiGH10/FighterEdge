import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'coach_voice.dart';
import 'coach_voice_choice.dart';
import 'reaction_timing.dart';

/// Plays one recorded clip at a time. A seam so [ClipCoachVoice] can be tested
/// without an audio plugin.
abstract class ClipPlayer {
  /// Loads [assets] ahead of time so the first call is not late.
  Future<void> prepare(Iterable<String> assets);

  /// Plays [asset] and completes when it has finished, or after [timeout] if
  /// the player never says so. Throws if the clip cannot be played.
  Future<void> play(String asset, {required Duration timeout});

  Future<void> stop();

  Future<void> dispose();
}

/// [ClipPlayer] on the `audioplayers` plugin.
class AudioplayersClipPlayer implements ClipPlayer {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _complete;
  Completer<void>? _playing;
  bool _ready = false;

  @override
  Future<void> prepare(Iterable<String> assets) async {
    if (_ready) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    // Athletes drill to music: duck it under each call instead of stopping
    // it, and keep speaking with the silent switch on.
    await _player.setAudioContext(AudioContextConfig(
      focus: AudioContextConfigFocus.duckOthers,
      respectSilence: false,
    ).build());
    _complete = _player.onPlayerComplete.listen((_) => _finish());
    await AudioCache.instance.loadAll(assets.toList());
    _ready = true;
  }

  @override
  Future<void> play(String asset, {required Duration timeout}) async {
    if (!_ready) await prepare(const []);
    _finish();
    final done = _playing = Completer<void>();
    await _player.play(AssetSource(asset));
    await done.future.timeout(timeout, onTimeout: () async {
      // A clip that never reports completion must not freeze the drill.
      await _player.stop();
    });
  }

  void _finish() {
    final playing = _playing;
    if (playing != null && !playing.isCompleted) playing.complete();
    _playing = null;
  }

  @override
  Future<void> stop() async {
    _finish();
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _finish();
    await _complete?.cancel();
    await _player.dispose();
  }
}

/// [CoachVoice] that plays recorded clips of one voice.
///
/// The drill only ever says a fixed list of lines ([CoachLines.all]), so each
/// is rendered once by a free neural voice model and shipped as a small clip.
/// Nothing is generated on the phone, and the drill hears the same coach on
/// every device. A line with no clip, or a player that fails, falls back to
/// [fallback] (the phone's own voice), so a drill never goes quiet.
class ClipCoachVoice implements CoachVoice {
  final CoachVoiceChoice voice;
  final ClipPlayer _player;
  final CoachVoice _fallback;

  bool _ready = false;
  bool _broken = false;

  ClipCoachVoice({
    required this.voice,
    required ClipPlayer player,
    required CoachVoice fallback,
  })  : assert(voice.usesClips),
        _player = player,
        _fallback = fallback;

  @override
  bool get isAvailable => !_broken || _fallback.isAvailable;

  @override
  Future<void> prepare() async {
    if (_ready || _broken) return;
    try {
      await _player.prepare([
        for (final line in CoachLines.all) CoachClipNames.path(voice, line),
      ]);
      _ready = true;
    } catch (_) {
      _broken = true;
      await _fallback.prepare();
    }
  }

  @override
  Future<void> say(String line) async {
    if (!CoachLines.all.contains(line)) return _fallback.say(line);
    if (!_ready) await prepare();
    if (_broken) return _fallback.say(line);
    try {
      await _player.play(
        CoachClipNames.path(voice, line),
        timeout: SpeechEstimate.timeout(line),
      );
    } catch (_) {
      // Clips cannot play on this phone; the phone's voice takes over for
      // this line and the rest of the session.
      _broken = true;
      await _fallback.say(line);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    await _fallback.stop();
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}

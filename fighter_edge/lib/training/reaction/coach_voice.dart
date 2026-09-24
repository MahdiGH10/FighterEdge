/// The voice that calls reaction drills.
///
/// Mirrors the reminder and billing gateways: the drill depends on this
/// interface, never on a speech SDK, so tests and any platform without a
/// speech engine get a silent voice instead of a crash. The drill always
/// shows every call on screen too, so a silent voice degrades to a visual
/// drill rather than a broken one.
abstract class CoachVoice {
  /// Whether calls will actually be heard. The drill says so when not.
  bool get isAvailable;

  /// Warms the engine up before the first call, so "Jab!" is not late.
  Future<void> prepare();

  /// Speaks [line] and completes when the voice has finished saying it.
  /// Never throws: a failed call just means that one line was not heard.
  Future<void> say(String line);

  /// Cuts off whatever is being said.
  Future<void> stop();
}

/// No speech engine: the drill runs on screen only.
class SilentCoachVoice implements CoachVoice {
  const SilentCoachVoice();

  @override
  bool get isAvailable => false;

  @override
  Future<void> prepare() async {}

  @override
  Future<void> say(String line) async {}

  @override
  Future<void> stop() async {}
}

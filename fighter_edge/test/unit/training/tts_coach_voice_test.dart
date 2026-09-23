import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/training/reaction/tts_coach_voice.dart';

/// White-box tests of the speech adapter against a faked `flutter_tts`
/// platform channel: what it asks the engine for, and that a broken or hung
/// engine can never throw into, or freeze, a drill.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  late List<MethodCall> calls;

  void engine(Future<Object?>? Function(MethodCall call) handler) {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('prepares a clipped English coach voice that waits for each line',
      () async {
    engine((_) async => 1);
    final voice = TtsCoachVoice();
    await voice.prepare();
    final byName = {for (final c in calls) c.method: c.arguments};
    expect(byName['awaitSpeakCompletion'], true);
    expect(byName['setLanguage'], 'en-US');
    expect(byName['setSpeechRate'], 0.55);
    expect(byName['setPitch'], 0.9);
    expect(byName['setVolume'], 1.0);
    expect(byName.containsKey('setIosAudioCategory'), isFalse,
        reason: 'iOS-only session setup is not sent to other platforms');
    expect(voice.isAvailable, isTrue);

    // Preparing twice does not reconfigure the engine.
    final before = calls.length;
    await voice.prepare();
    expect(calls.length, before);
  });

  test('on iOS, calls duck the athlete\'s music instead of stopping it',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    engine((_) async => 1);
    final voice = TtsCoachVoice();
    await voice.prepare();
    // The iOS session branch runs: it takes the shared audio session first.
    // (flutter_tts then checks the *real* OS via dart:io before sending
    // setIosAudioCategory, so on a non-iOS test host that final call is
    // filtered by the plugin itself — the ducking has to be heard on a
    // device.)
    expect(
      calls.where((c) => c.method == 'setSharedInstance').single.arguments,
      true,
    );
    expect(voice.isAvailable, isTrue);
  });

  test('says exactly the line it is given', () async {
    engine((_) async => 1);
    final voice = TtsCoachVoice();
    await voice.say('Step left, Hook!');
    final speak = calls.where((c) => c.method == 'speak').single;
    final text = speak.arguments is Map
        ? (speak.arguments as Map)['text']
        : speak.arguments;
    expect(text, 'Step left, Hook!');
  });

  test('a device without a speech engine goes quietly silent', () async {
    engine((call) async {
      if (call.method == 'setLanguage') {
        throw PlatformException(code: 'no_engine');
      }
      return 1;
    });
    final voice = TtsCoachVoice();
    await voice.prepare();
    expect(voice.isAvailable, isFalse);
    await voice.say('Jab!'); // must not throw
    expect(calls.where((c) => c.method == 'speak'), isEmpty);
  });

  test('a failed line or stop never throws into the drill', () async {
    engine((call) async {
      if (call.method == 'speak' || call.method == 'stop') {
        throw PlatformException(code: 'busy');
      }
      return 1;
    });
    final voice = TtsCoachVoice();
    await voice.say('Sprawl!');
    await voice.stop();
    expect(voice.isAvailable, isTrue, reason: 'one bad line is not fatal');
  });

  testWidgets('an engine that never reports completion cannot freeze a drill',
      (tester) async {
    final never = Completer<Object?>();
    engine((call) => call.method == 'speak' ? never.future : Future.value(1));
    final voice = TtsCoachVoice();
    var done = false;
    unawaited(voice.say('Shoot!').then((_) => done = true));
    await tester.pump(const Duration(seconds: 5));
    expect(done, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(done, isTrue, reason: 'gives up on the line after 6 s');
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/training/reaction/clip_coach_voice.dart';
import 'package:fighter_edge/training/reaction/coach_voice.dart';
import 'package:fighter_edge/training/reaction/coach_voice_choice.dart';
import 'package:fighter_edge/training/reaction/reaction_drill.dart';
import 'package:fighter_edge/training/reaction/selectable_coach_voice.dart';

class _FakePlayer implements ClipPlayer {
  final played = <String>[];
  var prepared = <String>[];
  var stops = 0;
  var disposed = false;
  Object? failWith;

  @override
  Future<void> prepare(Iterable<String> assets) async {
    if (failWith != null) throw failWith!;
    prepared = assets.toList();
  }

  @override
  Future<void> play(String asset, {required Duration timeout}) async {
    if (failWith != null) throw failWith!;
    played.add(asset);
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => disposed = true;
}

class _FakeVoice implements CoachVoice {
  final lines = <String>[];
  var stops = 0;
  var prepares = 0;
  bool available = true;

  @override
  bool get isAvailable => available;
  @override
  Future<void> prepare() async => prepares++;
  @override
  Future<void> say(String line) async => lines.add(line);
  @override
  Future<void> stop() async => stops++;
}

void main() {
  group('Recorded clips', () {
    test('every line the drill can say has a clip, for every voice', () {
      for (final voice in CoachVoiceChoice.values.where((v) => v.usesClips)) {
        for (final line in CoachLines.all) {
          final file = File('assets/${CoachClipNames.path(voice, line)}');
          expect(file.existsSync(), isTrue,
              reason: '${voice.name} has no clip for "$line"');
          expect(file.lengthSync(), greaterThan(1000),
              reason: '${file.path} looks empty');
        }
      }
    });

    test('no clip is left over for a line the drill no longer says', () {
      final wanted = {
        for (final line in CoachLines.all) '${CoachClipNames.slug(line)}.mp3',
      };
      for (final voice in CoachVoiceChoice.values.where((v) => v.usesClips)) {
        final names = Directory('assets/voices/${voice.folder}')
            .listSync()
            .map((e) => e.uri.pathSegments.last)
            .toSet();
        expect(names, wanted, reason: voice.name);
      }
    });

    test('a line becomes its clip name', () {
      expect(CoachClipNames.slug('Jab!'), 'jab');
      expect(CoachClipNames.slug('Level change front roll!'),
          'level_change_front_roll');
      expect(CoachClipNames.slug('Get ready!'), 'get_ready');
      expect(CoachClipNames.path(CoachVoiceChoice.ukMale, 'Teep!'),
          'voices/uk_male/teep.mp3');
    });

    test('every spoken move is in the announcements-plus-moves list', () {
      for (final d in ReactionDiscipline.values) {
        for (final c in d.commands) {
          expect(CoachLines.all, contains('${c.spoken}!'));
        }
      }
      expect(CoachLines.all, containsAll(CoachLines.announcements));
    });
  });

  group('ClipCoachVoice', () {
    late _FakePlayer player;
    late _FakeVoice phone;
    late ClipCoachVoice voice;

    setUp(() {
      player = _FakePlayer();
      phone = _FakeVoice();
      voice = ClipCoachVoice(
        voice: CoachVoiceChoice.ukMale,
        player: player,
        fallback: phone,
      );
    });

    test('plays the clip for a line and never the phone voice', () async {
      await voice.say('Jab!');
      expect(player.played, ['voices/uk_male/jab.mp3']);
      expect(phone.lines, isEmpty);
      expect(voice.isAvailable, isTrue);
    });

    test('loads every clip of its voice ahead of time', () async {
      await voice.prepare();
      expect(player.prepared.toSet(), {
        for (final line in CoachLines.all)
          CoachClipNames.path(CoachVoiceChoice.ukMale, line),
      });
      expect(player.prepared, everyElement(startsWith('voices/uk_male/')));
    });

    test('a line with no clip is spoken by the phone voice', () async {
      await voice.say('Something new!');
      expect(player.played, isEmpty);
      expect(phone.lines, ['Something new!']);
    });

    test('a player that fails hands the rest of the drill to the phone',
        () async {
      player.failWith = StateError('no audio');
      await voice.say('Jab!');
      await voice.say('Hook!');
      expect(phone.lines, ['Jab!', 'Hook!']);
      expect(voice.isAvailable, isTrue, reason: 'the phone voice still speaks');
    });

    test('with no phone voice either, it says it is silent', () async {
      phone.available = false;
      player.failWith = StateError('no audio');
      await voice.say('Jab!');
      expect(voice.isAvailable, isFalse);
    });

    test('stop cuts the clip', () async {
      await voice.stop();
      expect(player.stops, 1);
      expect(phone.stops, 1);
    });
  });

  group('SelectableCoachVoice', () {
    late _FakeVoice phone;
    late Map<CoachVoiceChoice, _FakeVoice> clips;
    late SelectableCoachVoice voice;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      phone = _FakeVoice();
      clips = {};
      voice = SelectableCoachVoice(
        phone: phone,
        clips: (choice) => clips.putIfAbsent(choice, _FakeVoice.new),
      );
    });

    test('a new install starts on a recorded coach, not the phone voice',
        () async {
      expect(voice.choice, CoachVoiceChoice.usMale);
      await voice.say('Jab!');
      expect(clips[CoachVoiceChoice.usMale]!.lines, ['Jab!']);
      expect(phone.lines, isEmpty);
    });

    test('picking a voice switches to it, cuts the old one and remembers',
        () async {
      await voice.say('Jab!');
      final listened = <CoachVoiceChoice>[];
      voice.choiceListenable.addListener(() => listened.add(voice.choice));

      await voice.select(CoachVoiceChoice.usFemale);
      expect(voice.choice, CoachVoiceChoice.usFemale);
      expect(clips[CoachVoiceChoice.usMale]!.stops, 1);
      expect(listened, [CoachVoiceChoice.usFemale]);

      await voice.say('Hook!');
      expect(clips[CoachVoiceChoice.usFemale]!.lines, ['Hook!']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SelectableCoachVoice.preferenceKey), 'usFemale');
    });

    test('the phone voice is one of the choices', () async {
      await voice.select(CoachVoiceChoice.phone);
      await voice.say('Jab!');
      expect(phone.lines, ['Jab!']);
    });

    test('picking the voice already in use changes nothing', () async {
      var notified = 0;
      voice.choiceListenable.addListener(() => notified++);
      await voice.select(CoachVoiceChoice.usMale);
      expect(notified, 0);
    });

    test('the saved voice comes back on the next launch', () async {
      SharedPreferences.setMockInitialValues(
          {SelectableCoachVoice.preferenceKey: 'ukMale'});
      await voice.load();
      expect(voice.choice, CoachVoiceChoice.ukMale);
    });

    test('an unknown saved value is ignored', () async {
      SharedPreferences.setMockInitialValues(
          {SelectableCoachVoice.preferenceKey: 'robot'});
      await voice.load();
      expect(voice.choice, CoachVoiceChoice.usMale);
    });

    test('a pick made while loading is not overwritten by the saved one',
        () async {
      SharedPreferences.setMockInitialValues(
          {SelectableCoachVoice.preferenceKey: 'ukMale'});
      await voice.select(CoachVoiceChoice.usFemale);
      await voice.load();
      expect(voice.choice, CoachVoiceChoice.usFemale);
    });

    test('it reports whether the current voice can be heard', () async {
      clips[CoachVoiceChoice.usMale] = _FakeVoice()..available = false;
      expect(voice.isAvailable, isFalse);
      await voice.select(CoachVoiceChoice.phone);
      expect(voice.isAvailable, isTrue);
    });
  });
}

import 'dart:async';

import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/observability/boot_failure.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BootFailure.classify', () {
    test('names the kind of error, never its message', () {
      expect(
        BootFailure.classify(MissingPluginException('secret detail')),
        'missing_plugin',
      );
      expect(
        BootFailure.classify(
            PlatformException(code: 'channel-error', message: 'a@b.com')),
        'platform:channel-error',
      );
      expect(
        BootFailure.classify(
            FirebaseException(plugin: 'core', code: 'no-app', message: 'x')),
        'firebase:no-app',
      );
      expect(BootFailure.classify(TimeoutException('slow')), 'timeout');
      expect(BootFailure.classify(StateError('uid 123')), 'other');
    });
  });

  group('bootStep', () {
    late List<String?> logged;
    late DebugPrintCallback original;

    setUp(() {
      logged = [];
      original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logged.add(message);
    });
    tearDown(() => debugPrint = original);

    test('passes a successful step through without logging', () async {
      expect(await bootStep(BootStage.auth, () async => 42), 42);
      expect(logged, isEmpty);
    });

    test('logs one line and throws a BootFailure naming the step', () async {
      await expectLater(
        bootStep(
            BootStage.firebase, () => throw MissingPluginException('channel')),
        throwsA(isA<BootFailure>()
            .having((f) => f.stage, 'stage', BootStage.firebase)
            .having((f) => f.kind, 'kind', 'missing_plugin')),
      );
      expect(logged, ['[boot] failed at firebase: missing_plugin']);
    });
  });

  testWidgets('a failed boot shows the failure screen and Retry runs it again',
      (tester) async {
    var attempts = 0;
    Future<AppDependencies> failing() async {
      attempts++;
      throw const BootFailure(BootStage.auth, 'timeout');
    }

    await tester.pumpWidget(FighterEdgeBootstrap(initialize: failing));
    await tester.pumpAndSettle();

    expect(find.text('Could not start Fighter Edge'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Could not start Fighter Edge'), findsOneWidget);
  });
}

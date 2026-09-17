import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/widgets/animated_count.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

void main() {
  group('AnimatedCount', () {
    testWidgets('counts from the start value to the target', (tester) async {
      await tester.pumpWidget(_host(
        AnimatedCount(
          value: 2750,
          from: 0,
          formatter: (v) => '${v.round()}',
        ),
      ));

      // First frame sits at the start value.
      expect(find.text('0'), findsOneWidget);

      // Partway through it is somewhere in between — not start, not end.
      await tester.pump(MotionTokens.reveal ~/ 2);
      final midText = (tester.widget<Text>(find.byType(Text)).data ?? '');
      final mid = int.parse(midText);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(2750));

      // And it lands exactly on the target.
      await tester.pumpAndSettle();
      expect(find.text('2750'), findsOneWidget);
    });

    testWidgets('never overshoots its target', (tester) async {
      // A spring would sail past the value before settling, which would show
      // the user a calorie target they were never given.
      await tester.pumpWidget(_host(
        AnimatedCount(
          value: 100,
          from: 0,
          formatter: (v) => '${v.round()}',
        ),
      ));

      for (var elapsed = Duration.zero;
          elapsed < MotionTokens.reveal + const Duration(milliseconds: 100);
          elapsed += const Duration(milliseconds: 16)) {
        final text = tester.widget<Text>(find.byType(Text)).data ?? '';
        expect(
          int.parse(text),
          lessThanOrEqualTo(100),
          reason: 'overshot to $text',
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    testWidgets('renders the final value immediately under reduced motion',
        (tester) async {
      await tester.pumpWidget(_host(
        AnimatedCount(
          value: 2750,
          from: 0,
          formatter: (v) => '${v.round()}',
        ),
        disableAnimations: true,
      ));

      // No intermediate frame at all — straight to the answer.
      expect(find.text('2750'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('2750'), findsOneWidget);
    });

    testWidgets('applies the formatter, including suffixes', (tester) async {
      await tester.pumpWidget(_host(
        AnimatedCount(
          value: 147,
          formatter: (v) => '${v.round()}g',
        ),
        disableAnimations: true,
      ));

      expect(find.text('147g'), findsOneWidget);
    });

    testWidgets('without `from`, the first build is static', (tester) async {
      // Values that merely happen to be on screen should not count on every
      // rebuild; only an explicit `from` opts into the entrance count.
      await tester.pumpWidget(_host(
        AnimatedCount(
          value: 500,
          formatter: (v) => '${v.round()}',
        ),
      ));

      expect(find.text('500'), findsOneWidget);
    });
  });
}

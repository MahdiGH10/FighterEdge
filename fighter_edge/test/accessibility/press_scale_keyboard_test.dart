import 'dart:ui' show SemanticsAction;

import 'package:fighter_edge/theme/app_accessibility.dart';
import 'package:fighter_edge/theme/app_colors.dart';
import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/widgets/filter_chips.dart';
import 'package:fighter_edge/widgets/press_scale.dart';
import 'package:fighter_edge/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keyboard and switch-control access to every [PressScale] surface
/// (WCAG 2.1.1 Keyboard, 2.4.7 Focus Visible).
Future<void> _pump(WidgetTester tester, List<Widget> children) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  ));
}

Widget _surface(String label, VoidCallback? onTap) => PressScale(
      onTap: onTap,
      haptic: null,
      child: SizedBox(height: 48, width: 160, child: Text(label)),
    );

Border? _ringOf(WidgetTester tester, {int index = 0}) {
  final box = find
      .descendant(
        of: find.byType(PressScale).at(index),
        matching: find.byType(DecoratedBox),
      )
      .first;
  return (tester.widget<DecoratedBox>(box).decoration as BoxDecoration).border
      as Border?;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

class _CountsBuilds extends StatefulWidget {
  const _CountsBuilds(this.onInit);
  final VoidCallback onInit;

  @override
  State<_CountsBuilds> createState() => _CountsBuildsState();
}

class _CountsBuildsState extends State<_CountsBuilds> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 48, width: 160);
}

void main() {
  testWidgets(
      'Tab reaches an enabled surface; Enter and Space each activate it',
      (tester) async {
    var taps = 0;
    await _pump(tester, [_surface('Go', () => taps++)]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(taps, 0, reason: 'focus alone must not activate');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    expect(taps, 3);
  });

  testWidgets('holding Enter activates once, not on every key repeat',
      (tester) async {
    var taps = 0;
    await _pump(tester, [_surface('Go', () => taps++)]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);

    expect(taps, 1);
  });

  testWidgets('a surface with no onTap is skipped by Tab and ignores keys',
      (tester) async {
    var disabledTaps = 0;
    var taps = 0;
    await _pump(tester, [
      PressScale(
        onLongPress: () => disabledTaps++,
        haptic: null,
        child: const SizedBox(height: 48, width: 160, child: Text('Off')),
      ),
      _surface('On', () => taps++),
    ]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(taps, 1, reason: 'the first Tab skips the disabled surface');
    expect(disabledTaps, 0);
    expect(_ringOf(tester, index: 0), isNull);
    expect(_ringOf(tester, index: 1), isNotNull);
  });

  testWidgets('keyboard focus draws a ring; a touch press hides it again',
      (tester) async {
    await _pump(tester, [_surface('Go', () {})]);
    expect(_ringOf(tester), isNull, reason: 'no ring before any focus');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final ring = _ringOf(tester);
    expect(ring, isNotNull);
    expect(ring!.top.color, AppColors.accentText);
    expect(ring.top.width, FocusTokens.ringWidth);

    await tester.tap(find.byType(PressScale));
    await tester.pump();
    expect(_ringOf(tester), isNull,
        reason: 'a touch interaction is not keyboard focus');
  });

  testWidgets('the ring does not rebuild the surface underneath it',
      (tester) async {
    var inits = 0;
    await _pump(tester, [
      PressScale(
          onTap: () {}, haptic: null, child: _CountsBuilds(() => inits++)),
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringOf(tester), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(inits, 1, reason: 'focus moving on or off must keep child state');
  });

  test('the focus ring is at least 3:1 on every surface it can sit on', () {
    // WCAG 1.4.11: a focus indicator is a user-interface component.
    const surfaces = {
      'background': AppColors.background,
      'backgroundRaised': AppColors.backgroundRaised,
      'surface': AppColors.surface,
      'surfaceAlt': AppColors.surfaceAlt,
      'surfaceElevated': AppColors.surfaceElevated,
    };
    for (final entry in surfaces.entries) {
      expect(
          _contrast(AppColors.accentText, entry.value), greaterThanOrEqualTo(3),
          reason: 'ring on ${entry.key}');
    }
  });

  testWidgets('high contrast keeps the ring in a readable accent',
      (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: Builder(builder: (context) {
          captured = context;
          return const SizedBox();
        }),
      ),
    ));
    expect(_contrast(AppAccessibility.accentText(captured), AppColors.surface),
        greaterThanOrEqualTo(3));
  });

  testWidgets('PrimaryButton and GhostButton activate from the keyboard',
      (tester) async {
    var primary = 0;
    var ghost = 0;
    await _pump(tester, [
      PrimaryButton('Save', onPressed: () => primary++),
      GhostButton('Skip', onPressed: () => ghost++),
    ]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(primary, 1);
    expect(ghost, 1);
  });

  testWidgets('a disabled PrimaryButton cannot be focused or activated',
      (tester) async {
    await _pump(tester, [const PrimaryButton('Save')]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(_ringOf(tester), isNull);
    expect(FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<PrimaryButton>()));
  });

  testWidgets('chips move selection with Tab then Space', (tester) async {
    final chosen = <int>[];
    await _pump(tester, [
      FilterChips(
        options: const ['Day', 'Week', 'Month'],
        selectedIndex: 0,
        scrollable: false,
        onSelected: chosen.add,
      ),
    ]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(chosen, [1]);
  });

  testWidgets('screen readers still get one button with a tap action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, [PrimaryButton('Save', onPressed: () {})]);

    final data = tester.getSemantics(find.text('Save')).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.label, 'Save');
    semantics.dispose();
  });
}

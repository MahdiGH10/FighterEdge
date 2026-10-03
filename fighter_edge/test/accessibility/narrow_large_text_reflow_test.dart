import 'package:fl_chart/fl_chart.dart';
import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_plan_screen.dart';
import 'package:fighter_edge/l10n/gen/app_localizations.dart';
import 'package:fighter_edge/screens/onboarding/onboarding_steps.dart';
import 'package:fighter_edge/screens/reaction_drill_picker.dart';
import 'package:fighter_edge/screens/weight_tracker_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/widgets/app_scaffold.dart';
import 'package:fighter_edge/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_harness.dart';
import 'large_text_test.dart' show expectNoFlutterException;

/// Labels and values stay whole on a 320 px phone and at 200% text
/// (WCAG 1.4.4 Resize Text, 1.4.10 Reflow): they wrap, stack or scale instead
/// of ending in "..." or breaking inside a word.
void _phone(WidgetTester tester, {required double width, double text = 1}) {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// How many lines a Text laid out on: the distinct tops of its glyph boxes.
int _lines(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final boxes = paragraph.getBoxesForSelection(TextSelection(
    baseOffset: 0,
    extentOffset: paragraph.text.toPlainText().length,
  ));
  return boxes.map((box) => box.top.round()).toSet().length;
}

/// True when [word] sits on one line, i.e. was not broken inside the word.
bool _wordIsWhole(WidgetTester tester, Finder text, String word) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final start = paragraph.text.toPlainText().indexOf(word);
  expect(start, isNonNegative, reason: '"$word" is in the text');
  final boxes = paragraph.getBoxesForSelection(TextSelection(
    baseOffset: start,
    extentOffset: start + word.length,
  ));
  return boxes.map((box) => box.top.round()).toSet().length == 1;
}

NutritionTarget _target() => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      estimatedRmrKcal: 1780,
      maintenanceRangeLowKcal: 2400,
      maintenanceRangeHighKcal: 2600,
      targetCalories: 2500,
      proteinGrams: 150,
      fatGrams: 80,
      carbGrams: 260,
      fiberGramsLow: 30,
      fiberGramsHigh: 40,
      equationProfileUsed: EquationProfile.higherOffset,
      confidence: ConfidenceLabel.high,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Without the real fonts every glyph is a one-em square, and wrapping
  // assertions would measure the placeholder font, not the app.
  setUpAll(() async {
    final oswald = FontLoader('Oswald')
      ..addFont(rootBundle.load('assets/fonts/Oswald-Variable.ttf'));
    final barlow = FontLoader('Barlow')
      ..addFont(rootBundle.load('assets/fonts/barlow/Barlow-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/barlow/Barlow-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/barlow/Barlow-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/barlow/Barlow-Bold.ttf'));
    final phosphorRegular = FontLoader('PhosphorRegular')
      ..addFont(rootBundle.load('assets/fonts/phosphor/Phosphor-Regular.ttf'));
    final phosphorFill = FontLoader('PhosphorFill')
      ..addFont(rootBundle.load('assets/fonts/phosphor/Phosphor-Fill.ttf'));
    await Future.wait([
      oswald.load(),
      barlow.load(),
      phosphorRegular.load(),
      phosphorFill.load(),
    ]);
  });

  group('reaction picker chips', () {
    testWidgets('Wrestling is whole on a 320 px phone', (tester) async {
      _phone(tester, width: 320);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        Theme(
          data: AppTheme.dark(),
          child: const Scaffold(body: ReactionDrillPicker()),
        ),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      final paragraph =
          tester.renderObject<RenderParagraph>(find.text('Wrestling'));
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: 'the label must not end in an ellipsis');
      expectNoFlutterException(tester);
    });

    testWidgets('three equal chips share one row on a normal phone',
        (tester) async {
      _phone(tester, width: 390);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        Theme(
          data: AppTheme.dark(),
          child: const Scaffold(body: ReactionDrillPicker()),
        ),
        repo: repo,
      ));
      await tester.pumpAndSettle();

      final tops = [
        for (final label in ['Wrestling', 'Striking', 'MMA'])
          tester.getTopLeft(find.text(label)).dy,
      ];
      expect(tops[1], closeTo(tops[0], 1));
      expect(tops[2], closeTo(tops[0], 1));
    });
  });

  group('fuel plan macro cards', () {
    Future<void> pumpPlan(WidgetTester tester) async {
      final repo = await makeRepo(signedIn: true);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _target());
      await tester.pumpWidget(wrapApp(
        Theme(data: AppTheme.dark(), child: const EdgeFuelPlanScreen()),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('stack one per row at 200% and never split a label',
        (tester) async {
      _phone(tester, width: 320, text: 2);
      await pumpPlan(tester);

      final protein = find.text('Protein');
      expect(_lines(tester, protein), 1, reason: 'no "Protei" / "n"');
      expect(_lines(tester, find.text('Carbs')), 1);
      expect(_lines(tester, find.text('Fats')), 1);
      expect(tester.getTopLeft(find.text('Carbs')).dy,
          greaterThan(tester.getTopLeft(protein).dy));
      expect(tester.getTopLeft(find.text('Fats')).dy,
          greaterThan(tester.getTopLeft(find.text('Carbs')).dy));
      expect(_lines(tester, find.text('150 g')), 1);
      expectNoFlutterException(tester);
    });

    testWidgets('sit side by side at normal text', (tester) async {
      _phone(tester, width: 320);
      await pumpPlan(tester);

      final protein = tester.getTopLeft(find.text('Protein'));
      final carbs = tester.getTopLeft(find.text('Carbs'));
      expect(carbs.dy, closeTo(protein.dy, 1));
      expect(carbs.dx, greaterThan(protein.dx));
    });
  });

  group('weight tracker', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Widget host(AppState state) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            ChangeNotifierProvider.value(
              value: EdgeFuelController(
                repository: InMemoryEdgeFuelRepository(),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: const WeightTrackerScreen(),
          ),
        );

    AppState daily(int days) {
      final today = DateTime(2026, 10, 1);
      final state = AppState(dataRepository: InMemoryDataRepository())
        ..setUser('u1');
      for (var i = days - 1; i >= 0; i--) {
        state.addWeight(today.subtract(Duration(days: i)), 80.0 - i * 0.1);
      }
      return state;
    }

    final dateLabel = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          RegExp(r'^\d{1,2}/\d{1,2}$').hasMatch(widget.data ?? ''),
    );

    for (final scenario in [
      (width: 320.0, text: 2.0),
      (width: 320.0, text: 1.0),
      (width: 390.0, text: 2.0),
      (width: 390.0, text: 1.0),
    ]) {
      testWidgets(
          'chart dates never overlap at ${scenario.width.toInt()} px, '
          '${(scenario.text * 100).toInt()}% text', (tester) async {
        _phone(tester, width: scenario.width, text: scenario.text);
        await tester.pumpWidget(host(daily(21)));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(dateLabel.first, 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();

        final rects = [
          for (var i = 0; i < dateLabel.evaluate().length; i++)
            tester.getRect(dateLabel.at(i)),
        ];
        expect(rects.length, inInclusiveRange(2, 4));
        // The strip reserved under the plot grows with the text size. A fixed
        // 24 px strip clipped the bottom of 200% dates, and a clip is
        // painted, so no layout rect shows it.
        final strip = tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .titlesData
            .bottomTitles
            .sideTitles
            .reservedSize;
        expect(
            strip, greaterThanOrEqualTo(ChartTokens.dateAxis * scenario.text));
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(rects[i].overlaps(rects[j]), isFalse,
                reason: 'label $i overlaps label $j');
          }
        }
      });
    }

    testWidgets('a normal phone still labels four dates', (tester) async {
      _phone(tester, width: 390);
      await tester.pumpWidget(host(daily(21)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(dateLabel.first, 200,
          scrollable: find.byType(Scrollable).first);
      expect(dateLabel.evaluate().length, 4);
    });

    testWidgets('stat cards stack at 200% so "Set in EdgeFuel" stays whole',
        (tester) async {
      _phone(tester, width: 320, text: 2);
      await tester.pumpWidget(host(daily(5)));
      await tester.pumpAndSettle();

      expect(_wordIsWhole(tester, find.text('Set in EdgeFuel'), 'EdgeFuel'),
          isTrue,
          reason: 'wrapping between words is fine, "EdgeFue" / "l" is not');
      expect(tester.getTopLeft(find.text('Goal')).dy,
          greaterThan(tester.getTopLeft(find.text('7-day avg')).dy));
      expectNoFlutterException(tester);
    });

    testWidgets('stat cards sit side by side at normal text', (tester) async {
      _phone(tester, width: 390);
      await tester.pumpWidget(host(daily(5)));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('Goal')).dx,
          greaterThan(tester.getTopLeft(find.text('7-day avg')).dx));
    });
  });

  group('tab headers', () {
    testWidgets('scale a long title down instead of ending in an ellipsis',
        (tester) async {
      _phone(tester, width: 320, text: 2);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: ScreenScaffold.tab(
          title: 'Nutrition',
          actions: const [Icon(Icons.add)],
          body: ListView(),
        ),
      ));
      await tester.pumpAndSettle();

      final title = find.text('NUTRITION');
      expect(tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
          isFalse,
          reason: 'the whole word is laid out');
      // 16 px gutter, 56 px for the action.
      expect(
          tester.getRect(title).right, lessThanOrEqualTo(320 - 16 - 56 + 0.5));
      expect(tester.getRect(title).left, greaterThanOrEqualTo(16 - 0.5));
      expectNoFlutterException(tester);
    });

    testWidgets('keep full size when the title already fits', (tester) async {
      _phone(tester, width: 390);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: ScreenScaffold.tab(title: 'Train', body: ListView()),
      ));
      await tester.pumpAndSettle();

      final paragraph =
          tester.renderObject<RenderParagraph>(find.text('TRAIN'));
      expect(tester.getSize(find.text('TRAIN')).height,
          closeTo(paragraph.size.height, 0.01),
          reason: 'no scale applied');
    });
  });

  group('onboarding body fields', () {
    Future<void> pumpBody(WidgetTester tester) async {
      final age = TextEditingController();
      final height = TextEditingController();
      final weight = TextEditingController();
      final target = TextEditingController();
      addTearDown(() {
        age.dispose();
        height.dispose();
        weight.dispose();
        target.dispose();
      });
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: BodyInputs(
              age: age,
              height: height,
              currentWeight: weight,
              targetWeight: target,
              nutritionGoal: NutritionGoal.maintain,
              error: null,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Age and Height stack at 200%, each with the full width',
        (tester) async {
      _phone(tester, width: 320, text: 2);
      await pumpBody(tester);

      final age = tester.getRect(find.byType(AppTextField).at(0));
      final height = tester.getRect(find.byType(AppTextField).at(1));
      expect(height.top, greaterThanOrEqualTo(age.bottom));
      expect(height.width, age.width);
      expect(height.width, greaterThan(270));
      expectNoFlutterException(tester);
    });

    testWidgets('Age and Height share a row at normal text', (tester) async {
      _phone(tester, width: 390);
      await pumpBody(tester);

      final age = tester.getRect(find.byType(AppTextField).at(0));
      final height = tester.getRect(find.byType(AppTextField).at(1));
      expect(height.top, closeTo(age.top, 1));
      expect(height.left, greaterThan(age.right));
    });
  });
}

import 'package:fighter_edge/features/edge_fuel/domain/validation/banned_advice_validator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/validation/copy_lint.dart';
import 'package:flutter_test/flutter_test.dart';

typedef T = ToneCategory;

void expectTone(String text, T category) {
  expect(CopyLint.categories(text), contains(category), reason: text);
  expect(CopyLint.isClean(text), isFalse, reason: text);
}

void main() {
  test('food morality labels', () {
    for (final text in [
      'Bad carbs slow you down.',
      'Pick good foods today.',
      'Clean eating wins fights.',
      'A junk snack.',
      'Guilt-free dessert.',
      'Gutes Essen, schlechte Lebensmittel.',
      'Keine Sünde.',
    ]) {
      expectTone(text, T.foodMorality);
    }
  });

  test('cheat and earn words', () {
    expectTone('Cheat meal Saturday.', T.cheat);
    expectTone('CHEAT-DAY', T.cheat);
    expectTone('Schummeltag.', T.cheat);
    expectTone('You earned this dinner.', T.earn);
    expectTone('You deserve a treat.', T.earn);
    expectTone('Burn it off tomorrow.', T.earn);
    expectTone('Das hast du dir verdient.', T.earn);
  });

  test('"over" warnings', () {
    for (final text in [
      "You're over your target.",
      'You went over.',
      '200 kcal over budget.',
      'Over by 200 kcal.',
      'You exceeded your goal.',
      '300 kcal above target.',
      'You ate too much.',
      '200 kcal über dem Ziel.',
      'Ziel überschritten.',
    ]) {
      expectTone(text, T.overWarning);
    }
  });

  test('streaks', () {
    expectTone('Keep your logging streak alive!', T.streak);
    expectTone('Serie gerissen.', T.streak);
  });

  test('neutral copy is clean', () {
    for (final text in [
      "Today's target met, plus 120 kcal",
      'A missed day is a missed day.',
      'Your weight is above your path.',
      'Have a good day.',
      'Log a meal.',
      'Learn the jab.',
      'Go over your notes with your coach.',
      'Tagesziel erreicht, plus 120 kcal',
      'Moreover, protein helps.',
    ]) {
      expect(CopyLint.scan(text), isEmpty, reason: text);
    }
  });

  test('lint reports both rule 3 and rule 6', () {
    final report = CopyLint.lint('Cheat day, then a sauna.');
    expect(report.isClean, isFalse);
    expect(report.tone.map((v) => v.category), [T.cheat]);
    expect(report.bannedAdvice.map((m) => m.category),
        [BannedAdviceCategory.heatSweating]);
    expect(report.toString(), allOf(contains('cheat'), contains('sauna')));
    expect(CopyLint.lint('Eat to your target.').isClean, isTrue);
  });

  test('violations compare by value', () {
    expect(const ToneViolation(T.cheat, 'cheat'),
        const ToneViolation(T.cheat, 'cheat'));
    expect(const ToneViolation(T.cheat, 'cheat').hashCode,
        const ToneViolation(T.cheat, 'cheat').hashCode);
    expect(const ToneViolation(T.cheat, 'cheat').toString(),
        'ToneViolation(cheat: "cheat")');
  });
}

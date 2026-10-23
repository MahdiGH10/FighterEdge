import 'package:fighter_edge/features/edge_fuel/domain/validation/banned_advice_validator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/validation/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

typedef C = BannedAdviceCategory;

void expectBanned(String text, C category) {
  expect(BannedAdviceValidator.categories(text), contains(category),
      reason: text);
  expect(BannedAdviceValidator.isClean(text), isFalse, reason: text);
}

void expectClean(String text) {
  expect(BannedAdviceValidator.scan(text), isEmpty, reason: text);
  expect(BannedAdviceValidator.isClean(text), isTrue, reason: text);
}

void main() {
  group('normalizeForScan', () {
    test('folds case, accents, spacing and punctuation', () {
      expect(normalizeForScan('  Sweat-Suit!! '), ' sweat suit ');
      expect(normalizeForScan('SAÚNA'), ' sauna ');
      expect(normalizeForScan('Flüssigkeit'), ' flussigkeit ');
      expect(normalizeForScan('heiße'), ' heisse ');
      expect(normalizeForScan("don't"), ' dont ');
      expect(normalizeForScan('don’t'), ' dont ');
    });

    test('drops invisible characters and folds look-alikes', () {
      expect(normalizeForScan('sa​una'), ' sauna ');
      expect(normalizeForScan('sau­na'), ' sauna ');
      // Cyrillic a and Greek o.
      expect(normalizeForScan('sаuna'), ' sauna ');
      expect(normalizeForScan('flοw'), ' flow ');
      // Full-width letters.
      expect(normalizeForScan('Ｓａｕｎａ'), ' sauna ');
    });

    test('joins three or more spaced single letters', () {
      expect(normalizeForScan('s.a.u.n.a time'), ' sauna time ');
      expect(normalizeForScan('f a s t i n g'), ' fasting ');
      expect(normalizeForScan('a b'), ' a b ');
    });

    test('decodes leet only inside words', () {
      expect(normalizeForScan('s4una', deleet: true), ' sauna ');
      expect(normalizeForScan('f@sting', deleet: true), ' fasting ');
      expect(normalizeForScan('5 days, 2300 mg', deleet: true),
          ' 5 days 2300 mg ');
      expect(normalizeForScan('s4una'), ' s4una ');
    });

    test('squash keeps letters only', () {
      expect(squashForScan('sau na'), 'sauna');
      expect(squashForScan('s4un4'), 'sun');
      expect(squashForScan('s4un4', deleet: true), 'sauna');
      expect(squashForScan('SWEAT_suit'), 'sweatsuit');
    });
  });

  group('rule 3 categories', () {
    test('fluid restriction', () {
      for (final text in [
        'Cut your water the day before.',
        'Restrict fluids for 24 hours.',
        "Don't drink any water after dinner.",
        'No fluids until the scale.',
        'A water cut gets the last kilo.',
        'Do a dry fast.',
        'Dehydrate yourself before the weigh-in.',
        'Drop the water weight on Friday.',
        'Spit into a bottle to make weight.',
        'Trink weniger Wasser.',
        'Flüssigkeit reduzieren ab Mittwoch.',
        'Mach einen Wasser-Cut.',
      ]) {
        expectBanned(text, C.fluidRestriction);
      }
    });

    test('sodium manipulation', () {
      for (final text in [
        'Cut out salt for three days.',
        'Lower your sodium this week.',
        'Start a sodium load on Monday.',
        'Salt loading, then none.',
        'Keep sodium under 500 mg.',
        'Take 2000 mg of sodium.',
        'Salz weglassen.',
      ]) {
        expectBanned(text, C.sodiumManipulation);
      }
    });

    test('water loading', () {
      for (final text in [
        'Water loading starts D-5.',
        'Load up on water early in the week.',
        'Drink two gallons a day.',
        'Drink 8 litres of water a day.',
        'Switch to distilled water.',
        'Hyperhydrate first.',
        'Wasser laden am Montag.',
      ]) {
        expectBanned(text, C.waterLoading);
      }
    });

    test('heat and sweating', () {
      for (final text in [
        'Sit in the sauna.',
        'Use a steam room.',
        'Take a hot bath with Epsom salt.',
        'Run in a sweat suit.',
        'Wear a plastic suit.',
        'Sweat it off on the bike.',
        'Zieh den Schwitzanzug an.',
        'Ein heißes Bad hilft.',
      ]) {
        expectBanned(text, C.heatSweating);
      }
    });

    test('diuretics', () {
      for (final text in [
        'A diuretic helps.',
        'Take water pills.',
        'Lasix the night before.',
        'Dandelion root tea.',
        'Entwässerungstabletten.',
      ]) {
        expectBanned(text, C.diuretic);
      }
    });

    test('laxatives and purging', () {
      for (final text in [
        'Use a laxative.',
        'An enema clears the gut.',
        'Purge after dinner.',
        'Induce vomiting.',
        'Abführmittel nehmen.',
      ]) {
        expectBanned(text, C.laxativeOrPurging);
      }
    });

    test('fasting', () {
      for (final text in [
        'Fasting for a day drops weight.',
        'Train fasted.',
        'Fast for 24 hours.',
        'Do a water fast.',
        'Skip breakfast.',
        'Skipping meals is fine.',
        "Don't eat anything until the weigh-in.",
        'Eat nothing on Friday.',
        'Stop eating after lunch.',
        'Starve yourself.',
        'A crash diet works.',
        'Nichts essen bis zum Wiegen.',
        'Mahlzeiten auslassen.',
      ]) {
        expectBanned(text, C.fasting);
      }
    });
  });

  group('obfuscation', () {
    test('case, spacing, punctuation, leet and look-alikes', () {
      for (final text in [
        'SAUNA',
        'S a u n a',
        's.a.u.n.a',
        's-a-u-n-a',
        'sau na',
        's4una',
        's@una',
        'Sa​una',
        'sаuna',
        'sweat_suit',
        'SweatSuit',
      ]) {
        expectBanned(text, C.heatSweating);
      }
      expectBanned('d1uretic', C.diuretic);
      expectBanned('l a x a t i v e', C.laxativeOrPurging);
      expectBanned('f4sting', C.fasting);
      expectBanned('F-A-S-T-I-N-G', C.fasting);
      expectBanned('water-loading', C.waterLoading);
    });
  });

  group('ordinary fighter copy stays clean', () {
    test('food, hydration and recovery advice', () {
      for (final text in [
        'Drink to thirst and keep your urine pale.',
        'Eat a carb-rich meal two hours before training.',
        'Protein at every meal helps recovery.',
        "Don't eat new foods on fight day.",
        'Small, frequent meals after the weigh-in.',
        'Breakfast ingredients: oats, milk, banana.',
        'Lower fibre for a few days if your plan says so.',
        'Log your weight each morning.',
        'Rest day: eat to your target.',
        'Iss genug Kohlenhydrate an harten Tagen.',
        'Trink nach Durst.',
        'Wiege dich jeden Morgen.',
        'Your session lasts 5 rounds of 3 minutes.',
      ]) {
        expectClean(text);
      }
    });
  });

  test('negation is not read: policy copy that names a method is flagged', () {
    expectBanned('Never use a sauna.', C.heatSweating);
  });

  test('scan reports each pattern once and the matched folded text', () {
    final matches = BannedAdviceValidator.scan('Sauna, then a sauna again.');
    expect(matches, [const BannedAdviceMatch(C.heatSweating, 'sauna')]);
    expect(matches.single.toString(), contains('heatSweating'));
    expect(matches.single, const BannedAdviceMatch(C.heatSweating, 'sauna'));
    expect(matches.single.hashCode,
        const BannedAdviceMatch(C.heatSweating, 'sauna').hashCode);
  });

  test('several categories in one text', () {
    expect(
      BannedAdviceValidator.categories(
          'Sauna, a diuretic and a laxative, then fast for a day.'),
      {C.heatSweating, C.diuretic, C.laxativeOrPurging, C.fasting},
    );
  });

  test('the denylist is marked as pending dietitian sign-off', () {
    expect(BannedAdviceValidator.dietitianSignOffPending, isTrue);
  });
}

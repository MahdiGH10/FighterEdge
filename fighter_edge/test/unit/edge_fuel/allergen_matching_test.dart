import 'package:fighter_edge/features/edge_fuel/domain/allergen_matching.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AllergenMatcher', () {
    test('matches the obvious terms', () {
      final match = AllergenMatcher.match(['peanuts', 'gluten', 'shellfish']);
      expect(match.matched, {
        Allergen.peanuts,
        Allergen.gluten,
        Allergen.shellfish,
      });
      expect(match.unmatched, isEmpty);
    });

    test('matches common synonyms a user would actually type', () {
      expect(AllergenMatcher.match(['dairy']).matched, {Allergen.milk});
      expect(AllergenMatcher.match(['lactose']).matched, {Allergen.milk});
      expect(AllergenMatcher.match(['wheat']).matched, {Allergen.gluten});
      expect(AllergenMatcher.match(['coeliac']).matched, {Allergen.gluten});
      expect(AllergenMatcher.match(['prawns']).matched, {Allergen.shellfish});
      expect(AllergenMatcher.match(['tahini']).matched, {Allergen.sesame});
      expect(AllergenMatcher.match(['almonds']).matched, {Allergen.treeNuts});
    });

    test('is case- and punctuation-insensitive', () {
      final match = AllergenMatcher.match(['  PEANUTS!  ', 'Tree-Nuts']);
      expect(match.matched, {Allergen.peanuts, Allergen.treeNuts});
      expect(match.unmatched, isEmpty);
    });

    test('resolves a term buried in a phrase', () {
      expect(AllergenMatcher.match(['no peanuts please']).matched, {
        Allergen.peanuts,
      });
    });

    test('does NOT match on substrings — "nutmeg" is not a tree nut', () {
      // The dangerous failure would be the opposite: matching too eagerly and
      // hiding food the user can safely eat, teaching them to disable the
      // filter. Whole-word matching is the reason this passes.
      final match = AllergenMatcher.match(['nutmeg']);
      expect(match.matched, isEmpty);
      expect(match.unmatched, ['nutmeg']);
    });

    test('reports what it could not understand instead of dropping it', () {
      // This is the safety-critical behaviour. A user who types "kiwi" must be
      // told the app is not filtering on it, not left assuming it is.
      final match = AllergenMatcher.match(['peanuts', 'kiwi', 'coriander']);
      expect(match.matched, {Allergen.peanuts});
      expect(match.unmatched, ['kiwi', 'coriander']);
      expect(match.hasUnmatched, isTrue);
    });

    test('ignores blank entries', () {
      final match = AllergenMatcher.match(['', '   ', ',']);
      expect(match.matched, isEmpty);
      expect(match.unmatched, isEmpty);
    });

    test('every tracked allergen has at least one synonym that resolves', () {
      // Guards against adding an Allergen value and forgetting to teach the
      // matcher about it, which would silently make it unfilterable.
      for (final allergen in Allergen.values) {
        final byName = AllergenMatcher.match([allergen.name]).matched;
        final byLabel = AllergenMatcher.match([_plainName(allergen)]).matched;
        expect(
          byName.isNotEmpty || byLabel.isNotEmpty,
          isTrue,
          reason: 'no synonym resolves to ${allergen.name}',
        );
      }
    });
  });
}

String _plainName(Allergen allergen) => switch (allergen) {
      Allergen.milk => 'milk',
      Allergen.eggs => 'eggs',
      Allergen.fish => 'fish',
      Allergen.shellfish => 'shellfish',
      Allergen.treeNuts => 'tree nuts',
      Allergen.peanuts => 'peanuts',
      Allergen.gluten => 'gluten',
      Allergen.soy => 'soy',
      Allergen.sesame => 'sesame',
      Allergen.mustard => 'mustard',
      Allergen.celery => 'celery',
      Allergen.sulphites => 'sulphites',
    };

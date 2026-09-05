import 'models/food_enums.dart';

/// The result of interpreting a user's free-text allergen list.
///
/// [unmatched] is the important half. The setup wizard collects allergens as
/// free text, so a user can type anything — "kiwi", "coriander", "MSG". The app
/// tracks twelve regulated allergens and cannot filter on the rest. Silently
/// discarding what it could not understand would let someone believe they are
/// protected when they are not, so the unmatched terms are surfaced in the UI.
class AllergenMatch {
  final Set<Allergen> matched;
  final List<String> unmatched;

  const AllergenMatch({this.matched = const {}, this.unmatched = const []});

  bool get hasUnmatched => unmatched.isNotEmpty;
}

/// Maps free-text allergen entries onto the tracked [Allergen] set.
///
/// Deliberately conservative: a term only matches when it is a recognised
/// synonym. Guessing — treating "nutmeg" as a tree nut because it contains
/// "nut" — would be worse than admitting the app does not understand it, which
/// is why matching is on whole words rather than substrings.
class AllergenMatcher {
  AllergenMatcher._();

  static const Map<Allergen, List<String>> _synonyms = {
    Allergen.milk: [
      'milk',
      'dairy',
      'lactose',
      'cheese',
      'yogurt',
      'yoghurt',
      'butter',
      'cream',
      'whey',
      'casein',
    ],
    Allergen.eggs: ['egg', 'eggs', 'albumen', 'ovalbumin'],
    Allergen.fish: [
      'fish',
      'salmon',
      'tuna',
      'cod',
      'sardine',
      'sardines',
      'anchovy',
      'anchovies',
    ],
    Allergen.shellfish: [
      'shellfish',
      'crustacean',
      'crustaceans',
      'shrimp',
      'prawn',
      'prawns',
      'crab',
      'lobster',
      'mollusc',
      'mussel',
      'mussels',
      'clam',
      'clams',
      'oyster',
      'oysters',
      'squid',
      'octopus',
    ],
    Allergen.treeNuts: [
      'nut',
      'nuts',
      'tree nut',
      'tree nuts',
      'treenut',
      'treenuts',
      'almond',
      'almonds',
      'walnut',
      'walnuts',
      'cashew',
      'cashews',
      'pistachio',
      'pistachios',
      'hazelnut',
      'hazelnuts',
      'pecan',
      'pecans',
      'macadamia',
      'brazil nut',
    ],
    Allergen.peanuts: ['peanut', 'peanuts', 'groundnut', 'groundnuts'],
    Allergen.gluten: [
      'gluten',
      'wheat',
      'barley',
      'rye',
      'spelt',
      'coeliac',
      'celiac',
      'semolina',
      'couscous',
    ],
    Allergen.soy: ['soy', 'soya', 'soybean', 'soybeans', 'edamame', 'tofu'],
    Allergen.sesame: ['sesame', 'tahini', 'sesame seed', 'sesame seeds'],
    Allergen.mustard: ['mustard'],
    Allergen.celery: ['celery', 'celeriac'],
    Allergen.sulphites: ['sulphite', 'sulphites', 'sulfite', 'sulfites'],
  };

  /// Interprets a list of free-text entries (already split on commas by the
  /// wizard).
  static AllergenMatch match(Iterable<String> entries) {
    final matched = <Allergen>{};
    final unmatched = <String>[];

    for (final raw in entries) {
      final term = _normalise(raw);
      if (term.isEmpty) continue;

      final hit = _lookup(term);
      if (hit == null) {
        unmatched.add(raw.trim());
      } else {
        matched.add(hit);
      }
    }

    return AllergenMatch(matched: matched, unmatched: unmatched);
  }

  static Allergen? _lookup(String term) {
    for (final entry in _synonyms.entries) {
      for (final synonym in entry.value) {
        if (term == synonym) return entry.key;
      }
    }
    // Allow a multi-word entry like "no tree nuts please" to still resolve, by
    // checking whole words rather than substrings. "nutmeg" must not match
    // "nut", so this compares tokens, never fragments.
    final words = term.split(' ').where((w) => w.isNotEmpty).toSet();
    for (final entry in _synonyms.entries) {
      for (final synonym in entry.value) {
        if (!synonym.contains(' ') && words.contains(synonym)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  static String _normalise(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

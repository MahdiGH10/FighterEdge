import 'text_normalizer.dart';

/// Rule 3 of the Fuel V2 spec: the app never gives advice on fluid or sodium
/// restriction, water loading, sauna, sweat suits, diuretics, laxatives or
/// fasting. No flag, tier or subscription unlocks it.
///
/// This is the denylist. It runs on any text: UI strings (the copy lint runs
/// it over both ARB files), notifications, recipe notes, and anything an AI
/// model returns. It is deliberately strict: it does not try to read
/// negation, so "never use a sauna" is flagged too. Copy that explains the
/// policy should say it without naming the method ("Fighter Edge plans food
/// only"); where naming it is the point, the ARB test keeps a short,
/// reasoned allowlist. A false positive costs a rewrite; a false negative
/// puts a banned instruction on a fighter's screen.
///
/// Pure Dart: no clock, no platform, no network.
// dietitian sign-off pending: the terms and patterns are a safety screen
// written from the ISSN 2025 position stand (points 9-12) and the ACSM 2021
// consensus (Table 6), not yet reviewed by a sports dietitian.
enum BannedAdviceCategory {
  /// Cutting or limiting water or other fluids, spitting, or dehydrating on
  /// purpose.
  fluidRestriction,

  /// Cutting, loading or counting sodium or salt for weight.
  sodiumManipulation,

  /// Water loading and distilled-water tricks.
  waterLoading,

  /// Sauna, steam room, hot bath, sweat suit, plastic or rubber suit.
  heatSweating,

  /// Diuretics, water pills and masking agents.
  diuretic,

  /// Laxatives, enemas and induced vomiting.
  laxativeOrPurging,

  /// Fasting, skipped meals and not eating.
  fasting,
}

/// One banned phrase found in a text. [matched] is the folded text that
/// matched, for a developer reading a failed test; never log it, because the
/// scanned text can be user or model content.
class BannedAdviceMatch {
  const BannedAdviceMatch(this.category, this.matched);

  final BannedAdviceCategory category;
  final String matched;

  @override
  bool operator ==(Object other) =>
      other is BannedAdviceMatch &&
      other.category == category &&
      other.matched == matched;

  @override
  int get hashCode => Object.hash(category, matched);

  @override
  String toString() => 'BannedAdviceMatch(${category.name}: "$matched")';
}

RegExp _re(String pattern) => RegExp(pattern);

/// A number with a sodium unit: "2300 mg", "50 mmol".
const String _numberUnit = r'\d+(?:\s+\d+)*\s*(?:mg|g|grams?|mmol|meq)\b';

/// Words that put a limit on something: "cut", "limit", "no", "less".
const String _limitVerbs = r'(?:restrict(?:ing|ed)?|limit(?:ing|ed)?|'
    r'cut(?:ting)?|reduc(?:e|ing|ed)|minimi[sz](?:e|ing)|lower(?:ing)?|'
    r'ration(?:ing)?|withhold(?:ing)?|deny(?:ing)?|eliminat(?:e|ing)|'
    r'stop(?:ping)?|avoid(?:ing)?|drop(?:ping)?|less|no|zero|without|'
    r'skip(?:ping)?|low|lowest)';

/// Up to three small words between the verb and the noun: "cut back on
/// your water".
const String _fillers = r'(?:(?:your|the|all|any|of|on|down|back|in|out|'
    r'dietary|added|table|extra)\s+){0,3}';

final Map<BannedAdviceCategory, List<RegExp>> _patterns = {
  BannedAdviceCategory.fluidRestriction: [
    _re(r'\b' +
        _limitVerbs +
        r'\s+' +
        _fillers +
        r'(?:water|fluids?|liquids?|drinking|hydration)\b'),
    _re(r'\b(?:dont|do not|never|stop|cant|cannot|no)\s+'
        r'(?:drink|drinking|sip|sipping|have|having)\s+'
        r'(?:(?:any|much|more|too much|your|the|a lot of)\s+)*'
        r'(?:water|fluids?|liquids?)\b'),
    _re(r'\b(?:nothing to drink|no drinks|no drinking|no fluids?)\b'),
    _re(r'\b(?:water|fluids?|liquids?|hydration)\s+'
        r'(?:restriction|restricted|restricting|cut|cuts|cutting|deprivation|'
        r'manipulation|depletion|fast|fasting|diet)\b'),
    _re(r'\bdry\s+(?:fast|day|out|cut)\b'),
    _re(r'\bdehydrat(?:e|ed|ing|ion)\s+(?:yourself|your body|before|to make|'
        r'to cut|for weight|for the weigh)'),
    _re(r'\b(?:to|and|will|should|try to|by|deliberately|purposely|'
        r'intentionally|then|you can)\s+dehydrate\b'),
    _re(r'\bthirst\s+(?:cut|training|method)\b'),
    _re(r'\b(?:cut|drop|lose|losing|shed|dump|drain|flush|sweat|sweating)\s+'
        r'(?:off\s+|out\s+)?(?:the\s+|your\s+|that\s+|some\s+|extra\s+)?'
        r'water\s+weight\b'),
    _re(r'\bwater\s+weight\s+(?:cut|loss|manipulation)\b'),
    // Spitting to shed the last grams of fluid.
    _re(r'\bspit(?:ting)?\s+(?:to|into|in|out|off|for|your|it|weight)\b'),
    // German.
    _re(r'\b(?:weniger|nicht|kein(?:e|en)?|ohne)\s+(?:mehr\s+)?'
        r'(?:wasser|flussigkeit|trinken)\b'),
    _re(r'\b(?:wasser|flussigkeit)s?\s*(?:entzug|restriktion|reduktion|'
        r'reduzieren|begrenzen)'),
    _re(r'\b(?:trinken|flussigkeit|wasser)\s+(?:reduzieren|begrenzen|'
        r'einschranken|weglassen)'),
    _re(r'\bwasser\s*cut\b'),
    _re(r'\bausspucken\b'),
  ],
  BannedAdviceCategory.sodiumManipulation: [
    _re(r'\b' +
        _limitVerbs +
        r'\s+' +
        _fillers +
        r'(?:sodium|salt|salty|natrium|salz)\b'),
    _re(r'\b(?:sodium|salt|natrium|salz)\s+'
        r'(?:restriction|restricted|restricting|cut|cuts|cutting|depletion|'
        r'manipulation|loading|load|loaded|protocol|free|deprivation|'
        r'reduzieren|reduktion|weglassen)\b'),
    _re(r'\b(?:load|loading|loaded|boost|boosting|extra|megadose|'
        r'pile on|binge on)\s+(?:up\s+)?(?:on\s+|with\s+)?(?:sodium|salt)\b'),
    _re(r'\b(?:sodium|salt|natrium)\s+(?:\w+\s+){0,2}' + _numberUnit),
    _re(r'\b' + _numberUnit + r'\s+(?:of\s+)?(?:sodium|salt|natrium)\b'),
  ],
  BannedAdviceCategory.waterLoading: [
    _re(r'\bwater\s*load(?:ing|ed|s)?\b'),
    _re(r'\b(?:load|loading|loaded)\s+(?:up\s+)?(?:on\s+|with\s+)?'
        r'(?:water|fluids?)\b'),
    _re(r'\bhyper\s*hydrat'),
    _re(r'\bgallons?\b'),
    _re(r'\b(?:\d+(?:\s+\d+)?|several|many)\s+(?:l|liters?|litres?)\s+of\s+'
        r'water\s+(?:a|per|each|every)\s+day\b'),
    _re(r'\bdistill?ed\s+water\b'),
    _re(r'\bwasser\s*(?:laden|beladung|aufladen)'),
    _re(r'\bdestilliert\w*\s+wasser\b'),
  ],
  BannedAdviceCategory.heatSweating: [
    _re(r'\bsaunas?\b'),
    _re(r'\bsteam\s*(?:room|bath|rooms|baths)\b'),
    _re(r'\bhot\s+(?:bath|baths|tub|room|box|yoga|bikram)\b'),
    _re(r'\bhot\s*box\b'),
    _re(r'\bsweat\s*(?:suit|suits|box|gear|jacket)\b'),
    _re(r'\b(?:rubber|plastic|neoprene|heated|trash\s*bag|bin\s*bag|'
        r'garbage\s*bag)\s*(?:suit|suits|wrap|wraps|bag|bags|jacket)\b'),
    _re(r'\b(?:sweat|sweating)\s+(?:it\s+|them\s+)?(?:off|out)\b'),
    _re(r'\bsweat\s+(?:to\s+)?(?:cut|lose|drop|make weight)\b'),
    _re(r'\b(?:passive|forced)\s+(?:heat|sweat|sweating)\b'),
    _re(r'\bepsom\b'),
    _re(r'\b(?:schwitzanzug|dampfbad|heisses?\s+bad|heisse\s+wanne)\b'),
  ],
  BannedAdviceCategory.diuretic: [
    _re(r'\bdiuretics?\b'),
    _re(r'\b(?:water|fluid|dehydration)\s+(?:pills?|tablets?)\b'),
    _re(r'\b(?:lasix|furosemide|frusemide|hydrochlorothiazide|hctz|'
        r'spironolactone|torsemide|bumetanide|acetazolamide|diamox|'
        r'triamterene|amiloride|masking agents?)\b'),
    _re(r'\bdandelion\s+(?:root|tea|extract|pills?)\b'),
    _re(r'\bflush(?:ing)?\s+(?:out\s+)?(?:water|fluids?)\b'),
    _re(r'\b(?:entwasser\w*|diuretik\w*|wassertablette\w*|harntreib\w*)\b'),
  ],
  BannedAdviceCategory.laxativeOrPurging: [
    _re(r'\blaxatives?\b'),
    _re(r'\benemas?\b'),
    _re(r'\bcolon\s+(?:cleans\w*|flush\w*|prep)\b'),
    _re(r'\bbowel\s+prep\b'),
    _re(r'\bpurg(?:e|ed|es|ing)\b'),
    _re(r'\b(?:make\s+yourself\s+(?:sick|throw\s+up)|induce\s+vomiting|'
        r'induced\s+vomiting|self\s+induced|throw\s+up\s+on\s+purpose|puke)\b'),
    _re(r'\b(?:senna|bisacodyl|dulcolax|ex\s+lax)\b'),
    _re(r'\b(?:abfuhr\w*|einlauf|einlaufe|erbrechen\s+ausl\w*|kotzen)\b'),
  ],
  BannedAdviceCategory.fasting: [
    _re(r'\bfasting\b'),
    _re(r'\bfasted\b'),
    _re(r'\bfasts?\s+(?:for|until|till|from|on|all|the\s+(?:day|week)|\d)'),
    _re(r'\b(?:water|dry|juice|intermittent|extended|prolonged)\s+fast\b'),
    _re(r'\bskip(?:ping|ped)?\s+(?:a\s+|your\s+|the\s+|all\s+|most\s+|some\s+)?'
        r'(?:meals?|breakfast|lunch|dinner|eating)\b'),
    _re(r'\bstarv(?:e|ed|ing|ation)\b'),
    _re(r'\b(?:eat|eating)\s+(?:nothing|very little|almost nothing)\b'),
    _re(r'\b(?:stop|stopped|quit)\s+eating\b'),
    // "Don't eat anything until the weigh-in", not "don't eat new foods".
    _re(r'\b(?:dont|do not|never|cant|cannot)\s+eat\s+(?:anything|at all|'
        r'for\s+\d|until|till|after|before|all day|today|tomorrow)\b'),
    _re(r'\bno\s+food\s+(?:for|until|till|after|today|all)\b'),
    _re(r'\bnothing\s+to\s+eat\b'),
    _re(r'\bcrash\s+diet\b'),
    _re(r'\bvery\s+low\s+calorie\b'),
    _re(r'\bvlcd\b'),
    _re(r'\b(?:fasten|hungern|nichts\s+(?:mehr\s+)?essen|'
        r'mahlzeit(?:en)?\s+auslassen|essen\s+auslassen)\b'),
  ],
};

/// Tokens that stay unambiguous with the spaces taken out, so "sau na" and
/// "s4un4" cannot slip past the word patterns.
const Map<BannedAdviceCategory, List<String>> _squashed = {
  BannedAdviceCategory.heatSweating: ['sauna', 'sweatsuit'],
  BannedAdviceCategory.diuretic: ['diuretic'],
  BannedAdviceCategory.laxativeOrPurging: ['laxative'],
  BannedAdviceCategory.waterLoading: ['waterloading', 'hyperhydrat'],
};

class BannedAdviceValidator {
  const BannedAdviceValidator._();

  // dietitian sign-off pending: see [BannedAdviceCategory].
  static const bool dietitianSignOffPending = true;

  /// Every banned phrase in [text], at most one per pattern. Empty when the
  /// text is clean.
  static List<BannedAdviceMatch> scan(String text) {
    final matches = <BannedAdviceMatch>[];
    final forms = {
      normalizeForScan(text),
      normalizeForScan(text, deleet: true),
    };
    for (final entry in _patterns.entries) {
      for (final pattern in entry.value) {
        for (final form in forms) {
          final match = pattern.firstMatch(form);
          if (match != null) {
            matches.add(BannedAdviceMatch(entry.key, match[0]!.trim()));
            break;
          }
        }
      }
    }
    final seen = {for (final m in matches) m.category};
    final squashed = {
      squashForScan(text),
      squashForScan(text, deleet: true),
    };
    for (final entry in _squashed.entries) {
      if (seen.contains(entry.key)) continue;
      final token = entry.value
          .where((t) => squashed.any((form) => form.contains(t)))
          .firstOrNull;
      if (token != null) matches.add(BannedAdviceMatch(entry.key, token));
    }
    return matches;
  }

  /// The categories [text] falls into.
  static Set<BannedAdviceCategory> categories(String text) =>
      {for (final m in scan(text)) m.category};

  /// True when [text] contains no banned advice. Use it as the gate for any
  /// generated text: a false result means the text is dropped and replaced
  /// with the "talk to a professional" card, never edited and shown.
  static bool isClean(String text) => scan(text).isEmpty;
}

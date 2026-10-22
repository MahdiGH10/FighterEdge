import 'banned_advice_validator.dart';
import 'text_normalizer.dart';

/// Rule 6 of the Fuel V2 spec: tone is neutral. No red numbers, no "over"
/// warnings, no good/bad food labels, no food-logging streaks, no cheat or
/// earn words. A missed day is a missed day, nothing more.
///
/// [CopyLint.scan] is the text half of that rule: a pure function over any
/// string. [CopyLint.lint] adds rule 3 ([BannedAdviceValidator]) so one call
/// checks a string against both. A unit test runs [CopyLint.lint] over every
/// string in the EN and DE ARB files, so a banned word fails the build
/// instead of reaching a screen. The colour half of the rule belongs to the
/// design tokens.
///
/// Pure Dart: no clock, no platform, no network.
enum ToneCategory {
  /// "Good food", "bad carbs", "clean eating", "junk", "guilt-free".
  foodMorality,

  /// "Cheat meal", "cheat day".
  cheat,

  /// "Earn your dinner", "burn it off", "you deserve".
  earn,

  /// "Over your target", "you went over", "exceeded", "above target".
  overWarning,

  /// Streaks. Rule 6 bans them for food logging; the lint flags every one so
  /// a training streak has to be allowed on purpose.
  streak,
}

class ToneViolation {
  const ToneViolation(this.category, this.matched);

  final ToneCategory category;

  /// The folded text that matched, for a developer reading a failed test.
  final String matched;

  @override
  bool operator ==(Object other) =>
      other is ToneViolation &&
      other.category == category &&
      other.matched == matched;

  @override
  int get hashCode => Object.hash(category, matched);

  @override
  String toString() => 'ToneViolation(${category.name}: "$matched")';
}

/// Both rules' findings for one string.
class CopyLintReport {
  const CopyLintReport({required this.tone, required this.bannedAdvice});

  /// Rule 6.
  final List<ToneViolation> tone;

  /// Rule 3.
  final List<BannedAdviceMatch> bannedAdvice;

  bool get isClean => tone.isEmpty && bannedAdvice.isEmpty;

  @override
  String toString() => [...tone, ...bannedAdvice].join(', ');
}

RegExp _re(String pattern) => RegExp(pattern);

/// Nouns a target or limit can be about.
const String _targetNouns = r'(?:limit|target|targets|goal|goals|budget|'
    r'calorie|calories|kcal|protein|carb|carbs|fat|macro|macros|allowance|'
    r'plan)\b';

final Map<ToneCategory, List<RegExp>> _tonePatterns = {
  ToneCategory.foodMorality: [
    _re(r'\b(?:good|bad|clean|dirty|junk|naughty|sinful|unhealthy|guilty|'
        r'guilt free|forbidden|banned|off limits)\s+'
        r'(?:food|foods|meal|meals|carb|carbs|fat|fats|eating|choice|choices|'
        r'snack|snacks|calories|ingredient|ingredients|diet)\b'),
    _re(r'\bjunk\b'),
    _re(r'\bguilt\s*free\b'),
    _re(r'\bguilty\s+pleasure\b'),
    _re(r'\b(?:sinful|naughty)\b'),
    _re(r'\b(?:clean eating|eat clean|eating clean)\b'),
    _re(r'\b(?:gute[snm]?|schlechte[snm]?|saubere[snm]?|ungesunde[snm]?)\s+'
        r'(?:essen|lebensmittel|kohlenhydrate|fett|mahlzeit\w*)\b'),
    _re(r'\b(?:sunde|sundig|schuldgefuhl\w*)\b'),
  ],
  ToneCategory.cheat: [
    _re(r'\bcheat\w*\b'),
    _re(r'\bschummel\w*\b'),
  ],
  ToneCategory.earn: [
    _re(r'\bearn(?:s|ed|ing)?\b'),
    _re(r'\bdeserv\w*\b'),
    _re(r'\b(?:burn|work)\s+(?:(?:it|that|this|them)\s+)?off\b'),
    _re(r'\bverdien\w*\b'),
    _re(r'\babtrainier\w*\b'),
  ],
  ToneCategory.overWarning: [
    _re(r'\bover\s+(?:your\s+|the\s+|my\s+|our\s+|a\s+|todays\s+)?' +
        _targetNouns),
    _re(r'\babove\s+(?:your\s+|the\s+|todays\s+)?' + _targetNouns),
    // "You went over", not "go over the plan with your coach".
    _re(r'\b(?:went|go|goes|going|gone|youre|you are|im|i am)\s+over'
        r'(?=\s*$|\s+(?:by|today|again|it)\b)'),
    _re(r'\bover\s+by\s+\d'),
    _re(r'\bexceed\w*\b'),
    _re(r'\bovershot\b'),
    _re(r'\b(?:overate|overeat|overeating|overeaten)\b'),
    _re(r'\b(?:ate|eaten|eating|eat)\s+too\s+much\b'),
    _re(r'\b(?:uber|ueber)\s+(?:dem|deinem|deinen|dein|das)\s*'
        r'(?:limit|ziel|tagesziel|budget|kalorien\w*)\b'),
    _re(r'\buberschritten\b'),
    _re(r'\bzu\s+viel\s+gegessen\b'),
  ],
  ToneCategory.streak: [
    _re(r'\bstreaks?\b'),
    _re(r'\bserie\s+(?:gerissen|verloren|unterbrochen)\b'),
  ],
};

class CopyLint {
  const CopyLint._();

  /// Every banned tone word or phrase in [text] (rule 6), at most one per
  /// pattern.
  static List<ToneViolation> scan(String text) {
    final folded = normalizeForScan(text);
    final violations = <ToneViolation>[];
    for (final entry in _tonePatterns.entries) {
      for (final pattern in entry.value) {
        final match = pattern.firstMatch(folded);
        if (match != null) {
          violations.add(ToneViolation(entry.key, match[0]!.trim()));
        }
      }
    }
    return violations;
  }

  /// The tone categories [text] falls into.
  static Set<ToneCategory> categories(String text) =>
      {for (final v in scan(text)) v.category};

  /// True when [text] has no rule 6 tone words. See [lint] for rules 3 and 6
  /// together.
  static bool isClean(String text) => scan(text).isEmpty;

  /// Rule 6 tone words and rule 3 banned advice in [text].
  static CopyLintReport lint(String text) => CopyLintReport(
        tone: scan(text),
        bannedAdvice: BannedAdviceValidator.scan(text),
      );
}

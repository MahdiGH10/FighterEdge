import 'text_normalizer.dart';

/// Rule 6 of the Fuel V2 spec: tone is neutral. No red numbers, no "over"
/// warnings, no good/bad food labels, no food-logging streaks, no cheat or
/// earn words. A missed day is a missed day, nothing more.
///
/// [CopyLint.scan] is the text half of that rule: a pure function over any
/// string. A unit test runs it over every Fuel and camp string in the ARB
/// files, so a banned word fails the build instead of reaching a screen. The
/// colour half belongs to the design tokens.
enum ToneCategory {
  /// "Good food", "bad carbs", "clean eating", "junk", "guilt-free".
  foodMorality,

  /// "Cheat meal", "cheat day".
  cheat,

  /// "Earn your dinner", "burn it off", "you deserve".
  earn,

  /// "Over your target", "you went over", "exceeded".
  overWarning,

  /// Food-logging streaks.
  streak,
}

class ToneViolation {
  const ToneViolation(this.category, this.matched);

  final ToneCategory category;

  /// The folded text that matched, for a developer reading a failed test.
  final String matched;

  @override
  String toString() => 'ToneViolation(${category.name}: "$matched")';
}

RegExp _re(String pattern) => RegExp(pattern);

final Map<ToneCategory, List<RegExp>> _tonePatterns = {
  ToneCategory.foodMorality: [
    _re(r'\b(?:good|bad|clean|dirty|junk|naughty|sinful|unhealthy|guilty|'
        r'guilt free|forbidden|banned|off limits)\s+'
        r'(?:food|foods|meal|meals|carb|carbs|fat|fats|eating|choice|choices|'
        r'snack|snacks|calories|ingredient|ingredients|day|days|diet)\b'),
    _re(r'\bjunk\b'),
    _re(r'\bguilt\s*free\b'),
    _re(r'\bguilty\s+pleasure\b'),
    _re(r'\b(?:sinful|naughty)\b'),
    _re(r'\b(?:clean eating|eat clean|eating clean)\b'),
    _re(r'\b(?:gutes?|schlechtes?|saubere?s?|ungesundes?)\s+'
        r'(?:essen|lebensmittel|kohlenhydrate|fett)\b'),
    _re(r'\b(?:sunde|sundig|schuldgefuhl)\b'),
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
    _re(r'\bover\s+(?:your\s+|the\s+|my\s+|our\s+|a\s+)?'
        r'(?:limit|target|targets|goal|goals|budget|calorie|calories|kcal|'
        r'protein|carb|carbs|fat|macro|macros|allowance|plan)\b'),
    _re(r'\b(?:went|go|goes|going|gone|youre|you are|im|i am)\s+over\b'),
    _re(r'\bover\s+by\s+\d'),
    _re(r'\bover\s+budget\b'),
    _re(r'\bexceed\w*\b'),
    _re(r'\bovershot\b'),
    _re(r'\b(?:overate|overeat|overeating|overeaten)\b'),
    _re(r'\b(?:uber|ueber)\s+(?:dem|deinem|deinen|dein)\s*'
        r'(?:limit|ziel|budget|kalorien)\b'),
    _re(r'\buberschritten\b'),
  ],
  ToneCategory.streak: [
    _re(r'\bstreaks?\b'),
    _re(r'\bserie\s+(?:gerissen|verloren|unterbrochen)\b'),
  ],
};

class CopyLint {
  const CopyLint._();

  /// Every banned tone word or phrase in [text].
  static List<ToneViolation> scan(String text) {
    final folded = normalizeForScan(text);
    final violations = <ToneViolation>[];
    for (final entry in _tonePatterns.entries) {
      for (final pattern in entry.value) {
        final match = pattern.firstMatch(folded);
        if (match != null) {
          violations.add(ToneViolation(entry.key, match.group(0)!.trim()));
        }
      }
    }
    return violations;
  }

  static Set<ToneCategory> categories(String text) =>
      {for (final v in scan(text)) v.category};

  static bool isClean(String text) => scan(text).isEmpty;
}

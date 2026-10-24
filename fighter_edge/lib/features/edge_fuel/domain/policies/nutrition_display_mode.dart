/// How much of the nutrition side of the app the athlete wants to see.
///
/// Research on food-tracking apps (see `nutrition_research_20261022/
/// retention.md`) ties harm to fixation on numbers, logging reminders and
/// weight prompts, and weight-class sport is a higher-risk group. These modes
/// are the athlete's own off switch. Nothing sets one for them and nothing
/// labels them; the app only ever offers.
///
/// Pure Dart: no Flutter, no storage, no clock.
enum NutritionDisplayMode {
  /// Everything on, as the app ships.
  normal,

  /// No calories, grams, weights or progress numbers anywhere. Food can still
  /// be logged by name. (Not offered yet: it needs every number surface
  /// covered first, so it ships as its own slice.)
  hideNumbers,

  /// Nutrition steps out of the way: the Fuel tab, its numbers, weight and
  /// weight-cut tools, and every nutrition reminder are off. Training goes on.
  paused;

  /// The Fuel tab, food logging and weight tools are available.
  bool get showsNutrition => this != paused;

  /// Calories, grams, weights and progress numbers may be shown.
  bool get showsNumbers => this == normal;

  /// Nutrition reminders (fuel window, weigh-in, protein) may be sent. They
  /// are off in both quiet modes: reminders are the feature the research
  /// links to compulsive logging.
  bool get allowsNutritionReminders => this == normal;

  /// The stored name, stable across versions.
  String get storageName => name;

  /// The mode for a stored name. Anything unknown reads as [normal], the
  /// shipped behavior.
  static NutritionDisplayMode fromStorage(String? value) {
    for (final mode in values) {
      if (mode.name == value) return mode;
    }
    return normal;
  }
}

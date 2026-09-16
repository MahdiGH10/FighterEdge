import 'package:flutter/services.dart';

/// The app's haptic vocabulary.
///
/// Part of the design system rather than a utility: which feedback fires for
/// which class of event is a design decision, and routing every call through
/// these five names is what keeps it consistent. Call sites name the *event*
/// ("this was a commit"), never the waveform.
///
/// Physical feedback is the difference between a screen that responds and one
/// that merely updates — and it is free. Spend it on moments that mean
/// something; firing on every scroll tick or rebuild makes the device feel
/// broken rather than alive.
class AppHaptics {
  AppHaptics._();

  /// Moving between peer options — tab changes, filter chips, segmented
  /// controls. The lightest tick available; nothing was committed.
  static void selection() => HapticFeedback.selectionClick();

  /// Opening or activating something — a card, a list row, a nav push.
  static void tap() => HapticFeedback.lightImpact();

  /// The user committed a change: logging a weigh-in, starting a session,
  /// saving a plan. Heavier than [tap] because something actually happened.
  static void commit() => HapticFeedback.mediumImpact();

  /// A goal landed — session completed, streak extended, plan generated.
  /// Two beats, because a single thump reads as "done", not "well done".
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await HapticFeedback.mediumImpact();
  }

  /// Something was refused, destroyed, or needs attention before continuing.
  static void warning() => HapticFeedback.heavyImpact();
}

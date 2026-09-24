// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navTrain => 'Train';

  @override
  String get navFuel => 'Fuel';

  @override
  String get navProfile => 'Profile';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonToday => 'Today';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String get commonSigningOut => 'Signing out...';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsLanguageBeta =>
      'German is partly translated — the rest stays in English for now.';

  @override
  String get settingsSectionSubscription => 'Subscription';

  @override
  String get settingsManagePro => 'Manage Pro';

  @override
  String get settingsUpgradePro => 'Upgrade to Pro';

  @override
  String get settingsManageProSubtitle =>
      'Refresh status and manage billing once connected';

  @override
  String get settingsUpgradeProSubtitle =>
      'AI Fighter Brief, full drill and recipe libraries, corner cues';

  @override
  String get settingsSectionTraining => 'Training Preferences';

  @override
  String get settingsMetricUnits => 'Metric units';

  @override
  String get settingsMetricUnitsKg => 'Weights show in kg';

  @override
  String get settingsMetricUnitsLb => 'Weights show in lb';

  @override
  String get settingsTimerHaptics => 'Timer haptics';

  @override
  String get settingsTimerHapticsSubtitle =>
      'Round alerts can use vibration feedback';

  @override
  String get settingsCampReminders => 'Camp reminders';

  @override
  String get settingsCampRemindersUnavailable => 'Not available on this device';

  @override
  String settingsCampRemindersOn(String time) {
    return 'A nudge on the days you train, around $time';
  }

  @override
  String get settingsCampRemindersOff => 'Get a nudge on the days you train';

  @override
  String get settingsSectionSafety => 'Safety & Trust';

  @override
  String get settingsSafeCut => 'Safe cut guidance';

  @override
  String get settingsSafeCutSubtitle =>
      'Show hydration and non-medical weight-cut reminders';

  @override
  String get settingsTrustNote =>
      'Fighter Edge guides training and nutrition decisions. It does not replace a coach, doctor, or licensed nutrition professional.';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsChangePasswordSubtitle =>
      'Confirm your current password to set a new one';

  @override
  String get settingsChangePasswordGoogle =>
      'You sign in with Google — manage it in your Google account';

  @override
  String get settingsTerms => 'Terms of Service';

  @override
  String get settingsTermsSubtitle => 'The rules for using Fighter Edge';

  @override
  String get settingsPrivacy => 'Privacy Policy';

  @override
  String get settingsPrivacySubtitle => 'What we store and why';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountSubtitle =>
      'Permanently erase your account and all of your data';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardWeeklyOverview => 'Weekly Overview';

  @override
  String get dashboardNextSession => 'Next Session';

  @override
  String get dashboardRecentActivity => 'Recent Activity';

  @override
  String get dashboardSeeAll => 'See all';

  @override
  String get dashboardStatWeight => 'Weight';

  @override
  String get dashboardStatSessions => 'Sessions';

  @override
  String get dashboardStatStreak => 'Streak';

  @override
  String get dashboardStatCompleted => 'completed';

  @override
  String dashboardStatDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String get dashboardAddWeighIn => 'Add weigh-in';

  @override
  String get dashboardStreakAtRisk => 'At risk';

  @override
  String get dashboardStreakOnFire => 'On fire';

  @override
  String get dashboardStreakLogToday => 'Log today';

  @override
  String get fuelWeekTitle => 'FUEL THIS WEEK';

  @override
  String fuelWeekLogged(int count) {
    return '$count/7 logged';
  }

  @override
  String get fuelWeekOnTarget => 'on target';

  @override
  String get fuelWeekProteinHit => 'protein hit';

  @override
  String get fuelWeekAvgKcal => 'avg kcal';

  @override
  String get fuelWeekEmpty =>
      'Log meals this week and your fuel trend builds here, day by day against your target.';

  @override
  String fuelLeftToday(int kcal) {
    return '$kcal kcal left today';
  }

  @override
  String get fuelLeftTodaySubtitle => 'Recipes that fit, highest protein first';

  @override
  String get nutritionTitle => 'Nutrition';

  @override
  String get nutritionTabToday => 'Today';

  @override
  String get nutritionTabMeals => 'Meals';

  @override
  String get nutritionTabRecipes => 'Recipes';

  @override
  String get nutritionCalories => 'Calories';

  @override
  String get nutritionMeals => 'Meals';

  @override
  String get nutritionAddFood => 'Add food';

  @override
  String get nutritionSearchFoods => 'Search foods';

  @override
  String get nutritionLoggedToday => 'logged today';

  @override
  String get nutritionProtein => 'Protein';

  @override
  String get nutritionCarbs => 'Carbs';

  @override
  String get nutritionFats => 'Fats';

  @override
  String nutritionAddedSnack(String name, int kcal) {
    return '$name · $kcal kcal added';
  }

  @override
  String addFoodTitle(String day) {
    return 'Add to $day';
  }

  @override
  String get addFoodSaved => 'SAVED';

  @override
  String get addFoodRecent => 'RECENT';

  @override
  String get addFoodManual => 'Enter macros manually';

  @override
  String get addFoodManualSubtitle =>
      'For a meal out, a label, or anything not listed';

  @override
  String get addFoodEmptyHint =>
      'Search the food list and pick how much you had — the macros work themselves out. Foods you log show up here next time, one tap away.';

  @override
  String get addFoodNotFound => 'Not in the food list yet';

  @override
  String get addFoodNotFoundHint =>
      'Try a simpler word (\"rice\", \"chicken\"), or enter the macros yourself below.';

  @override
  String get addFoodHowMuch => 'HOW MUCH?';

  @override
  String get addFoodGrams => 'Grams';

  @override
  String addFoodAddTo(String day) {
    return 'Add to $day';
  }

  @override
  String addFoodPerHundred(int kcal, String protein) {
    return '$kcal kcal · ${protein}g protein per 100 g';
  }

  @override
  String addFoodAllergenWarning(String allergens) {
    return 'Contains $allergens — on your allergen list.';
  }

  @override
  String get trainTitle => 'Train';

  @override
  String get trainTabWeek => 'Week';

  @override
  String get trainTabHistory => 'History';

  @override
  String get trainTabDrills => 'Drills';

  @override
  String get timerTitle => 'Round Timer';

  @override
  String get timerRound => 'Round';

  @override
  String get timerWork => 'WORK';

  @override
  String get timerRest => 'REST';

  @override
  String get timerDone => 'DONE';

  @override
  String get timerStart => 'Start';

  @override
  String get timerPause => 'Pause';

  @override
  String get timerReset => 'Reset';

  @override
  String get timerRestart => 'Restart';

  @override
  String timerNext(String label) {
    return 'Next: $label';
  }

  @override
  String get timerYourCorner => 'YOUR CORNER';

  @override
  String get timerCornerTeaser =>
      'Pro puts a corner in your rest: a cue for the next round.';

  @override
  String get timerNextSessionComplete => 'Session complete';

  @override
  String get timerNextFinalRound => 'Final round';

  @override
  String get timerNextRest => 'Rest';

  @override
  String timerNextRound(int round) {
    return 'Round $round';
  }

  @override
  String get timerCallTime => 'Time';

  @override
  String get timerCallRest => 'Rest';

  @override
  String get timerCallTenSeconds => 'Ten seconds';

  @override
  String timerClockSemantics(int minutes, int seconds) {
    return '$minutes minutes $seconds seconds left';
  }

  @override
  String timerAnnounceWork(int round, int total) {
    return 'Round $round of $total. Work.';
  }

  @override
  String timerAnnounceRest(int round) {
    return 'Round $round done. Rest.';
  }

  @override
  String get timerAnnounceDone => 'Session complete.';

  @override
  String get paywallWaitlistCta => 'Notify me when Pro opens';

  @override
  String get paywallWaitlistJoined => 'You\'re on the list';

  @override
  String get paywallWaitlistThanks =>
      'Noted. Pro will appear here when it opens, with the price shown before any charge.';

  @override
  String get paywallWaitlistBody =>
      'Pro can\'t be bought on this build yet. Tap below and this device will remember you asked. The store price is always shown before any payment.';

  @override
  String get paywallRenewalDisclosure =>
      'Subscriptions renew automatically at the price and period shown above unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID or Google Play account when you confirm the purchase. You can manage or cancel your subscription at any time in your store account settings.';

  @override
  String get legalTermsLink => 'Terms of Use';

  @override
  String get legalPrivacyLink => 'Privacy Policy';

  @override
  String get legalOpenPublished => 'Open the published version';

  @override
  String get trainTabReaction => 'Reaction';

  @override
  String get reactionTitle => 'Reaction Drill';

  @override
  String get reactionHeadline => 'The coach calls it. You react.';

  @override
  String get reactionSoundHint =>
      'Sound on. Every run is shuffled — nothing to memorize.';

  @override
  String get reactionDisciplineGrappling => 'Wrestling';

  @override
  String get reactionDisciplineStriking => 'Striking';

  @override
  String get reactionDisciplineMma => 'MMA';

  @override
  String get reactionLevelBeginner => 'Beginner';

  @override
  String get reactionLevelIntermediate => 'Intermediate';

  @override
  String get reactionLevelAdvanced => 'Advanced';

  @override
  String get reactionLevelAdvancedPlus => 'Advanced+';

  @override
  String get reactionStatDuration => 'DURATION';

  @override
  String get reactionStatMoves => 'MOVES';

  @override
  String get reactionStatReact => 'REACTION';

  @override
  String reactionInTheMix(int count) {
    return 'IN THE MIX · $count';
  }

  @override
  String get reactionStart => 'Start drill';

  @override
  String get reactionGetInStance => 'GET IN STANCE';

  @override
  String get reactionStop => 'Stop';

  @override
  String get reactionTimeUp => 'TIME';

  @override
  String reactionSummary(int calls, int moves) {
    return '$calls calls · $moves moves';
  }

  @override
  String get reactionAgain => 'Go again';

  @override
  String get reactionDone => 'Done';

  @override
  String get reactionNoVoice =>
      'No voice on this device. Follow the calls on screen.';

  @override
  String get reactionTestVoice => 'Test voice';

  @override
  String get reactionShowAll => 'Show all';

  @override
  String get reactionShowLess => 'Show less';

  @override
  String get reactionPause => 'Pause';

  @override
  String get reactionResume => 'Resume';

  @override
  String get reactionPaused => 'PAUSED';

  @override
  String reactionTimeLeft(String time) {
    return '$time left';
  }

  @override
  String reactionCallNumber(int n) {
    return 'CALL $n';
  }

  @override
  String reactionFinishedSummary(int calls, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      calls,
      locale: localeName,
      other: '$calls calls',
      one: '1 call',
    );
    return '$_temp0 in $time';
  }

  @override
  String reactionNextLevel(String level) {
    return 'Ready for $level?';
  }

  @override
  String reactionStopped(String time, int calls) {
    String _temp0 = intl.Intl.pluralLogic(
      calls,
      locale: localeName,
      other: '$calls calls',
      one: '1 call',
    );
    return 'Stopped at $time · $_temp0';
  }

  @override
  String get reactionLeaveTitle => 'Leave the drill?';

  @override
  String get reactionLeaveBody => 'This run will end.';

  @override
  String get reactionLeaveStay => 'Keep going';

  @override
  String get reactionLeaveConfirm => 'Leave';

  @override
  String reactionRecoveryNote(String time, int moves) {
    return '+$time s to reset after $moves+ moves';
  }

  @override
  String reactionBlockRestNote(String time, int min, int max) {
    return '+$time s rest every $min–$max calls';
  }

  @override
  String devMessageFrom(String from) {
    return 'FROM $from';
  }

  @override
  String get devMessageGotIt => 'Got it';

  @override
  String get foodMarkEaten => 'Mark as eaten';

  @override
  String get foodMarkNotEaten => 'Mark as not eaten';

  @override
  String foodMarkedEaten(String name) {
    return '$name marked as eaten';
  }

  @override
  String foodMarkedNotEaten(String name) {
    return '$name marked as not eaten';
  }

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonSaveMeal => 'Save meal';

  @override
  String get commonUnsave => 'Unsave';

  @override
  String get commonDelete => 'Delete';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authWelcomeBackSubtitle => 'Sign in to continue your camp';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authSigningIn => 'Signing in...';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authNoAccount => 'New here?';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';
}

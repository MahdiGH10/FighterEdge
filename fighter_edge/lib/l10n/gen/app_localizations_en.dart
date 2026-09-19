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

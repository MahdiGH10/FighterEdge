import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTrain.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get navTrain;

  /// No description provided for @navFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get navFuel;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonSignOut;

  /// No description provided for @commonSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out...'**
  String get commonSigningOut;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsSectionApp;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get settingsLanguageGerman;

  /// No description provided for @settingsLanguageBeta.
  ///
  /// In en, this message translates to:
  /// **'German is partly translated — the rest stays in English for now.'**
  String get settingsLanguageBeta;

  /// No description provided for @settingsSectionSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get settingsSectionSubscription;

  /// No description provided for @settingsManagePro.
  ///
  /// In en, this message translates to:
  /// **'Manage Pro'**
  String get settingsManagePro;

  /// No description provided for @settingsUpgradePro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get settingsUpgradePro;

  /// No description provided for @settingsManageProSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Refresh status and manage billing once connected'**
  String get settingsManageProSubtitle;

  /// No description provided for @settingsUpgradeProSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI Fighter Brief, full drill and recipe libraries, corner cues'**
  String get settingsUpgradeProSubtitle;

  /// No description provided for @settingsSectionTraining.
  ///
  /// In en, this message translates to:
  /// **'Training Preferences'**
  String get settingsSectionTraining;

  /// No description provided for @settingsMetricUnits.
  ///
  /// In en, this message translates to:
  /// **'Metric units'**
  String get settingsMetricUnits;

  /// No description provided for @settingsMetricUnitsKg.
  ///
  /// In en, this message translates to:
  /// **'Weights show in kg'**
  String get settingsMetricUnitsKg;

  /// No description provided for @settingsMetricUnitsLb.
  ///
  /// In en, this message translates to:
  /// **'Weights show in lb'**
  String get settingsMetricUnitsLb;

  /// No description provided for @settingsTimerHaptics.
  ///
  /// In en, this message translates to:
  /// **'Timer haptics'**
  String get settingsTimerHaptics;

  /// No description provided for @settingsTimerHapticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Round alerts can use vibration feedback'**
  String get settingsTimerHapticsSubtitle;

  /// No description provided for @settingsCampReminders.
  ///
  /// In en, this message translates to:
  /// **'Camp reminders'**
  String get settingsCampReminders;

  /// No description provided for @settingsCampRemindersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get settingsCampRemindersUnavailable;

  /// No description provided for @settingsCampRemindersOn.
  ///
  /// In en, this message translates to:
  /// **'A nudge on the days you train, around {time}'**
  String settingsCampRemindersOn(String time);

  /// No description provided for @settingsCampRemindersOff.
  ///
  /// In en, this message translates to:
  /// **'Get a nudge on the days you train'**
  String get settingsCampRemindersOff;

  /// No description provided for @settingsSectionSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety & Trust'**
  String get settingsSectionSafety;

  /// No description provided for @settingsSafeCut.
  ///
  /// In en, this message translates to:
  /// **'Safe cut guidance'**
  String get settingsSafeCut;

  /// No description provided for @settingsSafeCutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show hydration and non-medical weight-cut reminders'**
  String get settingsSafeCutSubtitle;

  /// No description provided for @settingsTrustNote.
  ///
  /// In en, this message translates to:
  /// **'Fighter Edge guides training and nutrition decisions. It does not replace a coach, doctor, or licensed nutrition professional.'**
  String get settingsTrustNote;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePassword;

  /// No description provided for @settingsChangePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your current password to set a new one'**
  String get settingsChangePasswordSubtitle;

  /// No description provided for @settingsChangePasswordGoogle.
  ///
  /// In en, this message translates to:
  /// **'You sign in with Google — manage it in your Google account'**
  String get settingsChangePasswordGoogle;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTerms;

  /// No description provided for @settingsTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The rules for using Fighter Edge'**
  String get settingsTermsSubtitle;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What we store and why'**
  String get settingsPrivacySubtitle;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently erase your account and all of your data'**
  String get settingsDeleteAccountSubtitle;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardWeeklyOverview.
  ///
  /// In en, this message translates to:
  /// **'Weekly Overview'**
  String get dashboardWeeklyOverview;

  /// No description provided for @dashboardNextSession.
  ///
  /// In en, this message translates to:
  /// **'Next Session'**
  String get dashboardNextSession;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get dashboardSeeAll;

  /// No description provided for @dashboardStatWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get dashboardStatWeight;

  /// No description provided for @dashboardStatSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get dashboardStatSessions;

  /// No description provided for @dashboardStatStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get dashboardStatStreak;

  /// No description provided for @dashboardStatCompleted.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get dashboardStatCompleted;

  /// No description provided for @dashboardStatDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day} other{days}}'**
  String dashboardStatDays(int count);

  /// No description provided for @dashboardAddWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Add weigh-in'**
  String get dashboardAddWeighIn;

  /// No description provided for @dashboardStreakAtRisk.
  ///
  /// In en, this message translates to:
  /// **'At risk'**
  String get dashboardStreakAtRisk;

  /// No description provided for @dashboardStreakOnFire.
  ///
  /// In en, this message translates to:
  /// **'On fire'**
  String get dashboardStreakOnFire;

  /// No description provided for @dashboardStreakLogToday.
  ///
  /// In en, this message translates to:
  /// **'Log today'**
  String get dashboardStreakLogToday;

  /// No description provided for @fuelWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'FUEL THIS WEEK'**
  String get fuelWeekTitle;

  /// No description provided for @fuelWeekLogged.
  ///
  /// In en, this message translates to:
  /// **'{count}/7 logged'**
  String fuelWeekLogged(int count);

  /// No description provided for @fuelWeekOnTarget.
  ///
  /// In en, this message translates to:
  /// **'on target'**
  String get fuelWeekOnTarget;

  /// No description provided for @fuelWeekProteinHit.
  ///
  /// In en, this message translates to:
  /// **'protein hit'**
  String get fuelWeekProteinHit;

  /// No description provided for @fuelWeekAvgKcal.
  ///
  /// In en, this message translates to:
  /// **'avg kcal'**
  String get fuelWeekAvgKcal;

  /// No description provided for @fuelWeekEmpty.
  ///
  /// In en, this message translates to:
  /// **'Log meals this week and your fuel trend builds here, day by day against your target.'**
  String get fuelWeekEmpty;

  /// No description provided for @fuelLeftToday.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal left today'**
  String fuelLeftToday(int kcal);

  /// No description provided for @fuelLeftTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recipes that fit, highest protein first'**
  String get fuelLeftTodaySubtitle;

  /// No description provided for @nutritionTitle.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get nutritionTitle;

  /// No description provided for @nutritionTabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get nutritionTabToday;

  /// No description provided for @nutritionTabMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get nutritionTabMeals;

  /// No description provided for @nutritionTabRecipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get nutritionTabRecipes;

  /// No description provided for @nutritionCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get nutritionCalories;

  /// No description provided for @nutritionMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get nutritionMeals;

  /// No description provided for @nutritionAddFood.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get nutritionAddFood;

  /// No description provided for @nutritionSearchFoods.
  ///
  /// In en, this message translates to:
  /// **'Search foods'**
  String get nutritionSearchFoods;

  /// No description provided for @nutritionLoggedToday.
  ///
  /// In en, this message translates to:
  /// **'logged today'**
  String get nutritionLoggedToday;

  /// No description provided for @nutritionProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get nutritionProtein;

  /// No description provided for @nutritionCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get nutritionCarbs;

  /// No description provided for @nutritionFats.
  ///
  /// In en, this message translates to:
  /// **'Fats'**
  String get nutritionFats;

  /// No description provided for @nutritionAddedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} · {kcal} kcal added'**
  String nutritionAddedSnack(String name, int kcal);

  /// No description provided for @addFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to {day}'**
  String addFoodTitle(String day);

  /// No description provided for @addFoodSaved.
  ///
  /// In en, this message translates to:
  /// **'SAVED'**
  String get addFoodSaved;

  /// No description provided for @addFoodRecent.
  ///
  /// In en, this message translates to:
  /// **'RECENT'**
  String get addFoodRecent;

  /// No description provided for @addFoodManual.
  ///
  /// In en, this message translates to:
  /// **'Enter macros manually'**
  String get addFoodManual;

  /// No description provided for @addFoodManualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For a meal out, a label, or anything not listed'**
  String get addFoodManualSubtitle;

  /// No description provided for @addFoodEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Search the food list and pick how much you had — the macros work themselves out. Foods you log show up here next time, one tap away.'**
  String get addFoodEmptyHint;

  /// No description provided for @addFoodNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not in the food list yet'**
  String get addFoodNotFound;

  /// No description provided for @addFoodNotFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Try a simpler word (\"rice\", \"chicken\"), or enter the macros yourself below.'**
  String get addFoodNotFoundHint;

  /// No description provided for @addFoodHowMuch.
  ///
  /// In en, this message translates to:
  /// **'HOW MUCH?'**
  String get addFoodHowMuch;

  /// No description provided for @addFoodGrams.
  ///
  /// In en, this message translates to:
  /// **'Grams'**
  String get addFoodGrams;

  /// No description provided for @addFoodAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to {day}'**
  String addFoodAddTo(String day);

  /// No description provided for @addFoodPerHundred.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal · {protein}g protein per 100 g'**
  String addFoodPerHundred(int kcal, String protein);

  /// No description provided for @addFoodAllergenWarning.
  ///
  /// In en, this message translates to:
  /// **'Contains {allergens} — on your allergen list.'**
  String addFoodAllergenWarning(String allergens);

  /// No description provided for @trainTitle.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get trainTitle;

  /// No description provided for @trainTabWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get trainTabWeek;

  /// No description provided for @trainTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get trainTabHistory;

  /// No description provided for @trainTabDrills.
  ///
  /// In en, this message translates to:
  /// **'Drills'**
  String get trainTabDrills;

  /// No description provided for @timerTitle.
  ///
  /// In en, this message translates to:
  /// **'Round Timer'**
  String get timerTitle;

  /// No description provided for @timerRound.
  ///
  /// In en, this message translates to:
  /// **'Round'**
  String get timerRound;

  /// No description provided for @timerWork.
  ///
  /// In en, this message translates to:
  /// **'WORK'**
  String get timerWork;

  /// No description provided for @timerRest.
  ///
  /// In en, this message translates to:
  /// **'REST'**
  String get timerRest;

  /// No description provided for @timerDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get timerDone;

  /// No description provided for @timerStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get timerStart;

  /// No description provided for @timerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get timerPause;

  /// No description provided for @timerReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get timerReset;

  /// No description provided for @timerRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get timerRestart;

  /// No description provided for @timerNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {label}'**
  String timerNext(String label);

  /// No description provided for @timerYourCorner.
  ///
  /// In en, this message translates to:
  /// **'YOUR CORNER'**
  String get timerYourCorner;

  /// No description provided for @timerCornerTeaser.
  ///
  /// In en, this message translates to:
  /// **'Pro puts a corner in your rest: a cue for the next round.'**
  String get timerCornerTeaser;

  /// No description provided for @trainTabReaction.
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
  String get trainTabReaction;

  /// No description provided for @reactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reaction Drill'**
  String get reactionTitle;

  /// No description provided for @reactionHeadline.
  ///
  /// In en, this message translates to:
  /// **'The coach calls it. You react.'**
  String get reactionHeadline;

  /// No description provided for @reactionSoundHint.
  ///
  /// In en, this message translates to:
  /// **'Sound on. Every run is shuffled — nothing to memorize.'**
  String get reactionSoundHint;

  /// No description provided for @reactionDisciplineGrappling.
  ///
  /// In en, this message translates to:
  /// **'Wrestling'**
  String get reactionDisciplineGrappling;

  /// No description provided for @reactionDisciplineStriking.
  ///
  /// In en, this message translates to:
  /// **'Striking'**
  String get reactionDisciplineStriking;

  /// No description provided for @reactionDisciplineMma.
  ///
  /// In en, this message translates to:
  /// **'MMA'**
  String get reactionDisciplineMma;

  /// No description provided for @reactionLevelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get reactionLevelBeginner;

  /// No description provided for @reactionLevelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get reactionLevelIntermediate;

  /// No description provided for @reactionLevelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get reactionLevelAdvanced;

  /// No description provided for @reactionLevelAdvancedPlus.
  ///
  /// In en, this message translates to:
  /// **'Advanced+'**
  String get reactionLevelAdvancedPlus;

  /// No description provided for @reactionStatDuration.
  ///
  /// In en, this message translates to:
  /// **'DURATION'**
  String get reactionStatDuration;

  /// No description provided for @reactionStatMoves.
  ///
  /// In en, this message translates to:
  /// **'MOVES'**
  String get reactionStatMoves;

  /// No description provided for @reactionStatReact.
  ///
  /// In en, this message translates to:
  /// **'REACTION'**
  String get reactionStatReact;

  /// No description provided for @reactionInTheMix.
  ///
  /// In en, this message translates to:
  /// **'IN THE MIX · {count}'**
  String reactionInTheMix(int count);

  /// No description provided for @reactionStart.
  ///
  /// In en, this message translates to:
  /// **'Start drill'**
  String get reactionStart;

  /// No description provided for @reactionGetInStance.
  ///
  /// In en, this message translates to:
  /// **'GET IN STANCE'**
  String get reactionGetInStance;

  /// No description provided for @reactionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get reactionStop;

  /// No description provided for @reactionTimeUp.
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get reactionTimeUp;

  /// No description provided for @reactionSummary.
  ///
  /// In en, this message translates to:
  /// **'{calls} calls · {moves} moves'**
  String reactionSummary(int calls, int moves);

  /// No description provided for @reactionAgain.
  ///
  /// In en, this message translates to:
  /// **'Go again'**
  String get reactionAgain;

  /// No description provided for @reactionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reactionDone;

  /// No description provided for @reactionNoVoice.
  ///
  /// In en, this message translates to:
  /// **'No voice on this device. Follow the calls on screen.'**
  String get reactionNoVoice;

  /// No description provided for @reactionTestVoice.
  ///
  /// In en, this message translates to:
  /// **'Test voice'**
  String get reactionTestVoice;

  /// No description provided for @reactionShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get reactionShowAll;

  /// No description provided for @reactionShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get reactionShowLess;

  /// No description provided for @reactionPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get reactionPause;

  /// No description provided for @reactionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get reactionResume;

  /// No description provided for @reactionPaused.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get reactionPaused;

  /// No description provided for @reactionTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String reactionTimeLeft(String time);

  /// No description provided for @reactionCallNumber.
  ///
  /// In en, this message translates to:
  /// **'CALL {n}'**
  String reactionCallNumber(int n);

  /// No description provided for @reactionFinishedSummary.
  ///
  /// In en, this message translates to:
  /// **'{calls, plural, =1{1 call} other{{calls} calls}} in {time}'**
  String reactionFinishedSummary(int calls, String time);

  /// No description provided for @reactionNextLevel.
  ///
  /// In en, this message translates to:
  /// **'Ready for {level}?'**
  String reactionNextLevel(String level);

  /// No description provided for @reactionStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped at {time} · {calls, plural, =1{1 call} other{{calls} calls}}'**
  String reactionStopped(String time, int calls);

  /// No description provided for @reactionLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the drill?'**
  String get reactionLeaveTitle;

  /// No description provided for @reactionLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'This run will end.'**
  String get reactionLeaveBody;

  /// No description provided for @reactionLeaveStay.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get reactionLeaveStay;

  /// No description provided for @reactionLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get reactionLeaveConfirm;

  /// No description provided for @reactionRecoveryNote.
  ///
  /// In en, this message translates to:
  /// **'+{time} s to reset after {moves}+ moves'**
  String reactionRecoveryNote(String time, int moves);

  /// No description provided for @reactionBlockRestNote.
  ///
  /// In en, this message translates to:
  /// **'+{time} s rest every {min}–{max} calls'**
  String reactionBlockRestNote(String time, int min, int max);

  /// No description provided for @devMessageFrom.
  ///
  /// In en, this message translates to:
  /// **'FROM {from}'**
  String devMessageFrom(String from);

  /// No description provided for @devMessageGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get devMessageGotIt;

  /// No description provided for @foodMarkEaten.
  ///
  /// In en, this message translates to:
  /// **'Mark as eaten'**
  String get foodMarkEaten;

  /// No description provided for @foodMarkNotEaten.
  ///
  /// In en, this message translates to:
  /// **'Mark as not eaten'**
  String get foodMarkNotEaten;

  /// No description provided for @foodMarkedEaten.
  ///
  /// In en, this message translates to:
  /// **'{name} marked as eaten'**
  String foodMarkedEaten(String name);

  /// No description provided for @foodMarkedNotEaten.
  ///
  /// In en, this message translates to:
  /// **'{name} marked as not eaten'**
  String foodMarkedNotEaten(String name);

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonSaveMeal.
  ///
  /// In en, this message translates to:
  /// **'Save meal'**
  String get commonSaveMeal;

  /// No description provided for @commonUnsave.
  ///
  /// In en, this message translates to:
  /// **'Unsave'**
  String get commonUnsave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authWelcomeBackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your camp'**
  String get authWelcomeBackSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get authSigningIn;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get authNoAccount;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return LDe();
    case 'en':
      return LEn();
  }

  throw FlutterError(
      'L.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

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

  /// No description provided for @settingsReduceTransparency.
  ///
  /// In en, this message translates to:
  /// **'Reduce transparency'**
  String get settingsReduceTransparency;

  /// No description provided for @settingsReduceTransparencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Solid backgrounds instead of frosted glass. High contrast does this too'**
  String get settingsReduceTransparencySubtitle;

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
  /// **'Full drill library, session mode, and training-day fuel'**
  String get settingsUpgradeProSubtitle;

  /// No description provided for @settingsSectionTraining.
  ///
  /// In en, this message translates to:
  /// **'Training preferences'**
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

  /// No description provided for @settingsSectionSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety & trust'**
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

  /// No description provided for @settingsEthics.
  ///
  /// In en, this message translates to:
  /// **'Ethical Guidelines'**
  String get settingsEthics;

  /// No description provided for @settingsEthicsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What Fighter Edge will never do'**
  String get settingsEthicsSubtitle;

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

  /// No description provided for @dashboardNextSession.
  ///
  /// In en, this message translates to:
  /// **'Next session'**
  String get dashboardNextSession;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
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

  /// No description provided for @dashboardAddWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Add weigh-in'**
  String get dashboardAddWeighIn;

  /// No description provided for @fuelWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel this week'**
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

  /// No description provided for @nutritionPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get nutritionPreviousDay;

  /// No description provided for @nutritionNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nutritionNextDay;

  /// No description provided for @trainingLogSession.
  ///
  /// In en, this message translates to:
  /// **'Log session'**
  String get trainingLogSession;

  /// No description provided for @trainingEditSessionLog.
  ///
  /// In en, this message translates to:
  /// **'Edit session log'**
  String get trainingEditSessionLog;

  /// No description provided for @weightFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightFieldLabel;

  /// No description provided for @weightAddWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Add weigh-in'**
  String get weightAddWeighIn;

  /// No description provided for @weightEditWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Edit weigh-in'**
  String get weightEditWeighIn;

  /// No description provided for @weightDeleteWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Delete weigh-in?'**
  String get weightDeleteWeighIn;

  /// No description provided for @weightDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'This removes the weigh-in from your history and recalculates your trend.'**
  String get weightDeleteConfirm;

  /// No description provided for @weightWeighInActions.
  ///
  /// In en, this message translates to:
  /// **'Weigh-in actions'**
  String get weightWeighInActions;

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
  /// **'Saved'**
  String get addFoodSaved;

  /// No description provided for @addFoodRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
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
  /// **'How much?'**
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

  /// No description provided for @trainWeekNumber.
  ///
  /// In en, this message translates to:
  /// **'WEEK {number}'**
  String trainWeekNumber(int number);

  /// No description provided for @trainWeekDone.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {target} done'**
  String trainWeekDone(int completed, int target);

  /// No description provided for @trainRestHint.
  ///
  /// In en, this message translates to:
  /// **'Rest days never count against you'**
  String get trainRestHint;

  /// No description provided for @trainTodayHeading.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get trainTodayHeading;

  /// No description provided for @trainAboutMinutes.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} min'**
  String trainAboutMinutes(int minutes);

  /// No description provided for @trainStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start session'**
  String get trainStartSession;

  /// No description provided for @trainThisWeekHeading.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get trainThisWeekHeading;

  /// No description provided for @trainEmptyWeek.
  ///
  /// In en, this message translates to:
  /// **'No sessions planned yet. Your training week appears here once your camp is set up.'**
  String get trainEmptyWeek;

  /// No description provided for @trainEmptyHistory.
  ///
  /// In en, this message translates to:
  /// **'Complete or log a session to build history'**
  String get trainEmptyHistory;

  /// No description provided for @trainHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Session history'**
  String get trainHistoryTitle;

  /// No description provided for @profileAthleteFallback.
  ///
  /// In en, this message translates to:
  /// **'Fighter'**
  String get profileAthleteFallback;

  /// No description provided for @profileSubscriptionSection.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get profileSubscriptionSection;

  /// No description provided for @profileTrainingSection.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get profileTrainingSection;

  /// No description provided for @profileTrainingDays.
  ///
  /// In en, this message translates to:
  /// **'Training days'**
  String get profileTrainingDays;

  /// No description provided for @profileTrainingDaysValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day each week} other{{count} days each week}}'**
  String profileTrainingDaysValue(int count);

  /// No description provided for @profileWeightTracker.
  ///
  /// In en, this message translates to:
  /// **'Weight tracker'**
  String get profileWeightTracker;

  /// No description provided for @profileWeightTrackerHint.
  ///
  /// In en, this message translates to:
  /// **'Your weigh-ins and weight history'**
  String get profileWeightTrackerHint;

  /// No description provided for @profilePreferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences, privacy and account'**
  String get profilePreferencesSection;

  /// No description provided for @profileSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Units, reminders, data and account controls'**
  String get profileSettingsHint;

  /// No description provided for @firstWeekPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Build your plan'**
  String get firstWeekPlanTitle;

  /// No description provided for @firstWeekPlanHint.
  ///
  /// In en, this message translates to:
  /// **'Your target and training week are set.'**
  String get firstWeekPlanHint;

  /// No description provided for @firstWeekTourTitle.
  ///
  /// In en, this message translates to:
  /// **'Take the 30-second tour'**
  String get firstWeekTourTitle;

  /// No description provided for @firstWeekTourHint.
  ///
  /// In en, this message translates to:
  /// **'See where everything lives.'**
  String get firstWeekTourHint;

  /// No description provided for @firstWeekMealTitle.
  ///
  /// In en, this message translates to:
  /// **'Log your first meal'**
  String get firstWeekMealTitle;

  /// No description provided for @firstWeekMealHint.
  ///
  /// In en, this message translates to:
  /// **'One tap from Fuel. It starts your day’s score.'**
  String get firstWeekMealHint;

  /// No description provided for @firstWeekSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete a session'**
  String get firstWeekSessionTitle;

  /// No description provided for @firstWeekSessionHint.
  ///
  /// In en, this message translates to:
  /// **'Complete one in Train to start building consistency.'**
  String get firstWeekSessionHint;

  /// No description provided for @firstWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first week'**
  String get firstWeekTitle;

  /// No description provided for @firstWeekCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'First week: set'**
  String get firstWeekCompletedTitle;

  /// No description provided for @firstWeekProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total}'**
  String firstWeekProgress(int completed, int total);

  /// No description provided for @firstWeekCompleteHint.
  ///
  /// In en, this message translates to:
  /// **'Plan built, meal logged, first session done. That is a real start — keep training this week.'**
  String get firstWeekCompleteHint;

  /// No description provided for @firstWeekDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get firstWeekDone;

  /// No description provided for @firstWeekSemanticsDone.
  ///
  /// In en, this message translates to:
  /// **'{title}, done'**
  String firstWeekSemanticsDone(String title);

  /// No description provided for @firstWinTitle.
  ///
  /// In en, this message translates to:
  /// **'First meal logged.'**
  String get firstWinTitle;

  /// No description provided for @firstWinWithNumbers.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the board. Every meal you log shows how today stacks up against your target.'**
  String get firstWinWithNumbers;

  /// No description provided for @firstWinWithoutNumbers.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the board. Keep logging what you eat.'**
  String get firstWinWithoutNumbers;

  /// No description provided for @firstWinContinue.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get firstWinContinue;

  /// No description provided for @sessionLogRpe.
  ///
  /// In en, this message translates to:
  /// **'RPE {value} / 10'**
  String sessionLogRpe(int value);

  /// No description provided for @sessionLogReflection.
  ///
  /// In en, this message translates to:
  /// **'Quick reflection'**
  String get sessionLogReflection;

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
  /// **'Your corner'**
  String get timerYourCorner;

  /// No description provided for @timerCornerTeaser.
  ///
  /// In en, this message translates to:
  /// **'Pro puts a corner in your rest: a cue for the next round.'**
  String get timerCornerTeaser;

  /// No description provided for @timerNextSessionComplete.
  ///
  /// In en, this message translates to:
  /// **'Session complete'**
  String get timerNextSessionComplete;

  /// No description provided for @timerNextFinalRound.
  ///
  /// In en, this message translates to:
  /// **'Final round'**
  String get timerNextFinalRound;

  /// No description provided for @timerNextRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get timerNextRest;

  /// No description provided for @timerNextRound.
  ///
  /// In en, this message translates to:
  /// **'Round {round}'**
  String timerNextRound(int round);

  /// No description provided for @timerCallTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timerCallTime;

  /// No description provided for @timerCallRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get timerCallRest;

  /// No description provided for @timerCallTenSeconds.
  ///
  /// In en, this message translates to:
  /// **'Ten seconds'**
  String get timerCallTenSeconds;

  /// No description provided for @timerClockSemantics.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes {seconds} seconds left'**
  String timerClockSemantics(int minutes, int seconds);

  /// No description provided for @timerAnnounceWork.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}. Work.'**
  String timerAnnounceWork(int round, int total);

  /// No description provided for @timerAnnounceRest.
  ///
  /// In en, this message translates to:
  /// **'Round {round} done. Rest.'**
  String timerAnnounceRest(int round);

  /// No description provided for @timerAnnounceDone.
  ///
  /// In en, this message translates to:
  /// **'Session complete.'**
  String get timerAnnounceDone;

  /// No description provided for @paywallRenewalDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions renew automatically at the price and period shown above unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID or Google Play account when you confirm the purchase. You can manage or cancel your subscription at any time in your store account settings.'**
  String get paywallRenewalDisclosure;

  /// No description provided for @legalTermsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get legalTermsLink;

  /// No description provided for @legalPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyLink;

  /// No description provided for @legalOpenPublished.
  ///
  /// In en, this message translates to:
  /// **'Open the published version'**
  String get legalOpenPublished;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Help improve Fighter Edge'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In en, this message translates to:
  /// **'With your permission we collect anonymous usage events and crash reports. They never include your meals, weight, measurements, messages or email address. Nothing is sent unless you allow it.'**
  String get consentBody;

  /// No description provided for @consentAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get consentAllow;

  /// No description provided for @consentDecline.
  ///
  /// In en, this message translates to:
  /// **'Don\'t allow'**
  String get consentDecline;

  /// No description provided for @consentChangeLater.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in Settings.'**
  String get consentChangeLater;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsSectionPrivacy;

  /// No description provided for @settingsAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Usage analytics'**
  String get settingsAnalytics;

  /// No description provided for @settingsAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous events that show which features help. No health data.'**
  String get settingsAnalyticsSubtitle;

  /// No description provided for @settingsCrashReports.
  ///
  /// In en, this message translates to:
  /// **'Crash reports'**
  String get settingsCrashReports;

  /// No description provided for @settingsCrashReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Error details that help us fix bugs. No personal data.'**
  String get settingsCrashReportsSubtitle;

  /// No description provided for @healthConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Your body data, your call'**
  String get healthConsentTitle;

  /// No description provided for @healthConsentIntro.
  ///
  /// In en, this message translates to:
  /// **'To build your plan, Fighter Edge needs data about your body and health. The law treats this data as sensitive, so we ask for your explicit consent first.'**
  String get healthConsentIntro;

  /// No description provided for @healthConsentWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'What we store'**
  String get healthConsentWhatTitle;

  /// No description provided for @healthConsentWhat.
  ///
  /// In en, this message translates to:
  /// **'Age, height, weight and target weight, body fat if you add it, the energy profile you choose, activity level, diet, allergies and intolerances, and the food, weight and training you log.'**
  String get healthConsentWhat;

  /// No description provided for @healthConsentWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'What it\'s used for'**
  String get healthConsentWhyTitle;

  /// No description provided for @healthConsentWhy.
  ///
  /// In en, this message translates to:
  /// **'Only to calculate your targets, show your progress and guide you. Never for ads, and never sold.'**
  String get healthConsentWhy;

  /// No description provided for @healthConsentWhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Where it\'s kept'**
  String get healthConsentWhereTitle;

  /// No description provided for @healthConsentWhere.
  ///
  /// In en, this message translates to:
  /// **'In your account on Google Firebase. Only you can read it.'**
  String get healthConsentWhere;

  /// No description provided for @healthConsentWithdraw.
  ///
  /// In en, this message translates to:
  /// **'You can withdraw your consent at any time in Settings > Privacy. The app can\'t work without this data, so withdrawing deletes your account and its data.'**
  String get healthConsentWithdraw;

  /// No description provided for @healthConsentStatement.
  ///
  /// In en, this message translates to:
  /// **'I agree that Fighter Edge stores and uses my health data as described here and in the Privacy Policy.'**
  String get healthConsentStatement;

  /// No description provided for @healthConsentAgree.
  ///
  /// In en, this message translates to:
  /// **'I agree'**
  String get healthConsentAgree;

  /// No description provided for @healthConsentSignOut.
  ///
  /// In en, this message translates to:
  /// **'Not now, sign out'**
  String get healthConsentSignOut;

  /// No description provided for @healthConsentDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account instead'**
  String get healthConsentDeleteAccount;

  /// No description provided for @settingsHealthData.
  ///
  /// In en, this message translates to:
  /// **'Health data'**
  String get settingsHealthData;

  /// No description provided for @settingsHealthDataGranted.
  ///
  /// In en, this message translates to:
  /// **'You agreed on {date}'**
  String settingsHealthDataGranted(String date);

  /// No description provided for @settingsHealthDataGrantedNoDate.
  ///
  /// In en, this message translates to:
  /// **'You agreed to its use'**
  String get settingsHealthDataGrantedNoDate;

  /// No description provided for @settingsHealthDataWithdrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw consent?'**
  String get settingsHealthDataWithdrawTitle;

  /// No description provided for @settingsHealthDataWithdrawBody.
  ///
  /// In en, this message translates to:
  /// **'Fighter Edge can\'t calculate your plan or track your progress without your health data. Withdrawing your consent therefore means deleting your account and all its data.'**
  String get settingsHealthDataWithdrawBody;

  /// No description provided for @settingsHealthDataWithdrawConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsHealthDataWithdrawConfirm;

  /// No description provided for @deleteAccountSubscriptionWarning.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account doesn\'t cancel your subscription. Cancel it first in your App Store or Google Play account settings, or it keeps renewing.'**
  String get deleteAccountSubscriptionWarning;

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
  /// **'Sound on. One move per call, shuffled every run.'**
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

  /// No description provided for @reactionCoachVoice.
  ///
  /// In en, this message translates to:
  /// **'Coach voice'**
  String get reactionCoachVoice;

  /// No description provided for @reactionVoiceUsMale.
  ///
  /// In en, this message translates to:
  /// **'US male'**
  String get reactionVoiceUsMale;

  /// No description provided for @reactionVoiceUkMale.
  ///
  /// In en, this message translates to:
  /// **'UK male'**
  String get reactionVoiceUkMale;

  /// No description provided for @reactionVoiceUsFemale.
  ///
  /// In en, this message translates to:
  /// **'US female'**
  String get reactionVoiceUsFemale;

  /// No description provided for @reactionVoicePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone voice'**
  String get reactionVoicePhone;

  /// No description provided for @reactionPaceSteady.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get reactionPaceSteady;

  /// No description provided for @reactionPaceSprint.
  ///
  /// In en, this message translates to:
  /// **'Sprint'**
  String get reactionPaceSprint;

  /// No description provided for @reactionStatDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get reactionStatDuration;

  /// No description provided for @reactionStatReact.
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
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

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email.'**
  String get authEmailRequired;

  /// No description provided for @authEmailIncomplete.
  ///
  /// In en, this message translates to:
  /// **'That email looks incomplete.'**
  String get authEmailIncomplete;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get authPasswordRequired;

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

  /// No description provided for @dashboardFighter.
  ///
  /// In en, this message translates to:
  /// **'Fighter'**
  String get dashboardFighter;

  /// No description provided for @dashboardToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardToday;

  /// No description provided for @dashboardNoPlan.
  ///
  /// In en, this message translates to:
  /// **'No sessions planned'**
  String get dashboardNoPlan;

  /// No description provided for @dashboardWeekDone.
  ///
  /// In en, this message translates to:
  /// **'Week complete'**
  String get dashboardWeekDone;

  /// No description provided for @dashboardRestDay.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get dashboardRestDay;

  /// No description provided for @dashboardRecovery.
  ///
  /// In en, this message translates to:
  /// **'Your planned sessions are done. Take time to recover.'**
  String get dashboardRecovery;

  /// No description provided for @dashboardPlanHint.
  ///
  /// In en, this message translates to:
  /// **'Open Train to set up your week.'**
  String get dashboardPlanHint;

  /// No description provided for @dashboardNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next: {day} · {session}'**
  String dashboardNextUp(String day, String session);

  /// No description provided for @dashboardLogSession.
  ///
  /// In en, this message translates to:
  /// **'Log session'**
  String get dashboardLogSession;

  /// No description provided for @dashboardTimerAction.
  ///
  /// In en, this message translates to:
  /// **'Round timer'**
  String get dashboardTimerAction;

  /// No description provided for @dashboardOpenCamp.
  ///
  /// In en, this message translates to:
  /// **'Open camp'**
  String get dashboardOpenCamp;

  /// No description provided for @dashboardStatWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{week} other{weeks}}'**
  String dashboardStatWeeks(int count);

  /// No description provided for @weeklyCardTitle.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get weeklyCardTitle;

  /// No description provided for @weeklyCardRestWeek.
  ///
  /// In en, this message translates to:
  /// **'Rest week'**
  String get weeklyCardRestWeek;

  /// No description provided for @weeklyCardRestWeekHint.
  ///
  /// In en, this message translates to:
  /// **'No sessions planned. Rest is part of the plan.'**
  String get weeklyCardRestWeekHint;

  /// No description provided for @weeklyCardProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {planned} done'**
  String weeklyCardProgress(int done, int planned);

  /// No description provided for @weeklyCardNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {day} {session}'**
  String weeklyCardNext(String day, String session);

  /// No description provided for @weeklyCardAllDone.
  ///
  /// In en, this message translates to:
  /// **'All planned sessions done'**
  String get weeklyCardAllDone;

  /// No description provided for @weeklyCardNothingLeft.
  ///
  /// In en, this message translates to:
  /// **'No more sessions planned this week'**
  String get weeklyCardNothingLeft;

  /// No description provided for @weeklyCardTarget.
  ///
  /// In en, this message translates to:
  /// **'{target} needed to count this week'**
  String weeklyCardTarget(int target);

  /// No description provided for @weeklyCardStreak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week in a row} other{{count} weeks in a row}}'**
  String weeklyCardStreak(int count);

  /// No description provided for @weeklyCardReview.
  ///
  /// In en, this message translates to:
  /// **'Weekly review'**
  String get weeklyCardReview;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly review'**
  String get reviewTitle;

  /// No description provided for @reviewWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String reviewWeekOf(String date);

  /// No description provided for @reviewTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get reviewTraining;

  /// No description provided for @reviewSessionsDone.
  ///
  /// In en, this message translates to:
  /// **'{done} of {planned} sessions done'**
  String reviewSessionsDone(int done, int planned);

  /// No description provided for @reviewFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get reviewFood;

  /// No description provided for @reviewFoodNoTarget.
  ///
  /// In en, this message translates to:
  /// **'Set up Fuel to compare your week with a target.'**
  String get reviewFoodNoTarget;

  /// No description provided for @reviewFoodNoLogs.
  ///
  /// In en, this message translates to:
  /// **'No meals logged this week.'**
  String get reviewFoodNoLogs;

  /// No description provided for @reviewFoodAverage.
  ///
  /// In en, this message translates to:
  /// **'Average {average} kcal a day against a target of {target}.'**
  String reviewFoodAverage(int average, int target);

  /// No description provided for @reviewWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get reviewWeight;

  /// No description provided for @reviewWeightNoData.
  ///
  /// In en, this message translates to:
  /// **'Not enough weigh-ins for a trend yet.'**
  String get reviewWeightNoData;

  /// No description provided for @reviewWeightNoPath.
  ///
  /// In en, this message translates to:
  /// **'No weight path to compare with.'**
  String get reviewWeightNoPath;

  /// No description provided for @reviewWeightPath.
  ///
  /// In en, this message translates to:
  /// **'Path: {change} this week'**
  String reviewWeightPath(String change);

  /// No description provided for @reviewRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Recommendation'**
  String get reviewRecommendation;

  /// No description provided for @reviewRecMoveSession.
  ///
  /// In en, this message translates to:
  /// **'You have a planned session left over. Move it to today?'**
  String get reviewRecMoveSession;

  /// No description provided for @reviewRecLower.
  ///
  /// In en, this message translates to:
  /// **'Your weight is above your path and you ate to your target. Lower your daily target by {kcal} kcal?'**
  String reviewRecLower(int kcal);

  /// No description provided for @reviewRecRaise.
  ///
  /// In en, this message translates to:
  /// **'Your weight is below your path and you ate to your target. Raise your daily target by {kcal} kcal?'**
  String reviewRecRaise(int kcal);

  /// No description provided for @reviewHoldOnPath.
  ///
  /// In en, this message translates to:
  /// **'You are on path. Keep your plan as it is.'**
  String get reviewHoldOnPath;

  /// No description provided for @reviewHoldNoTarget.
  ///
  /// In en, this message translates to:
  /// **'Set up Fuel to get a calorie target before changes can be suggested.'**
  String get reviewHoldNoTarget;

  /// No description provided for @reviewHoldNeedLogs.
  ///
  /// In en, this message translates to:
  /// **'Log at least four days of food before your target is changed.'**
  String get reviewHoldNeedLogs;

  /// No description provided for @reviewHoldIntake.
  ///
  /// In en, this message translates to:
  /// **'You were not close to your target this week, so it stays. Aim for it first.'**
  String get reviewHoldIntake;

  /// No description provided for @reviewHoldNoPath.
  ///
  /// In en, this message translates to:
  /// **'Not enough weigh-ins, or no path to judge the scale by. Your target stays.'**
  String get reviewHoldNoPath;

  /// No description provided for @reviewHoldFloor.
  ///
  /// In en, this message translates to:
  /// **'Eating less would go under your resting energy estimate. Your target stays.'**
  String get reviewHoldFloor;

  /// No description provided for @reviewAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get reviewAccept;

  /// No description provided for @reviewKeepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Keep current'**
  String get reviewKeepCurrent;

  /// No description provided for @reviewGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get reviewGotIt;

  /// No description provided for @reviewAccepted.
  ///
  /// In en, this message translates to:
  /// **'You accepted this review.'**
  String get reviewAccepted;

  /// No description provided for @reviewKept.
  ///
  /// In en, this message translates to:
  /// **'You kept your current plan.'**
  String get reviewKept;

  /// No description provided for @dashboardSetFuel.
  ///
  /// In en, this message translates to:
  /// **'Set a fuel target'**
  String get dashboardSetFuel;

  /// No description provided for @dashboardFuelInfo.
  ///
  /// In en, this message translates to:
  /// **'Why this target matters'**
  String get dashboardFuelInfo;

  /// No description provided for @dashboardFuelExplanation.
  ///
  /// In en, this message translates to:
  /// **'Calories support your goal. Protein supports recovery and muscle. Carbohydrates provide energy for training.'**
  String get dashboardFuelExplanation;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @dashboardNoActivity.
  ///
  /// In en, this message translates to:
  /// **'Complete your first session to start your history.'**
  String get dashboardNoActivity;

  /// No description provided for @dashboardVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get dashboardVerifyEmail;

  /// No description provided for @dashboardConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get dashboardConfirmEmail;

  /// No description provided for @dashboardYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dashboardYesterday;

  /// No description provided for @dashboardDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String dashboardDaysAgo(int count);

  /// No description provided for @dashboardChecklistProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} complete'**
  String dashboardChecklistProgress(int done, int total);

  /// No description provided for @nutritionKcalLeft.
  ///
  /// In en, this message translates to:
  /// **'kcal left'**
  String get nutritionKcalLeft;

  /// No description provided for @nutritionOverTarget.
  ///
  /// In en, this message translates to:
  /// **'Today\'s target met, plus {kcal} kcal'**
  String nutritionOverTarget(int kcal);

  /// No description provided for @nutritionViewPlan.
  ///
  /// In en, this message translates to:
  /// **'View fuel plan'**
  String get nutritionViewPlan;

  /// No description provided for @nutritionRecipesFit.
  ///
  /// In en, this message translates to:
  /// **'Recipes that fit'**
  String get nutritionRecipesFit;

  /// No description provided for @nutritionMacroGrams.
  ///
  /// In en, this message translates to:
  /// **'{value} / {target} g'**
  String nutritionMacroGrams(int value, int target);

  /// No description provided for @nutritionGrams.
  ///
  /// In en, this message translates to:
  /// **'{value} g'**
  String nutritionGrams(int value);

  /// No description provided for @trainingSessionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get trainingSessionDone;

  /// No description provided for @tplGenericSkill.
  ///
  /// In en, this message translates to:
  /// **'Skill session'**
  String get tplGenericSkill;

  /// No description provided for @tplGenericSparring.
  ///
  /// In en, this message translates to:
  /// **'Sparring session'**
  String get tplGenericSparring;

  /// No description provided for @tplGenericConditioning.
  ///
  /// In en, this message translates to:
  /// **'Conditioning session'**
  String get tplGenericConditioning;

  /// No description provided for @tplGenericStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength session'**
  String get tplGenericStrength;

  /// No description provided for @tplGenericRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery session'**
  String get tplGenericRecovery;

  /// No description provided for @tplGenericGymClass.
  ///
  /// In en, this message translates to:
  /// **'Gym class'**
  String get tplGenericGymClass;

  /// No description provided for @planDisciplineBoxing.
  ///
  /// In en, this message translates to:
  /// **'Boxing'**
  String get planDisciplineBoxing;

  /// No description provided for @planDisciplineKickboxing.
  ///
  /// In en, this message translates to:
  /// **'Kickboxing'**
  String get planDisciplineKickboxing;

  /// No description provided for @planDisciplineMuayThai.
  ///
  /// In en, this message translates to:
  /// **'Muay Thai'**
  String get planDisciplineMuayThai;

  /// No description provided for @planDisciplineWrestling.
  ///
  /// In en, this message translates to:
  /// **'Wrestling'**
  String get planDisciplineWrestling;

  /// No description provided for @planDisciplineBjj.
  ///
  /// In en, this message translates to:
  /// **'BJJ'**
  String get planDisciplineBjj;

  /// No description provided for @planDisciplineMma.
  ///
  /// In en, this message translates to:
  /// **'MMA'**
  String get planDisciplineMma;

  /// No description provided for @planSessionMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String planSessionMinutes(int minutes);

  /// No description provided for @planSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{discipline} · {minutes} min'**
  String planSessionSubtitle(String discipline, int minutes);

  /// No description provided for @planStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get planStatusSkipped;

  /// No description provided for @planStatusNotDone.
  ///
  /// In en, this message translates to:
  /// **'Not done'**
  String get planStatusNotDone;

  /// No description provided for @planStatusMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved to {day}'**
  String planStatusMovedTo(String day);

  /// No description provided for @planStatusMovedFrom.
  ///
  /// In en, this message translates to:
  /// **'Moved from {day}'**
  String planStatusMovedFrom(String day);

  /// No description provided for @planActionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get planActionSkip;

  /// No description provided for @planActionMoveToToday.
  ///
  /// In en, this message translates to:
  /// **'Move to today'**
  String get planActionMoveToToday;

  /// No description provided for @planActionPutBack.
  ///
  /// In en, this message translates to:
  /// **'Put back'**
  String get planActionPutBack;

  /// No description provided for @planActionMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get planActionMore;

  /// No description provided for @trainingLogNamedSession.
  ///
  /// In en, this message translates to:
  /// **'Log {session}'**
  String trainingLogNamedSession(String session);

  /// No description provided for @trainTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get trainTools;

  /// No description provided for @trainTimerToolSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open intervals for sparring, MMA, boxing or BJJ'**
  String get trainTimerToolSubtitle;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingStep.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStep(int current, int total);

  /// No description provided for @onboardingSummary.
  ///
  /// In en, this message translates to:
  /// **'{days} days a week · {level} · {goal}'**
  String onboardingSummary(int days, String level, String goal);

  /// No description provided for @onboardingLoseFat.
  ///
  /// In en, this message translates to:
  /// **'Lose fat'**
  String get onboardingLoseFat;

  /// No description provided for @onboardingMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintain weight'**
  String get onboardingMaintain;

  /// No description provided for @onboardingGainMuscle.
  ///
  /// In en, this message translates to:
  /// **'Gain muscle'**
  String get onboardingGainMuscle;

  /// No description provided for @onboardingBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get onboardingBeginner;

  /// No description provided for @onboardingIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get onboardingIntermediate;

  /// No description provided for @onboardingAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get onboardingAdvanced;

  /// No description provided for @onboardingFighter.
  ///
  /// In en, this message translates to:
  /// **'Fighter'**
  String get onboardingFighter;

  /// No description provided for @welcomeProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'See your progress.'**
  String get welcomeProgressTitle;

  /// No description provided for @welcomeCampTitle.
  ///
  /// In en, this message translates to:
  /// **'Your camp, organised.'**
  String get welcomeCampTitle;

  /// No description provided for @welcomeCampBody.
  ///
  /// In en, this message translates to:
  /// **'Training week, weight and fuel in one place — built around the days you can actually train.'**
  String get welcomeCampBody;

  /// No description provided for @welcomeFuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel that matches the work.'**
  String get welcomeFuelTitle;

  /// No description provided for @welcomeFuelBody.
  ///
  /// In en, this message translates to:
  /// **'EdgeFuel sets your calories and macros from your body and your training load, then keeps score as you log.'**
  String get welcomeFuelBody;

  /// No description provided for @welcomeProgressBody.
  ///
  /// In en, this message translates to:
  /// **'Your training rhythm, weight trend and session history show progress week over week — not just today.'**
  String get welcomeProgressBody;

  /// No description provided for @welcomeWeeklyPlan.
  ///
  /// In en, this message translates to:
  /// **'Weekly plan'**
  String get welcomeWeeklyPlan;

  /// No description provided for @welcomeSessionLog.
  ///
  /// In en, this message translates to:
  /// **'Session log'**
  String get welcomeSessionLog;

  /// No description provided for @welcomeWeighIns.
  ///
  /// In en, this message translates to:
  /// **'Weigh-ins'**
  String get welcomeWeighIns;

  /// No description provided for @welcomeDailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily target'**
  String get welcomeDailyTarget;

  /// No description provided for @welcomeMacroSplit.
  ///
  /// In en, this message translates to:
  /// **'Macro split'**
  String get welcomeMacroSplit;

  /// No description provided for @welcomeMealLog.
  ///
  /// In en, this message translates to:
  /// **'Meal log'**
  String get welcomeMealLog;

  /// No description provided for @welcomeStreaks.
  ///
  /// In en, this message translates to:
  /// **'Consistency'**
  String get welcomeStreaks;

  /// No description provided for @welcomeWeightTrend.
  ///
  /// In en, this message translates to:
  /// **'Weight trend'**
  String get welcomeWeightTrend;

  /// No description provided for @welcomeHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get welcomeHistory;

  /// No description provided for @welcomeSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get welcomeSkip;

  /// No description provided for @welcomeBuildPlan.
  ///
  /// In en, this message translates to:
  /// **'Build my plan'**
  String get welcomeBuildPlan;

  /// No description provided for @welcomeDuration.
  ///
  /// In en, this message translates to:
  /// **'About 2 minutes · 7 quick questions'**
  String get welcomeDuration;

  /// No description provided for @welcomePage.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String welcomePage(int current, int total);

  /// No description provided for @setupCampEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Fresh account'**
  String get setupCampEyebrow;

  /// No description provided for @setupCampQuestion.
  ///
  /// In en, this message translates to:
  /// **'What should Fighter Edge build first?'**
  String get setupCampQuestion;

  /// No description provided for @setupCampHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the outcome that should shape your first training camp.'**
  String get setupCampHint;

  /// No description provided for @setupNutritionEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Nutrition goal'**
  String get setupNutritionEyebrow;

  /// No description provided for @setupNutritionQuestion.
  ///
  /// In en, this message translates to:
  /// **'What should EdgeFuel optimize for?'**
  String get setupNutritionQuestion;

  /// No description provided for @setupNutritionHint.
  ///
  /// In en, this message translates to:
  /// **'This creates your first calorie and macro target. You can edit it later.'**
  String get setupNutritionHint;

  /// No description provided for @setupBodyEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Body basics'**
  String get setupBodyEyebrow;

  /// No description provided for @setupBodyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Tell us your starting point.'**
  String get setupBodyQuestion;

  /// No description provided for @setupBodyHint.
  ///
  /// In en, this message translates to:
  /// **'No weight class needed. Use normal body details so your target is personal.'**
  String get setupBodyHint;

  /// No description provided for @setupEquationEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Calorie formula'**
  String get setupEquationEyebrow;

  /// No description provided for @setupEquationQuestion.
  ///
  /// In en, this message translates to:
  /// **'Which formula fits your body?'**
  String get setupEquationQuestion;

  /// No description provided for @setupEquationHint.
  ///
  /// In en, this message translates to:
  /// **'Calorie formulas differ slightly between male and female physiology — about 80 kcal a day either way. It only fine-tunes your estimate, so skip it if you\'d rather.'**
  String get setupEquationHint;

  /// No description provided for @setupActivityEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Daily activity'**
  String get setupActivityEyebrow;

  /// No description provided for @setupActivityQuestion.
  ///
  /// In en, this message translates to:
  /// **'Outside the gym, how active are you?'**
  String get setupActivityQuestion;

  /// No description provided for @setupActivityHint.
  ///
  /// In en, this message translates to:
  /// **'This is separate from training days so calories are not double-counted.'**
  String get setupActivityHint;

  /// No description provided for @setupRhythmEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Training rhythm'**
  String get setupRhythmEyebrow;

  /// No description provided for @setupRhythmQuestion.
  ///
  /// In en, this message translates to:
  /// **'How many days can you train?'**
  String get setupRhythmQuestion;

  /// No description provided for @setupRhythmHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a realistic week. Consistency beats an impossible plan.'**
  String get setupRhythmHint;

  /// No description provided for @setupReviewEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get setupReviewEyebrow;

  /// No description provided for @setupReviewQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your first plan is ready.'**
  String get setupReviewQuestion;

  /// No description provided for @setupReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Fighter Edge will start you fresh: clean dashboard, training week, and an EdgeFuel target.'**
  String get setupReviewHint;

  /// No description provided for @setupCampStructure.
  ///
  /// In en, this message translates to:
  /// **'Build fight-camp structure'**
  String get setupCampStructure;

  /// No description provided for @setupCampLoseWeight.
  ///
  /// In en, this message translates to:
  /// **'Lose weight safely'**
  String get setupCampLoseWeight;

  /// No description provided for @setupCampGainMuscle.
  ///
  /// In en, this message translates to:
  /// **'Gain muscle'**
  String get setupCampGainMuscle;

  /// No description provided for @setupCampTechnique.
  ///
  /// In en, this message translates to:
  /// **'Improve technique'**
  String get setupCampTechnique;

  /// No description provided for @setupCampCompetition.
  ///
  /// In en, this message translates to:
  /// **'Get competition ready'**
  String get setupCampCompetition;

  /// No description provided for @setupGoalLoseDescription.
  ///
  /// In en, this message translates to:
  /// **'Reduce body fat while preserving strength and training quality.'**
  String get setupGoalLoseDescription;

  /// No description provided for @setupGoalMaintainLabel.
  ///
  /// In en, this message translates to:
  /// **'Maintain'**
  String get setupGoalMaintainLabel;

  /// No description provided for @setupGoalMaintainDescription.
  ///
  /// In en, this message translates to:
  /// **'Hold your current weight and support consistent performance.'**
  String get setupGoalMaintainDescription;

  /// No description provided for @setupGoalGainDescription.
  ///
  /// In en, this message translates to:
  /// **'Build muscle with a controlled calorie surplus.'**
  String get setupGoalGainDescription;

  /// No description provided for @setupEquationHigher.
  ///
  /// In en, this message translates to:
  /// **'Male physiology'**
  String get setupEquationHigher;

  /// No description provided for @setupEquationLower.
  ///
  /// In en, this message translates to:
  /// **'Female physiology'**
  String get setupEquationLower;

  /// No description provided for @setupEquationNeutral.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get setupEquationNeutral;

  /// No description provided for @setupEquationHigherHint.
  ///
  /// In en, this message translates to:
  /// **'The standard formula for male bodies.'**
  String get setupEquationHigherHint;

  /// No description provided for @setupEquationLowerHint.
  ///
  /// In en, this message translates to:
  /// **'The standard formula for female bodies.'**
  String get setupEquationLowerHint;

  /// No description provided for @setupEquationNeutralHint.
  ///
  /// In en, this message translates to:
  /// **'We\'ll use the midpoint and show a slightly wider range.'**
  String get setupEquationNeutralHint;

  /// No description provided for @setupActivityVeryLow.
  ///
  /// In en, this message translates to:
  /// **'Very low'**
  String get setupActivityVeryLow;

  /// No description provided for @setupActivityLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get setupActivityLight;

  /// No description provided for @setupActivityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get setupActivityModerate;

  /// No description provided for @setupActivityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get setupActivityHigh;

  /// No description provided for @setupActivityVeryHigh.
  ///
  /// In en, this message translates to:
  /// **'Very high'**
  String get setupActivityVeryHigh;

  /// No description provided for @setupActivityVeryLowHint.
  ///
  /// In en, this message translates to:
  /// **'Mostly sitting — desk job, minimal walking.'**
  String get setupActivityVeryLowHint;

  /// No description provided for @setupActivityLightHint.
  ///
  /// In en, this message translates to:
  /// **'On your feet sometimes — teaching, light retail, short walks.'**
  String get setupActivityLightHint;

  /// No description provided for @setupActivityModerateHint.
  ///
  /// In en, this message translates to:
  /// **'Regularly active — physical job, daily walking, errands on foot.'**
  String get setupActivityModerateHint;

  /// No description provided for @setupActivityHighHint.
  ///
  /// In en, this message translates to:
  /// **'Very active day-to-day — physical labor, long shifts on your feet.'**
  String get setupActivityHighHint;

  /// No description provided for @setupActivityVeryHighHint.
  ///
  /// In en, this message translates to:
  /// **'Constant movement — manual labor, courier work, farming.'**
  String get setupActivityVeryHighHint;

  /// No description provided for @setupAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get setupAge;

  /// No description provided for @setupHeight.
  ///
  /// In en, this message translates to:
  /// **'Height cm'**
  String get setupHeight;

  /// No description provided for @setupCurrentWeight.
  ///
  /// In en, this message translates to:
  /// **'Current weight kg'**
  String get setupCurrentWeight;

  /// No description provided for @setupTargetMilestone.
  ///
  /// In en, this message translates to:
  /// **'Target milestone in kg'**
  String get setupTargetMilestone;

  /// No description provided for @setupGainMilestone.
  ///
  /// In en, this message translates to:
  /// **'Gain milestone in kg'**
  String get setupGainMilestone;

  /// No description provided for @setupOptionalMilestone.
  ///
  /// In en, this message translates to:
  /// **'Optional: leave blank and Fighter Edge starts with a safe 5% milestone.'**
  String get setupOptionalMilestone;

  /// No description provided for @setupSummaryCamp.
  ///
  /// In en, this message translates to:
  /// **'Camp'**
  String get setupSummaryCamp;

  /// No description provided for @setupSummaryNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get setupSummaryNutrition;

  /// No description provided for @setupSummaryExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get setupSummaryExperience;

  /// No description provided for @setupSummaryTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get setupSummaryTraining;

  /// No description provided for @setupSummaryActivity.
  ///
  /// In en, this message translates to:
  /// **'Daily activity'**
  String get setupSummaryActivity;

  /// No description provided for @setupDaysPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day per week} other{{count} days per week}}'**
  String setupDaysPerWeek(int count);

  /// No description provided for @setupDaysUnit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day per week} other{days per week}}'**
  String setupDaysUnit(int count);

  /// No description provided for @setupFewerDays.
  ///
  /// In en, this message translates to:
  /// **'Fewer days'**
  String get setupFewerDays;

  /// No description provided for @setupMoreDays.
  ///
  /// In en, this message translates to:
  /// **'More days'**
  String get setupMoreDays;

  /// No description provided for @setupCreatingPlan.
  ///
  /// In en, this message translates to:
  /// **'Creating your plan...'**
  String get setupCreatingPlan;

  /// No description provided for @setupStartPlan.
  ///
  /// In en, this message translates to:
  /// **'Start my plan'**
  String get setupStartPlan;

  /// No description provided for @setupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get setupContinue;

  /// No description provided for @setupSkipTarget.
  ///
  /// In en, this message translates to:
  /// **'Skip detailed target for now'**
  String get setupSkipTarget;

  /// No description provided for @setupSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save setup. Try again.'**
  String get setupSaveError;

  /// No description provided for @setupBodyMissing.
  ///
  /// In en, this message translates to:
  /// **'Complete your body details first.'**
  String get setupBodyMissing;

  /// No description provided for @setupReviewNeeded.
  ///
  /// In en, this message translates to:
  /// **'These details need review before we create a target.'**
  String get setupReviewNeeded;

  /// No description provided for @setupOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open your plan. Try again.'**
  String get setupOpenError;

  /// No description provided for @setupAgeError.
  ///
  /// In en, this message translates to:
  /// **'Enter an age from 18 to 90 for automated targets.'**
  String get setupAgeError;

  /// No description provided for @setupHeightError.
  ///
  /// In en, this message translates to:
  /// **'Enter height in cm, for example 178.'**
  String get setupHeightError;

  /// No description provided for @setupWeightError.
  ///
  /// In en, this message translates to:
  /// **'Enter current weight in kg, from 35 to 220 (for example 78).'**
  String get setupWeightError;

  /// No description provided for @setupScreeningError.
  ///
  /// In en, this message translates to:
  /// **'Review every health question before creating a target.'**
  String get setupScreeningError;

  /// No description provided for @setupTargetError.
  ///
  /// In en, this message translates to:
  /// **'Target weight should be a realistic kg value.'**
  String get setupTargetError;

  /// No description provided for @setupLossTargetError.
  ///
  /// In en, this message translates to:
  /// **'For weight loss, target weight should be below current weight.'**
  String get setupLossTargetError;

  /// No description provided for @setupGainTargetError.
  ///
  /// In en, this message translates to:
  /// **'For weight gain, target weight should be above current weight.'**
  String get setupGainTargetError;

  /// No description provided for @setupHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick health check'**
  String get setupHealthTitle;

  /// No description provided for @setupHealthHint.
  ///
  /// In en, this message translates to:
  /// **'We store only yes/no flags, never details. If any apply, we\'ll ask you to check with a qualified professional before showing an automated plan.'**
  String get setupHealthHint;

  /// No description provided for @setupHealthPregnant.
  ///
  /// In en, this message translates to:
  /// **'Pregnant or breastfeeding'**
  String get setupHealthPregnant;

  /// No description provided for @setupHealthEatingDisorder.
  ///
  /// In en, this message translates to:
  /// **'Eating-disorder history or symptoms'**
  String get setupHealthEatingDisorder;

  /// No description provided for @setupHealthDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Diabetes requiring medication'**
  String get setupHealthDiabetes;

  /// No description provided for @setupHealthKidney.
  ///
  /// In en, this message translates to:
  /// **'Kidney disease'**
  String get setupHealthKidney;

  /// No description provided for @setupHealthLiver.
  ///
  /// In en, this message translates to:
  /// **'Serious liver disease'**
  String get setupHealthLiver;

  /// No description provided for @setupHealthOtherDiet.
  ///
  /// In en, this message translates to:
  /// **'Another clinician-managed diet'**
  String get setupHealthOtherDiet;

  /// No description provided for @setupHealthReviewed.
  ///
  /// In en, this message translates to:
  /// **'I reviewed every health question'**
  String get setupHealthReviewed;

  /// No description provided for @setupReasonScreeningUnanswered.
  ///
  /// In en, this message translates to:
  /// **'Review the health questions before an automated target can be shown.'**
  String get setupReasonScreeningUnanswered;

  /// No description provided for @setupReasonScreeningNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Please check with a qualified professional before an automated plan.'**
  String get setupReasonScreeningNeedsReview;

  /// No description provided for @setupReasonUnderAge.
  ///
  /// In en, this message translates to:
  /// **'Automated plans are only available to adults 18 and over.'**
  String get setupReasonUnderAge;

  /// No description provided for @setupReasonInvalidVitals.
  ///
  /// In en, this message translates to:
  /// **'Height, weight, or age don\'t look like valid numbers.'**
  String get setupReasonInvalidVitals;

  /// No description provided for @setupReasonUnderweight.
  ///
  /// In en, this message translates to:
  /// **'Your current stats indicate an underweight range, so an automated fat-loss plan is blocked.'**
  String get setupReasonUnderweight;

  /// No description provided for @setupReasonInvalidFatLoss.
  ///
  /// In en, this message translates to:
  /// **'Your target weight should be below your current weight for a fat-loss plan.'**
  String get setupReasonInvalidFatLoss;

  /// No description provided for @setupReasonInvalidMuscleGain.
  ///
  /// In en, this message translates to:
  /// **'Your target weight should be above your current weight for a muscle-gain plan.'**
  String get setupReasonInvalidMuscleGain;

  /// No description provided for @setupReasonMissingTarget.
  ///
  /// In en, this message translates to:
  /// **'A target weight is needed for this goal.'**
  String get setupReasonMissingTarget;

  /// No description provided for @setupReasonMissingPace.
  ///
  /// In en, this message translates to:
  /// **'A pace is needed for this goal.'**
  String get setupReasonMissingPace;

  /// No description provided for @setupReasonRmrRange.
  ///
  /// In en, this message translates to:
  /// **'Your inputs produced an estimate outside a safe range — double-check height, weight, and age.'**
  String get setupReasonRmrRange;

  /// No description provided for @fuelSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel setup'**
  String get fuelSetupTitle;

  /// No description provided for @fuelSetupSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to set up EdgeFuel.'**
  String get fuelSetupSignIn;

  /// No description provided for @fuelStepGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get fuelStepGoal;

  /// No description provided for @fuelStepBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get fuelStepBody;

  /// No description provided for @fuelStepActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get fuelStepActivity;

  /// No description provided for @fuelStepTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get fuelStepTraining;

  /// No description provided for @fuelStepFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get fuelStepFood;

  /// No description provided for @fuelStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get fuelStepReview;

  /// No description provided for @fuelStepProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total} · {title}'**
  String fuelStepProgress(int current, int total, String title);

  /// No description provided for @fuelSetupNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get fuelSetupNext;

  /// No description provided for @fuelSetupSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your Fuel plan. Try again.'**
  String get fuelSetupSaveError;

  /// No description provided for @fuelGoalQuestion.
  ///
  /// In en, this message translates to:
  /// **'What are you training for?'**
  String get fuelGoalQuestion;

  /// No description provided for @fuelGoalHint.
  ///
  /// In en, this message translates to:
  /// **'This sets the direction of your plan. You can adjust the pace later.'**
  String get fuelGoalHint;

  /// No description provided for @fuelBodyQuestion.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your body'**
  String get fuelBodyQuestion;

  /// No description provided for @fuelBodyHint.
  ///
  /// In en, this message translates to:
  /// **'Used only to estimate your energy needs — never shown publicly.'**
  String get fuelBodyHint;

  /// No description provided for @fuelAge.
  ///
  /// In en, this message translates to:
  /// **'Age in years'**
  String get fuelAge;

  /// No description provided for @fuelHeight.
  ///
  /// In en, this message translates to:
  /// **'Height in cm'**
  String get fuelHeight;

  /// No description provided for @fuelCurrentWeight.
  ///
  /// In en, this message translates to:
  /// **'Current weight in kg'**
  String get fuelCurrentWeight;

  /// No description provided for @fuelTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'Target weight in kg'**
  String get fuelTargetWeight;

  /// No description provided for @fuelActivityQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your normal activity'**
  String get fuelActivityQuestion;

  /// No description provided for @fuelActivityHint.
  ///
  /// In en, this message translates to:
  /// **'Day-to-day movement outside training — Fighter Edge sessions are counted separately next.'**
  String get fuelActivityHint;

  /// No description provided for @fuelTrainingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Your training week'**
  String get fuelTrainingQuestion;

  /// No description provided for @fuelTrainingHint.
  ///
  /// In en, this message translates to:
  /// **'Fighter Edge sessions per week — used so we never double-count training inside your activity level.'**
  String get fuelTrainingHint;

  /// No description provided for @fuelFewerDays.
  ///
  /// In en, this message translates to:
  /// **'Fewer training days per week'**
  String get fuelFewerDays;

  /// No description provided for @fuelMoreDays.
  ///
  /// In en, this message translates to:
  /// **'More training days per week'**
  String get fuelMoreDays;

  /// No description provided for @fuelDaysUnit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day / week} other{days / week}}'**
  String fuelDaysUnit(int count);

  /// No description provided for @fuelPaceQuestion.
  ///
  /// In en, this message translates to:
  /// **'How fast?'**
  String get fuelPaceQuestion;

  /// No description provided for @fuelPaceGentle.
  ///
  /// In en, this message translates to:
  /// **'Gentle'**
  String get fuelPaceGentle;

  /// No description provided for @fuelPaceStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get fuelPaceStandard;

  /// No description provided for @fuelPaceUpper.
  ///
  /// In en, this message translates to:
  /// **'Upper limit'**
  String get fuelPaceUpper;

  /// No description provided for @fuelPaceConservative.
  ///
  /// In en, this message translates to:
  /// **'Conservative'**
  String get fuelPaceConservative;

  /// No description provided for @fuelPaceGentleHint.
  ///
  /// In en, this message translates to:
  /// **'~0.25% body weight per week.'**
  String get fuelPaceGentleHint;

  /// No description provided for @fuelPaceStandardHint.
  ///
  /// In en, this message translates to:
  /// **'~0.5% body weight per week — recommended.'**
  String get fuelPaceStandardHint;

  /// No description provided for @fuelPaceUpperHint.
  ///
  /// In en, this message translates to:
  /// **'~0.75% body weight per week, the automated limit.'**
  String get fuelPaceUpperHint;

  /// No description provided for @fuelPaceConservativeHint.
  ///
  /// In en, this message translates to:
  /// **'~0.10–0.25% body weight per week.'**
  String get fuelPaceConservativeHint;

  /// No description provided for @fuelPaceGainHint.
  ///
  /// In en, this message translates to:
  /// **'~0.25–0.50% body weight per week — recommended.'**
  String get fuelPaceGainHint;

  /// No description provided for @fuelFoodQuestion.
  ///
  /// In en, this message translates to:
  /// **'Food preferences'**
  String get fuelFoodQuestion;

  /// No description provided for @fuelFoodHint.
  ///
  /// In en, this message translates to:
  /// **'Optional now — shapes meal suggestions once recipes launch.'**
  String get fuelFoodHint;

  /// No description provided for @fuelDietType.
  ///
  /// In en, this message translates to:
  /// **'Diet type'**
  String get fuelDietType;

  /// No description provided for @fuelDietOmnivore.
  ///
  /// In en, this message translates to:
  /// **'Omnivore'**
  String get fuelDietOmnivore;

  /// No description provided for @fuelDietVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get fuelDietVegetarian;

  /// No description provided for @fuelDietVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get fuelDietVegan;

  /// No description provided for @fuelDietPescatarian.
  ///
  /// In en, this message translates to:
  /// **'Pescatarian'**
  String get fuelDietPescatarian;

  /// No description provided for @fuelDietHalal.
  ///
  /// In en, this message translates to:
  /// **'Halal'**
  String get fuelDietHalal;

  /// No description provided for @fuelAllergens.
  ///
  /// In en, this message translates to:
  /// **'Allergens (comma-separated)'**
  String get fuelAllergens;

  /// No description provided for @fuelDislikes.
  ///
  /// In en, this message translates to:
  /// **'Disliked foods (comma-separated)'**
  String get fuelDislikes;

  /// No description provided for @fuelMealsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Meals per day'**
  String get fuelMealsPerDay;

  /// No description provided for @fuelFewerMeals.
  ///
  /// In en, this message translates to:
  /// **'Fewer meals per day'**
  String get fuelFewerMeals;

  /// No description provided for @fuelMoreMeals.
  ///
  /// In en, this message translates to:
  /// **'More meals per day'**
  String get fuelMoreMeals;

  /// No description provided for @fuelBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get fuelBudget;

  /// No description provided for @fuelBudgetLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get fuelBudgetLow;

  /// No description provided for @fuelBudgetMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get fuelBudgetMedium;

  /// No description provided for @fuelBudgetHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get fuelBudgetHigh;

  /// No description provided for @fuelCookingTime.
  ///
  /// In en, this message translates to:
  /// **'Cooking time available'**
  String get fuelCookingTime;

  /// No description provided for @fuelCookingQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get fuelCookingQuick;

  /// No description provided for @fuelCookingModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get fuelCookingModerate;

  /// No description provided for @fuelCookingExtended.
  ///
  /// In en, this message translates to:
  /// **'Extended'**
  String get fuelCookingExtended;

  /// No description provided for @fuelReviewMoreSteps.
  ///
  /// In en, this message translates to:
  /// **'A few steps left'**
  String get fuelReviewMoreSteps;

  /// No description provided for @fuelReviewMoreStepsHint.
  ///
  /// In en, this message translates to:
  /// **'Finish the earlier steps to see your personalized plan.'**
  String get fuelReviewMoreStepsHint;

  /// No description provided for @fuelReviewUnsupported.
  ///
  /// In en, this message translates to:
  /// **'We can\'t automate this yet'**
  String get fuelReviewUnsupported;

  /// No description provided for @fuelReviewProfessional.
  ///
  /// In en, this message translates to:
  /// **'Please check with a professional first'**
  String get fuelReviewProfessional;

  /// No description provided for @fuelReviewProfessionalIntro.
  ///
  /// In en, this message translates to:
  /// **'Based on what you shared, an automated plan isn\'t appropriate here:'**
  String get fuelReviewProfessionalIntro;

  /// No description provided for @fuelReviewProfessionalOutro.
  ///
  /// In en, this message translates to:
  /// **'Speak with a qualified professional before starting an automated plan. You can still track meals and habits without calorie targets.'**
  String get fuelReviewProfessionalOutro;

  /// No description provided for @fuelReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get fuelReviewTitle;

  /// No description provided for @fuelReviewHint.
  ///
  /// In en, this message translates to:
  /// **'An estimate, not a diagnosis. You can revisit this any time.'**
  String get fuelReviewHint;

  /// No description provided for @fuelReviewDailyTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily target'**
  String get fuelReviewDailyTarget;

  /// No description provided for @fuelReviewMaintenanceRange.
  ///
  /// In en, this message translates to:
  /// **'Maintenance range {low}–{high} kcal'**
  String fuelReviewMaintenanceRange(String low, String high);

  /// No description provided for @fuelReviewAssumptions.
  ///
  /// In en, this message translates to:
  /// **'Assumptions'**
  String get fuelReviewAssumptions;

  /// No description provided for @fuelReviewGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get fuelReviewGoal;

  /// No description provided for @fuelReviewEquation.
  ///
  /// In en, this message translates to:
  /// **'Equation'**
  String get fuelReviewEquation;

  /// No description provided for @fuelReviewActivity.
  ///
  /// In en, this message translates to:
  /// **'Daily activity'**
  String get fuelReviewActivity;

  /// No description provided for @fuelReviewPace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get fuelReviewPace;

  /// No description provided for @fuelReviewProteinBasedOn.
  ///
  /// In en, this message translates to:
  /// **'Protein based on'**
  String get fuelReviewProteinBasedOn;

  /// No description provided for @fuelReviewConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get fuelReviewConfidence;

  /// No description provided for @fuelReviewFiber.
  ///
  /// In en, this message translates to:
  /// **'Fiber range'**
  String get fuelReviewFiber;

  /// No description provided for @fuelReviewWorthKnowing.
  ///
  /// In en, this message translates to:
  /// **'Worth knowing'**
  String get fuelReviewWorthKnowing;

  /// No description provided for @fuelReviewConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm my plan'**
  String get fuelReviewConfirm;

  /// No description provided for @fuelReviewFooter.
  ///
  /// In en, this message translates to:
  /// **'You can hide calorie numbers and use meal tracking only, or adjust these targets later in Fuel settings.'**
  String get fuelReviewFooter;

  /// No description provided for @fuelConfidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High confidence'**
  String get fuelConfidenceHigh;

  /// No description provided for @fuelConfidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium confidence'**
  String get fuelConfidenceMedium;

  /// No description provided for @fuelConfidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get fuelConfidenceLow;

  /// No description provided for @fuelWarningRmr.
  ///
  /// In en, this message translates to:
  /// **'Your pace was reduced so your target never drops below your estimated resting energy.'**
  String get fuelWarningRmr;

  /// No description provided for @fuelWarningCarbs.
  ///
  /// In en, this message translates to:
  /// **'Your deficit was reduced to keep enough carbohydrate for high training load.'**
  String get fuelWarningCarbs;

  /// No description provided for @fuelWarningProtein.
  ///
  /// In en, this message translates to:
  /// **'Even at maintenance calories, this protein target leaves little room for carbohydrate — consider a lower protein target or lighter training load.'**
  String get fuelWarningProtein;

  /// No description provided for @fuelWarningZeroCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbohydrate grams were clamped to zero after fat and protein were allocated.'**
  String get fuelWarningZeroCarbs;

  /// No description provided for @fuelPlanEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plan yet'**
  String get fuelPlanEmpty;

  /// No description provided for @fuelPlanEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Run the EdgeFuel setup to get a personalized daily target.'**
  String get fuelPlanEmptyHint;

  /// No description provided for @fuelPlanStart.
  ///
  /// In en, this message translates to:
  /// **'Start setup'**
  String get fuelPlanStart;

  /// No description provided for @fuelPlanCalculationTitle.
  ///
  /// In en, this message translates to:
  /// **'How this was calculated'**
  String get fuelPlanCalculationTitle;

  /// No description provided for @fuelPlanMidpoint.
  ///
  /// In en, this message translates to:
  /// **'midpoint'**
  String get fuelPlanMidpoint;

  /// No description provided for @fuelPlanCalculation.
  ///
  /// In en, this message translates to:
  /// **'Estimated resting energy: {rmr} kcal (Mifflin–St Jeor, {equation}). Multiplied by your activity factor, then adjusted for your goal pace. This is an estimate, not a diagnosis — recalculate any time by revisiting setup.'**
  String fuelPlanCalculation(String rmr, String equation);

  /// No description provided for @fuelPlanRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo setup'**
  String get fuelPlanRedo;

  /// No description provided for @planReadyExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your plan is based on your goals and training days. You can adjust it as your training changes.'**
  String get planReadyExplanation;

  /// No description provided for @planReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first Fighter Edge plan is ready'**
  String get planReadyTitle;

  /// No description provided for @planReadyReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Continue read-only'**
  String get planReadyReadOnly;

  /// No description provided for @planReadyDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Targets are estimates, not medical advice. Review your inputs anytime in EdgeFuel.'**
  String get planReadyDisclaimer;

  /// No description provided for @planReadyCalories.
  ///
  /// In en, this message translates to:
  /// **'Daily calories'**
  String get planReadyCalories;

  /// No description provided for @planReadyMissingTarget.
  ///
  /// In en, this message translates to:
  /// **'Your training week is ready. Add body details in Fuel to calculate a daily target.'**
  String get planReadyMissingTarget;

  /// No description provided for @profileFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get profileFreePlan;

  /// No description provided for @profileProActive.
  ///
  /// In en, this message translates to:
  /// **'Pro subscription active'**
  String get profileProActive;

  /// No description provided for @profileProDescription.
  ///
  /// In en, this message translates to:
  /// **'Camp plans, session mode, and the full drill library'**
  String get profileProDescription;

  /// No description provided for @profileUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get profileUpgrade;

  /// No description provided for @profileManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get profileManage;

  /// No description provided for @settingsProPlan.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get settingsProPlan;

  /// No description provided for @settingsFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get settingsFreePlan;

  /// No description provided for @dashboardEffort.
  ///
  /// In en, this message translates to:
  /// **'Effort {rating}/10'**
  String dashboardEffort(int rating);

  /// No description provided for @paywallPlainTitle.
  ///
  /// In en, this message translates to:
  /// **'Your camp, planned and fueled'**
  String get paywallPlainTitle;

  /// No description provided for @paywallPlainSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One plan. Everything in Fighter Edge.'**
  String get paywallPlainSubtitle;

  /// No description provided for @fuelRecipesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipes for your day'**
  String get fuelRecipesTitle;

  /// No description provided for @paywallBenefitDrillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Drill Library'**
  String get paywallBenefitDrillsTitle;

  /// No description provided for @paywallBenefitDrillsBody.
  ///
  /// In en, this message translates to:
  /// **'Every striking, wrestling, BJJ and clinch drill, with how to train it.'**
  String get paywallBenefitDrillsBody;

  /// No description provided for @paywallAnnualPlan.
  ///
  /// In en, this message translates to:
  /// **'Annual plan'**
  String get paywallAnnualPlan;

  /// No description provided for @paywallMonthlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Monthly plan'**
  String get paywallMonthlyPlan;

  /// No description provided for @paywallBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get paywallBestValue;

  /// No description provided for @paywallContinueAnnual.
  ///
  /// In en, this message translates to:
  /// **'Continue with annual plan'**
  String get paywallContinueAnnual;

  /// No description provided for @paywallContinueMonthly.
  ///
  /// In en, this message translates to:
  /// **'Continue with monthly plan'**
  String get paywallContinueMonthly;

  /// No description provided for @paywallTrust.
  ///
  /// In en, this message translates to:
  /// **'Secure checkout by Google Play or the App Store. Cancel anytime in your store account.'**
  String get paywallTrust;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestore;

  /// No description provided for @paywallRefreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh purchase status'**
  String get paywallRefreshStatus;

  /// No description provided for @paywallManage.
  ///
  /// In en, this message translates to:
  /// **'Manage or cancel subscription'**
  String get paywallManage;

  /// No description provided for @paywallOnPro.
  ///
  /// In en, this message translates to:
  /// **'You\'re on Pro'**
  String get paywallOnPro;

  /// No description provided for @paywallOnProRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get paywallOnProRefresh;

  /// No description provided for @paywallLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading store plans…'**
  String get paywallLoading;

  /// No description provided for @paywallSync.
  ///
  /// In en, this message translates to:
  /// **'Your store purchase is recognized. Pro unlocks after the secure account sync completes.'**
  String get paywallSync;

  /// No description provided for @paywallPurchaseActive.
  ///
  /// In en, this message translates to:
  /// **'Pro is active on your account.'**
  String get paywallPurchaseActive;

  /// No description provided for @paywallPurchasePending.
  ///
  /// In en, this message translates to:
  /// **'Purchase received. We are confirming your Pro access securely.'**
  String get paywallPurchasePending;

  /// No description provided for @paywallRestored.
  ///
  /// In en, this message translates to:
  /// **'Your Pro access is restored.'**
  String get paywallRestored;

  /// No description provided for @paywallNothingToRestore.
  ///
  /// In en, this message translates to:
  /// **'No active Pro access was found yet.'**
  String get paywallNothingToRestore;

  /// No description provided for @paywallPerYear.
  ///
  /// In en, this message translates to:
  /// **'{price} / year'**
  String paywallPerYear(String price);

  /// No description provided for @paywallPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String paywallPerMonth(String price);

  /// No description provided for @paywallAboutPerMonth.
  ///
  /// In en, this message translates to:
  /// **'About {price} / month'**
  String paywallAboutPerMonth(String price);

  /// No description provided for @paywallSave.
  ///
  /// In en, this message translates to:
  /// **'Save about {percent}%'**
  String paywallSave(int percent);

  /// No description provided for @fuelMealsLogged.
  ///
  /// In en, this message translates to:
  /// **'Meals logged · {eaten}/{total}'**
  String fuelMealsLogged(int eaten, int total);

  /// No description provided for @learningStart.
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get learningStart;

  /// No description provided for @learningChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a discipline'**
  String get learningChoose;

  /// No description provided for @learningChooseHint.
  ///
  /// In en, this message translates to:
  /// **'We will remember your choice on this account. You can change it any time.'**
  String get learningChooseHint;

  /// No description provided for @learningChange.
  ///
  /// In en, this message translates to:
  /// **'Change path'**
  String get learningChange;

  /// No description provided for @learningStriking.
  ///
  /// In en, this message translates to:
  /// **'Striking'**
  String get learningStriking;

  /// No description provided for @learningWrestling.
  ///
  /// In en, this message translates to:
  /// **'Wrestling'**
  String get learningWrestling;

  /// No description provided for @learningBjj.
  ///
  /// In en, this message translates to:
  /// **'BJJ'**
  String get learningBjj;

  /// No description provided for @learningClinch.
  ///
  /// In en, this message translates to:
  /// **'Clinch'**
  String get learningClinch;

  /// No description provided for @learningStrikingHint.
  ///
  /// In en, this message translates to:
  /// **'Learn punches, defence and kicks in order.'**
  String get learningStrikingHint;

  /// No description provided for @learningWrestlingHint.
  ///
  /// In en, this message translates to:
  /// **'Build your stance, then learn to take someone down and defend a takedown.'**
  String get learningWrestlingHint;

  /// No description provided for @learningBjjHint.
  ///
  /// In en, this message translates to:
  /// **'Brazilian jiu-jitsu: learn to move and escape when training on the ground.'**
  String get learningBjjHint;

  /// No description provided for @learningClinchHint.
  ///
  /// In en, this message translates to:
  /// **'Learn close-range holds, knees and control while standing.'**
  String get learningClinchHint;

  /// No description provided for @learningFoundations.
  ///
  /// In en, this message translates to:
  /// **'Foundations'**
  String get learningFoundations;

  /// No description provided for @learningBuilding.
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get learningBuilding;

  /// No description provided for @learningSharp.
  ///
  /// In en, this message translates to:
  /// **'Sharp'**
  String get learningSharp;

  /// No description provided for @learningCount.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} drills sharp'**
  String learningCount(int completed, int total);

  /// No description provided for @learningLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn: {drill}'**
  String learningLearn(String drill);

  /// No description provided for @learningLocked.
  ///
  /// In en, this message translates to:
  /// **'Pro drill · path paused'**
  String get learningLocked;

  /// No description provided for @learningViewPro.
  ///
  /// In en, this message translates to:
  /// **'View Pro options'**
  String get learningViewPro;

  /// No description provided for @learningComplete.
  ///
  /// In en, this message translates to:
  /// **'Path complete'**
  String get learningComplete;

  /// No description provided for @learningCompleteHint.
  ///
  /// In en, this message translates to:
  /// **'Keep practising these drills, or choose another discipline.'**
  String get learningCompleteHint;

  /// No description provided for @learningProgressHint.
  ///
  /// In en, this message translates to:
  /// **'Sharp means you can repeat the drill with control.'**
  String get learningProgressHint;

  /// No description provided for @learningNext.
  ///
  /// In en, this message translates to:
  /// **'Next in your path'**
  String get learningNext;

  /// No description provided for @learningAfter.
  ///
  /// In en, this message translates to:
  /// **'After this drill: {drill}'**
  String learningAfter(String drill);

  /// No description provided for @learningKeepPractising.
  ///
  /// In en, this message translates to:
  /// **'Keep practising this drill. Mark it Sharp when you can repeat it with control to advance your path.'**
  String get learningKeepPractising;

  /// No description provided for @learningPractiseLast.
  ///
  /// In en, this message translates to:
  /// **'This is the last drill in your path. Keep practising, then mark it Sharp when you are ready.'**
  String get learningPractiseLast;

  /// No description provided for @fightAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your next fight'**
  String get fightAddTitle;

  /// No description provided for @fightAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Countdown and a safe weight path'**
  String get fightAddSubtitle;

  /// No description provided for @fightSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Your fight'**
  String get fightSetupTitle;

  /// No description provided for @fightDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Fight date'**
  String get fightDateLabel;

  /// No description provided for @fightDatePick.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get fightDatePick;

  /// No description provided for @fightWeighInLabel.
  ///
  /// In en, this message translates to:
  /// **'Weigh-in'**
  String get fightWeighInLabel;

  /// No description provided for @fightWeighInSameDay.
  ///
  /// In en, this message translates to:
  /// **'Same day'**
  String get fightWeighInSameDay;

  /// No description provided for @fightWeighInDayBefore.
  ///
  /// In en, this message translates to:
  /// **'Day before'**
  String get fightWeighInDayBefore;

  /// No description provided for @fightWeighInTwoDays.
  ///
  /// In en, this message translates to:
  /// **'2 days before'**
  String get fightWeighInTwoDays;

  /// No description provided for @fightLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight limit ({unit})'**
  String fightLimitLabel(String unit);

  /// No description provided for @fightLimitError.
  ///
  /// In en, this message translates to:
  /// **'Enter a limit between {min} and {max} {unit}.'**
  String fightLimitError(String min, String max, String unit);

  /// No description provided for @fightCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Competition'**
  String get fightCategoryLabel;

  /// No description provided for @fightCategoryWhy.
  ///
  /// In en, this message translates to:
  /// **'This sets how much can safely come off in the final days.'**
  String get fightCategoryWhy;

  /// No description provided for @fightCategoryGrappling.
  ///
  /// In en, this message translates to:
  /// **'Wrestling and grappling'**
  String get fightCategoryGrappling;

  /// No description provided for @fightCategoryGrapplingHint.
  ///
  /// In en, this message translates to:
  /// **'Wrestling, BJJ, ADCC'**
  String get fightCategoryGrapplingHint;

  /// No description provided for @fightCategoryAmateur.
  ///
  /// In en, this message translates to:
  /// **'Amateur striking'**
  String get fightCategoryAmateur;

  /// No description provided for @fightCategoryAmateurHint.
  ///
  /// In en, this message translates to:
  /// **'Amateur boxing, amateur Muay Thai'**
  String get fightCategoryAmateurHint;

  /// No description provided for @fightCategoryOlympic.
  ///
  /// In en, this message translates to:
  /// **'Olympic combat sports'**
  String get fightCategoryOlympic;

  /// No description provided for @fightCategoryOlympicHint.
  ///
  /// In en, this message translates to:
  /// **'Judo, Olympic boxing, taekwondo'**
  String get fightCategoryOlympicHint;

  /// No description provided for @fightCategoryPro.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get fightCategoryPro;

  /// No description provided for @fightCategoryProHint.
  ///
  /// In en, this message translates to:
  /// **'Pro MMA, boxing, kickboxing, Muay Thai'**
  String get fightCategoryProHint;

  /// No description provided for @fightCampLabel.
  ///
  /// In en, this message translates to:
  /// **'Camp length'**
  String get fightCampLabel;

  /// No description provided for @fightCampWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String fightCampWeeks(int count);

  /// No description provided for @fightPathTitle.
  ///
  /// In en, this message translates to:
  /// **'Your weight path'**
  String get fightPathTitle;

  /// No description provided for @fightPathNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get fightPathNow;

  /// No description provided for @fightPathLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get fightPathLimit;

  /// No description provided for @fightPathToGo.
  ///
  /// In en, this message translates to:
  /// **'To go'**
  String get fightPathToGo;

  /// No description provided for @fightPathOnPace.
  ///
  /// In en, this message translates to:
  /// **'On pace: lose {rate} {unit} a week to reach {entry} {unit} by fight week.'**
  String fightPathOnPace(String rate, String entry, String unit);

  /// No description provided for @fightPathHold.
  ///
  /// In en, this message translates to:
  /// **'Within reach: hold your weight, and fight-week eating covers the rest.'**
  String get fightPathHold;

  /// No description provided for @fightPathSupervision.
  ///
  /// In en, this message translates to:
  /// **'Only possible with a water cut in the last days, which needs a coach or dietitian. Your camp is planned at the fastest safe pace. On food alone, the lightest limit you can make by then is {lightest} {unit}.'**
  String fightPathSupervision(String lightest, String unit);

  /// No description provided for @fightPathNotSafe.
  ///
  /// In en, this message translates to:
  /// **'Not safe by this date. The lightest limit you can make safely is {lightest} {unit}: choose a heavier class or a later fight.'**
  String fightPathNotSafe(String lightest, String unit);

  /// No description provided for @fightPathAtWeight.
  ///
  /// In en, this message translates to:
  /// **'You\'re at weight. Hold steady.'**
  String get fightPathAtWeight;

  /// No description provided for @fightPathNeedsWeight.
  ///
  /// In en, this message translates to:
  /// **'Log a weigh-in this week to see your path.'**
  String get fightPathNeedsWeight;

  /// No description provided for @fightPathNeedsScreening.
  ///
  /// In en, this message translates to:
  /// **'Complete Fuel setup to confirm adult eligibility and health screening before viewing weight guidance.'**
  String get fightPathNeedsScreening;

  /// No description provided for @fightPathStartScreening.
  ///
  /// In en, this message translates to:
  /// **'Complete Fuel setup'**
  String get fightPathStartScreening;

  /// No description provided for @fightPathProfessionalReview.
  ///
  /// In en, this message translates to:
  /// **'Your health answers need review by a qualified clinician or sports dietitian. Fighter Edge cannot plan a weight cut for you.'**
  String get fightPathProfessionalReview;

  /// No description provided for @fightPathAdultsOnly.
  ///
  /// In en, this message translates to:
  /// **'Weight cut plans are for adults. Plan your weight with your coach.'**
  String get fightPathAdultsOnly;

  /// No description provided for @fightPathSource.
  ///
  /// In en, this message translates to:
  /// **'Limits from the International Society of Sports Nutrition (2025).'**
  String get fightPathSource;

  /// No description provided for @fightSave.
  ///
  /// In en, this message translates to:
  /// **'Save fight'**
  String get fightSave;

  /// No description provided for @fightRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove fight'**
  String get fightRemove;

  /// No description provided for @fightRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this fight?'**
  String get fightRemoveTitle;

  /// No description provided for @fightRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Your countdown and weight path are cleared. You can add a fight again any time.'**
  String get fightRemoveBody;

  /// No description provided for @fightNight.
  ///
  /// In en, this message translates to:
  /// **'Fight night · {date}'**
  String fightNight(String date);

  /// No description provided for @fightDaysToGo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day to go} other{days to go}}'**
  String fightDaysToGo(int count);

  /// No description provided for @fightPhaseCamp.
  ///
  /// In en, this message translates to:
  /// **'Camp · week {week} of {total}'**
  String fightPhaseCamp(int week, int total);

  /// No description provided for @fightPhaseBeforeCamp.
  ///
  /// In en, this message translates to:
  /// **'Camp starts {date}'**
  String fightPhaseBeforeCamp(String date);

  /// No description provided for @fightPhaseFightWeek.
  ///
  /// In en, this message translates to:
  /// **'Fight week · day {day} of 7'**
  String fightPhaseFightWeek(int day);

  /// No description provided for @fightPhaseWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Weigh-in today'**
  String get fightPhaseWeighIn;

  /// No description provided for @fightPhaseRefuel.
  ///
  /// In en, this message translates to:
  /// **'Weighed in: refuel'**
  String get fightPhaseRefuel;

  /// No description provided for @fightPhaseWeighedIn.
  ///
  /// In en, this message translates to:
  /// **'Weighed in'**
  String get fightPhaseWeighedIn;

  /// No description provided for @fightPhaseFightDay.
  ///
  /// In en, this message translates to:
  /// **'Fight day'**
  String get fightPhaseFightDay;

  /// No description provided for @fightDone.
  ///
  /// In en, this message translates to:
  /// **'Fight done. Add your next one.'**
  String get fightDone;

  /// No description provided for @fightEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit fight'**
  String get fightEdit;

  /// No description provided for @fightPathShortSupervision.
  ///
  /// In en, this message translates to:
  /// **'Needs a supervised water cut. Tap to review.'**
  String get fightPathShortSupervision;

  /// No description provided for @fightPathShortNotSafe.
  ///
  /// In en, this message translates to:
  /// **'Not safe by this date. Tap to review.'**
  String get fightPathShortNotSafe;

  /// No description provided for @fightPathScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight path'**
  String get fightPathScreenTitle;

  /// No description provided for @fightCheckpointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly targets'**
  String get fightCheckpointsTitle;

  /// No description provided for @fightCheckpointFightWeek.
  ///
  /// In en, this message translates to:
  /// **'Fight week starts'**
  String get fightCheckpointFightWeek;

  /// No description provided for @fightChartLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit {value}'**
  String fightChartLimit(String value);

  /// No description provided for @fightChartToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get fightChartToday;

  /// No description provided for @fightChartWeighIns.
  ///
  /// In en, this message translates to:
  /// **'Weigh-ins'**
  String get fightChartWeighIns;

  /// No description provided for @fightChartTrend.
  ///
  /// In en, this message translates to:
  /// **'7-day trend'**
  String get fightChartTrend;

  /// No description provided for @fightChartPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get fightChartPlan;

  /// No description provided for @fightChartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Log two weigh-ins to draw your trend.'**
  String get fightChartEmpty;

  /// No description provided for @fightWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Fight week'**
  String get fightWeekTitle;

  /// No description provided for @fightWeekOpen.
  ///
  /// In en, this message translates to:
  /// **'Fight week plan'**
  String get fightWeekOpen;

  /// No description provided for @fightWeekStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String fightWeekStarts(String date);

  /// No description provided for @fightWeekWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Weigh-in · {date}'**
  String fightWeekWeighIn(String date);

  /// No description provided for @fightWeekCarbs.
  ///
  /// In en, this message translates to:
  /// **'Food takes about {kg} {unit} off in fight week: low fibre and fewer carbs from {date}.'**
  String fightWeekCarbs(String kg, String unit, String date);

  /// No description provided for @fightWeekFibre.
  ///
  /// In en, this message translates to:
  /// **'Food takes about {kg} {unit} off in fight week: low fibre from {date}.'**
  String fightWeekFibre(String kg, String unit, String date);

  /// No description provided for @fightWeekNoCut.
  ///
  /// In en, this message translates to:
  /// **'No cut needed. Eat to your plan and hold your weight.'**
  String get fightWeekNoCut;

  /// No description provided for @fightWeekSupervision.
  ///
  /// In en, this message translates to:
  /// **'The food steps below cover part of it. The rest needs a water cut, which needs a coach or dietitian. On food alone, the lightest limit you can make is {lightest} {unit}.'**
  String fightWeekSupervision(String lightest, String unit);

  /// No description provided for @fightWeekNeedsWeight.
  ///
  /// In en, this message translates to:
  /// **'Log a weigh-in to plan your fight week.'**
  String get fightWeekNeedsWeight;

  /// No description provided for @fightWeekWater.
  ///
  /// In en, this message translates to:
  /// **'Drink normally all week. Fighter Edge never plans water cuts.'**
  String get fightWeekWater;

  /// No description provided for @fightWeekToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get fightWeekToday;

  /// No description provided for @fightTodaySteps.
  ///
  /// In en, this message translates to:
  /// **'Today: {steps}'**
  String fightTodaySteps(String steps);

  /// No description provided for @fightWeekDays.
  ///
  /// In en, this message translates to:
  /// **'Day by day'**
  String get fightWeekDays;

  /// No description provided for @fightStepEat.
  ///
  /// In en, this message translates to:
  /// **'Eat to plan'**
  String get fightStepEat;

  /// No description provided for @fightStepEatBody.
  ///
  /// In en, this message translates to:
  /// **'Your usual camp targets.'**
  String get fightStepEatBody;

  /// No description provided for @fightStepFibre.
  ///
  /// In en, this message translates to:
  /// **'Low fibre'**
  String get fightStepFibre;

  /// No description provided for @fightStepFibreBody.
  ///
  /// In en, this message translates to:
  /// **'Under {grams} g of fibre: white rice, white bread, eggs, meat and fish. Skip beans, wholegrains, nuts and raw vegetables.'**
  String fightStepFibreBody(int grams);

  /// No description provided for @fightStepCarbs.
  ///
  /// In en, this message translates to:
  /// **'Fewer carbs'**
  String get fightStepCarbs;

  /// No description provided for @fightStepCarbsBody.
  ///
  /// In en, this message translates to:
  /// **'Smaller portions than usual of rice, bread, pasta and sweets. Keep protein up. If you feel dizzy or weak, eat.'**
  String get fightStepCarbsBody;

  /// No description provided for @fightStepWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Weigh-in'**
  String get fightStepWeighIn;

  /// No description provided for @fightStepWeighInBody.
  ///
  /// In en, this message translates to:
  /// **'Start your refuel straight after.'**
  String get fightStepWeighInBody;

  /// No description provided for @fightStepWeighInBodyNoRefuel.
  ///
  /// In en, this message translates to:
  /// **'Weigh in. Afterwards, follow your coach\'s or dietitian\'s advice.'**
  String get fightStepWeighInBodyNoRefuel;

  /// No description provided for @fightStepRefuel.
  ///
  /// In en, this message translates to:
  /// **'Refuel'**
  String get fightStepRefuel;

  /// No description provided for @fightStepRefuelBody.
  ///
  /// In en, this message translates to:
  /// **'Rehydration drink first, then fast carbs. Targets below.'**
  String get fightStepRefuelBody;

  /// No description provided for @fightStepFight.
  ///
  /// In en, this message translates to:
  /// **'Fight'**
  String get fightStepFight;

  /// No description provided for @fightStepFightBody.
  ///
  /// In en, this message translates to:
  /// **'Keep fibre low and eat foods you know.'**
  String get fightStepFightBody;

  /// No description provided for @fightRefuelTitle.
  ///
  /// In en, this message translates to:
  /// **'After the weigh-in'**
  String get fightRefuelTitle;

  /// No description provided for @fightRefuelDrink.
  ///
  /// In en, this message translates to:
  /// **'Rehydration drink'**
  String get fightRefuelDrink;

  /// No description provided for @fightRefuelDrinkWhen.
  ///
  /// In en, this message translates to:
  /// **'Straight after the weigh-in'**
  String get fightRefuelDrinkWhen;

  /// No description provided for @fightRefuelPerHour.
  ///
  /// In en, this message translates to:
  /// **'{amount} an hour'**
  String fightRefuelPerHour(String amount);

  /// No description provided for @fightRefuelCarbs.
  ///
  /// In en, this message translates to:
  /// **'Fast carbs'**
  String get fightRefuelCarbs;

  /// No description provided for @fightRefuelCarbsWhen.
  ///
  /// In en, this message translates to:
  /// **'After the drink'**
  String get fightRefuelCarbsWhen;

  /// No description provided for @fightRefuelUpTo.
  ///
  /// In en, this message translates to:
  /// **'Up to {amount} an hour'**
  String fightRefuelUpTo(String amount);

  /// No description provided for @fightRefuelTotal.
  ///
  /// In en, this message translates to:
  /// **'Carbs in total'**
  String get fightRefuelTotal;

  /// No description provided for @fightRefuelTotalWhen.
  ///
  /// In en, this message translates to:
  /// **'Between weigh-in and fight'**
  String get fightRefuelTotalWhen;

  /// No description provided for @fightRefuelFibre.
  ///
  /// In en, this message translates to:
  /// **'Fibre'**
  String get fightRefuelFibre;

  /// No description provided for @fightRefuelFibreValue.
  ///
  /// In en, this message translates to:
  /// **'Keep it low'**
  String get fightRefuelFibreValue;

  /// No description provided for @fightRefuelFibreWhen.
  ///
  /// In en, this message translates to:
  /// **'Until the fight'**
  String get fightRefuelFibreWhen;

  /// No description provided for @fightWeekSource.
  ///
  /// In en, this message translates to:
  /// **'Steps and targets from the International Society of Sports Nutrition (2025).'**
  String get fightWeekSource;

  /// No description provided for @fightWeekSourceSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps from the International Society of Sports Nutrition (2025).'**
  String get fightWeekSourceSteps;

  /// No description provided for @fightRefuelOff.
  ///
  /// In en, this message translates to:
  /// **'Refuel targets are not in this version. A sports dietitian has to review them first.'**
  String get fightRefuelOff;

  /// No description provided for @cornerBriefTitle.
  ///
  /// In en, this message translates to:
  /// **'Corner Brief'**
  String get cornerBriefTitle;

  /// No description provided for @cornerCueSeeProfessional.
  ///
  /// In en, this message translates to:
  /// **'Your cut needs a coach or dietitian. Talk to one before fight week.'**
  String get cornerCueSeeProfessional;

  /// No description provided for @cornerCueSetUpFuel.
  ///
  /// In en, this message translates to:
  /// **'Set up EdgeFuel and your corner can read your food too.'**
  String get cornerCueSetUpFuel;

  /// No description provided for @cornerCueFirstMeal.
  ///
  /// In en, this message translates to:
  /// **'Log your first meal and your corner can read your day.'**
  String get cornerCueFirstMeal;

  /// No description provided for @cornerCueProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein is today\'s gap: {grams} g to go.'**
  String cornerCueProtein(int grams);

  /// No description provided for @cornerCueCarbsBeforeTraining.
  ///
  /// In en, this message translates to:
  /// **'{grams} g of carbs to go. Get some in before you train.'**
  String cornerCueCarbsBeforeTraining(int grams);

  /// No description provided for @cornerCueCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs are today\'s gap: {grams} g to go.'**
  String cornerCueCarbs(int grams);

  /// No description provided for @cornerCueCalories.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal left today. Plan your next meal.'**
  String cornerCueCalories(int kcal);

  /// No description provided for @cornerCueOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track today. Keep the next meal balanced.'**
  String get cornerCueOnTrack;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Check your connection and try again.'**
  String get deleteAccountFailed;

  /// No description provided for @syncNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Some changes weren\'t saved to your account.'**
  String get syncNotSaved;

  /// No description provided for @syncRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get syncRetry;

  /// No description provided for @syncRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying…'**
  String get syncRetrying;

  /// No description provided for @reactionRest.
  ///
  /// In en, this message translates to:
  /// **'REST'**
  String get reactionRest;

  /// No description provided for @reactionRoundOf.
  ///
  /// In en, this message translates to:
  /// **'ROUND {n} OF {total}'**
  String reactionRoundOf(int n, int total);

  /// No description provided for @reactionRoundRestNote.
  ///
  /// In en, this message translates to:
  /// **'{time} rest between rounds'**
  String reactionRoundRestNote(String time);

  /// No description provided for @reactionMoveTimeNote.
  ///
  /// In en, this message translates to:
  /// **'Plus the time the move itself takes.'**
  String get reactionMoveTimeNote;

  /// No description provided for @paywallBenefitCampTitle.
  ///
  /// In en, this message translates to:
  /// **'Your camp week'**
  String get paywallBenefitCampTitle;

  /// No description provided for @paywallBenefitCampBody.
  ///
  /// In en, this message translates to:
  /// **'Dated sessions for your week, built around your level and your fight date.'**
  String get paywallBenefitCampBody;

  /// No description provided for @paywallBenefitFuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel for training days'**
  String get paywallBenefitFuelTitle;

  /// No description provided for @paywallBenefitFuelBody.
  ///
  /// In en, this message translates to:
  /// **'Calorie and protein targets that move with the week you train.'**
  String get paywallBenefitFuelBody;

  /// No description provided for @paywallBenefitReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly review'**
  String get paywallBenefitReviewTitle;

  /// No description provided for @paywallBenefitReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Each Sunday: what you did and what to change. You decide.'**
  String get paywallBenefitReviewBody;

  /// No description provided for @paywallBenefitWeightTitle.
  ///
  /// In en, this message translates to:
  /// **'Safe weight path'**
  String get paywallBenefitWeightTitle;

  /// No description provided for @paywallBenefitWeightBody.
  ///
  /// In en, this message translates to:
  /// **'A weight path to your fight date, with safety limits.'**
  String get paywallBenefitWeightBody;

  /// No description provided for @paywallTrialBadge.
  ///
  /// In en, this message translates to:
  /// **'{days}-day free trial'**
  String paywallTrialBadge(int days);

  /// No description provided for @paywallTrialThen.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day free, then {price}} other{{days} days free, then {price}}}'**
  String paywallTrialThen(int days, String price);

  /// No description provided for @paywallStartTrial.
  ///
  /// In en, this message translates to:
  /// **'Start free trial'**
  String get paywallStartTrial;

  /// No description provided for @paywallTrialRenewalDisclosure.
  ///
  /// In en, this message translates to:
  /// **'Free for {days, plural, =1{1 day} other{{days} days}}, then {price}, renewing automatically until you cancel. Cancel at least 24 hours before the trial ends in your store account settings to avoid being charged. Payment is charged to your Apple ID or Google Play account at the end of the trial.'**
  String paywallTrialRenewalDisclosure(int days, String price);

  /// No description provided for @paywallTrialActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Your free trial is running'**
  String get paywallTrialActiveTitle;

  /// No description provided for @paywallTrialActiveBody.
  ///
  /// In en, this message translates to:
  /// **'It becomes a paid plan when the trial ends unless you cancel in your store account.'**
  String get paywallTrialActiveBody;

  /// No description provided for @paywallUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions aren\'t available here yet'**
  String get paywallUnavailableTitle;

  /// No description provided for @paywallUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This version can\'t start a subscription yet. Your data stays saved.'**
  String get paywallUnavailableBody;

  /// No description provided for @readOnlyBanner.
  ///
  /// In en, this message translates to:
  /// **'Your data is saved. Subscribe to keep training.'**
  String get readOnlyBanner;

  /// No description provided for @readOnlyBannerCta.
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get readOnlyBannerCta;

  /// No description provided for @trialChipDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Trial · ends today} =1{Trial · 1 day left} other{Trial · {days} days left}}'**
  String trialChipDaysLeft(int days);

  /// No description provided for @trialReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Your free trial ends in 2 days'**
  String get trialReminderTitle;

  /// No description provided for @trialReminderBody.
  ///
  /// In en, this message translates to:
  /// **'It renews unless you cancel in your store account. Your data stays saved either way.'**
  String get trialReminderBody;

  /// No description provided for @planReadyStartFreeWeek.
  ///
  /// In en, this message translates to:
  /// **'Start your free week'**
  String get planReadyStartFreeWeek;

  /// No description provided for @planReadyStartTrialDays.
  ///
  /// In en, this message translates to:
  /// **'Start your {days}-day free trial'**
  String planReadyStartTrialDays(int days);

  /// No description provided for @planReadyViewPlans.
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get planReadyViewPlans;

  /// No description provided for @planReadyNotNowNote.
  ///
  /// In en, this message translates to:
  /// **'Your plan stays saved. Logging needs a subscription.'**
  String get planReadyNotNowNote;

  /// No description provided for @paywallTrialCancelNote.
  ///
  /// In en, this message translates to:
  /// **'Cancel in your store settings before the trial ends and you pay nothing.'**
  String get paywallTrialCancelNote;

  /// No description provided for @paywallAfterTrialNote.
  ///
  /// In en, this message translates to:
  /// **'If you don\'t subscribe after the trial, your plan and logs stay readable. Logging and sessions need a subscription.'**
  String get paywallAfterTrialNote;

  /// No description provided for @paywallBenefitSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session mode'**
  String get paywallBenefitSessionTitle;

  /// No description provided for @paywallBenefitSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Rounds and rest timed for you, with a tactical and a recovery cue on every break.'**
  String get paywallBenefitSessionBody;

  /// No description provided for @paywallContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get paywallContinue;

  /// No description provided for @fuelLogFood.
  ///
  /// In en, this message translates to:
  /// **'Log food'**
  String get fuelLogFood;

  /// No description provided for @fuelRecentFoods.
  ///
  /// In en, this message translates to:
  /// **'Recent foods'**
  String get fuelRecentFoods;

  /// No description provided for @fuelQuickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get fuelQuickAdd;

  /// No description provided for @fuelEmptyLog.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet. Use Log food to add your first meal.'**
  String get fuelEmptyLog;

  /// No description provided for @fuelGramsLeft.
  ///
  /// In en, this message translates to:
  /// **'{grams} g left'**
  String fuelGramsLeft(int grams);

  /// No description provided for @fuelConsumedKcal.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal logged'**
  String fuelConsumedKcal(int kcal);

  /// No description provided for @fuelRemovedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String fuelRemovedSnack(String name);

  /// No description provided for @fuelRepeatFood.
  ///
  /// In en, this message translates to:
  /// **'Log {name} again'**
  String fuelRepeatFood(String name);

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'All off'**
  String get settingsNotificationsOff;

  /// No description provided for @settingsNotificationsPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get settingsNotificationsPaused;

  /// No description provided for @settingsNotificationsOn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reminder on} other{{count} reminders on}}'**
  String settingsNotificationsOn(int count);

  /// No description provided for @notifScreenIntro.
  ///
  /// In en, this message translates to:
  /// **'Reminders stay on this device. You pick each one, and you get at most one a day.'**
  String get notifScreenIntro;

  /// No description provided for @notifPermissionOffAndroid.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Fighter Edge in your phone settings. To get reminders, open Settings, Apps, Fighter Edge, Notifications and turn them on.'**
  String get notifPermissionOffAndroid;

  /// No description provided for @notifPermissionOffIos.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Fighter Edge in your phone settings. To get reminders, open Settings, Notifications, Fighter Edge and turn on Allow Notifications.'**
  String get notifPermissionOffIos;

  /// No description provided for @notifSectionReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notifSectionReminders;

  /// No description provided for @notifSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session reminder'**
  String get notifSessionTitle;

  /// No description provided for @notifSessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A short note before your usual training time'**
  String get notifSessionSubtitle;

  /// No description provided for @notifReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly review'**
  String get notifReviewTitle;

  /// No description provided for @notifReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A Sunday evening look back at your week'**
  String get notifReviewSubtitle;

  /// No description provided for @notifSectionTiming.
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get notifSectionTiming;

  /// No description provided for @notifUsualTime.
  ///
  /// In en, this message translates to:
  /// **'Usual training time'**
  String get notifUsualTime;

  /// No description provided for @notifSessionLead.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get notifSessionLead;

  /// No description provided for @notifLeadOption.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before'**
  String notifLeadOption(int minutes);

  /// No description provided for @notifQuietStart.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start'**
  String get notifQuietStart;

  /// No description provided for @notifQuietEnd.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end'**
  String get notifQuietEnd;

  /// No description provided for @notifQuietNote.
  ///
  /// In en, this message translates to:
  /// **'Nothing is sent during quiet hours.'**
  String get notifQuietNote;

  /// No description provided for @notifPauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause all'**
  String get notifPauseAll;

  /// No description provided for @notifPauseAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Silence every reminder until you turn this off'**
  String get notifPauseAllSubtitle;

  /// No description provided for @notifHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders not arriving?'**
  String get notifHelpTitle;

  /// No description provided for @notifHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Some phones stop apps in the background to save battery. If reminders come late or not at all, let Fighter Edge run in the background in your battery settings.'**
  String get notifHelpBody;

  /// No description provided for @notifPrimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Want a reminder before your next session?'**
  String get notifPrimerTitle;

  /// No description provided for @notifPrimerBody.
  ///
  /// In en, this message translates to:
  /// **'One short note on the days you train, about an hour before. Never at night. You can change or stop it in Settings.'**
  String get notifPrimerBody;

  /// No description provided for @notifPrimerYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, remind me'**
  String get notifPrimerYes;

  /// No description provided for @notifPrimerNo.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notifPrimerNo;

  /// No description provided for @notifAutoPauseTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep these reminders?'**
  String get notifAutoPauseTitle;

  /// No description provided for @notifAutoPauseBodySession.
  ///
  /// In en, this message translates to:
  /// **'The last few session reminders went unopened, so we paused them. Keep them coming, or turn them off.'**
  String get notifAutoPauseBodySession;

  /// No description provided for @notifAutoPauseBodyReview.
  ///
  /// In en, this message translates to:
  /// **'The last few weekly reviews went unopened, so we paused them. Keep them coming, or turn them off.'**
  String get notifAutoPauseBodyReview;

  /// No description provided for @notifAutoPauseBodyGeneric.
  ///
  /// In en, this message translates to:
  /// **'The last few of these reminders went unopened, so we paused them. Keep them coming, or turn them off.'**
  String get notifAutoPauseBodyGeneric;

  /// No description provided for @notifAutoPauseKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep them'**
  String get notifAutoPauseKeep;

  /// No description provided for @notifAutoPauseOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get notifAutoPauseOff;

  /// No description provided for @notifSessionSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Your session is coming up'**
  String get notifSessionSoonTitle;

  /// No description provided for @notifSessionSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Training at {time}. A short warm-up first helps you start well.'**
  String notifSessionSoonBody(String time);

  /// No description provided for @notifSessionSoonFuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Session at {time}'**
  String notifSessionSoonFuelTitle(String time);

  /// No description provided for @notifSessionSoonFuelBody.
  ///
  /// In en, this message translates to:
  /// **'Your fuel window is open. Eat what sits well with you, then get your gear ready.'**
  String get notifSessionSoonFuelBody;

  /// No description provided for @notifFuelWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel window is open'**
  String get notifFuelWindowTitle;

  /// No description provided for @notifFuelWindowBody.
  ///
  /// In en, this message translates to:
  /// **'Your {time} session is coming. Eat what sits well with you, then train.'**
  String notifFuelWindowBody(String time);

  /// No description provided for @notifReviewWeeklyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your week in review'**
  String get notifReviewWeeklyTitle;

  /// No description provided for @notifReviewWeeklyBody.
  ///
  /// In en, this message translates to:
  /// **'Take a minute to see how the week went and set up the next one.'**
  String get notifReviewWeeklyBody;

  /// No description provided for @notifFightWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'One week to fight day'**
  String get notifFightWeekTitle;

  /// No description provided for @notifFightWeekBody.
  ///
  /// In en, this message translates to:
  /// **'Keep your sessions steady and your routine simple. Your camp plan has what is next.'**
  String get notifFightWeekBody;

  /// No description provided for @notifFightTomorrowTitle.
  ///
  /// In en, this message translates to:
  /// **'Fight day is tomorrow'**
  String get notifFightTomorrowTitle;

  /// No description provided for @notifFightTomorrowBody.
  ///
  /// In en, this message translates to:
  /// **'Rest up and keep your routine. The work is done.'**
  String get notifFightTomorrowBody;

  /// No description provided for @notifWeighInTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight check-in'**
  String get notifWeighInTitle;

  /// No description provided for @notifWeighInBody.
  ///
  /// In en, this message translates to:
  /// **'Log your weight if you track it. Skip it if today is not the day.'**
  String get notifWeighInBody;

  /// No description provided for @notifProteinTitle.
  ///
  /// In en, this message translates to:
  /// **'Dinner tonight'**
  String get notifProteinTitle;

  /// No description provided for @notifProteinBody.
  ///
  /// In en, this message translates to:
  /// **'A protein-rich meal after training helps you recover.'**
  String get notifProteinBody;

  /// No description provided for @notifTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Fighter tip'**
  String get notifTipTitle;

  /// No description provided for @notifTip0Body.
  ///
  /// In en, this message translates to:
  /// **'Sleep is part of training. A steady bedtime this week pays off in your next session.'**
  String get notifTip0Body;

  /// No description provided for @notifTip1Body.
  ///
  /// In en, this message translates to:
  /// **'Five easy minutes of warm-up make the first round of any session better.'**
  String get notifTip1Body;

  /// No description provided for @notifTip2Body.
  ///
  /// In en, this message translates to:
  /// **'Pick one technique to sharpen today. A small focus beats a big plan.'**
  String get notifTip2Body;

  /// No description provided for @notifTip3Body.
  ///
  /// In en, this message translates to:
  /// **'After a hard session, eat a proper meal. Recovery starts on your plate.'**
  String get notifTip3Body;

  /// No description provided for @notifTip4Body.
  ///
  /// In en, this message translates to:
  /// **'Light mobility between sessions keeps your hips and shoulders ready.'**
  String get notifTip4Body;

  /// No description provided for @notifTip5Body.
  ///
  /// In en, this message translates to:
  /// **'Breathe slowly for a minute before sparring. A calm start sets up your rounds.'**
  String get notifTip5Body;

  /// No description provided for @notifFuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel window'**
  String get notifFuelTitle;

  /// No description provided for @notifFuelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A heads-up before a hard session, when it is time to eat'**
  String get notifFuelSubtitle;

  /// No description provided for @notifFightTitle.
  ///
  /// In en, this message translates to:
  /// **'Fight countdown'**
  String get notifFightTitle;

  /// No description provided for @notifFightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A note a week and a day before your fight'**
  String get notifFightSubtitle;

  /// No description provided for @nutritionPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nutrition is paused'**
  String get nutritionPausedTitle;

  /// No description provided for @nutritionPausedBody.
  ///
  /// In en, this message translates to:
  /// **'Food logging, nutrition numbers, weight tools and nutrition reminders are off. Training goes on as normal. Turn it back on whenever you like.'**
  String get nutritionPausedBody;

  /// No description provided for @nutritionPausedResume.
  ///
  /// In en, this message translates to:
  /// **'Turn nutrition back on'**
  String get nutritionPausedResume;

  /// No description provided for @settingsSectionNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get settingsSectionNutrition;

  /// No description provided for @settingsNutritionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Nutrition display'**
  String get settingsNutritionDisplay;

  /// No description provided for @settingsNutritionDisplayNormal.
  ///
  /// In en, this message translates to:
  /// **'Everything on'**
  String get settingsNutritionDisplayNormal;

  /// No description provided for @settingsNutritionDisplayPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get settingsNutritionDisplayPaused;

  /// No description provided for @nutritionModeNormalTitle.
  ///
  /// In en, this message translates to:
  /// **'Show everything'**
  String get nutritionModeNormalTitle;

  /// No description provided for @nutritionModeNormalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Targets, food log, weight and nutrition reminders.'**
  String get nutritionModeNormalSubtitle;

  /// No description provided for @nutritionModePausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pause nutrition'**
  String get nutritionModePausedTitle;

  /// No description provided for @nutritionModePausedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hides food, nutrition numbers, weight tools and nutrition reminders. Training continues.'**
  String get nutritionModePausedSubtitle;

  /// No description provided for @reviewHoldPaused.
  ///
  /// In en, this message translates to:
  /// **'Nothing to change this week. Keep your plan as it is.'**
  String get reviewHoldPaused;

  /// No description provided for @nutritionNumbersHiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'Numbers are hidden'**
  String get nutritionNumbersHiddenTitle;

  /// No description provided for @nutritionNumbersHiddenBody.
  ///
  /// In en, this message translates to:
  /// **'Calories, grams, targets and weights are hidden. You can still log what you eat by name. Show them again whenever you like.'**
  String get nutritionNumbersHiddenBody;

  /// No description provided for @nutritionNumbersHiddenShow.
  ///
  /// In en, this message translates to:
  /// **'Show numbers'**
  String get nutritionNumbersHiddenShow;

  /// No description provided for @nutritionModeHideTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide numbers'**
  String get nutritionModeHideTitle;

  /// No description provided for @nutritionModeHideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hides calories, grams, targets and weight. You can still log foods by name.'**
  String get nutritionModeHideSubtitle;

  /// No description provided for @settingsNutritionDisplayHidden.
  ///
  /// In en, this message translates to:
  /// **'Numbers hidden'**
  String get settingsNutritionDisplayHidden;

  /// No description provided for @nutritionAddedSnackNoNumbers.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String nutritionAddedSnackNoNumbers(String name);

  /// No description provided for @nutritionLoggedByName.
  ///
  /// In en, this message translates to:
  /// **'Log what you eat. The numbers stay hidden.'**
  String get nutritionLoggedByName;
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

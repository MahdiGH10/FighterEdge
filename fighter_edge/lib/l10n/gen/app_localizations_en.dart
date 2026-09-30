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
  String get settingsSectionTraining => 'Training preferences';

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
  String get settingsSectionSafety => 'Safety & trust';

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
  String get dashboardWeeklyOverview => 'Weekly overview';

  @override
  String get dashboardNextSession => 'Next session';

  @override
  String get dashboardRecentActivity => 'Recent activity';

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
  String get fuelWeekTitle => 'Fuel this week';

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
  String get nutritionPreviousDay => 'Previous day';

  @override
  String get nutritionNextDay => 'Next day';

  @override
  String get trainingLogSession => 'Log session';

  @override
  String get trainingEditSessionLog => 'Edit session log';

  @override
  String get weightFieldLabel => 'Weight';

  @override
  String get weightAddWeighIn => 'Add weigh-in';

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
  String get addFoodSaved => 'Saved';

  @override
  String get addFoodRecent => 'Recent';

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
  String get addFoodHowMuch => 'How much?';

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
  String get timerYourCorner => 'Your corner';

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
  String get consentTitle => 'Help improve Fighter Edge';

  @override
  String get consentBody =>
      'With your permission we collect anonymous usage events and crash reports. They never include your meals, weight, measurements, messages or email address. Nothing is sent unless you allow it.';

  @override
  String get consentAllow => 'Allow';

  @override
  String get consentDecline => 'Don\'t allow';

  @override
  String get consentChangeLater => 'You can change this any time in Settings.';

  @override
  String get settingsSectionPrivacy => 'Privacy';

  @override
  String get settingsAnalytics => 'Usage analytics';

  @override
  String get settingsAnalyticsSubtitle =>
      'Anonymous events that show which features help. No health data.';

  @override
  String get settingsCrashReports => 'Crash reports';

  @override
  String get settingsCrashReportsSubtitle =>
      'Error details that help us fix bugs. No personal data.';

  @override
  String get healthConsentTitle => 'Your body data, your call';

  @override
  String get healthConsentIntro =>
      'To build your plan, Fighter Edge needs data about your body and health. The law treats this data as sensitive, so we ask for your explicit consent first.';

  @override
  String get healthConsentWhatTitle => 'What we store';

  @override
  String get healthConsentWhat =>
      'Age, height, weight and target weight, body fat if you add it, the energy profile you choose, activity level, diet, allergies and intolerances, and the food, weight and training you log.';

  @override
  String get healthConsentWhyTitle => 'What it\'s used for';

  @override
  String get healthConsentWhy =>
      'Only to calculate your targets, show your progress and guide you. Never for ads, and never sold.';

  @override
  String get healthConsentWhereTitle => 'Where it\'s kept';

  @override
  String get healthConsentWhere =>
      'In your account on Google Firebase. Only you can read it.';

  @override
  String get healthConsentWithdraw =>
      'You can withdraw your consent at any time in Settings > Privacy. The app can\'t work without this data, so withdrawing deletes your account and its data.';

  @override
  String get healthConsentStatement =>
      'I agree that Fighter Edge stores and uses my health data as described here and in the Privacy Policy.';

  @override
  String get healthConsentAgree => 'I agree';

  @override
  String get healthConsentSignOut => 'Not now, sign out';

  @override
  String get healthConsentDeleteAccount => 'Delete my account instead';

  @override
  String get aiConsentTitle => 'Before you talk to the coach';

  @override
  String get aiConsentBody =>
      'To answer, our server sends your calorie and macro targets, today\'s food-log summary, your diet type, allergies, disliked foods and your messages to OpenRouter (USA), which passes them to an AI model provider. Your name, email address and account ID are never sent.';

  @override
  String get aiConsentRetention =>
      'Some providers, especially free models, may keep what they receive under their own terms. Don\'t type anything you don\'t want to share.';

  @override
  String get aiConsentStatement =>
      'I agree that this data is sent to the AI provider as described, including to the USA.';

  @override
  String get aiConsentAgree => 'I agree';

  @override
  String get aiConsentChangeLater =>
      'You can turn this off any time in Settings > Privacy.';

  @override
  String get aiConsentRequiredNotice =>
      'Allow AI coach data sharing to get an answer.';

  @override
  String get settingsHealthData => 'Health data';

  @override
  String settingsHealthDataGranted(String date) {
    return 'You agreed on $date';
  }

  @override
  String get settingsHealthDataGrantedNoDate => 'You agreed to its use';

  @override
  String get settingsHealthDataWithdrawTitle => 'Withdraw consent?';

  @override
  String get settingsHealthDataWithdrawBody =>
      'Fighter Edge can\'t calculate your plan or track your progress without your health data. Withdrawing your consent therefore means deleting your account and all its data.';

  @override
  String get settingsHealthDataWithdrawConfirm => 'Delete my account';

  @override
  String get settingsAiCoach => 'AI coach data sharing';

  @override
  String get settingsAiCoachSubtitle =>
      'Sends your plan facts and messages to our AI provider (USA) when you use the coach.';

  @override
  String get deleteAccountSubscriptionWarning =>
      'Deleting your account doesn\'t cancel your subscription. Cancel it first in your App Store or Google Play account settings, or it keeps renewing.';

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
  String get reactionStatDuration => 'Duration';

  @override
  String get reactionStatMoves => 'Moves';

  @override
  String get reactionStatReact => 'Reaction';

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

  @override
  String get dashboardThisWeek => 'This week';

  @override
  String get dashboardFighter => 'Fighter';

  @override
  String get dashboardToday => 'Today';

  @override
  String get dashboardNoPlan => 'No sessions planned';

  @override
  String get dashboardWeekDone => 'Week complete';

  @override
  String get dashboardRestDay => 'Rest day';

  @override
  String get dashboardRecovery =>
      'Your planned sessions are done. Take time to recover.';

  @override
  String get dashboardPlanHint => 'Open Train to set up your week.';

  @override
  String dashboardNextUp(String day, String session) {
    return 'Next: $day · $session';
  }

  @override
  String get dashboardStartSession => 'Start session';

  @override
  String get dashboardOpenCamp => 'Open camp';

  @override
  String get dashboardSetFuel => 'Set a fuel target';

  @override
  String get dashboardFuelInfo => 'Why this target matters';

  @override
  String get dashboardFuelExplanation =>
      'Calories support your goal. Protein supports recovery and muscle. Carbohydrates provide energy for training.';

  @override
  String get commonClose => 'Close';

  @override
  String get dashboardNoActivity =>
      'Complete your first session to start your history.';

  @override
  String get dashboardVerifyEmail => 'Verify your email';

  @override
  String get dashboardConfirmEmail => 'Confirm your email';

  @override
  String get dashboardRiskTitle => 'Streak at risk';

  @override
  String dashboardFreezeHint(int count) {
    return 'Yesterday is unlogged. Protect it with a freeze ($count left).';
  }

  @override
  String get dashboardLogHint =>
      'No freeze is available. Log a session today to start again.';

  @override
  String get dashboardFreeze => 'Freeze';

  @override
  String get dashboardLogNow => 'Log now';

  @override
  String get dashboardFreezeUsed => 'Freeze used — yesterday is protected.';

  @override
  String get dashboardLogged => 'Logged';

  @override
  String get dashboardYesterday => 'Yesterday';

  @override
  String dashboardDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String dashboardChecklistProgress(int done, int total) {
    return '$done of $total complete';
  }

  @override
  String get nutritionKcalLeft => 'kcal left';

  @override
  String nutritionOverTarget(int kcal) {
    return '$kcal kcal above target';
  }

  @override
  String get nutritionViewPlan => 'View fuel plan';

  @override
  String get nutritionRecipesFit => 'Recipes that fit';

  @override
  String nutritionMacroGrams(int value, int target) {
    return '$value / $target g';
  }

  @override
  String nutritionGrams(int value) {
    return '$value g';
  }

  @override
  String get trainingSessionDone => 'Done';

  @override
  String trainingStartSession(String session) {
    return 'Start $session';
  }

  @override
  String get onboardingBack => 'Back';

  @override
  String onboardingStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String onboardingSummary(int days, String level, String goal) {
    return '$days days a week · $level · $goal';
  }

  @override
  String get onboardingLoseFat => 'Lose fat';

  @override
  String get onboardingMaintain => 'Maintain weight';

  @override
  String get onboardingGainMuscle => 'Gain muscle';

  @override
  String get onboardingBeginner => 'Beginner';

  @override
  String get onboardingIntermediate => 'Intermediate';

  @override
  String get onboardingAdvanced => 'Advanced';

  @override
  String get onboardingFighter => 'Fighter';

  @override
  String get welcomeProgressTitle => 'See your progress.';

  @override
  String get planReadyExplanation =>
      'Your plan is based on your goals and training days. You can adjust it as your training changes.';

  @override
  String get planReadyProTitle => 'More training tools with Pro';

  @override
  String get planReadyProBody =>
      'Pro includes a daily Fighter Brief, all drills and recipes, and cues between rounds.';

  @override
  String get planReadyCalories => 'Daily calories';

  @override
  String get planReadyMissingTarget =>
      'Your training week is ready. Add body details in Fuel to calculate a daily target.';

  @override
  String get profileFreePlan => 'Free plan';

  @override
  String get profileProActive => 'Pro subscription active';

  @override
  String get profileProDescription => 'Daily brief, all drills and recipes';

  @override
  String get profileUpgrade => 'Upgrade';

  @override
  String get profileManage => 'Manage';

  @override
  String get settingsProPlan => 'Pro';

  @override
  String get settingsFreePlan => 'Free';

  @override
  String dashboardEffort(int rating) {
    return 'Effort $rating/10';
  }

  @override
  String get paywallPlainTitle => 'Training tools with Pro';

  @override
  String get paywallPlainSubtitle =>
      'Daily coaching, every drill and recipe, and cues between rounds.';

  @override
  String get fuelRecipesTitle => 'Recipes for your day';

  @override
  String paywallMonthly(String price) {
    return 'Monthly · $price';
  }

  @override
  String fuelMealsLogged(int eaten, int total) {
    return 'Meals logged · $eaten/$total';
  }

  @override
  String get learningStart => 'Start here';

  @override
  String get learningChoose => 'Choose a discipline';

  @override
  String get learningChooseHint =>
      'We will remember your choice on this account. You can change it any time.';

  @override
  String get learningChange => 'Change path';

  @override
  String get learningStriking => 'Striking';

  @override
  String get learningWrestling => 'Wrestling';

  @override
  String get learningBjj => 'BJJ';

  @override
  String get learningClinch => 'Clinch';

  @override
  String get learningStrikingHint =>
      'Learn punches, defence and kicks in order.';

  @override
  String get learningWrestlingHint =>
      'Build your stance, then learn to take someone down and defend a takedown.';

  @override
  String get learningBjjHint =>
      'Brazilian jiu-jitsu: learn to move and escape when training on the ground.';

  @override
  String get learningClinchHint =>
      'Learn close-range holds, knees and control while standing.';

  @override
  String get learningFoundations => 'Foundations';

  @override
  String get learningBuilding => 'Building';

  @override
  String get learningSharp => 'Sharp';

  @override
  String learningCount(int completed, int total) {
    return '$completed of $total drills sharp';
  }

  @override
  String learningLearn(String drill) {
    return 'Learn: $drill';
  }

  @override
  String get learningLocked => 'Pro drill · path paused';

  @override
  String get learningViewPro => 'View Pro options';

  @override
  String get learningComplete => 'Path complete';

  @override
  String get learningCompleteHint =>
      'Keep practising these drills, or choose another discipline.';

  @override
  String get learningProgressHint =>
      'Sharp means you can repeat the drill with control.';

  @override
  String get learningNext => 'Next in your path';

  @override
  String learningAfter(String drill) {
    return 'After this drill: $drill';
  }

  @override
  String get learningKeepPractising =>
      'Keep practising this drill. Mark it Sharp when you can repeat it with control to advance your path.';

  @override
  String get learningPractiseLast =>
      'This is the last drill in your path. Keep practising, then mark it Sharp when you are ready.';

  @override
  String get fightAddTitle => 'Add your next fight';

  @override
  String get fightAddSubtitle => 'Countdown and a safe weight path';

  @override
  String get fightSetupTitle => 'Your fight';

  @override
  String get fightDateLabel => 'Fight date';

  @override
  String get fightDatePick => 'Choose date';

  @override
  String get fightWeighInLabel => 'Weigh-in';

  @override
  String get fightWeighInSameDay => 'Same day';

  @override
  String get fightWeighInDayBefore => 'Day before';

  @override
  String get fightWeighInTwoDays => '2 days before';

  @override
  String fightLimitLabel(String unit) {
    return 'Weight limit ($unit)';
  }

  @override
  String fightLimitError(String min, String max, String unit) {
    return 'Enter a limit between $min and $max $unit.';
  }

  @override
  String get fightCategoryLabel => 'Competition';

  @override
  String get fightCategoryWhy =>
      'This sets how much can safely come off in the final days.';

  @override
  String get fightCategoryGrappling => 'Wrestling and grappling';

  @override
  String get fightCategoryGrapplingHint => 'Wrestling, BJJ, ADCC';

  @override
  String get fightCategoryAmateur => 'Amateur striking';

  @override
  String get fightCategoryAmateurHint => 'Amateur boxing, amateur Muay Thai';

  @override
  String get fightCategoryOlympic => 'Olympic combat sports';

  @override
  String get fightCategoryOlympicHint => 'Judo, Olympic boxing, taekwondo';

  @override
  String get fightCategoryPro => 'Professional';

  @override
  String get fightCategoryProHint => 'Pro MMA, boxing, kickboxing, Muay Thai';

  @override
  String get fightCampLabel => 'Camp length';

  @override
  String fightCampWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get fightPathTitle => 'Your weight path';

  @override
  String get fightPathNow => 'Now';

  @override
  String get fightPathLimit => 'Limit';

  @override
  String get fightPathToGo => 'To go';

  @override
  String fightPathOnPace(String rate, String entry, String unit) {
    return 'On pace: lose $rate $unit a week to reach $entry $unit by fight week.';
  }

  @override
  String get fightPathHold =>
      'Within reach: hold your weight, and fight-week eating covers the rest.';

  @override
  String fightPathSupervision(String lightest, String unit) {
    return 'Only possible with a water cut in the last days, which needs a coach or dietitian. Your camp is planned at the fastest safe pace. On food alone, the lightest limit you can make by then is $lightest $unit.';
  }

  @override
  String fightPathNotSafe(String lightest, String unit) {
    return 'Not safe by this date. The lightest limit you can make safely is $lightest $unit: choose a heavier class or a later fight.';
  }

  @override
  String get fightPathAtWeight => 'You\'re at weight. Hold steady.';

  @override
  String get fightPathNeedsWeight =>
      'Log a weigh-in this week to see your path.';

  @override
  String get fightPathAdultsOnly =>
      'Weight cut plans are for adults. Plan your weight with your coach.';

  @override
  String get fightPathSource =>
      'Limits from the International Society of Sports Nutrition (2025).';

  @override
  String get fightSave => 'Save fight';

  @override
  String get fightRemove => 'Remove fight';

  @override
  String get fightRemoveTitle => 'Remove this fight?';

  @override
  String get fightRemoveBody =>
      'Your countdown and weight path are cleared. You can add a fight again any time.';

  @override
  String fightNight(String date) {
    return 'Fight night · $date';
  }

  @override
  String fightDaysToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days to go',
      one: 'day to go',
    );
    return '$_temp0';
  }

  @override
  String fightPhaseCamp(int week, int total) {
    return 'Camp · week $week of $total';
  }

  @override
  String fightPhaseBeforeCamp(String date) {
    return 'Camp starts $date';
  }

  @override
  String fightPhaseFightWeek(int day) {
    return 'Fight week · day $day of 7';
  }

  @override
  String get fightPhaseWeighIn => 'Weigh-in today';

  @override
  String get fightPhaseRefuel => 'Weighed in: refuel';

  @override
  String get fightPhaseFightDay => 'Fight day';

  @override
  String get fightDone => 'Fight done. Add your next one.';

  @override
  String get fightEdit => 'Edit fight';

  @override
  String get fightPathShortSupervision =>
      'Needs a supervised water cut. Tap to review.';

  @override
  String get fightPathShortNotSafe => 'Not safe by this date. Tap to review.';
}

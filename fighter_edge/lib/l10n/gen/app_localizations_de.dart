// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class LDe extends L {
  LDe([String locale = 'de']) : super(locale);

  @override
  String get navHome => 'Start';

  @override
  String get navTrain => 'Training';

  @override
  String get navFuel => 'Ernährung';

  @override
  String get navProfile => 'Profil';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonUndo => 'Rückgängig';

  @override
  String get commonToday => 'Heute';

  @override
  String get commonSignOut => 'Abmelden';

  @override
  String get commonSigningOut => 'Wird abgemeldet …';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemsprache';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsLanguageBeta =>
      'Deutsch ist teilweise übersetzt — der Rest bleibt vorerst auf Englisch.';

  @override
  String get settingsSectionSubscription => 'Abo';

  @override
  String get settingsManagePro => 'Pro verwalten';

  @override
  String get settingsUpgradePro => 'Auf Pro upgraden';

  @override
  String get settingsManageProSubtitle =>
      'Status aktualisieren und Zahlungen verwalten, sobald verbunden';

  @override
  String get settingsUpgradeProSubtitle =>
      'KI-Fighter-Brief, komplette Drill- und Rezept-Bibliothek, Ecken-Tipps';

  @override
  String get settingsSectionTraining => 'Trainingseinstellungen';

  @override
  String get settingsMetricUnits => 'Metrische Einheiten';

  @override
  String get settingsMetricUnitsKg => 'Gewicht in kg';

  @override
  String get settingsMetricUnitsLb => 'Gewicht in lb';

  @override
  String get settingsTimerHaptics => 'Timer-Vibration';

  @override
  String get settingsTimerHapticsSubtitle => 'Rundensignale können vibrieren';

  @override
  String get settingsCampReminders => 'Trainings-Erinnerungen';

  @override
  String get settingsCampRemindersUnavailable =>
      'Auf diesem Gerät nicht verfügbar';

  @override
  String settingsCampRemindersOn(String time) {
    return 'Ein Hinweis an deinen Trainingstagen, gegen $time';
  }

  @override
  String get settingsCampRemindersOff =>
      'Lass dich an deinen Trainingstagen erinnern';

  @override
  String get settingsSectionSafety => 'Sicherheit & Vertrauen';

  @override
  String get settingsSafeCut => 'Hinweise zum sicheren Abkochen';

  @override
  String get settingsSafeCutSubtitle =>
      'Zeigt Hinweise zu Flüssigkeit und Gewichtsabbau — keine medizinische Beratung';

  @override
  String get settingsSectionAccount => 'Konto';

  @override
  String get settingsChangePassword => 'Passwort ändern';

  @override
  String get settingsChangePasswordSubtitle =>
      'Bestätige dein aktuelles Passwort, um ein neues zu setzen';

  @override
  String get settingsChangePasswordGoogle =>
      'Du meldest dich mit Google an — verwalte das in deinem Google-Konto';

  @override
  String get settingsTerms => 'Nutzungsbedingungen';

  @override
  String get settingsTermsSubtitle =>
      'Die Regeln für die Nutzung von Fighter Edge';

  @override
  String get settingsPrivacy => 'Datenschutzerklärung';

  @override
  String get settingsPrivacySubtitle => 'Was wir speichern und warum';

  @override
  String get settingsDeleteAccount => 'Konto löschen';

  @override
  String get settingsDeleteAccountSubtitle =>
      'Löscht dein Konto und alle deine Daten endgültig';

  @override
  String get dashboardTitle => 'Übersicht';

  @override
  String get dashboardWeeklyOverview => 'Wochenübersicht';

  @override
  String get dashboardNextSession => 'Nächste Einheit';

  @override
  String get dashboardRecentActivity => 'Letzte Aktivität';

  @override
  String get dashboardSeeAll => 'Alle ansehen';

  @override
  String get dashboardStatWeight => 'Gewicht';

  @override
  String get dashboardStatSessions => 'Einheiten';

  @override
  String get dashboardStatStreak => 'Serie';

  @override
  String get dashboardStatCompleted => 'abgeschlossen';

  @override
  String dashboardStatDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tage',
      one: 'Tag',
    );
    return '$_temp0';
  }

  @override
  String get dashboardAddWeighIn => 'Gewicht eintragen';

  @override
  String get dashboardStreakAtRisk => 'In Gefahr';

  @override
  String get dashboardStreakOnFire => 'Läuft';

  @override
  String get dashboardStreakLogToday => 'Heute eintragen';

  @override
  String get fuelWeekTitle => 'ERNÄHRUNG DIESE WOCHE';

  @override
  String fuelWeekLogged(int count) {
    return '$count/7 erfasst';
  }

  @override
  String get fuelWeekOnTarget => 'im Ziel';

  @override
  String get fuelWeekProteinHit => 'Protein erreicht';

  @override
  String get fuelWeekAvgKcal => 'Ø kcal';

  @override
  String get fuelWeekEmpty =>
      'Trag diese Woche deine Mahlzeiten ein — dann entsteht hier dein Verlauf, Tag für Tag gegen dein Ziel.';

  @override
  String fuelLeftToday(int kcal) {
    return 'Noch $kcal kcal heute';
  }

  @override
  String get fuelLeftTodaySubtitle =>
      'Passende Rezepte, das meiste Protein zuerst';

  @override
  String get nutritionTitle => 'Ernährung';

  @override
  String get nutritionTabToday => 'Heute';

  @override
  String get nutritionTabMeals => 'Mahlzeiten';

  @override
  String get nutritionTabRecipes => 'Rezepte';

  @override
  String get nutritionCalories => 'Kalorien';

  @override
  String get nutritionMeals => 'Mahlzeiten';

  @override
  String get nutritionAddFood => 'Essen hinzufügen';

  @override
  String get nutritionSearchFoods => 'Lebensmittel suchen';

  @override
  String get nutritionLoggedToday => 'heute erfasst';

  @override
  String get nutritionProtein => 'Protein';

  @override
  String get nutritionCarbs => 'Kohlenhydrate';

  @override
  String get nutritionFats => 'Fette';

  @override
  String nutritionAddedSnack(String name, int kcal) {
    return '$name · $kcal kcal hinzugefügt';
  }

  @override
  String addFoodTitle(String day) {
    return 'Hinzufügen zu $day';
  }

  @override
  String get addFoodSaved => 'GESPEICHERT';

  @override
  String get addFoodRecent => 'ZULETZT';

  @override
  String get addFoodManual => 'Nährwerte selbst eingeben';

  @override
  String get addFoodManualSubtitle =>
      'Für auswärts essen, eine Verpackung oder alles, was nicht gelistet ist';

  @override
  String get addFoodEmptyHint =>
      'Such ein Lebensmittel und wähl die Menge — die Nährwerte rechnet die App aus. Was du einträgst, steht beim nächsten Mal hier, einen Tipp entfernt.';

  @override
  String get addFoodNotFound => 'Noch nicht in der Lebensmittelliste';

  @override
  String get addFoodNotFoundHint =>
      'Probier ein einfacheres Wort („Reis“, „Hähnchen“) oder gib die Nährwerte unten selbst ein.';

  @override
  String get addFoodHowMuch => 'WIE VIEL?';

  @override
  String get addFoodGrams => 'Gramm';

  @override
  String addFoodAddTo(String day) {
    return 'Zu $day hinzufügen';
  }

  @override
  String addFoodPerHundred(int kcal, String protein) {
    return '$kcal kcal · $protein g Protein pro 100 g';
  }

  @override
  String addFoodAllergenWarning(String allergens) {
    return 'Enthält $allergens — steht auf deiner Allergenliste.';
  }

  @override
  String get trainTitle => 'Training';

  @override
  String get trainTabWeek => 'Woche';

  @override
  String get trainTabHistory => 'Verlauf';

  @override
  String get trainTabDrills => 'Drills';

  @override
  String get timerTitle => 'Runden-Timer';

  @override
  String get timerRound => 'Runde';

  @override
  String get timerWork => 'ARBEIT';

  @override
  String get timerRest => 'PAUSE';

  @override
  String get timerDone => 'FERTIG';

  @override
  String get timerStart => 'Start';

  @override
  String get timerPause => 'Pause';

  @override
  String get timerReset => 'Zurücksetzen';

  @override
  String get timerRestart => 'Neu starten';

  @override
  String timerNext(String label) {
    return 'Danach: $label';
  }

  @override
  String get timerYourCorner => 'DEINE ECKE';

  @override
  String get timerCornerTeaser =>
      'Mit Pro steht dir in der Pause deine Ecke zur Seite: ein Hinweis für die nächste Runde.';

  @override
  String devMessageFrom(String from) {
    return 'VON $from';
  }

  @override
  String get devMessageGotIt => 'Alles klar';

  @override
  String get authWelcomeBack => 'Willkommen zurück';

  @override
  String get authWelcomeBackSubtitle => 'Melde dich an und mach im Camp weiter';

  @override
  String get authEmail => 'E-Mail';

  @override
  String get authPassword => 'Passwort';

  @override
  String get authSignIn => 'Anmelden';

  @override
  String get authSigningIn => 'Wird angemeldet …';

  @override
  String get authForgotPassword => 'Passwort vergessen?';

  @override
  String get authNoAccount => 'Neu hier?';

  @override
  String get authCreateAccount => 'Konto erstellen';

  @override
  String get authShowPassword => 'Passwort anzeigen';

  @override
  String get authHidePassword => 'Passwort verbergen';
}

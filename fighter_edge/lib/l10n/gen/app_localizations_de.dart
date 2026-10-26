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
  String get settingsReduceTransparency => 'Transparenz reduzieren';

  @override
  String get settingsReduceTransparencySubtitle =>
      'Feste Hintergründe statt Milchglas. Hoher Kontrast macht das ebenfalls';

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
      'Alle Drills, Session-Modus und Ernährung für Trainingstage';

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
  String get settingsSectionSafety => 'Sicherheit & Vertrauen';

  @override
  String get settingsSafeCut => 'Hinweise zum sicheren Abkochen';

  @override
  String get settingsSafeCutSubtitle =>
      'Zeigt Hinweise zu Flüssigkeit und Gewichtsabbau — keine medizinische Beratung';

  @override
  String get settingsTrustNote =>
      'Fighter Edge unterstützt deine Trainings- und Ernährungsentscheidungen. Es ersetzt keinen Coach, keine Ärztin oder keinen Arzt und keine zugelassene Ernährungsfachkraft.';

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
  String get settingsEthics => 'Ethische Leitlinien';

  @override
  String get settingsEthicsSubtitle => 'Was Fighter Edge niemals tut';

  @override
  String get settingsDeleteAccount => 'Konto löschen';

  @override
  String get settingsDeleteAccountSubtitle =>
      'Löscht dein Konto und alle deine Daten endgültig';

  @override
  String get dashboardTitle => 'Übersicht';

  @override
  String get dashboardNextSession => 'Nächste Einheit';

  @override
  String get dashboardRecentActivity => 'Letzte Aktivitäten';

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
  String get dashboardAddWeighIn => 'Gewicht eintragen';

  @override
  String get fuelWeekTitle => 'Ernährung diese Woche';

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
  String get nutritionPreviousDay => 'Vorheriger Tag';

  @override
  String get nutritionNextDay => 'Nächster Tag';

  @override
  String get trainingLogSession => 'Einheit erfassen';

  @override
  String get trainingEditSessionLog => 'Einheitsprotokoll bearbeiten';

  @override
  String get weightFieldLabel => 'Gewicht';

  @override
  String get weightAddWeighIn => 'Gewicht erfassen';

  @override
  String get weightEditWeighIn => 'Wiegen bearbeiten';

  @override
  String get weightDeleteWeighIn => 'Wiegen löschen?';

  @override
  String get weightDeleteConfirm =>
      'Dieser Eintrag wird aus dem Verlauf entfernt und dein Trend neu berechnet.';

  @override
  String get weightWeighInActions => 'Aktionen für Wiegeeintrag';

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
  String get addFoodSaved => 'Gespeichert';

  @override
  String get addFoodRecent => 'Zuletzt';

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
  String get addFoodHowMuch => 'Wie viel?';

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
  String trainWeekNumber(int number) {
    return 'WOCHE $number';
  }

  @override
  String trainWeekDone(int completed, int target) {
    return '$completed von $target erledigt';
  }

  @override
  String get trainRestHint => 'Ruhetage zählen nicht gegen dich';

  @override
  String get trainTodayHeading => 'HEUTE';

  @override
  String trainAboutMinutes(int minutes) {
    return 'Etwa $minutes Min.';
  }

  @override
  String get trainStartSession => 'Training starten';

  @override
  String get trainThisWeekHeading => 'DIESE WOCHE';

  @override
  String get trainEmptyWeek =>
      'Noch keine Einheiten geplant. Deine Trainingswoche erscheint hier, sobald dein Camp eingerichtet ist.';

  @override
  String get trainEmptyHistory =>
      'Schließe eine Einheit ab oder trage sie ein, um deinen Verlauf aufzubauen';

  @override
  String get trainHistoryTitle => 'Trainingsverlauf';

  @override
  String get profileAthleteFallback => 'Kämpfer';

  @override
  String get profileSubscriptionSection => 'Abo';

  @override
  String get profileTrainingSection => 'Training';

  @override
  String get profileTrainingDays => 'Trainingstage';

  @override
  String profileTrainingDaysValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage pro Woche',
      one: '1 Tag pro Woche',
    );
    return '$_temp0';
  }

  @override
  String get profileWeightTracker => 'Gewichtsverlauf';

  @override
  String get profileWeightTrackerHint =>
      'Deine Wiegeeinträge und dein Gewichtsverlauf';

  @override
  String get profilePreferencesSection =>
      'Einstellungen, Datenschutz und Konto';

  @override
  String get profileSettingsHint =>
      'Einheiten, Erinnerungen, Daten und Kontoeinstellungen';

  @override
  String get firstWeekPlanTitle => 'Plan erstellen';

  @override
  String get firstWeekPlanHint =>
      'Dein Ziel und deine Trainingswoche stehen fest.';

  @override
  String get firstWeekTourTitle => '30-Sekunden-Rundgang starten';

  @override
  String get firstWeekTourHint => 'Sieh dir an, wo du alles findest.';

  @override
  String get firstWeekMealTitle => 'Erste Mahlzeit eintragen';

  @override
  String get firstWeekMealHint =>
      'Ein Tipp in Fuel genügt. So beginnt dein Tagesüberblick.';

  @override
  String get firstWeekSessionTitle => 'Trainingseinheit abschließen';

  @override
  String get firstWeekSessionHint =>
      'Schließe eine Einheit in Training ab und baue Beständigkeit auf.';

  @override
  String get firstWeekTitle => 'Deine erste Woche';

  @override
  String get firstWeekCompletedTitle => 'Erste Woche: geschafft';

  @override
  String firstWeekProgress(int completed, int total) {
    return '$completed von $total';
  }

  @override
  String get firstWeekCompleteHint =>
      'Plan erstellt, Mahlzeit eingetragen, erste Einheit geschafft. Das ist ein echter Anfang — trainiere diese Woche weiter.';

  @override
  String get firstWeekDone => 'Fertig';

  @override
  String firstWeekSemanticsDone(String title) {
    return '$title, erledigt';
  }

  @override
  String get firstWinTitle => 'Erste Mahlzeit eingetragen.';

  @override
  String get firstWinWithNumbers =>
      'Du bist gestartet. Jede eingetragene Mahlzeit zeigt dir, wo du heute im Vergleich zu deinem Ziel stehst.';

  @override
  String get firstWinWithoutNumbers =>
      'Du bist gestartet. Trage weiter ein, was du isst.';

  @override
  String get firstWinContinue => 'Weiter so';

  @override
  String sessionLogRpe(int value) {
    return 'Belastung $value / 10';
  }

  @override
  String get sessionLogReflection => 'Kurze Notiz';

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
  String get timerYourCorner => 'Deine Ecke';

  @override
  String get timerCornerTeaser =>
      'Mit Pro steht dir in der Pause deine Ecke zur Seite: ein Hinweis für die nächste Runde.';

  @override
  String get timerNextSessionComplete => 'Einheit beendet';

  @override
  String get timerNextFinalRound => 'Letzte Runde';

  @override
  String get timerNextRest => 'Pause';

  @override
  String timerNextRound(int round) {
    return 'Runde $round';
  }

  @override
  String get timerCallTime => 'Zeit';

  @override
  String get timerCallRest => 'Pause';

  @override
  String get timerCallTenSeconds => 'Zehn Sekunden';

  @override
  String timerClockSemantics(int minutes, int seconds) {
    return 'Noch $minutes Minuten $seconds Sekunden';
  }

  @override
  String timerAnnounceWork(int round, int total) {
    return 'Runde $round von $total. Los.';
  }

  @override
  String timerAnnounceRest(int round) {
    return 'Runde $round vorbei. Pause.';
  }

  @override
  String get timerAnnounceDone => 'Einheit beendet.';

  @override
  String get paywallRenewalDisclosure =>
      'Abonnements verlängern sich automatisch zum oben angezeigten Preis und Zeitraum, sofern sie nicht mindestens 24 Stunden vor Ende des laufenden Zeitraums gekündigt werden. Die Zahlung wird bei Bestätigung des Kaufs über deine Apple-ID bzw. dein Google-Play-Konto abgerechnet. Du kannst dein Abo jederzeit in den Einstellungen deines Store-Kontos verwalten oder kündigen.';

  @override
  String get legalTermsLink => 'Nutzungsbedingungen';

  @override
  String get legalPrivacyLink => 'Datenschutzerklärung';

  @override
  String get legalOpenPublished => 'Veröffentlichte Fassung öffnen';

  @override
  String get consentTitle => 'Hilf uns, Fighter Edge zu verbessern';

  @override
  String get consentBody =>
      'Mit deiner Erlaubnis erfassen wir anonyme Nutzungsereignisse und Absturzberichte. Sie enthalten nie deine Mahlzeiten, dein Gewicht, Körpermaße, Nachrichten oder deine E-Mail-Adresse. Ohne deine Erlaubnis wird nichts gesendet.';

  @override
  String get consentAllow => 'Erlauben';

  @override
  String get consentDecline => 'Nicht erlauben';

  @override
  String get consentChangeLater =>
      'Du kannst das jederzeit in den Einstellungen ändern.';

  @override
  String get settingsSectionPrivacy => 'Datenschutz';

  @override
  String get settingsAnalytics => 'Nutzungsanalyse';

  @override
  String get settingsAnalyticsSubtitle =>
      'Anonyme Ereignisse, die zeigen, welche Funktionen helfen. Keine Gesundheitsdaten.';

  @override
  String get settingsCrashReports => 'Absturzberichte';

  @override
  String get settingsCrashReportsSubtitle =>
      'Fehlerdetails, mit denen wir Bugs beheben. Keine persönlichen Daten.';

  @override
  String get healthConsentTitle => 'Deine Körperdaten, deine Entscheidung';

  @override
  String get healthConsentIntro =>
      'Um deinen Plan zu erstellen, braucht Fighter Edge Daten über deinen Körper und deine Gesundheit. Das Gesetz stuft diese Daten als besonders sensibel ein, deshalb bitten wir zuerst um deine ausdrückliche Einwilligung.';

  @override
  String get healthConsentWhatTitle => 'Was wir speichern';

  @override
  String get healthConsentWhat =>
      'Alter, Größe, Gewicht und Zielgewicht, Körperfett, falls du es angibst, das gewählte Energieprofil, Aktivitätslevel, Ernährungsweise, Allergien und Unverträglichkeiten sowie die Mahlzeiten, Gewichte und Trainings, die du einträgst.';

  @override
  String get healthConsentWhyTitle => 'Wofür wir sie nutzen';

  @override
  String get healthConsentWhy =>
      'Nur, um deine Ziele zu berechnen, deinen Fortschritt zu zeigen und dich anzuleiten. Nie für Werbung und nie verkauft.';

  @override
  String get healthConsentWhereTitle => 'Wo sie liegen';

  @override
  String get healthConsentWhere =>
      'In deinem Konto bei Google Firebase. Nur du kannst sie lesen.';

  @override
  String get healthConsentWithdraw =>
      'Du kannst deine Einwilligung jederzeit unter Einstellungen > Datenschutz widerrufen. Ohne diese Daten funktioniert die App nicht, deshalb löscht ein Widerruf dein Konto und seine Daten.';

  @override
  String get healthConsentStatement =>
      'Ich willige ein, dass Fighter Edge meine Gesundheitsdaten wie hier und in der Datenschutzerklärung beschrieben speichert und nutzt.';

  @override
  String get healthConsentAgree => 'Ich willige ein';

  @override
  String get healthConsentSignOut => 'Jetzt nicht, abmelden';

  @override
  String get healthConsentDeleteAccount => 'Stattdessen mein Konto löschen';

  @override
  String get settingsHealthData => 'Gesundheitsdaten';

  @override
  String settingsHealthDataGranted(String date) {
    return 'Eingewilligt am $date';
  }

  @override
  String get settingsHealthDataGrantedNoDate => 'Du hast eingewilligt';

  @override
  String get settingsHealthDataWithdrawTitle => 'Einwilligung widerrufen?';

  @override
  String get settingsHealthDataWithdrawBody =>
      'Ohne deine Gesundheitsdaten kann Fighter Edge weder deinen Plan berechnen noch deinen Fortschritt verfolgen. Ein Widerruf bedeutet deshalb, dass dein Konto mit allen Daten gelöscht wird.';

  @override
  String get settingsHealthDataWithdrawConfirm => 'Mein Konto löschen';

  @override
  String get deleteAccountSubscriptionWarning =>
      'Das Löschen deines Kontos kündigt dein Abo nicht. Kündige es zuerst in deinen App-Store- oder Google-Play-Einstellungen, sonst verlängert es sich weiter.';

  @override
  String get trainTabReaction => 'Reaktion';

  @override
  String get reactionTitle => 'Reaktionsdrill';

  @override
  String get reactionHeadline => 'Der Coach ruft. Du reagierst.';

  @override
  String get reactionSoundHint =>
      'Ton an. Jeder Durchgang wird neu gemischt – nichts zum Auswendiglernen.';

  @override
  String get reactionDisciplineGrappling => 'Ringen';

  @override
  String get reactionDisciplineStriking => 'Striking';

  @override
  String get reactionDisciplineMma => 'MMA';

  @override
  String get reactionLevelBeginner => 'Anfänger';

  @override
  String get reactionLevelIntermediate => 'Mittelstufe';

  @override
  String get reactionLevelAdvanced => 'Fortgeschritten';

  @override
  String get reactionLevelAdvancedPlus => 'Fortgeschritten+';

  @override
  String get reactionPaceSteady => 'Gleichmäßig';

  @override
  String get reactionPaceSprint => 'Sprint';

  @override
  String get reactionStatDuration => 'Dauer';

  @override
  String get reactionStatReact => 'Reaktion';

  @override
  String reactionInTheMix(int count) {
    return 'IM MIX · $count';
  }

  @override
  String get reactionStart => 'Drill starten';

  @override
  String get reactionGetInStance => 'IN KAMPFSTELLUNG';

  @override
  String get reactionStop => 'Stopp';

  @override
  String get reactionTimeUp => 'ZEIT';

  @override
  String reactionSummary(int calls, int moves) {
    return '$calls Rufe · $moves Bewegungen';
  }

  @override
  String get reactionAgain => 'Nochmal';

  @override
  String get reactionDone => 'Fertig';

  @override
  String get reactionNoVoice =>
      'Keine Sprachausgabe auf diesem Gerät. Folge den Rufen auf dem Bildschirm.';

  @override
  String get reactionTestVoice => 'Stimme testen';

  @override
  String get reactionShowAll => 'Alle zeigen';

  @override
  String get reactionShowLess => 'Weniger zeigen';

  @override
  String get reactionPause => 'Pause';

  @override
  String get reactionResume => 'Weiter';

  @override
  String get reactionPaused => 'PAUSIERT';

  @override
  String reactionTimeLeft(String time) {
    return 'Noch $time';
  }

  @override
  String reactionCallNumber(int n) {
    return 'RUF $n';
  }

  @override
  String reactionFinishedSummary(int calls, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      calls,
      locale: localeName,
      other: '$calls Rufe',
      one: '1 Ruf',
    );
    return '$_temp0 in $time';
  }

  @override
  String reactionNextLevel(String level) {
    return 'Bereit für $level?';
  }

  @override
  String reactionStopped(String time, int calls) {
    String _temp0 = intl.Intl.pluralLogic(
      calls,
      locale: localeName,
      other: '$calls Rufe',
      one: '1 Ruf',
    );
    return 'Gestoppt bei $time · $_temp0';
  }

  @override
  String get reactionLeaveTitle => 'Drill verlassen?';

  @override
  String get reactionLeaveBody => 'Dieser Durchgang wird beendet.';

  @override
  String get reactionLeaveStay => 'Weitermachen';

  @override
  String get reactionLeaveConfirm => 'Verlassen';

  @override
  String reactionBlockRestNote(String time, int min, int max) {
    return '+$time s Pause alle $min–$max Rufe';
  }

  @override
  String devMessageFrom(String from) {
    return 'VON $from';
  }

  @override
  String get devMessageGotIt => 'Alles klar';

  @override
  String get foodMarkEaten => 'Als gegessen markieren';

  @override
  String get foodMarkNotEaten => 'Als nicht gegessen markieren';

  @override
  String foodMarkedEaten(String name) {
    return '$name als gegessen markiert';
  }

  @override
  String foodMarkedNotEaten(String name) {
    return '$name als nicht gegessen markiert';
  }

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonSaveMeal => 'Speichern';

  @override
  String get commonUnsave => 'Nicht mehr speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get authWelcomeBack => 'Willkommen zurück';

  @override
  String get authWelcomeBackSubtitle => 'Melde dich an und mach im Camp weiter';

  @override
  String get authEmailRequired => 'Gib deine E-Mail-Adresse ein.';

  @override
  String get authEmailIncomplete => 'Die E-Mail-Adresse ist unvollständig.';

  @override
  String get authPasswordRequired => 'Gib dein Passwort ein.';

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

  @override
  String get dashboardFighter => 'Athlet';

  @override
  String get dashboardToday => 'Heute';

  @override
  String get dashboardNoPlan => 'Noch keine Einheiten geplant';

  @override
  String get dashboardWeekDone => 'Woche abgeschlossen';

  @override
  String get dashboardRestDay => 'Ruhetag';

  @override
  String get dashboardRecovery =>
      'Deine geplanten Einheiten sind erledigt. Nimm dir Zeit zur Erholung.';

  @override
  String get dashboardPlanHint => 'Öffne Training, um deine Woche zu planen.';

  @override
  String dashboardNextUp(String day, String session) {
    return 'Als Nächstes: $day · $session';
  }

  @override
  String get dashboardLogSession => 'Einheit erfassen';

  @override
  String get dashboardTimerAction => 'Runden-Timer';

  @override
  String get dashboardOpenCamp => 'Trainingsplan öffnen';

  @override
  String dashboardStatWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wochen',
      one: 'Woche',
    );
    return '$_temp0';
  }

  @override
  String get weeklyCardTitle => 'Diese Woche';

  @override
  String get weeklyCardRestWeek => 'Ruhewoche';

  @override
  String get weeklyCardRestWeekHint =>
      'Keine Einheiten geplant. Ruhe gehört zum Plan.';

  @override
  String weeklyCardProgress(int done, int planned) {
    return '$done von $planned erledigt';
  }

  @override
  String weeklyCardNext(String day, String session) {
    return 'Als Nächstes: $day $session';
  }

  @override
  String get weeklyCardAllDone => 'Alle geplanten Einheiten erledigt';

  @override
  String get weeklyCardNothingLeft =>
      'Diese Woche sind keine Einheiten mehr geplant';

  @override
  String weeklyCardTarget(int target) {
    return '$target nötig, damit die Woche zählt';
  }

  @override
  String weeklyCardStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wochen in Folge',
      one: '1 Woche in Folge',
    );
    return '$_temp0';
  }

  @override
  String get weeklyCardReview => 'Wochenrückblick';

  @override
  String get reviewTitle => 'Wochenrückblick';

  @override
  String reviewWeekOf(String date) {
    return 'Woche ab $date';
  }

  @override
  String get reviewTraining => 'Training';

  @override
  String reviewSessionsDone(int done, int planned) {
    return '$done von $planned Einheiten erledigt';
  }

  @override
  String get reviewFood => 'Ernährung';

  @override
  String get reviewFoodNoTarget =>
      'Richte Fuel ein, um deine Woche mit einem Ziel zu vergleichen.';

  @override
  String get reviewFoodNoLogs =>
      'Diese Woche wurden keine Mahlzeiten eingetragen.';

  @override
  String reviewFoodAverage(int average, int target) {
    return 'Durchschnitt $average kcal am Tag bei einem Ziel von $target.';
  }

  @override
  String get reviewWeight => 'Gewicht';

  @override
  String get reviewWeightNoData => 'Noch zu wenige Wiegungen für einen Trend.';

  @override
  String get reviewWeightNoPath => 'Kein Gewichtspfad zum Vergleichen.';

  @override
  String reviewWeightPath(String change) {
    return 'Pfad: $change diese Woche';
  }

  @override
  String get reviewRecommendation => 'Empfehlung';

  @override
  String get reviewRecMoveSession =>
      'Eine geplante Einheit ist übrig. Auf heute verschieben?';

  @override
  String reviewRecLower(int kcal) {
    return 'Dein Gewicht liegt über deinem Pfad und du hast dein Ziel gegessen. Tagesziel um $kcal kcal senken?';
  }

  @override
  String reviewRecRaise(int kcal) {
    return 'Dein Gewicht liegt unter deinem Pfad und du hast dein Ziel gegessen. Tagesziel um $kcal kcal erhöhen?';
  }

  @override
  String get reviewHoldOnPath =>
      'Du liegst auf Kurs. Lass deinen Plan, wie er ist.';

  @override
  String get reviewHoldNoTarget =>
      'Richte Fuel ein, um ein Kalorienziel zu bekommen, bevor Änderungen vorgeschlagen werden.';

  @override
  String get reviewHoldNeedLogs =>
      'Trage mindestens vier Tage Essen ein, bevor dein Ziel geändert wird.';

  @override
  String get reviewHoldIntake =>
      'Du warst diese Woche nicht nah an deinem Ziel, deshalb bleibt es. Erreiche es zuerst.';

  @override
  String get reviewHoldNoPath =>
      'Zu wenige Wiegungen oder kein Pfad, an dem sich die Waage messen lässt. Dein Ziel bleibt.';

  @override
  String get reviewHoldFloor =>
      'Weniger zu essen würde unter deinen geschätzten Grundumsatz fallen. Dein Ziel bleibt.';

  @override
  String get reviewAccept => 'Annehmen';

  @override
  String get reviewKeepCurrent => 'Aktuellen Plan behalten';

  @override
  String get reviewGotIt => 'Verstanden';

  @override
  String get reviewAccepted => 'Du hast diesen Rückblick angenommen.';

  @override
  String get reviewKept => 'Du hast deinen aktuellen Plan behalten.';

  @override
  String get dashboardSetFuel => 'Ernährungsziel festlegen';

  @override
  String get dashboardFuelInfo => 'Warum dieses Ziel wichtig ist';

  @override
  String get dashboardFuelExplanation =>
      'Kalorien unterstützen dein Ziel. Eiweiß unterstützt Erholung und Muskeln. Kohlenhydrate liefern Energie fürs Training.';

  @override
  String get commonClose => 'Schließen';

  @override
  String get dashboardNoActivity =>
      'Schließe deine erste Einheit ab, um deinen Verlauf zu starten.';

  @override
  String get dashboardVerifyEmail => 'E-Mail bestätigen';

  @override
  String get dashboardConfirmEmail => 'E-Mail bestätigen';

  @override
  String get dashboardYesterday => 'Gestern';

  @override
  String dashboardDaysAgo(int count) {
    return 'Vor $count Tagen';
  }

  @override
  String dashboardChecklistProgress(int done, int total) {
    return '$done von $total erledigt';
  }

  @override
  String get nutritionKcalLeft => 'kcal übrig';

  @override
  String nutritionOverTarget(int kcal) {
    return 'Tagesziel erreicht, plus $kcal kcal';
  }

  @override
  String get nutritionViewPlan => 'Ernährungsplan ansehen';

  @override
  String get nutritionRecipesFit => 'Passende Rezepte';

  @override
  String nutritionMacroGrams(int value, int target) {
    return '$value / $target g';
  }

  @override
  String nutritionGrams(int value) {
    return '$value g';
  }

  @override
  String get trainingSessionDone => 'Erledigt';

  @override
  String get tplGenericSkill => 'Technik-Einheit';

  @override
  String get tplGenericSparring => 'Sparring-Einheit';

  @override
  String get tplGenericConditioning => 'Konditionseinheit';

  @override
  String get tplGenericStrength => 'Krafteinheit';

  @override
  String get tplGenericRecovery => 'Regenerationseinheit';

  @override
  String get tplGenericGymClass => 'Kurs im Gym';

  @override
  String get planDisciplineBoxing => 'Boxen';

  @override
  String get planDisciplineKickboxing => 'Kickboxen';

  @override
  String get planDisciplineMuayThai => 'Muay Thai';

  @override
  String get planDisciplineWrestling => 'Ringen';

  @override
  String get planDisciplineBjj => 'BJJ';

  @override
  String get planDisciplineMma => 'MMA';

  @override
  String planSessionMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String planSessionSubtitle(String discipline, int minutes) {
    return '$discipline · $minutes Min.';
  }

  @override
  String get planStatusSkipped => 'Übersprungen';

  @override
  String get planStatusNotDone => 'Nicht gemacht';

  @override
  String planStatusMovedTo(String day) {
    return 'Verschoben auf $day';
  }

  @override
  String planStatusMovedFrom(String day) {
    return 'Verschoben von $day';
  }

  @override
  String get planActionSkip => 'Überspringen';

  @override
  String get planActionMoveToToday => 'Auf heute verschieben';

  @override
  String get planActionPutBack => 'Zurücksetzen';

  @override
  String get planActionMore => 'Weitere Optionen';

  @override
  String trainingLogNamedSession(String session) {
    return '$session erfassen';
  }

  @override
  String get trainTools => 'Werkzeuge';

  @override
  String get trainTimerToolSubtitle =>
      'Freie Intervalle für Sparring, MMA, Boxen oder BJJ';

  @override
  String get onboardingBack => 'Zurück';

  @override
  String onboardingStep(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String onboardingSummary(int days, String level, String goal) {
    return '$days Tage pro Woche · $level · $goal';
  }

  @override
  String get onboardingLoseFat => 'Fett verlieren';

  @override
  String get onboardingMaintain => 'Gewicht halten';

  @override
  String get onboardingGainMuscle => 'Muskeln aufbauen';

  @override
  String get onboardingBeginner => 'Anfänger';

  @override
  String get onboardingIntermediate => 'Fortgeschritten';

  @override
  String get onboardingAdvanced => 'Erfahren';

  @override
  String get onboardingFighter => 'Wettkämpfer';

  @override
  String get welcomeProgressTitle => 'Sieh deine Fortschritte.';

  @override
  String get welcomeCampTitle => 'Dein Camp, klar geplant.';

  @override
  String get welcomeCampBody =>
      'Trainingswoche, Gewicht und Ernährung an einem Ort — abgestimmt auf die Tage, an denen du trainieren kannst.';

  @override
  String get welcomeFuelTitle => 'Ernährung passend zum Training.';

  @override
  String get welcomeFuelBody =>
      'EdgeFuel berechnet Kalorien und Makros aus deinen Körperdaten und deinem Trainingsumfang und zeigt dir beim Eintragen, wo du stehst.';

  @override
  String get welcomeProgressBody =>
      'Dein Trainingsrhythmus, Gewichtsverlauf und deine Trainingshistorie zeigen dir Fortschritte von Woche zu Woche — nicht nur heute.';

  @override
  String get welcomeWeeklyPlan => 'Wochenplan';

  @override
  String get welcomeSessionLog => 'Trainingstagebuch';

  @override
  String get welcomeWeighIns => 'Wiegeeinträge';

  @override
  String get welcomeDailyTarget => 'Tagesziel';

  @override
  String get welcomeMacroSplit => 'Makroverteilung';

  @override
  String get welcomeMealLog => 'Ernährungstagebuch';

  @override
  String get welcomeStreaks => 'Beständigkeit';

  @override
  String get welcomeWeightTrend => 'Gewichtsverlauf';

  @override
  String get welcomeHistory => 'Verlauf';

  @override
  String get welcomeSkip => 'Überspringen';

  @override
  String get welcomeBuildPlan => 'Plan erstellen';

  @override
  String get welcomeDuration => 'Etwa 2 Minuten · 7 kurze Fragen';

  @override
  String welcomePage(int current, int total) {
    return 'Seite $current von $total';
  }

  @override
  String get setupCampEyebrow => 'Neues Konto';

  @override
  String get setupCampQuestion => 'Womit soll Fighter Edge beginnen?';

  @override
  String get setupCampHint =>
      'Wähle das Ziel, das dein erstes Trainingscamp bestimmen soll.';

  @override
  String get setupNutritionEyebrow => 'Ernährungsziel';

  @override
  String get setupNutritionQuestion =>
      'Worauf soll EdgeFuel ausgerichtet sein?';

  @override
  String get setupNutritionHint =>
      'Daraus entsteht dein erstes Kalorien- und Makroziel. Du kannst es später ändern.';

  @override
  String get setupBodyEyebrow => 'Körperdaten';

  @override
  String get setupBodyQuestion => 'Wo stehst du gerade?';

  @override
  String get setupBodyHint =>
      'Du brauchst keine Gewichtsklasse. Deine üblichen Körperdaten reichen für ein persönliches Ziel.';

  @override
  String get setupEquationEyebrow => 'Kalorienformel';

  @override
  String get setupEquationQuestion => 'Welche Formel passt zu deinem Körper?';

  @override
  String get setupEquationHint =>
      'Die Kalorienformeln für männliche und weibliche Physiologie unterscheiden sich leicht — um etwa 80 kcal pro Tag. Das verfeinert nur die Schätzung. Du kannst die Angabe überspringen.';

  @override
  String get setupActivityEyebrow => 'Alltagsbewegung';

  @override
  String get setupActivityQuestion =>
      'Wie aktiv bist du außerhalb des Trainings?';

  @override
  String get setupActivityHint =>
      'Das zählt getrennt von deinen Trainingstagen, damit Kalorien nicht doppelt berechnet werden.';

  @override
  String get setupRhythmEyebrow => 'Trainingsrhythmus';

  @override
  String get setupRhythmQuestion => 'An wie vielen Tagen kannst du trainieren?';

  @override
  String get setupRhythmHint =>
      'Wähle eine realistische Woche. Regelmäßigkeit ist wichtiger als ein unerreichbarer Plan.';

  @override
  String get setupReviewEyebrow => 'Prüfen';

  @override
  String get setupReviewQuestion => 'Dein erster Plan ist bereit.';

  @override
  String get setupReviewHint =>
      'Fighter Edge beginnt mit einer leeren Übersicht, einer Trainingswoche und einem EdgeFuel-Ziel.';

  @override
  String get setupCampStructure => 'Struktur fürs Trainingscamp aufbauen';

  @override
  String get setupCampLoseWeight => 'Sicher Gewicht verlieren';

  @override
  String get setupCampGainMuscle => 'Muskeln aufbauen';

  @override
  String get setupCampTechnique => 'Technik verbessern';

  @override
  String get setupCampCompetition => 'Auf den Wettkampf vorbereiten';

  @override
  String get setupGoalLoseDescription =>
      'Körperfett reduzieren und dabei Kraft und Trainingsqualität erhalten.';

  @override
  String get setupGoalMaintainLabel => 'Halten';

  @override
  String get setupGoalMaintainDescription =>
      'Dein Gewicht halten und gleichbleibende Leistung unterstützen.';

  @override
  String get setupGoalGainDescription =>
      'Mit einem kontrollierten Kalorienüberschuss Muskeln aufbauen.';

  @override
  String get setupEquationHigher => 'Männliche Physiologie';

  @override
  String get setupEquationLower => 'Weibliche Physiologie';

  @override
  String get setupEquationNeutral => 'Keine Angabe';

  @override
  String get setupEquationHigherHint =>
      'Die Standardformel für männliche Körper.';

  @override
  String get setupEquationLowerHint =>
      'Die Standardformel für weibliche Körper.';

  @override
  String get setupEquationNeutralHint =>
      'Wir verwenden den Mittelwert und zeigen eine etwas größere Spanne.';

  @override
  String get setupActivityVeryLow => 'Sehr gering';

  @override
  String get setupActivityLight => 'Leicht';

  @override
  String get setupActivityModerate => 'Mittel';

  @override
  String get setupActivityHigh => 'Hoch';

  @override
  String get setupActivityVeryHigh => 'Sehr hoch';

  @override
  String get setupActivityVeryLowHint =>
      'Meist sitzend — Schreibtischarbeit, kaum Spaziergänge.';

  @override
  String get setupActivityLightHint =>
      'Gelegentlich auf den Beinen — Unterricht, leichter Verkauf, kurze Wege.';

  @override
  String get setupActivityModerateHint =>
      'Regelmäßig aktiv — körperliche Arbeit, tägliche Spaziergänge, Wege zu Fuß.';

  @override
  String get setupActivityHighHint =>
      'Im Alltag sehr aktiv — körperliche Arbeit, lange Schichten im Stehen.';

  @override
  String get setupActivityVeryHighHint =>
      'Ständig in Bewegung — Handarbeit, Lieferdienst oder Landwirtschaft.';

  @override
  String get setupAge => 'Alter';

  @override
  String get setupHeight => 'Größe in cm';

  @override
  String get setupCurrentWeight => 'Aktuelles Gewicht in kg';

  @override
  String get setupTargetMilestone => 'Zielgewicht in kg';

  @override
  String get setupGainMilestone => 'Gewichtsziel für Zunahme in kg';

  @override
  String get setupOptionalMilestone =>
      'Optional: Wenn du das Feld leer lässt, beginnt Fighter Edge mit einem sicheren 5-%-Zwischenziel.';

  @override
  String get setupSummaryCamp => 'Camp';

  @override
  String get setupSummaryNutrition => 'Ernährung';

  @override
  String get setupSummaryExperience => 'Erfahrung';

  @override
  String get setupSummaryTraining => 'Training';

  @override
  String get setupSummaryActivity => 'Alltagsbewegung';

  @override
  String setupDaysPerWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage pro Woche',
      one: '1 Tag pro Woche',
    );
    return '$_temp0';
  }

  @override
  String setupDaysUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tage pro Woche',
      one: 'Tag pro Woche',
    );
    return '$_temp0';
  }

  @override
  String get setupFewerDays => 'Weniger Tage';

  @override
  String get setupMoreDays => 'Mehr Tage';

  @override
  String get setupCreatingPlan => 'Dein Plan wird erstellt...';

  @override
  String get setupStartPlan => 'Meinen Plan starten';

  @override
  String get setupContinue => 'Weiter';

  @override
  String get setupSkipTarget => 'Detailliertes Ziel vorerst überspringen';

  @override
  String get setupSaveError =>
      'Einrichtung konnte nicht gespeichert werden. Versuche es erneut.';

  @override
  String get setupBodyMissing => 'Ergänze zuerst deine Körperdaten.';

  @override
  String get setupReviewNeeded =>
      'Diese Angaben müssen geprüft werden, bevor wir ein Ziel erstellen können.';

  @override
  String get setupOpenError =>
      'Dein Plan konnte nicht geöffnet werden. Versuche es erneut.';

  @override
  String get setupAgeError =>
      'Gib für automatische Ziele ein Alter zwischen 18 und 90 ein.';

  @override
  String get setupHeightError => 'Gib deine Größe in cm ein, zum Beispiel 178.';

  @override
  String get setupWeightError =>
      'Gib dein aktuelles Gewicht in kg zwischen 35 und 220 ein, zum Beispiel 78.';

  @override
  String get setupScreeningError =>
      'Prüfe alle Gesundheitsfragen, bevor ein Ziel erstellt wird.';

  @override
  String get setupTargetError =>
      'Das Zielgewicht muss ein realistischer Wert in kg sein.';

  @override
  String get setupLossTargetError =>
      'Zum Abnehmen muss das Zielgewicht unter dem aktuellen Gewicht liegen.';

  @override
  String get setupGainTargetError =>
      'Zum Zunehmen muss das Zielgewicht über dem aktuellen Gewicht liegen.';

  @override
  String get setupHealthTitle => 'Kurzer Gesundheitscheck';

  @override
  String get setupHealthHint =>
      'Wir speichern nur Ja/Nein-Angaben, keine Details. Falls etwas zutrifft, bitten wir dich vor einem automatischen Plan um Rücksprache mit einer qualifizierten Fachperson.';

  @override
  String get setupHealthPregnant => 'Schwanger oder stillend';

  @override
  String get setupHealthEatingDisorder =>
      'Essstörung in der Vorgeschichte oder entsprechende Symptome';

  @override
  String get setupHealthDiabetes => 'Diabetes mit Medikamentenbehandlung';

  @override
  String get setupHealthKidney => 'Nierenerkrankung';

  @override
  String get setupHealthLiver => 'Schwere Lebererkrankung';

  @override
  String get setupHealthOtherDiet => 'Andere ärztlich betreute Ernährung';

  @override
  String get setupHealthReviewed => 'Ich habe alle Gesundheitsfragen geprüft';

  @override
  String get setupReasonScreeningUnanswered =>
      'Prüfe die Gesundheitsfragen, bevor ein automatisches Ziel angezeigt werden kann.';

  @override
  String get setupReasonScreeningNeedsReview =>
      'Bitte sprich vor einem automatischen Plan mit einer qualifizierten Fachperson.';

  @override
  String get setupReasonUnderAge =>
      'Automatische Pläne sind erst ab 18 Jahren verfügbar.';

  @override
  String get setupReasonInvalidVitals =>
      'Größe, Gewicht oder Alter scheinen ungültig zu sein.';

  @override
  String get setupReasonUnderweight =>
      'Deine Angaben liegen im Untergewichtsbereich. Ein automatischer Plan zum Fettabbau ist deshalb gesperrt.';

  @override
  String get setupReasonInvalidFatLoss =>
      'Für einen Plan zum Fettabbau muss dein Zielgewicht unter deinem aktuellen Gewicht liegen.';

  @override
  String get setupReasonInvalidMuscleGain =>
      'Für einen Plan zum Muskelaufbau muss dein Zielgewicht über deinem aktuellen Gewicht liegen.';

  @override
  String get setupReasonMissingTarget =>
      'Für dieses Ziel brauchst du ein Zielgewicht.';

  @override
  String get setupReasonMissingPace => 'Für dieses Ziel brauchst du ein Tempo.';

  @override
  String get setupReasonRmrRange =>
      'Deine Angaben ergeben einen Wert außerhalb des sicheren Bereichs. Prüfe Größe, Gewicht und Alter.';

  @override
  String get fuelSetupTitle => 'Fuel einrichten';

  @override
  String get fuelSetupSignIn => 'Melde dich an, um EdgeFuel einzurichten.';

  @override
  String get fuelStepGoal => 'Ziel';

  @override
  String get fuelStepBody => 'Körper';

  @override
  String get fuelStepActivity => 'Aktivität';

  @override
  String get fuelStepTraining => 'Training';

  @override
  String get fuelStepFood => 'Ernährung';

  @override
  String get fuelStepReview => 'Prüfen';

  @override
  String fuelStepProgress(int current, int total, String title) {
    return 'Schritt $current von $total · $title';
  }

  @override
  String get fuelSetupNext => 'Weiter';

  @override
  String get fuelSetupSaveError =>
      'Dein Fuel-Plan konnte nicht gespeichert werden. Versuche es erneut.';

  @override
  String get fuelGoalQuestion => 'Wofür trainierst du?';

  @override
  String get fuelGoalHint =>
      'Das gibt deinem Plan die Richtung. Das Tempo kannst du später anpassen.';

  @override
  String get fuelBodyQuestion => 'Erzähl uns von deinem Körper';

  @override
  String get fuelBodyHint =>
      'Diese Angaben dienen nur zur Schätzung deines Energiebedarfs und werden nie öffentlich gezeigt.';

  @override
  String get fuelAge => 'Alter in Jahren';

  @override
  String get fuelHeight => 'Größe in cm';

  @override
  String get fuelCurrentWeight => 'Aktuelles Gewicht in kg';

  @override
  String get fuelTargetWeight => 'Zielgewicht in kg';

  @override
  String get fuelActivityQuestion => 'Deine Alltagsbewegung';

  @override
  String get fuelActivityHint =>
      'Bewegung außerhalb des Trainings — Fighter-Edge-Einheiten zählen im nächsten Schritt getrennt.';

  @override
  String get fuelTrainingQuestion => 'Deine Trainingswoche';

  @override
  String get fuelTrainingHint =>
      'Fighter-Edge-Einheiten pro Woche — so zählen wir Training und Alltagsbewegung nicht doppelt.';

  @override
  String get fuelFewerDays => 'Weniger Trainingstage pro Woche';

  @override
  String get fuelMoreDays => 'Mehr Trainingstage pro Woche';

  @override
  String fuelDaysUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tage / Woche',
      one: 'Tag / Woche',
    );
    return '$_temp0';
  }

  @override
  String get fuelPaceQuestion => 'Wie schnell?';

  @override
  String get fuelPaceGentle => 'Behutsam';

  @override
  String get fuelPaceStandard => 'Standard';

  @override
  String get fuelPaceUpper => 'Obergrenze';

  @override
  String get fuelPaceConservative => 'Vorsichtig';

  @override
  String get fuelPaceGentleHint => 'Etwa 0,25 % des Körpergewichts pro Woche.';

  @override
  String get fuelPaceStandardHint =>
      'Etwa 0,5 % des Körpergewichts pro Woche — empfohlen.';

  @override
  String get fuelPaceUpperHint =>
      'Etwa 0,75 % des Körpergewichts pro Woche, die automatische Obergrenze.';

  @override
  String get fuelPaceConservativeHint =>
      'Etwa 0,10–0,25 % des Körpergewichts pro Woche.';

  @override
  String get fuelPaceGainHint =>
      'Etwa 0,25–0,50 % des Körpergewichts pro Woche — empfohlen.';

  @override
  String get fuelFoodQuestion => 'Ernährungsvorlieben';

  @override
  String get fuelFoodHint =>
      'Jetzt optional — später für Mahlzeitenvorschläge, sobald Rezepte verfügbar sind.';

  @override
  String get fuelDietType => 'Ernährungsweise';

  @override
  String get fuelDietOmnivore => 'Allesesser';

  @override
  String get fuelDietVegetarian => 'Vegetarisch';

  @override
  String get fuelDietVegan => 'Vegan';

  @override
  String get fuelDietPescatarian => 'Pescetarisch';

  @override
  String get fuelDietHalal => 'Halal';

  @override
  String get fuelAllergens => 'Allergene (durch Kommas getrennt)';

  @override
  String get fuelDislikes => 'Ungeliebte Lebensmittel (durch Kommas getrennt)';

  @override
  String get fuelMealsPerDay => 'Mahlzeiten pro Tag';

  @override
  String get fuelFewerMeals => 'Weniger Mahlzeiten pro Tag';

  @override
  String get fuelMoreMeals => 'Mehr Mahlzeiten pro Tag';

  @override
  String get fuelBudget => 'Budget';

  @override
  String get fuelBudgetLow => 'Niedrig';

  @override
  String get fuelBudgetMedium => 'Mittel';

  @override
  String get fuelBudgetHigh => 'Hoch';

  @override
  String get fuelCookingTime => 'Verfügbare Kochzeit';

  @override
  String get fuelCookingQuick => 'Kurz';

  @override
  String get fuelCookingModerate => 'Mittel';

  @override
  String get fuelCookingExtended => 'Länger';

  @override
  String get fuelReviewMoreSteps => 'Noch ein paar Schritte';

  @override
  String get fuelReviewMoreStepsHint =>
      'Schließe die vorherigen Schritte ab, um deinen persönlichen Plan zu sehen.';

  @override
  String get fuelReviewUnsupported =>
      'Dafür können wir noch keinen automatischen Plan erstellen';

  @override
  String get fuelReviewProfessional =>
      'Sprich bitte zuerst mit einer Fachperson';

  @override
  String get fuelReviewProfessionalIntro =>
      'Nach deinen Angaben ist ein automatischer Plan hier nicht passend:';

  @override
  String get fuelReviewProfessionalOutro =>
      'Sprich vor einem automatischen Plan mit einer qualifizierten Fachperson. Du kannst Mahlzeiten und Gewohnheiten auch ohne Kalorienziel erfassen.';

  @override
  String get fuelReviewTitle => 'Dein Plan';

  @override
  String get fuelReviewHint =>
      'Eine Schätzung, keine Diagnose. Du kannst diese Angaben jederzeit erneut prüfen.';

  @override
  String get fuelReviewDailyTarget => 'Tagesziel';

  @override
  String fuelReviewMaintenanceRange(String low, String high) {
    return 'Erhaltungsbereich $low–$high kcal';
  }

  @override
  String get fuelReviewAssumptions => 'Annahmen';

  @override
  String get fuelReviewGoal => 'Ziel';

  @override
  String get fuelReviewEquation => 'Formel';

  @override
  String get fuelReviewActivity => 'Alltagsbewegung';

  @override
  String get fuelReviewPace => 'Tempo';

  @override
  String get fuelReviewProteinBasedOn => 'Protein bezogen auf';

  @override
  String get fuelReviewConfidence => 'Sicherheit der Schätzung';

  @override
  String get fuelReviewFiber => 'Ballaststoffbereich';

  @override
  String get fuelReviewWorthKnowing => 'Wichtig zu wissen';

  @override
  String get fuelReviewConfirm => 'Plan bestätigen';

  @override
  String get fuelReviewFooter =>
      'Du kannst Kalorienzahlen ausblenden und nur Mahlzeiten erfassen oder die Ziele später in den Fuel-Einstellungen ändern.';

  @override
  String get fuelConfidenceHigh => 'Hohe Sicherheit';

  @override
  String get fuelConfidenceMedium => 'Mittlere Sicherheit';

  @override
  String get fuelConfidenceLow => 'Geringe Sicherheit';

  @override
  String get fuelWarningRmr =>
      'Dein Tempo wurde gesenkt, damit dein Ziel nicht unter deinen geschätzten Ruheenergiebedarf fällt.';

  @override
  String get fuelWarningCarbs =>
      'Dein Kaloriendefizit wurde verkleinert, damit bei hoher Trainingsbelastung genug Kohlenhydrate bleiben.';

  @override
  String get fuelWarningProtein =>
      'Auch bei Erhaltungskalorien lässt dieses Proteinziel wenig Raum für Kohlenhydrate. Erwäge ein niedrigeres Proteinziel oder weniger Trainingsbelastung.';

  @override
  String get fuelWarningZeroCarbs =>
      'Nach der Zuteilung von Fett und Protein wurden die Kohlenhydrate auf null begrenzt.';

  @override
  String get fuelPlanEmpty => 'Noch kein Plan';

  @override
  String get fuelPlanEmptyHint =>
      'Richte EdgeFuel ein, um ein persönliches Tagesziel zu erhalten.';

  @override
  String get fuelPlanStart => 'Einrichtung starten';

  @override
  String get fuelPlanCalculationTitle => 'So wurde das Ziel berechnet';

  @override
  String get fuelPlanMidpoint => 'Mittelwert';

  @override
  String fuelPlanCalculation(String rmr, String equation) {
    return 'Geschätzter Ruheenergiebedarf: $rmr kcal (Mifflin–St Jeor, $equation). Der Wert wurde mit deinem Aktivitätsfaktor multipliziert und anschließend an dein Zieltempo angepasst. Das ist eine Schätzung, keine Diagnose. Du kannst die Einrichtung jederzeit erneut durchlaufen.';
  }

  @override
  String get fuelPlanRedo => 'Erneut einrichten';

  @override
  String get planReadyExplanation =>
      'Dein Plan richtet sich nach deinen Zielen und Trainingstagen. Du kannst ihn anpassen, wenn sich dein Training ändert.';

  @override
  String get planReadyTitle => 'Dein erster Fighter-Edge-Plan ist bereit';

  @override
  String get planReadyReadOnly => 'Schreibgeschützt fortfahren';

  @override
  String get planReadyDisclaimer =>
      'Zielwerte sind Schätzungen und keine medizinische Beratung. Du kannst deine Angaben jederzeit in EdgeFuel prüfen.';

  @override
  String get planReadyCalories => 'Tägliche Kalorien';

  @override
  String get planReadyMissingTarget =>
      'Deine Trainingswoche steht. Ergänze deine Körperdaten unter Fuel, um ein Tagesziel zu berechnen.';

  @override
  String get profileFreePlan => 'Kostenloser Plan';

  @override
  String get profileProActive => 'Pro-Abonnement aktiv';

  @override
  String get profileProDescription =>
      'Camp-Pläne, Session-Modus und alle Drills';

  @override
  String get profileUpgrade => 'Upgrade';

  @override
  String get profileManage => 'Verwalten';

  @override
  String get settingsProPlan => 'Pro';

  @override
  String get settingsFreePlan => 'Kostenlos';

  @override
  String dashboardEffort(int rating) {
    return 'Anstrengung $rating/10';
  }

  @override
  String get paywallPlainTitle => 'Dein Camp, geplant und ernährt';

  @override
  String get paywallPlainSubtitle => 'Ein Abo. Alles in Fighter Edge.';

  @override
  String get fuelRecipesTitle => 'Rezepte für deinen Tag';

  @override
  String get paywallBenefitDrillsTitle => 'Alle Drills';

  @override
  String get paywallBenefitDrillsBody =>
      'Jeder Drill für Striking, Ringen, BJJ und Clinch, mit Trainingsanleitung.';

  @override
  String get paywallAnnualPlan => 'Jahresabo';

  @override
  String get paywallMonthlyPlan => 'Monatsabo';

  @override
  String get paywallBestValue => 'Bester Preis';

  @override
  String get paywallContinueAnnual => 'Weiter mit Jahresabo';

  @override
  String get paywallContinueMonthly => 'Weiter mit Monatsabo';

  @override
  String get paywallTrust =>
      'Sichere Zahlung über Google Play oder den App Store. Jederzeit im Store-Konto kündbar.';

  @override
  String get paywallRestore => 'Käufe wiederherstellen';

  @override
  String get paywallRefreshStatus => 'Kaufstatus aktualisieren';

  @override
  String get paywallManage => 'Abo verwalten oder kündigen';

  @override
  String get paywallOnPro => 'Du hast Pro';

  @override
  String get paywallOnProRefresh => 'Status aktualisieren';

  @override
  String get paywallLoading => 'Store-Preise werden geladen…';

  @override
  String get paywallSync =>
      'Dein Store-Kauf ist erkannt. Pro wird freigeschaltet, sobald der sichere Kontoabgleich fertig ist.';

  @override
  String get paywallPurchaseActive => 'Pro ist in deinem Konto aktiv.';

  @override
  String get paywallPurchasePending =>
      'Kauf erhalten. Wir bestätigen deinen Pro-Zugang sicher.';

  @override
  String get paywallRestored => 'Dein Pro-Zugang ist wiederhergestellt.';

  @override
  String get paywallNothingToRestore =>
      'Bisher wurde kein aktiver Pro-Zugang gefunden.';

  @override
  String paywallPerYear(String price) {
    return '$price / Jahr';
  }

  @override
  String paywallPerMonth(String price) {
    return '$price / Monat';
  }

  @override
  String paywallAboutPerMonth(String price) {
    return 'Etwa $price / Monat';
  }

  @override
  String paywallSave(int percent) {
    return 'Spare etwa $percent %';
  }

  @override
  String fuelMealsLogged(int eaten, int total) {
    return 'Mahlzeiten erfasst · $eaten/$total';
  }

  @override
  String get learningStart => 'Hier starten';

  @override
  String get learningChoose => 'Wähle eine Disziplin';

  @override
  String get learningChooseHint =>
      'Wir speichern deine Wahl für dieses Konto. Du kannst sie jederzeit ändern.';

  @override
  String get learningChange => 'Lernpfad wechseln';

  @override
  String get learningStriking => 'Schlagtechniken';

  @override
  String get learningWrestling => 'Ringen';

  @override
  String get learningBjj => 'BJJ';

  @override
  String get learningClinch => 'Clinch';

  @override
  String get learningStrikingHint =>
      'Lerne Schläge, Abwehr und Tritte Schritt für Schritt.';

  @override
  String get learningWrestlingHint =>
      'Übe deinen Stand, dann lerne, jemanden zu Boden zu bringen und das selbst abzuwehren.';

  @override
  String get learningBjjHint =>
      'Brasilianisches Jiu-Jitsu: Lerne, dich am Boden zu bewegen und zu befreien.';

  @override
  String get learningClinchHint =>
      'Lerne Haltegriffe, Kniestöße und Kontrolle im engen Standkampf.';

  @override
  String get learningFoundations => 'Grundlagen';

  @override
  String get learningBuilding => 'Aufbau';

  @override
  String get learningSharp => 'Sicher';

  @override
  String learningCount(int completed, int total) {
    return '$completed von $total Techniken sicher';
  }

  @override
  String learningLearn(String drill) {
    return 'Lernen: $drill';
  }

  @override
  String get learningLocked => 'Pro-Technik · Lernpfad pausiert';

  @override
  String get learningViewPro => 'Pro-Optionen ansehen';

  @override
  String get learningComplete => 'Lernpfad abgeschlossen';

  @override
  String get learningCompleteHint =>
      'Übe diese Techniken weiter oder wähle eine andere Disziplin.';

  @override
  String get learningProgressHint =>
      'Sicher bedeutet, dass du die Technik kontrolliert wiederholen kannst.';

  @override
  String get learningNext => 'Als Nächstes in deinem Lernpfad';

  @override
  String learningAfter(String drill) {
    return 'Nach dieser Technik: $drill';
  }

  @override
  String get learningKeepPractising =>
      'Übe diese Technik weiter. Markiere sie als sicher, wenn du sie kontrolliert wiederholen kannst, um im Lernpfad weiterzugehen.';

  @override
  String get learningPractiseLast =>
      'Dies ist die letzte Technik deines Lernpfads. Übe weiter und markiere sie als sicher, sobald du bereit bist.';

  @override
  String get fightAddTitle => 'Nächsten Kampf eintragen';

  @override
  String get fightAddSubtitle => 'Countdown und ein sicherer Gewichtsweg';

  @override
  String get fightSetupTitle => 'Dein Kampf';

  @override
  String get fightDateLabel => 'Kampftag';

  @override
  String get fightDatePick => 'Datum wählen';

  @override
  String get fightWeighInLabel => 'Wiegen';

  @override
  String get fightWeighInSameDay => 'Am selben Tag';

  @override
  String get fightWeighInDayBefore => 'Am Vortag';

  @override
  String get fightWeighInTwoDays => '2 Tage vorher';

  @override
  String fightLimitLabel(String unit) {
    return 'Gewichtslimit ($unit)';
  }

  @override
  String fightLimitError(String min, String max, String unit) {
    return 'Gib ein Limit zwischen $min und $max $unit ein.';
  }

  @override
  String get fightCategoryLabel => 'Wettkampf';

  @override
  String get fightCategoryWhy =>
      'Das legt fest, wie viel in den letzten Tagen sicher runter darf.';

  @override
  String get fightCategoryGrappling => 'Ringen und Grappling';

  @override
  String get fightCategoryGrapplingHint => 'Ringen, BJJ, ADCC';

  @override
  String get fightCategoryAmateur => 'Amateur-Schlagsport';

  @override
  String get fightCategoryAmateurHint => 'Amateurboxen, Amateur-Muay-Thai';

  @override
  String get fightCategoryOlympic => 'Olympischer Kampfsport';

  @override
  String get fightCategoryOlympicHint => 'Judo, olympisches Boxen, Taekwondo';

  @override
  String get fightCategoryPro => 'Profi';

  @override
  String get fightCategoryProHint => 'Profi-MMA, Boxen, Kickboxen, Muay Thai';

  @override
  String get fightCampLabel => 'Camp-Dauer';

  @override
  String fightCampWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wochen',
      one: '1 Woche',
    );
    return '$_temp0';
  }

  @override
  String get fightPathTitle => 'Dein Gewichtsweg';

  @override
  String get fightPathNow => 'Jetzt';

  @override
  String get fightPathLimit => 'Limit';

  @override
  String get fightPathToGo => 'Noch';

  @override
  String fightPathOnPace(String rate, String entry, String unit) {
    return 'Im Plan: $rate $unit pro Woche, damit du zur Kampfwoche bei $entry $unit bist.';
  }

  @override
  String get fightPathHold =>
      'In Reichweite: Halte dein Gewicht, den Rest schafft die Ernährung in der Kampfwoche.';

  @override
  String fightPathSupervision(String lightest, String unit) {
    return 'Nur mit einem Wasser-Cut in den letzten Tagen möglich, und der gehört in die Hände eines Coaches oder Ernährungsberaters. Dein Camp ist im schnellsten sicheren Tempo geplant. Allein über die Ernährung schaffst du bis dahin höchstens $lightest $unit.';
  }

  @override
  String fightPathNotSafe(String lightest, String unit) {
    return 'Bis zu diesem Termin nicht sicher machbar. Das leichteste sichere Limit ist $lightest $unit: Wähle eine höhere Gewichtsklasse oder einen späteren Kampf.';
  }

  @override
  String get fightPathAtWeight => 'Du bist im Limit. Halte dein Gewicht.';

  @override
  String get fightPathNeedsWeight =>
      'Trag diese Woche ein Gewicht ein, um deinen Weg zu sehen.';

  @override
  String get fightPathNeedsScreening =>
      'Schließe die Fuel-Einrichtung ab, um Alter und Gesundheit zu prüfen, bevor du Hinweise zum Gewicht erhältst.';

  @override
  String get fightPathStartScreening => 'Fuel-Einrichtung abschließen';

  @override
  String get fightPathProfessionalReview =>
      'Deine Gesundheitsangaben müssen von einer qualifizierten medizinischen Fachperson oder Ernährungsfachkraft geprüft werden. Fighter Edge kann für dich keinen Gewichtsplan erstellen.';

  @override
  String get fightPathAdultsOnly =>
      'Gewichtspläne gibt es nur für Erwachsene. Plane dein Gewicht mit deinem Coach.';

  @override
  String get fightPathSource =>
      'Grenzwerte der International Society of Sports Nutrition (2025).';

  @override
  String get fightSave => 'Kampf speichern';

  @override
  String get fightRemove => 'Kampf entfernen';

  @override
  String get fightRemoveTitle => 'Diesen Kampf entfernen?';

  @override
  String get fightRemoveBody =>
      'Countdown und Gewichtsweg werden gelöscht. Du kannst jederzeit wieder einen Kampf eintragen.';

  @override
  String fightNight(String date) {
    return 'Kampfabend · $date';
  }

  @override
  String fightDaysToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tage bis zum Kampf',
      one: 'Tag bis zum Kampf',
    );
    return '$_temp0';
  }

  @override
  String fightPhaseCamp(int week, int total) {
    return 'Camp · Woche $week von $total';
  }

  @override
  String fightPhaseBeforeCamp(String date) {
    return 'Camp beginnt am $date';
  }

  @override
  String fightPhaseFightWeek(int day) {
    return 'Kampfwoche · Tag $day von 7';
  }

  @override
  String get fightPhaseWeighIn => 'Heute ist Wiegen';

  @override
  String get fightPhaseRefuel => 'Gewogen: jetzt auffüllen';

  @override
  String get fightPhaseWeighedIn => 'Gewogen';

  @override
  String get fightPhaseFightDay => 'Kampftag';

  @override
  String get fightDone => 'Kampf vorbei. Trag deinen nächsten ein.';

  @override
  String get fightEdit => 'Kampf bearbeiten';

  @override
  String get fightPathShortSupervision =>
      'Nur mit betreutem Wasser-Cut machbar. Zum Prüfen tippen.';

  @override
  String get fightPathShortNotSafe =>
      'Bis zu diesem Termin nicht sicher. Zum Prüfen tippen.';

  @override
  String get fightPathScreenTitle => 'Gewichtsweg';

  @override
  String get fightCheckpointsTitle => 'Wochenziele';

  @override
  String get fightCheckpointFightWeek => 'Kampfwoche beginnt';

  @override
  String fightChartLimit(String value) {
    return 'Limit $value';
  }

  @override
  String get fightChartToday => 'Heute';

  @override
  String get fightChartWeighIns => 'Wiegungen';

  @override
  String get fightChartTrend => '7-Tage-Trend';

  @override
  String get fightChartPlan => 'Plan';

  @override
  String get fightChartEmpty =>
      'Trag zwei Gewichte ein, um deinen Trend zu sehen.';

  @override
  String get fightWeekTitle => 'Kampfwoche';

  @override
  String get fightWeekOpen => 'Plan für die Kampfwoche';

  @override
  String fightWeekStarts(String date) {
    return 'Beginnt am $date';
  }

  @override
  String fightWeekWeighIn(String date) {
    return 'Wiegen · $date';
  }

  @override
  String fightWeekCarbs(String kg, String unit, String date) {
    return 'Die Ernährung bringt in der Kampfwoche etwa $kg $unit: ab $date ballaststoffarm und weniger Kohlenhydrate.';
  }

  @override
  String fightWeekFibre(String kg, String unit, String date) {
    return 'Die Ernährung bringt in der Kampfwoche etwa $kg $unit: ab $date ballaststoffarm.';
  }

  @override
  String get fightWeekNoCut =>
      'Kein Cut nötig. Iss nach Plan und halte dein Gewicht.';

  @override
  String fightWeekSupervision(String lightest, String unit) {
    return 'Die Schritte unten schaffen einen Teil davon. Der Rest braucht einen Wasser-Cut, und der gehört in die Hände eines Coaches oder Ernährungsberaters. Allein über die Ernährung schaffst du höchstens $lightest $unit.';
  }

  @override
  String get fightWeekNeedsWeight =>
      'Trag ein Gewicht ein, um deine Kampfwoche zu planen.';

  @override
  String get fightWeekWater =>
      'Trink die ganze Woche normal. Fighter Edge plant nie einen Wasser-Cut.';

  @override
  String get fightWeekToday => 'Heute';

  @override
  String fightTodaySteps(String steps) {
    return 'Heute: $steps';
  }

  @override
  String get fightWeekDays => 'Tag für Tag';

  @override
  String get fightStepEat => 'Nach Plan essen';

  @override
  String get fightStepEatBody => 'Deine normalen Camp-Ziele.';

  @override
  String get fightStepFibre => 'Ballaststoffarm';

  @override
  String fightStepFibreBody(int grams) {
    return 'Unter $grams g Ballaststoffe: weißer Reis, Weißbrot, Eier, Fleisch und Fisch. Lass Hülsenfrüchte, Vollkorn, Nüsse und rohes Gemüse weg.';
  }

  @override
  String get fightStepCarbs => 'Weniger Kohlenhydrate';

  @override
  String get fightStepCarbsBody =>
      'Kleinere Portionen Reis, Brot, Nudeln und Süßes als sonst. Halte das Protein hoch. Wenn dir schwindlig wird oder du dich schwach fühlst: iss.';

  @override
  String get fightStepWeighIn => 'Wiegen';

  @override
  String get fightStepWeighInBody =>
      'Direkt danach mit dem Auffüllen beginnen.';

  @override
  String get fightStepWeighInBodyNoRefuel =>
      'Wiegen. Danach folge dem Rat deines Trainers oder deiner Ernährungsfachkraft.';

  @override
  String get fightStepRefuel => 'Auffüllen';

  @override
  String get fightStepRefuelBody =>
      'Zuerst ein Rehydrationsgetränk, dann schnelle Kohlenhydrate. Ziele siehe unten.';

  @override
  String get fightStepFight => 'Kampf';

  @override
  String get fightStepFightBody =>
      'Wenig Ballaststoffe, und iss nur, was du kennst.';

  @override
  String get fightRefuelTitle => 'Nach dem Wiegen';

  @override
  String get fightRefuelDrink => 'Rehydrationsgetränk';

  @override
  String get fightRefuelDrinkWhen => 'Direkt nach dem Wiegen';

  @override
  String fightRefuelPerHour(String amount) {
    return '$amount pro Stunde';
  }

  @override
  String get fightRefuelCarbs => 'Schnelle Kohlenhydrate';

  @override
  String get fightRefuelCarbsWhen => 'Nach dem Getränk';

  @override
  String fightRefuelUpTo(String amount) {
    return 'Bis zu $amount pro Stunde';
  }

  @override
  String get fightRefuelTotal => 'Kohlenhydrate gesamt';

  @override
  String get fightRefuelTotalWhen => 'Zwischen Wiegen und Kampf';

  @override
  String get fightRefuelFibre => 'Ballaststoffe';

  @override
  String get fightRefuelFibreValue => 'Niedrig halten';

  @override
  String get fightRefuelFibreWhen => 'Bis zum Kampf';

  @override
  String get fightWeekSource =>
      'Schritte und Ziele nach der International Society of Sports Nutrition (2025).';

  @override
  String get fightWeekSourceSteps =>
      'Schritte nach der International Society of Sports Nutrition (2025).';

  @override
  String get fightRefuelOff =>
      'Ziele fürs Auffüllen sind in dieser Version nicht enthalten. Eine Sporternährungsberatung muss sie erst prüfen.';

  @override
  String get cornerBriefTitle => 'Ecken-Briefing';

  @override
  String get cornerCueSeeProfessional =>
      'Dein Gewichtsplan braucht einen Coach oder eine Ernährungsfachkraft. Sprich vor der Kampfwoche mit jemandem.';

  @override
  String get cornerCueSetUpFuel =>
      'Richte EdgeFuel ein, dann kann deine Ecke auch dein Essen lesen.';

  @override
  String get cornerCueFirstMeal =>
      'Trag deine erste Mahlzeit ein, dann kann deine Ecke deinen Tag lesen.';

  @override
  String cornerCueProtein(int grams) {
    return 'Eiweiß ist heute die Lücke: noch $grams g.';
  }

  @override
  String cornerCueCarbsBeforeTraining(int grams) {
    return 'Noch $grams g Kohlenhydrate. Iss einen Teil davon vor dem Training.';
  }

  @override
  String cornerCueCarbs(int grams) {
    return 'Kohlenhydrate sind heute die Lücke: noch $grams g.';
  }

  @override
  String cornerCueCalories(int kcal) {
    return 'Noch $kcal kcal heute. Plane deine nächste Mahlzeit.';
  }

  @override
  String get cornerCueOnTrack =>
      'Heute im Plan. Halte die nächste Mahlzeit ausgewogen.';

  @override
  String get deleteAccountFailed =>
      'Dein Konto konnte nicht gelöscht werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get syncNotSaved =>
      'Einige Änderungen wurden nicht in deinem Konto gespeichert.';

  @override
  String get syncRetry => 'Erneut versuchen';

  @override
  String get syncRetrying => 'Wird erneut versucht …';

  @override
  String get reactionRest => 'PAUSE';

  @override
  String reactionRoundOf(int n, int total) {
    return 'RUNDE $n VON $total';
  }

  @override
  String reactionRoundRestNote(String time) {
    return '$time Pause zwischen den Runden';
  }

  @override
  String get reactionMoveTimeNote =>
      'Dazu kommt die Zeit für die Bewegung selbst.';

  @override
  String get paywallBenefitCampTitle => 'Deine Camp-Woche';

  @override
  String get paywallBenefitCampBody =>
      'Datierte Einheiten für deine Woche, passend zu Level und Kampftermin.';

  @override
  String get paywallBenefitFuelTitle => 'Ernährung für Trainingstage';

  @override
  String get paywallBenefitFuelBody =>
      'Kalorien- und Proteinziele, die sich mit deiner Trainingswoche bewegen.';

  @override
  String get paywallBenefitReviewTitle => 'Wochenrückblick';

  @override
  String get paywallBenefitReviewBody =>
      'Jeden Sonntag: was du geschafft hast und was sich ändern sollte. Du entscheidest.';

  @override
  String get paywallBenefitWeightTitle => 'Sicherer Gewichtsweg';

  @override
  String get paywallBenefitWeightBody =>
      'Ein Gewichtsweg bis zum Kampftermin, mit Sicherheitsgrenzen.';

  @override
  String paywallTrialBadge(int days) {
    return '$days Tage gratis testen';
  }

  @override
  String paywallTrialThen(int days, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage gratis, danach $price',
      one: '1 Tag gratis, danach $price',
    );
    return '$_temp0';
  }

  @override
  String get paywallStartTrial => 'Gratis-Test starten';

  @override
  String paywallTrialRenewalDisclosure(int days, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return 'Gratis für $_temp0, danach $price, mit automatischer Verlängerung bis zur Kündigung. Kündige mindestens 24 Stunden vor Ende des Tests in den Einstellungen deines Store-Kontos, um eine Abbuchung zu vermeiden. Die Zahlung wird nach Ende des Tests über deine Apple-ID bzw. dein Google-Play-Konto abgerechnet.';
  }

  @override
  String get paywallTrialActiveTitle => 'Dein Gratis-Test läuft';

  @override
  String get paywallTrialActiveBody =>
      'Er wird zu einem bezahlten Abo, wenn der Test endet, sofern du nicht in deinem Store-Konto kündigst.';

  @override
  String get paywallUnavailableTitle => 'Abos sind hier noch nicht verfügbar';

  @override
  String get paywallUnavailableBody =>
      'Diese Version kann noch kein Abo starten. Deine Daten bleiben gespeichert.';

  @override
  String get readOnlyBanner =>
      'Deine Daten sind gespeichert. Abonniere, um weiter zu trainieren.';

  @override
  String get readOnlyBannerCta => 'Tarife ansehen';

  @override
  String trialChipDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Test · noch $days Tage',
      one: 'Test · noch 1 Tag',
      zero: 'Test · endet heute',
    );
    return '$_temp0';
  }

  @override
  String get trialReminderTitle => 'Dein Gratis-Test endet in 2 Tagen';

  @override
  String get trialReminderBody =>
      'Er verlängert sich, sofern du nicht in deinem Store-Konto kündigst. Deine Daten bleiben in jedem Fall gespeichert.';

  @override
  String get planReadyStartFreeWeek => 'Starte deine Gratis-Woche';

  @override
  String planReadyStartTrialDays(int days) {
    return 'Starte deinen $days-Tage-Gratis-Test';
  }

  @override
  String get planReadyViewPlans => 'Tarife ansehen';

  @override
  String get planReadyNotNowNote =>
      'Dein Plan bleibt gespeichert. Zum Eintragen brauchst du ein Abo.';

  @override
  String get paywallTrialCancelNote =>
      'Kündige vor Testende in deinen Store-Einstellungen und du zahlst nichts.';

  @override
  String get paywallAfterTrialNote =>
      'Wenn du nach dem Test kein Abo abschließt, bleiben dein Plan und deine Einträge lesbar. Eintragen und Einheiten brauchen ein Abo.';

  @override
  String get paywallBenefitSessionTitle => 'Einheiten-Modus';

  @override
  String get paywallBenefitSessionBody =>
      'Runden und Pausen werden für dich getimt, mit einem taktischen und einem Erholungs-Tipp in jeder Pause.';

  @override
  String get paywallContinue => 'Weiter';

  @override
  String get fuelLogFood => 'Essen erfassen';

  @override
  String get fuelRecentFoods => 'Zuletzt erfasst';

  @override
  String get fuelQuickAdd => 'Schnell hinzufügen';

  @override
  String get fuelEmptyLog =>
      'Noch nichts erfasst. Füge über „Essen erfassen“ deine erste Mahlzeit hinzu.';

  @override
  String fuelGramsLeft(int grams) {
    return '$grams g übrig';
  }

  @override
  String fuelConsumedKcal(int kcal) {
    return '$kcal kcal erfasst';
  }

  @override
  String fuelRemovedSnack(String name) {
    return '$name entfernt';
  }

  @override
  String fuelRepeatFood(String name) {
    return '$name erneut erfassen';
  }

  @override
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get settingsNotificationsOff => 'Alle aus';

  @override
  String get settingsNotificationsPaused => 'Pausiert';

  @override
  String settingsNotificationsOn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Erinnerungen an',
      one: '1 Erinnerung an',
    );
    return '$_temp0';
  }

  @override
  String get notifScreenIntro =>
      'Erinnerungen bleiben auf diesem Gerät. Du wählst jede einzeln und bekommst höchstens eine pro Tag.';

  @override
  String get notifPermissionOffAndroid =>
      'Benachrichtigungen sind für Fighter Edge in den Handy-Einstellungen ausgeschaltet. Öffne für Erinnerungen Einstellungen, Apps, Fighter Edge, Benachrichtigungen und schalte sie ein.';

  @override
  String get notifPermissionOffIos =>
      'Benachrichtigungen sind für Fighter Edge in den Handy-Einstellungen ausgeschaltet. Öffne für Erinnerungen Einstellungen, Mitteilungen, Fighter Edge und schalte „Mitteilungen erlauben“ ein.';

  @override
  String get notifSectionReminders => 'Erinnerungen';

  @override
  String get notifSessionTitle => 'Einheit-Erinnerung';

  @override
  String get notifSessionSubtitle =>
      'Ein kurzer Hinweis vor deiner üblichen Trainingszeit';

  @override
  String get notifReviewTitle => 'Wochenrückblick';

  @override
  String get notifReviewSubtitle =>
      'Ein Rückblick auf deine Woche am Sonntagabend';

  @override
  String get notifSectionTiming => 'Zeiten';

  @override
  String get notifUsualTime => 'Übliche Trainingszeit';

  @override
  String get notifSessionLead => 'Erinnere mich';

  @override
  String notifLeadOption(int minutes) {
    return '$minutes Min. vorher';
  }

  @override
  String get notifQuietStart => 'Ruhezeit beginnt';

  @override
  String get notifQuietEnd => 'Ruhezeit endet';

  @override
  String get notifQuietNote => 'Während der Ruhezeit wird nichts gesendet.';

  @override
  String get notifPauseAll => 'Alles pausieren';

  @override
  String get notifPauseAllSubtitle =>
      'Schaltet jede Erinnerung stumm, bis du es wieder ausschaltest';

  @override
  String get notifHelpTitle => 'Erinnerungen kommen nicht an?';

  @override
  String get notifHelpBody =>
      'Manche Handys beenden Apps im Hintergrund, um Akku zu sparen. Kommen Erinnerungen spät oder gar nicht, erlaube Fighter Edge in den Akku-Einstellungen, im Hintergrund zu laufen.';

  @override
  String get notifPrimerTitle =>
      'Möchtest du eine Erinnerung vor deiner nächsten Einheit?';

  @override
  String get notifPrimerBody =>
      'Ein kurzer Hinweis an deinen Trainingstagen, etwa eine Stunde vorher. Nie nachts. In den Einstellungen kannst du es ändern oder beenden.';

  @override
  String get notifPrimerYes => 'Ja, erinnere mich';

  @override
  String get notifPrimerNo => 'Jetzt nicht';

  @override
  String get notifAutoPauseTitle => 'Diese Erinnerungen behalten?';

  @override
  String get notifAutoPauseBodySession =>
      'Die letzten Einheit-Erinnerungen blieben ungeöffnet, deshalb haben wir sie pausiert. Lass sie weiterlaufen oder schalte sie aus.';

  @override
  String get notifAutoPauseBodyReview =>
      'Die letzten Wochenrückblicke blieben ungeöffnet, deshalb haben wir sie pausiert. Lass sie weiterlaufen oder schalte sie aus.';

  @override
  String get notifAutoPauseBodyGeneric =>
      'Die letzten dieser Erinnerungen blieben ungeöffnet, deshalb haben wir sie pausiert. Lass sie weiterlaufen oder schalte sie aus.';

  @override
  String get notifAutoPauseKeep => 'Behalten';

  @override
  String get notifAutoPauseOff => 'Ausschalten';

  @override
  String get notifSessionSoonTitle => 'Deine Einheit steht bevor';

  @override
  String notifSessionSoonBody(String time) {
    return 'Training um $time. Ein kurzes Aufwärmen vorab hilft dir beim Start.';
  }

  @override
  String notifSessionSoonFuelTitle(String time) {
    return 'Einheit um $time';
  }

  @override
  String get notifSessionSoonFuelBody =>
      'Dein Fuel-Fenster ist offen. Iss, was dir gut bekommt, und pack dann deine Sachen.';

  @override
  String get notifFuelWindowTitle => 'Fuel-Fenster ist offen';

  @override
  String notifFuelWindowBody(String time) {
    return 'Deine Einheit um $time steht bevor. Iss, was dir gut bekommt, und trainiere dann.';
  }

  @override
  String get notifReviewWeeklyTitle => 'Dein Wochenrückblick';

  @override
  String get notifReviewWeeklyBody =>
      'Nimm dir eine Minute, sieh dir die Woche an und plane die nächste.';

  @override
  String get notifFightWeekTitle => 'Noch eine Woche bis zum Kampf';

  @override
  String get notifFightWeekBody =>
      'Bleib bei deinen Einheiten und halte deine Routine einfach. Dein Camp-Plan zeigt, was als Nächstes kommt.';

  @override
  String get notifFightTomorrowTitle => 'Morgen ist Kampftag';

  @override
  String get notifFightTomorrowBody =>
      'Ruh dich aus und bleib bei deiner Routine. Die Arbeit ist getan.';

  @override
  String get notifWeighInTitle => 'Gewichts-Check';

  @override
  String get notifWeighInBody =>
      'Trag dein Gewicht ein, wenn du es verfolgst. Lass es aus, wenn heute nicht der Tag ist.';

  @override
  String get notifProteinTitle => 'Abendessen heute';

  @override
  String get notifProteinBody =>
      'Eine proteinreiche Mahlzeit nach dem Training unterstützt deine Erholung.';

  @override
  String get notifTipTitle => 'Tipp für Kämpfer';

  @override
  String get notifTip0Body =>
      'Schlaf gehört zum Training. Eine feste Schlafenszeit diese Woche zahlt sich in der nächsten Einheit aus.';

  @override
  String get notifTip1Body =>
      'Fünf lockere Minuten Aufwärmen machen die erste Runde jeder Einheit besser.';

  @override
  String get notifTip2Body =>
      'Such dir heute eine Technik zum Schärfen aus. Ein kleiner Fokus schlägt einen großen Plan.';

  @override
  String get notifTip3Body =>
      'Iss nach einer harten Einheit eine richtige Mahlzeit. Erholung beginnt auf dem Teller.';

  @override
  String get notifTip4Body =>
      'Leichte Mobilität zwischen den Einheiten hält Hüfte und Schultern bereit.';

  @override
  String get notifTip5Body =>
      'Atme vor dem Sparring eine Minute lang ruhig. Ein ruhiger Start prägt deine Runden.';

  @override
  String get notifFuelTitle => 'Fuel-Fenster';

  @override
  String get notifFuelSubtitle =>
      'Ein Hinweis vor einer harten Einheit, wenn es Zeit zum Essen ist';

  @override
  String get notifFightTitle => 'Kampf-Countdown';

  @override
  String get notifFightSubtitle =>
      'Ein Hinweis eine Woche und einen Tag vor deinem Kampf';

  @override
  String get nutritionPausedTitle => 'Ernährung ist pausiert';

  @override
  String get nutritionPausedBody =>
      'Essensprotokoll, Ernährungszahlen, Gewichtsfunktionen und Ernährungshinweise sind aus. Das Training läuft ganz normal weiter. Schalte sie wieder ein, wann du möchtest.';

  @override
  String get nutritionPausedResume => 'Ernährung wieder einschalten';

  @override
  String get settingsSectionNutrition => 'Ernährung';

  @override
  String get settingsNutritionDisplay => 'Ernährungsanzeige';

  @override
  String get settingsNutritionDisplayNormal => 'Alles an';

  @override
  String get settingsNutritionDisplayPaused => 'Pausiert';

  @override
  String get nutritionModeNormalTitle => 'Alles anzeigen';

  @override
  String get nutritionModeNormalSubtitle =>
      'Ziele, Essensprotokoll, Gewicht und Ernährungshinweise.';

  @override
  String get nutritionModePausedTitle => 'Ernährung pausieren';

  @override
  String get nutritionModePausedSubtitle =>
      'Blendet Essen, Ernährungszahlen, Gewichtsfunktionen und Ernährungshinweise aus. Das Training geht weiter.';

  @override
  String get reviewHoldPaused =>
      'Diese Woche gibt es nichts zu ändern. Bleib bei deinem Plan.';

  @override
  String get nutritionNumbersHiddenTitle => 'Zahlen sind ausgeblendet';

  @override
  String get nutritionNumbersHiddenBody =>
      'Kalorien, Gramm, Ziele und Gewichte sind ausgeblendet. Du kannst weiterhin eintragen, was du isst. Blende sie wieder ein, wann du möchtest.';

  @override
  String get nutritionNumbersHiddenShow => 'Zahlen anzeigen';

  @override
  String get nutritionModeHideTitle => 'Zahlen ausblenden';

  @override
  String get nutritionModeHideSubtitle =>
      'Blendet Kalorien, Gramm, Ziele und Gewicht aus. Du kannst Essen weiterhin mit Namen eintragen.';

  @override
  String get settingsNutritionDisplayHidden => 'Zahlen ausgeblendet';

  @override
  String nutritionAddedSnackNoNumbers(String name) {
    return '$name hinzugefügt';
  }

  @override
  String get nutritionLoggedByName =>
      'Trag ein, was du isst. Die Zahlen bleiben ausgeblendet.';
}

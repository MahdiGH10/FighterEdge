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
      'Tägliches Ecken-Briefing und Coach, komplette Drill- und Rezept-Bibliothek, Ecken-Tipps';

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
  String get dashboardWeeklyOverview => 'Wochenübersicht';

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
  String get paywallWaitlistCta => 'Benachrichtige mich, wenn Pro startet';

  @override
  String get paywallWaitlistJoined => 'Du stehst auf der Liste';

  @override
  String get paywallWaitlistThanks =>
      'Notiert. Pro erscheint hier, sobald es startet, mit Preis vor jeder Zahlung.';

  @override
  String get paywallWaitlistBody =>
      'Pro kann in dieser Version noch nicht gekauft werden. Tippe unten, und dieses Gerät merkt sich deine Anfrage. Der Store-Preis wird immer vor jeder Zahlung angezeigt.';

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
  String get aiConsentTitle => 'Bevor du mit dem Coach sprichst';

  @override
  String get aiConsentBody =>
      'Für eine Antwort sendet unser Server deine Kalorien- und Makroziele, die Zusammenfassung deines heutigen Ernährungsprotokolls, deine Ernährungsweise, Allergien, Abneigungen, deine Nachrichten und, wenn du sie nutzt, deine heute geplante Einheit, deine Trainingstage im Vergleich zu deinem Plan, deinen 7-Tage-Gewichtstrend und dein Fight Camp (Termine, Gewichtslimit und den heutigen rein ernährungsbasierten Plan) an Groq oder OpenRouter (USA), das sie an einen KI-Modellanbieter weitergeben kann. Dein Name, deine E-Mail-Adresse und deine Konto-ID werden nie gesendet.';

  @override
  String get aiConsentRetention =>
      'Manche Anbieter, besonders kostenlose Modelle, können Eingaben nach ihren eigenen Bedingungen speichern. Schreib nichts, was du nicht teilen möchtest.';

  @override
  String get aiConsentStatement =>
      'Ich willige ein, dass diese Daten wie beschrieben an den KI-Anbieter übermittelt werden, auch in die USA.';

  @override
  String get aiConsentAgree => 'Ich willige ein';

  @override
  String get aiConsentChangeLater =>
      'Du kannst das jederzeit unter Einstellungen > Datenschutz ausschalten.';

  @override
  String get aiConsentRequiredNotice =>
      'Erlaube die Datenweitergabe an den KI-Coach, um eine Antwort zu bekommen.';

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
  String get settingsAiCoach => 'Datenweitergabe an den KI-Coach';

  @override
  String get settingsAiCoachSubtitle =>
      'Sendet deine Planwerte und Nachrichten an unseren KI-Anbieter (USA), wenn du den Coach nutzt.';

  @override
  String get settingsAdPrivacy => 'Datenschutz bei Werbung';

  @override
  String get settingsAdPrivacySubtitle =>
      'Ändere deine Einwilligung für die freiwilligen Videos';

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
  String get reactionStatDuration => 'Dauer';

  @override
  String get reactionStatMoves => 'Bewegungen';

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
  String reactionRecoveryNote(String time, int moves) {
    return '+$time s zum Zurücksetzen nach $moves+ Bewegungen';
  }

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
  String get dashboardThisWeek => 'Diese Woche';

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
  String get dashboardStartSession => 'Einheit starten';

  @override
  String get dashboardOpenCamp => 'Trainingsplan öffnen';

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
  String get dashboardRiskTitle => 'Serie gefährdet';

  @override
  String dashboardFreezeHint(int count) {
    return 'Gestern fehlt ein Eintrag. Schütze den Tag mit einem Schutz ($count übrig).';
  }

  @override
  String get dashboardLogHint =>
      'Kein Schutz verfügbar. Trage heute eine Einheit ein, um neu zu starten.';

  @override
  String get dashboardFreeze => 'Schützen';

  @override
  String get dashboardLogNow => 'Jetzt eintragen';

  @override
  String get dashboardFreezeUsed => 'Schutz verwendet — gestern ist geschützt.';

  @override
  String get dashboardLogged => 'Eingetragen';

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
    return '$kcal kcal über dem Ziel';
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
  String trainingStartSession(String session) {
    return '$session starten';
  }

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
  String get planReadyExplanation =>
      'Dein Plan richtet sich nach deinen Zielen und Trainingstagen. Du kannst ihn anpassen, wenn sich dein Training ändert.';

  @override
  String get planReadyProTitle => 'Weitere Trainingshilfen mit Pro';

  @override
  String get planReadyProBody =>
      'Pro enthält ein tägliches Ecken-Briefing mit Coach, alle Übungen und Rezepte sowie Hinweise zwischen den Runden.';

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
      'Täglicher Brief, alle Übungen und Rezepte';

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
  String get paywallPlainTitle => 'Deine Ecke, jeden Tag';

  @override
  String get paywallPlainSubtitle => 'Ein Abo. Alles in Fighter Edge.';

  @override
  String get fuelRecipesTitle => 'Rezepte für deinen Tag';

  @override
  String get paywallBenefitBriefTitle => 'Tägliches Ecken-Briefing';

  @override
  String get paywallBenefitBriefBody =>
      'Drei Zeilen täglich zu Training, Ernährung und Gewicht, plus ein Coach für deine Fragen.';

  @override
  String get paywallBenefitRecipesTitle => 'Alle Rezepte';

  @override
  String get paywallBenefitRecipesBody =>
      'Jedes Rezept, auf deine Portionen skaliert und auf deine Allergene geprüft.';

  @override
  String get paywallBenefitDrillsTitle => 'Alle Drills';

  @override
  String get paywallBenefitDrillsBody =>
      'Jeder Drill für Striking, Ringen, BJJ und Clinch, mit Trainingsanleitung.';

  @override
  String get paywallBenefitCuesTitle => 'Ecken-Tipps';

  @override
  String get paywallBenefitCuesBody =>
      'Ein taktischer und ein Erholungs-Tipp in jeder Pause des Runden-Timers.';

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
  String get paywallSoonTitle => 'Pro startet bald';

  @override
  String get paywallNoPaymentToday =>
      'Heute keine Zahlung. Vor jeder Abbuchung fragen wir noch einmal.';

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
  String get cornerBriefFreeHint =>
      'Mit Pro schreibt deine Ecke das ganze Briefing: Training, Ernährung und Gewicht, aktualisiert bei jedem Eintrag.';

  @override
  String get cornerBriefUnlock => 'Ganzes Briefing freischalten';

  @override
  String get cornerBriefProHint =>
      'Deine Ecke schreibt drei Zeilen für heute: Training, Ernährung und Gewicht.';

  @override
  String get cornerBriefGet => 'Heutiges Briefing holen';

  @override
  String get cornerBriefWriting => 'Deine Ecke liest deinen Tag…';

  @override
  String get cornerBriefUpdating =>
      'Wird nach deinem letzten Eintrag aktualisiert…';

  @override
  String get cornerBriefQuota =>
      'Die Briefings für heute sind aufgebraucht. Morgen wieder.';

  @override
  String get cornerBriefQuotaStale =>
      'Die Briefings für heute sind aufgebraucht. Dieses ist von vor deinem letzten Eintrag.';

  @override
  String get cornerBriefUnavailable =>
      'Deine Ecke konnte gerade nicht antworten.';

  @override
  String get cornerBriefSyncing =>
      'Pro wird noch mit deinem Konto synchronisiert.';

  @override
  String get cornerBriefTryAgain => 'Nochmal versuchen';

  @override
  String get cornerBriefVerify =>
      'Bestätige deine E-Mail-Adresse, um das ganze Briefing zu bekommen.';

  @override
  String get cornerBriefVerifyAction => 'E-Mail bestätigen';

  @override
  String get cornerBriefSetUpAction => 'EdgeFuel einrichten';

  @override
  String get cornerBriefAskCoach => 'Frag deinen Coach';

  @override
  String get cornerBriefProfessional =>
      'Bitte sprich mit einer qualifizierten Fachperson, bevor du danach handelst.';

  @override
  String get cornerBriefWatchVideo =>
      'Kurzes Video ansehen für das ganze Briefing heute';

  @override
  String get cornerBriefRewardedNote =>
      'Dein kostenloses Briefing für heute. Mit Pro wird es nach jedem Eintrag neu geschrieben.';

  @override
  String get cornerBriefRewardUsed =>
      'Dein kostenloses Briefing für heute ist genutzt. Morgen wieder, oder hol dir Pro.';

  @override
  String get cornerBriefVideoClosed =>
      'Schau das Video bis zum Ende, um das Briefing freizuschalten.';

  @override
  String get cornerBriefNoVideo =>
      'Gerade kein Video verfügbar. Versuch es später noch mal.';

  @override
  String get cornerBriefRewardFailed =>
      'Deine Ecke konnte es gerade nicht schreiben. Tipp später noch mal, ohne neues Video.';

  @override
  String get cornerTopicTraining => 'Training';

  @override
  String get cornerTopicFuel => 'Ernährung';

  @override
  String get cornerTopicWeight => 'Gewicht';

  @override
  String get cornerTopicCamp => 'Camp';

  @override
  String get cornerTopicRecovery => 'Erholung';
}

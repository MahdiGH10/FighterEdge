import '../../features/edge_fuel/domain/models/fuel_day_plan.dart';
import '../../features/training_plan/domain/models/date_key.dart';
import '../../features/training_plan/domain/models/session_status.dart';
import '../../features/training_plan/domain/session_status_resolver.dart';
import 'notification_channel.dart';
import 'notification_history.dart';
import 'notification_settings.dart';
import 'planned_notification.dart';

/// Turns the training plan, fuel day types, the fight date and the user's
/// notification settings into the notifications to schedule next. Pure: it
/// reads no clock (callers pass `now`) and calls no plugin.
///
/// All times are local wall-clock [DateTime]s; time zone and daylight saving
/// are the gateway's job. Nothing in the output carries a weight, calorie,
/// measurement, meal text, email or user id.
///
/// Rules in short:
/// * A session reminder fires `sessionLeadMinutes` before the user's usual
///   training time. Rest days, completed, skipped and moved sessions get
///   none.
/// * A fuel window (hard and double days only, adults only) is merged into
///   the session reminder when both are planned the same day.
/// * Quiet hours apply to every channel. A session reminder or fuel window
///   that lands inside them moves to the end of quiet hours if that is still
///   before the session, otherwise it is dropped. Other channels move to the
///   end of quiet hours only when that is the same day, otherwise dropped.
///   Nobody is woken.
/// * At most one non-transactional notification per local calendar day.
///   Priority: fight countdown, session (with fuel window), weekly review,
///   weigh-in, protein, tip. The losers are dropped, not moved.
/// * `pauseAll`, a disabled channel, an active `pausedUntil` or an
///   auto-paused channel plan nothing for that channel. The trial-ending
///   notice is a billing notice: it ignores `pauseAll` and auto-pause and
///   does not use up the daily cap, but it still needs its own channel to be
///   enabled and not paused until a later date.
/// * Nothing is planned for a moment at or before `now`.
class NotificationPlanner {
  const NotificationPlanner();

  /// Sunday review time.
  static const int weeklyReviewHour = 18;

  /// Fight countdown milestones fire in the morning.
  static const int fightCountdownHour = 9;

  /// Plain weigh-in reminder, early but after default quiet hours.
  static const int weighInHour = 8;

  /// The single evening protein slot.
  static const int proteinGapHour = 17;

  /// Tips go out around midday.
  static const int tipHour = 12;

  /// Trial-ending notice time, two days before the trial ends.
  static const int trialEndingHour = 10;
  static const int trialEndingDaysBefore = 2;

  /// Fight countdown milestones, in days before the fight.
  static const List<int> fightMilestones = [7, 1];

  /// Most tips in any rolling seven days, and the least gap between two.
  static const int maxTipsPerWeek = 2;
  static const int minDaysBetweenTips = 3;

  /// Size of the bundled tip list. Content keys are `notif.tip.0` to
  /// `notif.tip.<tipCount - 1>`.
  static const int tipCount = 6;

  static const List<String> _weekdayNames = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  /// Plans notifications with a fire time in `(now, now + horizonDays]`,
  /// sorted by fire time then id.
  ///
  /// * [sessions] are the dated sessions with their resolved status (from
  ///   `SessionStatusResolver`), which is how completed, skipped and moved
  ///   sessions are known.
  /// * [fuelDayTypes] maps a date (time of day ignored) to its fuel day type.
  /// * [weighInWeekdays] are `DateTime.monday`..`DateTime.sunday` for the
  ///   plain weigh-in reminder; empty means none. Callers must not pass
  ///   weekdays on behalf of a weight cut: that content is not generated.
  /// * [ageYears] null (unknown) or under 18 hides the nutrition channels.
  List<PlannedNotification> plan({
    required DateTime now,
    required NotificationSettings settings,
    required List<ResolvedSession> sessions,
    Map<DateTime, FuelDayType> fuelDayTypes = const {},
    DateTime? fightDate,
    DateTime? trialEndsAt,
    required NotificationHistory history,
    required int? ageYears,
    int horizonDays = 7,
    Set<int> weighInWeekdays = const {},
  }) {
    final run = _Run(
      now: now,
      settings: settings,
      history: history,
      adult: ageYears != null && ageYears >= 18,
      horizonDays: horizonDays,
    );
    final candidates = <PlannedNotification>[
      ...run.sessionCandidates(sessions, fuelDayTypes),
      ...run.weeklyReview(),
      ...run.fightCountdown(fightDate),
      ...run.weighIn(weighInWeekdays),
      ...run.proteinGap(sessions),
    ];

    final byDay = <String, PlannedNotification>{};
    for (final n in candidates) {
      final key = dateKey(n.fireAt);
      if (run.blockedDays.contains(key)) continue;
      final current = byDay[key];
      if (current == null || _beats(n, current)) byDay[key] = n;
    }

    final result = <PlannedNotification>[
      ...byDay.values,
      ...run.tips(taken: byDay.keys.toSet()),
      ...run.trialEnding(trialEndsAt),
    ]..sort(_byFireTime);
    return result;
  }

  static bool _beats(PlannedNotification a, PlannedNotification b) {
    final byPriority = a.channel.priority.compareTo(b.channel.priority);
    return byPriority != 0 ? byPriority < 0 : _byFireTime(a, b) < 0;
  }

  static int _byFireTime(PlannedNotification a, PlannedNotification b) {
    final byTime = a.fireAt.compareTo(b.fireAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }
}

/// Working state for one planning call.
class _Run {
  _Run({
    required this.now,
    required this.settings,
    required this.history,
    required this.adult,
    required int horizonDays,
  })  : end = DateTime(
          now.year,
          now.month,
          now.day + horizonDays,
          now.hour,
          now.minute,
          now.second,
          now.millisecond,
        ),
        days = [
          for (var i = 0; i <= horizonDays; i++)
            DateTime(now.year, now.month, now.day + i),
        ],
        autoPaused = autoPausedChannels(history, now),
        blockedDays = {
          for (final r in history.records)
            if (!r.channel.isTransactional) dateKey(r.firedAt),
        };

  final DateTime now;
  final DateTime end;
  final NotificationSettings settings;
  final NotificationHistory history;
  final bool adult;

  /// Calendar days from today through the horizon.
  final List<DateTime> days;
  final Set<NotificationChannel> autoPaused;

  /// Days that already had a non-transactional notification delivered.
  final Set<String> blockedDays;

  static DateTime _at(DateTime day, int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool _allowed(NotificationChannel channel, DateTime fireAt) {
    if (!settings.isEnabled(channel)) return false;
    final until = settings.pausedUntil[channel];
    if (until != null && until.isAfter(fireAt)) return false;
    if (channel.isTransactional) return true;
    if (settings.pauseAll) return false;
    if (channel.isNutrition && (settings.pauseNutrition || !adult)) {
      return false;
    }
    return !autoPaused.contains(channel);
  }

  /// Applies quiet hours, the window and the channel rules to a wanted time.
  /// Null when the notification must not be planned.
  DateTime? _place(
    NotificationChannel channel,
    DateTime wanted, {
    DateTime? notAfter,
    bool sameDay = false,
  }) {
    final t = settings.quietHours.release(wanted);
    if (notAfter != null && t.isAfter(notAfter)) return null;
    if (sameDay && dateKey(t) != dateKey(wanted)) return null;
    if (!t.isAfter(now) || t.isAfter(end)) return null;
    return _allowed(channel, t) ? t : null;
  }

  List<PlannedNotification> sessionCandidates(
    List<ResolvedSession> sessions,
    Map<DateTime, FuelDayType> fuelDayTypes,
  ) {
    final fuelByDay = <String, FuelDayType>{};
    final sortedFuel = fuelDayTypes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in sortedFuel) {
      fuelByDay[dateKey(e.key)] = e.value;
    }

    // One reminder per day: the first open session by id.
    final open = sessions
        .where((s) =>
            s.status == SessionStatus.planned ||
            s.status == SessionStatus.today)
        .toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.session.id.compareTo(b.session.id);
      });
    final perDay = <String, ResolvedSession>{};
    for (final s in open) {
      perDay.putIfAbsent(dateKey(s.date), () => s);
    }

    final h = settings.usualTrainingHour;
    final m = settings.usualTrainingMinute;
    final out = <PlannedNotification>[];
    for (final s in perDay.values) {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      final sessionAt = _at(day, h, m);
      final reminder = _place(
        NotificationChannel.sessionReminder,
        _at(day, h, m - settings.sessionLeadMinutes),
        notAfter: sessionAt,
      );
      final type = fuelByDay[dateKey(day)];
      final fuel = type == FuelDayType.hard || type == FuelDayType.doubleDay
          ? _place(
              NotificationChannel.fuelWindow,
              _at(day, h, m - settings.fuelWindowLeadMinutes),
              notAfter: sessionAt,
            )
          : null;
      if (reminder == null && fuel == null) continue;

      final args = <String, String>{
        if (s.session.discipline != null)
          'discipline': s.session.discipline!.name,
        'weekday': NotificationPlanner._weekdayNames[day.weekday - 1],
        'sessionAt': _hhmm(sessionAt),
      };
      final route = '/train/session/${s.session.id}';
      if (reminder != null && fuel != null) {
        out.add(PlannedNotification(
          id: PlannedNotification.stableId(
            NotificationChannel.sessionReminder,
            day,
            s.session.id,
          ),
          channel: NotificationChannel.sessionReminder,
          fireAt: fuel.isBefore(reminder) ? fuel : reminder,
          contentKey: 'notif.session.soonFuel',
          args: {...args, 'fuelWindowAt': _hhmm(fuel)},
          route: route,
        ));
      } else if (reminder != null) {
        out.add(PlannedNotification(
          id: PlannedNotification.stableId(
            NotificationChannel.sessionReminder,
            day,
            s.session.id,
          ),
          channel: NotificationChannel.sessionReminder,
          fireAt: reminder,
          contentKey: 'notif.session.soon',
          args: args,
          route: route,
        ));
      } else {
        out.add(PlannedNotification(
          id: PlannedNotification.stableId(
            NotificationChannel.fuelWindow,
            day,
            s.session.id,
          ),
          channel: NotificationChannel.fuelWindow,
          fireAt: fuel!,
          contentKey: 'notif.fuel.window',
          args: {...args, 'fuelWindowAt': _hhmm(fuel)},
          route: route,
        ));
      }
    }
    return out;
  }

  List<PlannedNotification> weeklyReview() {
    final out = <PlannedNotification>[];
    for (final day in days) {
      if (day.weekday != DateTime.sunday) continue;
      final at = _place(
        NotificationChannel.weeklyReview,
        _at(day, NotificationPlanner.weeklyReviewHour, 0),
        sameDay: true,
      );
      if (at == null) continue;
      out.add(PlannedNotification(
        id: PlannedNotification.stableId(NotificationChannel.weeklyReview, day),
        channel: NotificationChannel.weeklyReview,
        fireAt: at,
        contentKey: 'notif.review.weekly',
        route: '/review',
      ));
    }
    return out;
  }

  List<PlannedNotification> fightCountdown(DateTime? fightDate) {
    if (fightDate == null) return const [];
    final out = <PlannedNotification>[];
    for (final daysBefore in NotificationPlanner.fightMilestones) {
      final day = DateTime(
        fightDate.year,
        fightDate.month,
        fightDate.day - daysBefore,
      );
      final at = _place(
        NotificationChannel.fightCountdown,
        _at(day, NotificationPlanner.fightCountdownHour, 0),
        sameDay: true,
      );
      if (at == null) continue;
      out.add(PlannedNotification(
        id: PlannedNotification.stableId(
          NotificationChannel.fightCountdown,
          day,
          'd$daysBefore',
        ),
        channel: NotificationChannel.fightCountdown,
        fireAt: at,
        contentKey:
            daysBefore == 1 ? 'notif.fight.tomorrow' : 'notif.fight.week',
        args: {'daysToFight': '$daysBefore'},
        route: '/home',
      ));
    }
    return out;
  }

  List<PlannedNotification> weighIn(Set<int> weekdays) {
    if (weekdays.isEmpty) return const [];
    final out = <PlannedNotification>[];
    for (final day in days) {
      if (!weekdays.contains(day.weekday)) continue;
      final at = _place(
        NotificationChannel.weighIn,
        _at(day, NotificationPlanner.weighInHour, 0),
        sameDay: true,
      );
      if (at == null) continue;
      out.add(PlannedNotification(
        id: PlannedNotification.stableId(NotificationChannel.weighIn, day),
        channel: NotificationChannel.weighIn,
        fireAt: at,
        contentKey: 'notif.weighIn.reminder',
        route: '/fuel',
      ));
    }
    return out;
  }

  /// Training days are days with a planned, current or completed session.
  List<PlannedNotification> proteinGap(List<ResolvedSession> sessions) {
    final trainingDays = {
      for (final s in sessions)
        if (s.status == SessionStatus.planned ||
            s.status == SessionStatus.today ||
            s.status == SessionStatus.completed)
          dateKey(s.date),
    };
    final out = <PlannedNotification>[];
    for (final day in days) {
      if (!trainingDays.contains(dateKey(day))) continue;
      final at = _place(
        NotificationChannel.proteinGap,
        _at(day, NotificationPlanner.proteinGapHour, 0),
        sameDay: true,
      );
      if (at == null) continue;
      out.add(PlannedNotification(
        id: PlannedNotification.stableId(NotificationChannel.proteinGap, day),
        channel: NotificationChannel.proteinGap,
        fireAt: at,
        contentKey: 'notif.protein.evening',
        route: '/fuel',
      ));
    }
    return out;
  }

  static int _dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  /// Lowest priority: only on days nothing else is planned or delivered, at
  /// most [NotificationPlanner.maxTipsPerWeek] in any seven days (counting
  /// tips already delivered) and never closer than
  /// [NotificationPlanner.minDaysBetweenTips] days.
  List<PlannedNotification> tips({required Set<String> taken}) {
    final tipDays = <int>[
      for (final r in history.records)
        if (r.channel == NotificationChannel.fighterTip &&
            !r.firedAt.isAfter(now))
          _dayNumber(r.firedAt),
    ];
    final out = <PlannedNotification>[];
    for (final day in days) {
      final key = dateKey(day);
      if (taken.contains(key) || blockedDays.contains(key)) continue;
      final n = _dayNumber(day);
      final inWeek = tipDays.where((t) => t >= n - 6 && t <= n).length;
      final tooClose = tipDays.any(
        (t) => t <= n && n - t < NotificationPlanner.minDaysBetweenTips,
      );
      if (inWeek >= NotificationPlanner.maxTipsPerWeek || tooClose) continue;
      final at = _place(
        NotificationChannel.fighterTip,
        _at(day, NotificationPlanner.tipHour, 0),
        sameDay: true,
      );
      if (at == null) continue;
      tipDays.add(n);
      out.add(PlannedNotification(
        id: PlannedNotification.stableId(NotificationChannel.fighterTip, day),
        channel: NotificationChannel.fighterTip,
        fireAt: at,
        contentKey: 'notif.tip.${n % NotificationPlanner.tipCount}',
        route: '/home',
      ));
    }
    return out;
  }

  /// One billing notice, once: nothing if one was already delivered.
  List<PlannedNotification> trialEnding(DateTime? trialEndsAt) {
    if (trialEndsAt == null) return const [];
    final alreadySent = history.records.any(
      (r) => r.channel == NotificationChannel.trialEnding,
    );
    if (alreadySent) return const [];
    final day = DateTime(
      trialEndsAt.year,
      trialEndsAt.month,
      trialEndsAt.day - NotificationPlanner.trialEndingDaysBefore,
    );
    final at = _place(
      NotificationChannel.trialEnding,
      _at(day, NotificationPlanner.trialEndingHour, 0),
    );
    if (at == null) return const [];
    return [
      PlannedNotification(
        id: PlannedNotification.stableId(NotificationChannel.trialEnding, day),
        channel: NotificationChannel.trialEnding,
        fireAt: at,
        contentKey: 'notif.trial.ending',
        args: {'daysLeft': '${NotificationPlanner.trialEndingDaysBefore}'},
        route: '/home',
      ),
    ];
  }
}

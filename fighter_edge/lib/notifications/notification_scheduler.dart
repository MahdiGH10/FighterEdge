import '../features/edge_fuel/domain/models/fuel_day_plan.dart';
import '../features/training_plan/domain/session_status_resolver.dart';
import 'domain/notification_channel.dart';
import 'domain/notification_history.dart';
import 'domain/notification_planner.dart';
import 'domain/notification_settings.dart';
import 'domain/planned_notification.dart';
import 'notification_copy.dart';
import 'notification_history_store.dart';
import 'reminder_gateway.dart';

/// What the planner needs besides the settings. Collected fresh for every
/// reconcile, so the scheduler never holds a stale copy of the plan.
class NotificationInputs {
  const NotificationInputs({
    this.sessions = const [],
    this.fuelDayTypes = const {},
    this.fightDate,
    this.trialEndsAt,
    this.ageYears,
    this.weighInWeekdays = const {},
  });

  final List<ResolvedSession> sessions;
  final Map<DateTime, FuelDayType> fuelDayTypes;
  final DateTime? fightDate;
  final DateTime? trialEndsAt;
  final int? ageYears;
  final Set<int> weighInWeekdays;
}

/// What one reconcile did.
class ReconcileResult {
  const ReconcileResult({
    required this.scheduled,
    required this.autoPaused,
    required this.ledger,
  });

  /// What the gateway now holds for the plan.
  final List<PlannedNotification> scheduled;

  /// Channels whose last notifications all went unopened. The app asks the
  /// athlete about each one.
  final Set<NotificationChannel> autoPaused;

  final NotificationLedger ledger;
}

/// The reconciler: brings the OS's pending notifications in line with the
/// planner's answer.
///
/// It reads no clock of its own (`now` comes from outside), holds no state
/// between runs beyond the ledger it persists, and calls the planner, the
/// copy and the gateway in that order. Running it twice with the same inputs
/// leaves the OS in the same state, so callers may run it as often as they
/// like.
class NotificationScheduler {
  NotificationScheduler({
    required ReminderGateway gateway,
    required NotificationHistoryStore historyStore,
    NotificationPlanner planner = const NotificationPlanner(),
  })  : _gateway = gateway,
        _historyStore = historyStore,
        _planner = planner;

  /// Nothing is scheduled further out than this many days.
  static const int horizonDays = 7;

  final ReminderGateway _gateway;
  final NotificationHistoryStore _historyStore;
  final NotificationPlanner _planner;

  /// Plans and schedules. [signedIn] false, or an OS that does not allow
  /// notifications, leaves nothing scheduled.
  Future<ReconcileResult> reconcile({
    required DateTime now,
    required NotificationSettings settings,
    required NotificationInputs inputs,
    required NotificationCopy copy,
    required bool signedIn,
    required bool systemAllowed,
  }) async {
    var ledger = (await _historyStore.load()).settle(now);

    if (!signedIn) {
      await _gateway.cancelAll();
      ledger = ledger.withScheduled(const []);
      await _historyStore.save(ledger);
      return ReconcileResult(
        scheduled: const [],
        autoPaused: const {},
        ledger: ledger,
      );
    }

    final history = ledger.toHistory();
    final autoPaused = autoPausedChannels(history, now);
    final plan = systemAllowed
        ? _planner.plan(
            now: now,
            settings: settings,
            sessions: inputs.sessions,
            fuelDayTypes: inputs.fuelDayTypes,
            fightDate: inputs.fightDate,
            trialEndsAt: inputs.trialEndsAt,
            history: history,
            ageYears: inputs.ageYears,
            horizonDays: horizonDays,
            weighInWeekdays: inputs.weighInWeekdays,
          )
        : const <PlannedNotification>[];

    final reminders = <ScheduledReminder>[];
    final kept = <PlannedNotification>[];
    for (final n in plan) {
      final text = copy.resolve(n.contentKey, n.args);
      // A key without words is dropped, never shown raw.
      if (text == null) continue;
      reminders.add(ScheduledReminder(
        id: n.id,
        channel: n.channel,
        fireAt: n.fireAt,
        title: text.title,
        body: text.body,
        route: n.route,
      ));
      kept.add(n);
    }

    await _gateway.replaceScheduled(reminders);
    ledger = ledger.withScheduled(kept);
    await _historyStore.save(ledger);
    return ReconcileResult(
      scheduled: kept,
      autoPaused: autoPaused,
      ledger: ledger,
    );
  }

  /// Records a tap on notification [id] and returns the new ledger.
  Future<NotificationLedger> recordOpened(int id, DateTime now) async {
    final ledger = (await _historyStore.load()).settle(now).opened(id, now);
    await _historyStore.save(ledger);
    return ledger;
  }

  /// Forgets a channel's history after the athlete answered the auto-pause
  /// question.
  Future<NotificationLedger> clearChannel(
    NotificationChannel channel,
    DateTime now,
  ) async {
    final ledger =
        (await _historyStore.load()).settle(now).withoutChannel(channel);
    await _historyStore.save(ledger);
    return ledger;
  }
}

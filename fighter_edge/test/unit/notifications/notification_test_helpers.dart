import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/intensity.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_session.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_kind.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_status.dart';
import 'package:fighter_edge/features/training_plan/domain/session_status_resolver.dart';
import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/domain/notification_history.dart';
import 'package:fighter_edge/notifications/domain/notification_planner.dart';
import 'package:fighter_edge/notifications/domain/notification_settings.dart';
import 'package:fighter_edge/notifications/domain/planned_notification.dart';

/// Monday 1 June 2026, 09:00 local. June has no daylight-saving change in
/// the usual test time zones, so wall-clock math is easy to read.
final DateTime monday = DateTime(2026, 6, 1);
final DateTime now = DateTime(2026, 6, 1, 9);

/// Day [offset] days after Monday 1 June, at [hour]:[minute].
DateTime day(int offset, [int hour = 0, int minute = 0]) =>
    DateTime(2026, 6, 1 + offset, hour, minute);

const NotificationPlanner planner = NotificationPlanner();

/// Settings with exactly [channels] switched on.
NotificationSettings on(
  Iterable<NotificationChannel> channels, {
  int usualHour = 18,
  int usualMinute = 0,
  int sessionLead = 60,
  int fuelLead = 150,
  QuietHours quiet = const QuietHours(),
  bool pauseAll = false,
  bool pauseNutrition = false,
  Map<NotificationChannel, DateTime> pausedUntil = const {},
}) =>
    NotificationSettings(
      enabledChannels: channels.toSet(),
      usualTrainingHour: usualHour,
      usualTrainingMinute: usualMinute,
      sessionLeadMinutes: sessionLead,
      fuelWindowLeadMinutes: fuelLead,
      quietHours: quiet,
      pauseAll: pauseAll,
      pauseNutrition: pauseNutrition,
      pausedUntil: pausedUntil,
    );

final NotificationSettings allOn = on(NotificationChannel.values);

/// A session [offset] days after Monday with the given status.
ResolvedSession session(
  int offset, {
  SessionStatus status = SessionStatus.planned,
  String? id,
  Discipline? discipline = Discipline.boxing,
}) {
  final date = day(offset);
  final sessionId = id ?? 's-$offset';
  return ResolvedSession(
    session: PlannedSession(
      id: sessionId,
      date: date,
      kind: SessionKind.skill,
      discipline: discipline,
      intensity: Intensity.moderate,
      titleKey: 'tplGenericSkill',
      estimatedMinutes: 60,
    ),
    date: date,
    status: status,
  );
}

List<PlannedNotification> run({
  DateTime? at,
  NotificationSettings? settings,
  List<ResolvedSession> sessions = const [],
  Map<DateTime, FuelDayType> fuel = const {},
  DateTime? fightDate,
  DateTime? trialEndsAt,
  NotificationHistory? history,
  int? age = 30,
  int horizonDays = 7,
  Set<int> weighInWeekdays = const {},
}) =>
    planner.plan(
      now: at ?? now,
      settings: settings ?? allOn,
      sessions: sessions,
      fuelDayTypes: fuel,
      fightDate: fightDate,
      trialEndsAt: trialEndsAt,
      history: history ?? NotificationHistory(),
      ageYears: age,
      horizonDays: horizonDays,
      weighInWeekdays: weighInWeekdays,
    );

List<NotificationChannel> channelsOf(List<PlannedNotification> plan) =>
    [for (final n in plan) n.channel];

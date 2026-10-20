import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../models/training_log_entry.dart';
import '../../../theme/app_icons.dart';
import '../../daily_snapshot/domain/daily_snapshot.dart' as snapshot;
import '../domain/models/discipline.dart';
import '../domain/models/planned_session.dart';
import '../domain/models/session_kind.dart';

/// Words and icons for the planned week. The domain only knows l10n keys
/// (`PlannedSession.titleKey`); this is the one place they become text.
class PlanLabels {
  PlanLabels._();

  /// The title of [session]. A key this build has no text for (a later
  /// template set) falls back to the kind's generic title.
  static String title(L l, PlannedSession session) =>
      _titleForKey(l, session.titleKey) ?? _titleForKind(l, session.kind);

  static String? _titleForKey(L l, String key) => switch (key) {
        'tplGenericSkill' => l.tplGenericSkill,
        'tplGenericSparring' => l.tplGenericSparring,
        'tplGenericConditioning' => l.tplGenericConditioning,
        'tplGenericStrength' => l.tplGenericStrength,
        'tplGenericRecovery' => l.tplGenericRecovery,
        'tplGenericGymClass' => l.tplGenericGymClass,
        _ => null,
      };

  static String _titleForKind(L l, SessionKind kind) => switch (kind) {
        SessionKind.skill => l.tplGenericSkill,
        SessionKind.sparring => l.tplGenericSparring,
        SessionKind.conditioning => l.tplGenericConditioning,
        SessionKind.strength => l.tplGenericStrength,
        SessionKind.recovery => l.tplGenericRecovery,
        SessionKind.gymClass => l.tplGenericGymClass,
      };

  static String discipline(L l, Discipline discipline) => switch (discipline) {
        Discipline.boxing => l.planDisciplineBoxing,
        Discipline.kickboxing => l.planDisciplineKickboxing,
        Discipline.muayThai => l.planDisciplineMuayThai,
        Discipline.wrestling => l.planDisciplineWrestling,
        Discipline.bjj => l.planDisciplineBjj,
        Discipline.mma => l.planDisciplineMma,
      };

  /// "Boxing · 45 min", or "45 min" for a session with no discipline.
  static String subtitle(L l, PlannedSession session) {
    final discipline = session.discipline;
    return discipline == null
        ? l.planSessionMinutes(session.estimatedMinutes)
        : l.planSessionSubtitle(
            PlanLabels.discipline(l, discipline),
            session.estimatedMinutes,
          );
  }

  /// A short weekday name for [date] in the app language ("Thu").
  static String weekday(BuildContext context, DateTime date) =>
      DateFormat.E(Localizations.localeOf(context).toString()).format(date);

  static IconData icon(SessionKind kind, Discipline? discipline) {
    switch (kind) {
      case SessionKind.conditioning:
        return AppIcons.lightning;
      case SessionKind.strength:
        return AppIcons.barbell;
      case SessionKind.recovery:
        return AppIcons.flowerLotus;
      case SessionKind.gymClass:
        return AppIcons.house;
      case SessionKind.skill:
      case SessionKind.sparring:
        return switch (discipline) {
          Discipline.wrestling => AppIcons.handGrabbing,
          Discipline.bjj || Discipline.mma => AppIcons.handFist,
          _ => AppIcons.boxingGlove,
        };
    }
  }

  /// The icon for a History or Recent activity row.
  static IconData logIcon(TrainingLogEntry entry) {
    final kind = SessionKind.values
        .where((k) => k.name == entry.detail['kind'])
        .firstOrNull;
    if (kind != null) {
      final discipline = Discipline.values
          .where((d) => d.name == entry.detail['discipline'])
          .firstOrNull;
      return icon(kind, discipline);
    }
    return switch (entry.source) {
      TrainingSource.planned => AppIcons.boxingGlove,
      TrainingSource.timer => AppIcons.timer,
      TrainingSource.reaction => AppIcons.lightning,
      TrainingSource.manual => AppIcons.barbell,
    };
  }

  /// The fixed name of [session] that may leave the device (the Corner line
  /// uses it); the words of a title never do.
  static snapshot.SessionKind snapshotKind(PlannedSession session) {
    switch (session.kind) {
      case SessionKind.conditioning:
        return snapshot.SessionKind.conditioning;
      case SessionKind.strength:
        return snapshot.SessionKind.strength;
      case SessionKind.recovery:
        return snapshot.SessionKind.recovery;
      case SessionKind.gymClass:
        return snapshot.SessionKind.other;
      case SessionKind.skill:
      case SessionKind.sparring:
        return switch (session.discipline) {
          Discipline.boxing ||
          Discipline.kickboxing ||
          Discipline.muayThai =>
            snapshot.SessionKind.striking,
          Discipline.wrestling => snapshot.SessionKind.wrestling,
          Discipline.bjj => snapshot.SessionKind.bjj,
          Discipline.mma || null => snapshot.SessionKind.other,
        };
    }
  }
}

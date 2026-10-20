import '../../fight_camp/domain/calendar.dart';
import 'models/date_key.dart';
import 'models/plan_inputs.dart';
import 'models/planned_block.dart';
import 'models/planned_day.dart';
import 'models/planned_session.dart';
import 'models/planned_week.dart';
import 'models/reason_code.dart';
import 'models/session_kind.dart';
import 'models/session_template.dart';
import 'rules/phase_modifiers.dart';
import 'rules/template_selection.dart';
import 'rules/week_allocation.dart';

/// Builds a [PlannedWeek] from [PlanInputs] and a [TemplateSet].
///
/// Deterministic: no clock, no randomness, no AI. The same inputs, week start
/// and template set always give the same week, byte for byte (compare
/// [PlannedWeek.toJson]).
class TrainingPlanGenerator {
  const TrainingPlanGenerator();

  /// Bump when the rules change, so stored weeks say which rules made them.
  static const int version = 1;

  /// Sessions never plan shorter than this, whatever the volume modifier.
  static const int minPlannedMinutes = 10;

  /// The seven days from [weekStart] (any weekday; the app uses Monday).
  /// Days before [PlanInputs.startDate] are rest days.
  PlannedWeek week(
    PlanInputs inputs,
    DateTime weekStart,
    TemplateSet templates,
  ) {
    final allocation = allocateWeek(inputs, weekStart);
    final ordinals = <String, int>{};
    final days = <PlannedDay>[];

    for (final slot in allocation.days) {
      final kind = slot.kind;
      if (kind == null) {
        days.add(
          PlannedDay(date: slot.date, type: slot.type, reasons: slot.reasons),
        );
        continue;
      }
      final ordinalKey = '${kind.name}/${slot.discipline?.name}';
      final ordinal = ordinals[ordinalKey] ?? 0;
      ordinals[ordinalKey] = ordinal + 1;

      final choice = selectTemplate(
        templates: templates,
        kind: kind,
        discipline: slot.discipline,
        level: inputs.level,
        phase: slot.phase,
        intensity: slot.intensity,
        rotationIndex: allocation.weekIndex + ordinal,
      );
      final session = _session(inputs, slot, choice);
      days.add(
        PlannedDay(date: slot.date, type: slot.type, sessions: [session]),
      );
    }

    return PlannedWeek(
      weekStart: calendarDay(weekStart),
      planStart: inputs.startDate,
      days: days,
      generatorVersion: version,
      templateSetVersion: templates.version,
      inputsHash: inputs.hash,
      reasons: allocation.reasons,
    );
  }

  PlannedSession _session(
    PlanInputs inputs,
    DaySlot slot,
    TemplateChoice choice,
  ) {
    final template = choice.template;
    final kind = choice.kind;
    final override = inputs.sessionMinutes;
    // A gym class is the gym's, so the fight phase does not trim it.
    final volume = kind == SessionKind.gymClass
        ? 1.0
        : PhaseModifiers.forPhase(slot.phase).volume;
    final baseMinutes = override ??
        template?.estimatedMinutes ??
        inputs.level.defaultSessionMinutes;
    final planned = _atLeast(baseMinutes * volume, minPlannedMinutes);
    final factor = template == null
        ? 1.0
        : baseMinutes * volume / template.estimatedMinutes;

    return PlannedSession(
      id: '${dateKey(slot.date)}.${kind.name}',
      date: slot.date,
      templateId: template?.id,
      templateVersion: template?.version,
      kind: kind,
      discipline: slot.discipline,
      intensity: slot.intensity,
      titleKey: template?.titleKey ?? kind.fallbackTitleKey,
      blocks: [
        if (template != null)
          for (final block in template.blocks) _block(block, factor),
      ],
      estimatedMinutes: planned,
      reasons: [
        ...slot.reasons,
        ...choice.reasons,
        if (override != null) ReasonCode.sessionMinutesOverride,
      ],
    );
  }

  PlannedBlock _block(BlockTemplate block, double factor) => PlannedBlock(
        kind: block.kind,
        minutes:
            block.minutes == null ? null : _atLeast(block.minutes! * factor, 1),
        rounds:
            block.rounds == null ? null : _atLeast(block.rounds! * factor, 1),
        workSec: block.workSec,
        restSec: block.restSec,
        drillIds: block.drillIds,
        cueKeys: block.cueKeys,
      );

  static int _atLeast(double value, int floor) {
    final rounded = value.round();
    return rounded < floor ? floor : rounded;
  }
}

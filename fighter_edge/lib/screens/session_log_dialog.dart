import 'package:flutter/material.dart';

import '../features/training_plan/domain/models/planned_session.dart';
import '../features/training_plan/presentation/plan_controller.dart';
import '../features/training_plan/presentation/plan_labels.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_typography.dart';

/// Asks for the effort (RPE) and a short note, then marks [session] done.
///
/// This is the one way to log a session from Home and Train. It never starts
/// the timer and never logs without the athlete choosing an RPE.
Future<void> logSessionWithRpe(
  BuildContext context,
  PlanController plan,
  PlannedSession session,
) async {
  final title = PlanLabels.title(L.of(context), session);
  final existing = plan.logEntryFor(session.id);
  final result = await showDialog<({int rpe, String note})>(
    context: context,
    builder: (_) => SessionLogDialog(
      title: title,
      initialRpe: existing?.rpe ?? 0,
      initialNote: existing?.note ?? '',
    ),
  );
  if (result == null) return;
  plan.complete(session, title: title, rpe: result.rpe, note: result.note);
  AppHaptics.success();
}

/// Owns the note controller so it is disposed with the dialog, after its exit
/// animation, never while a focused field is still on screen.
class SessionLogDialog extends StatefulWidget {
  final String title;
  final int initialRpe;
  final String initialNote;
  const SessionLogDialog({
    super.key,
    required this.title,
    required this.initialRpe,
    required this.initialNote,
  });

  @override
  State<SessionLogDialog> createState() => _SessionLogDialogState();
}

class _SessionLogDialogState extends State<SessionLogDialog> {
  late int _rpe;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _rpe = widget.initialRpe == 0 ? 7 : widget.initialRpe;
    _note = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Log ${widget.title}', style: AppType.title2()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('RPE $_rpe / 10',
              style: AppType.subhead(
                  weight: FontWeight.w700, color: AppColors.textSecondary)),
          Slider(
            value: _rpe.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppColors.primary,
            onChanged: (value) => setState(() => _rpe = value.round()),
          ),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 3,
            style: AppType.callout(),
            cursorColor: AppColors.primary,
            decoration: const InputDecoration(
              hintText: 'Quick reflection',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: AppType.callout(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, (rpe: _rpe, note: _note.text)),
          child: Text('Save',
              style: AppType.callout(
                  weight: FontWeight.w700, color: AppColors.accentText)),
        ),
      ],
    );
  }
}

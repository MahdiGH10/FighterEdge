import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../notifications/domain/notification_channel.dart';
import '../../notifications/domain/notification_settings.dart';
import '../../notifications/notification_controller.dart';
import '../../notifications/notification_inputs_reader.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_haptics.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/glass_sheet.dart';
import '../../widgets/grouped_list.dart';

/// Settings > Notifications: which reminders are on, when they fire and when
/// they stay quiet. Everything here is stored on the device.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  /// Minutes before the usual training time that the reminder can fire.
  static const List<int> leadOptions = [15, 30, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final controller = context.watch<NotificationController>();
    final settings = controller.settings;
    final nutrition = NotificationInputsReader.nutritionAllowed(
      context.watch<EdgeFuelController>(),
    );
    final secondary = AppAccessibility.textSecondary(context);

    return ScreenScaffold(
      title: l.settingsNotifications,
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.none, Insets.lg, Insets.xxl),
        children: [
          Text(l.notifScreenIntro, style: AppType.subhead(color: secondary)),
          const SizedBox(height: Insets.lg),
          if (controller.showPermissionNote) ...[
            GroupedList(children: [
              Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(AppIcons.bellRinging,
                        color: AppColors.emberSoft, size: IconSizes.row),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        defaultTargetPlatform == TargetPlatform.iOS
                            ? l.notifPermissionOffIos
                            : l.notifPermissionOffAndroid,
                        style: AppType.subhead(color: secondary),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: Insets.xl),
          ],
          _SectionLabel(l.notifSectionReminders),
          GroupedList(children: [
            _SwitchRow(
              title: l.notifSessionTitle,
              subtitle: l.notifSessionSubtitle,
              value: settings.isEnabled(NotificationChannel.sessionReminder),
              onChanged: (on) => _toggle(
                controller,
                NotificationChannel.sessionReminder,
                on,
              ),
            ),
            // A fuel window is a nutrition note, so it is offered only to an
            // adult with a confirmed Fuel setup.
            if (nutrition)
              _SwitchRow(
                title: l.notifFuelTitle,
                subtitle: l.notifFuelSubtitle,
                value: settings.isEnabled(NotificationChannel.fuelWindow),
                onChanged: (on) => _toggle(
                  controller,
                  NotificationChannel.fuelWindow,
                  on,
                ),
              ),
            _SwitchRow(
              title: l.notifReviewTitle,
              subtitle: l.notifReviewSubtitle,
              value: settings.isEnabled(NotificationChannel.weeklyReview),
              onChanged: (on) => _toggle(
                controller,
                NotificationChannel.weeklyReview,
                on,
              ),
            ),
            _SwitchRow(
              title: l.notifFightTitle,
              subtitle: l.notifFightSubtitle,
              value: settings.isEnabled(NotificationChannel.fightCountdown),
              onChanged: (on) => _toggle(
                controller,
                NotificationChannel.fightCountdown,
                on,
              ),
            ),
          ]),
          const SizedBox(height: Insets.xl),
          _SectionLabel(l.notifSectionTiming),
          GroupedList(children: [
            GroupedRow(
              title: l.notifUsualTime,
              subtitle: _format(
                context,
                settings.usualTrainingHour * 60 + settings.usualTrainingMinute,
              ),
              onTap: () => _pickUsualTime(context, controller),
            ),
            GroupedRow(
              title: l.notifSessionLead,
              subtitle: l.notifLeadOption(settings.sessionLeadMinutes),
              onTap: () => _pickLead(context, controller),
            ),
            GroupedRow(
              title: l.notifQuietStart,
              subtitle: _format(context, settings.quietHours.startMinute),
              onTap: () => _pickQuiet(context, controller, start: true),
            ),
            GroupedRow(
              title: l.notifQuietEnd,
              subtitle: _format(context, settings.quietHours.endMinute),
              onTap: () => _pickQuiet(context, controller, start: false),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: Insets.sm),
            child: Text(l.notifQuietNote,
                style: AppType.subhead(color: secondary)),
          ),
          const SizedBox(height: Insets.xl),
          GroupedList(children: [
            _SwitchRow(
              title: l.notifPauseAll,
              subtitle: l.notifPauseAllSubtitle,
              value: settings.pauseAll,
              onChanged: (on) {
                AppHaptics.commit();
                controller.setPauseAll(on);
              },
            ),
            if (nutrition)
              _SwitchRow(
                title: l.notifPauseNutrition,
                subtitle: l.notifPauseNutritionSubtitle,
                value: settings.pauseNutrition,
                onChanged: (on) {
                  AppHaptics.commit();
                  controller.setPauseNutrition(on);
                },
              ),
          ]),
          const SizedBox(height: Insets.xl),
          GroupedList(children: [
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.notifHelpTitle,
                      style: AppType.callout(weight: FontWeight.w600)),
                  const SizedBox(height: Insets.xs),
                  Text(l.notifHelpBody,
                      style: AppType.subhead(color: secondary)),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  static Future<void> _toggle(
    NotificationController controller,
    NotificationChannel channel,
    bool on,
  ) async {
    AppHaptics.commit();
    await controller.setChannelEnabled(channel, on);
  }

  static String _format(BuildContext context, int minuteOfDay) =>
      TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60)
          .format(context);

  static Future<void> _pickUsualTime(
    BuildContext context,
    NotificationController controller,
  ) async {
    final s = controller.settings;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: s.usualTrainingHour,
        minute: s.usualTrainingMinute,
      ),
    );
    if (picked == null) return;
    AppHaptics.commit();
    controller.setUsualTime(picked.hour, picked.minute);
  }

  static Future<void> _pickQuiet(
    BuildContext context,
    NotificationController controller, {
    required bool start,
  }) async {
    final quiet = controller.settings.quietHours;
    final current = start ? quiet.startMinute : quiet.endMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final minute = picked.hour * 60 + picked.minute;
    AppHaptics.commit();
    controller.setQuietHours(QuietHours(
      startMinute: start ? minute : quiet.startMinute,
      endMinute: start ? quiet.endMinute : minute,
    ));
  }

  static Future<void> _pickLead(
    BuildContext context,
    NotificationController controller,
  ) async {
    final l = L.of(context);
    final current = controller.settings.sessionLeadMinutes;
    final options = {...leadOptions, current}.toList()..sort();
    final picked = await showGlassSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.xl, Insets.none, Insets.xl, Insets.sm),
                child: Text(l.notifSessionLead, style: AppType.title1()),
              ),
              for (final minutes in options)
                _ChoiceRow(
                  label: l.notifLeadOption(minutes),
                  selected: minutes == current,
                  onTap: () {
                    AppHaptics.selection();
                    Navigator.of(sheetContext).pop(minutes);
                  },
                ),
              const SizedBox(height: Insets.lg),
            ],
          ),
        ),
      ),
    );
    if (picked != null) controller.setSessionLead(picked);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        label,
        style: AppType.micro(
          weight: FontWeight.w800,
          color: AppColors.textMuted,
          spacing: 1,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => GroupedRow(
        title: title,
        subtitle: subtitle,
        trailing: Semantics(
          label: title,
          child: Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.textSecondary,
            onChanged: onChanged,
          ),
        ),
      );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppAccessibility.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.xl, vertical: Insets.md),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppType.body())),
                if (selected)
                  const Icon(AppIcons.check, color: AppColors.accentText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

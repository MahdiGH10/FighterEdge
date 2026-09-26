import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../state/app_state.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_haptics.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/app_text_field.dart';
import '../../../../widgets/filter_chips.dart';
import '../../../../widgets/primary_button.dart';
import '../../../edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../../../edge_fuel/presentation/widgets/choice_card.dart';
import '../../domain/calendar.dart';
import '../../domain/fight_camp.dart';
import '../../domain/weight_cut_policy.dart';
import '../fight_camp_controller.dart';
import '../fight_camp_copy.dart';
import '../widgets/weight_path_summary.dart';

/// Sets or edits the athlete's next fight (docs/FIGHT_CAMP_PATTERN_BRIEF.md,
/// screen A). The weight path previews live under the form, so the athlete
/// sees whether the limit is realistic before saving anything.
class FightSetupScreen extends StatefulWidget {
  const FightSetupScreen({super.key});

  @override
  State<FightSetupScreen> createState() => _FightSetupScreenState();
}

class _FightSetupScreenState extends State<FightSetupScreen> {
  static const _weighInLeads = [0, 1, 2];
  static const _campLengths = [6, 8, 10, 12];

  DateTime? _fightDate;
  int _weighInLead = 1;
  CompetitionCategory? _category;
  int _campWeeks = FightCamp.defaultCampWeeks;
  final _limit = TextEditingController();
  bool _limitTouched = false;
  FightCamp? _existing;

  @override
  void initState() {
    super.initState();
    final existing = context.read<FightCampController>().camp;
    _existing = existing;
    if (existing != null) {
      final units = context.read<AppState>();
      _fightDate = existing.fightDate;
      _weighInLead = daysBetween(existing.weighInDate, existing.fightDate);
      _category = existing.category;
      _campWeeks = existing.campWeeks;
      _limit.text =
          units.displayWeight(existing.weightLimitKg).toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  double? get _limitKg {
    final typed = double.tryParse(_limit.text.trim().replaceAll(',', '.'));
    if (typed == null) return null;
    return context.read<AppState>().weightToKg(typed);
  }

  bool get _limitValid {
    final kg = _limitKg;
    return kg != null &&
        kg >= FightCamp.minWeightLimitKg &&
        kg <= FightCamp.maxWeightLimitKg;
  }

  FightCamp? get _draft {
    final date = _fightDate;
    final category = _category;
    final kg = _limitKg;
    if (date == null || category == null || kg == null) return null;
    return FightCamp.tryCreate(
      fightDate: date,
      weighInDate: addDays(date, -_weighInLead),
      weightLimitKg: kg,
      category: category,
      campWeeks: _campWeeks,
    );
  }

  Future<void> _pickDate() async {
    final today = context.read<AppState>().now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _fightDate ?? addDays(today, FightCamp.defaultCampWeeks * 7),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: addDays(today, 365),
    );
    if (picked == null || !mounted) return;
    AppHaptics.selection();
    setState(() => _fightDate = calendarDay(picked));
  }

  void _save(FightCamp camp) {
    context.read<FightCampController>().save(camp);
    AppHaptics.commit();
    Navigator.of(context).maybePop();
  }

  Future<void> _remove() async {
    final l = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.fightRemoveTitle),
        content: Text(l.fightRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(l.fightRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<FightCampController>().clear();
    AppHaptics.warning();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final state = context.watch<AppState>();
    final copy =
        FightCampCopy(l, state, Localizations.localeOf(context).toString());
    final draft = _draft;
    final status = draft == null
        ? null
        : FightCampStatus.of(
            draft,
            weights: state.weights,
            today: state.now,
            ageYears: context.watch<EdgeFuelController>().draft?.ageYears,
          );
    final limitError = _limitTouched && _limit.text.isNotEmpty && !_limitValid
        ? l.fightLimitError(
            copy.weight(FightCamp.minWeightLimitKg).split('.').first,
            copy.weight(FightCamp.maxWeightLimitKg).split('.').first,
            copy.unit)
        : null;

    return ScreenScaffold(
      title: l.fightSetupTitle,
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.none, Insets.lg, Insets.xxl),
        children: [
          _Label(l.fightDateLabel),
          _DateField(
            label:
                _fightDate == null ? l.fightDatePick : copy.date(_fightDate!),
            chosen: _fightDate != null,
            onTap: _pickDate,
          ),
          const SizedBox(height: Insets.xl),
          _Label(l.fightWeighInLabel),
          FilterChips(
            options: [
              l.fightWeighInSameDay,
              l.fightWeighInDayBefore,
              l.fightWeighInTwoDays,
            ],
            selectedIndex: _weighInLeads.indexOf(_weighInLead),
            onSelected: (i) => setState(() => _weighInLead = _weighInLeads[i]),
            columns: 2,
          ),
          const SizedBox(height: Insets.xl),
          AppTextField(
            controller: _limit,
            label: l.fightLimitLabel(copy.unit),
            icon: Icons.monitor_weight_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(6),
            ],
            errorText: limitError,
            onChanged: (_) => setState(() => _limitTouched = true),
          ),
          const SizedBox(height: Insets.xl),
          _Label(l.fightCategoryLabel),
          Text(
            l.fightCategoryWhy,
            style:
                AppType.subhead(color: AppAccessibility.textSecondary(context)),
          ),
          const SizedBox(height: Insets.sm),
          for (final category in CompetitionCategory.values)
            Semantics(
              inMutuallyExclusiveGroup: true,
              selected: _category == category,
              child: ChoiceCard(
                title: copy.category(category),
                description: copy.categoryHint(category),
                selected: _category == category,
                onTap: () {
                  AppHaptics.selection();
                  setState(() => _category = category);
                },
              ),
            ),
          const SizedBox(height: Insets.lg),
          _Label(l.fightCampLabel),
          FilterChips(
            options: [for (final w in _campLengths) l.fightCampWeeks(w)],
            selectedIndex: _campLengths.indexOf(_campWeeks),
            onSelected: (i) => setState(() => _campWeeks = _campLengths[i]),
            columns: 2,
          ),
          if (status != null) ...[
            const SizedBox(height: Insets.xl),
            WeightPathSummary(status: status, copy: copy),
          ],
          const SizedBox(height: Insets.xl),
          PrimaryButton(
            l.fightSave,
            onPressed: draft == null ? null : () => _save(draft),
          ),
          if (_existing != null) ...[
            const SizedBox(height: Insets.sm),
            Center(
              child: TextButton(
                onPressed: _remove,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.negative,
                  minimumSize:
                      const Size.fromHeight(AppAccessibility.minTouchTarget),
                ),
                child: Text(l.fightRemove),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.sm),
        child: Text(text, style: AppType.headline()),
      );
}

class _DateField extends StatelessWidget {
  final String label;
  final bool chosen;
  final VoidCallback onTap;
  const _DateField(
      {required this.label, required this.chosen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
          side: BorderSide(color: AppAccessibility.border(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                minHeight: AppAccessibility.minTouchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg, vertical: Insets.md),
              child: Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: IconSizes.row,
                      color: AppAccessibility.textSecondary(context)),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      label,
                      style: AppType.body(
                        color: chosen
                            ? AppColors.textPrimary
                            : AppAccessibility.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

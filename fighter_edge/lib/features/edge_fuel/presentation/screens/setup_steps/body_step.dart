import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/app_text_field.dart';
import '../../../domain/models/nutrition_enums.dart';
import '../../controllers/edge_fuel_setup_controller.dart';
import '../../nutrition_copy.dart';
import '../../widgets/choice_card.dart';

/// Step 2 of 6 — body inputs and the equation-profile choice (master prompt
/// §6.2, "Inclusive equation UX"). Also carries the safety-flag screening
/// (§6, "Validation and safety") since it belongs with other personal
/// health data rather than as a separate step.
class BodyStep extends StatefulWidget {
  final EdgeFuelSetupController controller;
  final double? prefillWeightKg;
  const BodyStep({super.key, required this.controller, this.prefillWeightKg});

  @override
  State<BodyStep> createState() => _BodyStepState();
}

class _BodyStepState extends State<BodyStep> {
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _targetWeight;

  @override
  void initState() {
    super.initState();
    final draft = widget.controller.draft;
    final weight = draft.currentWeightKg ?? widget.prefillWeightKg;
    _age = TextEditingController(text: draft.ageYears?.toString() ?? '');
    _height = TextEditingController(text: draft.heightCm?.toString() ?? '');
    _weight = TextEditingController(text: weight?.toString() ?? '');
    _targetWeight =
        TextEditingController(text: draft.targetWeightKg?.toString() ?? '');
    if (draft.currentWeightKg == null && weight != null) {
      // Deferred a frame: this runs during the parent's build, and the
      // controller must not notify listeners mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.draft.currentWeightKg == null) {
          widget.controller.setBodyInputs(currentWeightKg: weight);
        }
      });
    }
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _targetWeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final draft = controller.draft;
    final needsTarget =
        draft.goal != null && draft.goal != NutritionGoal.maintain;
    final flags = draft.safetyFlags;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      children: [
        Text('Tell us about your body', style: AppTheme.display(22)),
        const SizedBox(height: Insets.sm),
        Text(
          'Used only to estimate your energy needs — never shown publicly.',
          style: AppTheme.body(13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.xl),
        AppTextField(
          controller: _age,
          label: 'Age in years',
          icon: Icons.cake_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _commitAge(),
        ),
        const SizedBox(height: Insets.md),
        AppTextField(
          controller: _height,
          label: 'Height in cm',
          icon: Icons.height,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
          ],
          onChanged: (_) => _commitHeight(),
        ),
        const SizedBox(height: Insets.md),
        AppTextField(
          controller: _weight,
          label: 'Current weight in kg',
          icon: Icons.monitor_weight_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
          ],
          onChanged: (_) => _commitWeight(),
        ),
        if (needsTarget) ...[
          const SizedBox(height: Insets.md),
          AppTextField(
            controller: _targetWeight,
            label: 'Target weight in kg',
            icon: Icons.flag_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
            ],
            onChanged: (_) => _commitTargetWeight(),
          ),
        ],
        const SizedBox(height: Insets.xl),
        Text('Which equation should we use?', style: AppTheme.display(16)),
        const SizedBox(height: Insets.xs),
        Text(
          "Mifflin–St Jeor uses two published offsets — this isn't a social question, "
          "it's about which formula fits your physiology best.",
          style: AppTheme.body(12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.md),
        for (final profile in EquationProfile.values)
          ChoiceCard(
            title: NutritionCopy.equationLabel(profile),
            description: NutritionCopy.equationDescription(profile),
            selected: draft.equationProfile == profile,
            onTap: () => controller.setBodyInputs(equationProfile: profile),
          ),
        const SizedBox(height: Insets.xl),
        Text('Quick health check', style: AppTheme.display(16)),
        const SizedBox(height: Insets.xs),
        Text(
          "We store only yes/no flags, never details. If any apply, we'll ask you "
          "to check with a qualified professional before showing an automated plan.",
          style: AppTheme.body(12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.sm),
        _SafetyCheck(
          label: 'Pregnant or breastfeeding',
          value: flags.pregnantOrBreastfeeding,
          onChanged: (v) => controller
              .setSafetyFlags(flags.copyWith(pregnantOrBreastfeeding: v)),
        ),
        _SafetyCheck(
          label: 'Eating-disorder history or symptoms',
          value: flags.eatingDisorderHistoryOrSymptoms,
          onChanged: (v) => controller.setSafetyFlags(
              flags.copyWith(eatingDisorderHistoryOrSymptoms: v)),
        ),
        _SafetyCheck(
          label: 'Diabetes requiring medication',
          value: flags.diabetesRequiringMedication,
          onChanged: (v) => controller
              .setSafetyFlags(flags.copyWith(diabetesRequiringMedication: v)),
        ),
        _SafetyCheck(
          label: 'Kidney disease',
          value: flags.kidneyDisease,
          onChanged: (v) =>
              controller.setSafetyFlags(flags.copyWith(kidneyDisease: v)),
        ),
        _SafetyCheck(
          label: 'Serious liver disease',
          value: flags.seriousLiverDisease,
          onChanged: (v) =>
              controller.setSafetyFlags(flags.copyWith(seriousLiverDisease: v)),
        ),
        _SafetyCheck(
          label: 'Another clinician-managed diet',
          value: flags.otherClinicianManagedDiet,
          onChanged: (v) => controller
              .setSafetyFlags(flags.copyWith(otherClinicianManagedDiet: v)),
        ),
      ],
    );
  }

  void _commitAge() {
    final value = int.tryParse(_age.text.trim());
    if (value != null) widget.controller.setBodyInputs(ageYears: value);
  }

  void _commitHeight() {
    final value = double.tryParse(_height.text.trim());
    if (value != null) widget.controller.setBodyInputs(heightCm: value);
  }

  void _commitWeight() {
    final value = double.tryParse(_weight.text.trim());
    if (value != null) widget.controller.setBodyInputs(currentWeightKg: value);
  }

  void _commitTargetWeight() {
    final value = double.tryParse(_targetWeight.text.trim());
    if (value != null) {
      widget.controller.setBodyInputs(targetWeightKg: value);
    }
  }
}

class _SafetyCheck extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SafetyCheck(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeColor: AppColors.primary,
        title: Text(label, style: AppTheme.body(13, weight: FontWeight.w600)),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/models/nutrition_enums.dart';
import '../../domain/models/nutrition_profile.dart';

/// Shared by initial onboarding and the resumable Fuel wizard. Six unchecked
/// flags are not a completed screening until the athlete confirms review.
class SafetyScreeningFields extends StatelessWidget {
  const SafetyScreeningFields({
    super.key,
    required this.flags,
    required this.status,
    required this.onFlagsChanged,
    required this.onReviewedChanged,
  });

  final NutritionSafetyFlags flags;
  final NutritionScreeningStatus status;
  final ValueChanged<NutritionSafetyFlags> onFlagsChanged;
  final ValueChanged<bool> onReviewedChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick health check', style: AppType.title2()),
        const SizedBox(height: Insets.xs),
        Text(
          "We store only yes/no flags, never details. If any apply, we'll ask you "
          "to check with a qualified professional before showing an automated plan.",
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.sm),
        _SafetyCheck(
          label: 'Pregnant or breastfeeding',
          value: flags.pregnantOrBreastfeeding,
          onChanged: (v) => onFlagsChanged(
            flags.copyWith(pregnantOrBreastfeeding: v),
          ),
        ),
        _SafetyCheck(
          label: 'Eating-disorder history or symptoms',
          value: flags.eatingDisorderHistoryOrSymptoms,
          onChanged: (v) => onFlagsChanged(
            flags.copyWith(eatingDisorderHistoryOrSymptoms: v),
          ),
        ),
        _SafetyCheck(
          label: 'Diabetes requiring medication',
          value: flags.diabetesRequiringMedication,
          onChanged: (v) => onFlagsChanged(
            flags.copyWith(diabetesRequiringMedication: v),
          ),
        ),
        _SafetyCheck(
          label: 'Kidney disease',
          value: flags.kidneyDisease,
          onChanged: (v) => onFlagsChanged(flags.copyWith(kidneyDisease: v)),
        ),
        _SafetyCheck(
          label: 'Serious liver disease',
          value: flags.seriousLiverDisease,
          onChanged: (v) => onFlagsChanged(
            flags.copyWith(seriousLiverDisease: v),
          ),
        ),
        _SafetyCheck(
          label: 'Another clinician-managed diet',
          value: flags.otherClinicianManagedDiet,
          onChanged: (v) => onFlagsChanged(
            flags.copyWith(otherClinicianManagedDiet: v),
          ),
        ),
        const SizedBox(height: Insets.sm),
        CheckboxListTile(
          value: status != NutritionScreeningStatus.unanswered,
          onChanged: (value) => onReviewedChanged(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
          title: Text(
            'I reviewed every health question',
            style: AppType.subhead(weight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SafetyCheck extends StatelessWidget {
  const _SafetyCheck({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xxs),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeColor: AppColors.primary,
        title: Text(label, style: AppType.subhead(weight: FontWeight.w600)),
      ),
    );
  }
}

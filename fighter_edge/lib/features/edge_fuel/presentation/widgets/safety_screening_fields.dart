import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../l10n/gen/app_localizations.dart';
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
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.setupHealthTitle, style: AppType.title2()),
        const SizedBox(height: Insets.xs),
        Text(
          l.setupHealthHint,
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.sm),
        _SafetyCheck(
          label: l.setupHealthPregnant,
          value: flags.pregnantOrBreastfeeding,
          onChanged: (v) => onFlagsChanged(
            flags.copyWith(pregnantOrBreastfeeding: v),
          ),
        ),
        _SafetyCheck(
          label: l.setupHealthEatingDisorder,
          value: flags.eatingDisorderHistoryOrSymptoms,
          onChanged: (v) => onFlagsChanged(
            flags.copyWith(eatingDisorderHistoryOrSymptoms: v),
          ),
        ),
        _SafetyCheck(
          label: l.setupHealthDiabetes,
          value: flags.diabetesRequiringMedication,
          onChanged: (v) => onFlagsChanged(
            flags.copyWith(diabetesRequiringMedication: v),
          ),
        ),
        _SafetyCheck(
          label: l.setupHealthKidney,
          value: flags.kidneyDisease,
          onChanged: (v) => onFlagsChanged(flags.copyWith(kidneyDisease: v)),
        ),
        _SafetyCheck(
          label: l.setupHealthLiver,
          value: flags.seriousLiverDisease,
          onChanged: (v) => onFlagsChanged(
            flags.copyWith(seriousLiverDisease: v),
          ),
        ),
        _SafetyCheck(
          label: l.setupHealthOtherDiet,
          value: flags.otherClinicianManagedDiet,
          onChanged: (v) => onFlagsChanged(
            flags.copyWith(otherClinicianManagedDiet: v),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            value: status != NutritionScreeningStatus.unanswered,
            onChanged: (value) => onReviewedChanged(value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            title: Text(
              l.setupHealthReviewed,
              style: AppType.subhead(weight: FontWeight.w700),
            ),
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
      child: Material(
        type: MaterialType.transparency,
        child: CheckboxListTile(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: AppColors.primary,
          title: Text(label, style: AppType.subhead(weight: FontWeight.w600)),
        ),
      ),
    );
  }
}

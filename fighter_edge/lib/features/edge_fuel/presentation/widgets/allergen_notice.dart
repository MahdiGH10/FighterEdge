import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/models/food_enums.dart';
import '../recipe_copy.dart';

/// The banner shown above the library when the allergen filter is hiding
/// recipes, and the escape hatch that reveals them.
///
/// EF3_PLAN.md §8 decision 1 (Option B): hide conflicts by default, but say so
/// and let the user choose. Hiding silently would make a 24-recipe catalog look
/// nearly empty with no explanation; showing everything unfiltered would put
/// the burden of catching an allergen on the user every single time.
class AllergenFilterBanner extends StatelessWidget {
  final int hiddenCount;
  final bool showingConflicts;
  final VoidCallback onToggle;

  const AllergenFilterBanner({
    super.key,
    required this.hiddenCount,
    required this.showingConflicts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (hiddenCount == 0 && !showingConflicts) return const SizedBox.shrink();

    final text = showingConflicts
        ? 'Showing recipes that contain your allergens.'
        : hiddenCount == 1
            ? '1 recipe hidden by your allergen filter.'
            : '$hiddenCount recipes hidden by your allergen filter.';

    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: AppColors.warning.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(
            showingConflicts
                ? Icons.visibility_outlined
                : Icons.filter_alt_outlined,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              text,
              style: AppType.subhead(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: onToggle,
            child: Text(
              showingConflicts ? 'Hide' : 'Show',
              style: AppType.subhead(
                color: AppColors.warning,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the user typed allergens the app could not interpret.
///
/// This is the honest half of free-text allergen entry. If someone typed
/// "kiwi", the app is not filtering on it and must say so — letting them
/// believe otherwise is the failure mode that actually hurts someone.
class UnmatchedAllergenNotice extends StatelessWidget {
  final List<String> terms;

  const UnmatchedAllergenNotice({super.key, required this.terms});

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              "We don't filter on ${terms.join(', ')} — check ingredients "
              'yourself for those.',
              style: AppType.subhead(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The allergen statement on a recipe detail screen (master prompt §5.3).
class AllergenStatement extends StatelessWidget {
  final Set<Allergen> allergens;
  final Set<Allergen> conflicting;

  const AllergenStatement({
    super.key,
    required this.allergens,
    this.conflicting = const {},
  });

  @override
  Widget build(BuildContext context) {
    final hasConflict = conflicting.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: hasConflict
            ? AppColors.warning.withValues(alpha: .10)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: hasConflict
              ? AppColors.warning.withValues(alpha: .45)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasConflict
                    ? Icons.warning_amber_rounded
                    : Icons.shield_outlined,
                size: 16,
                color: hasConflict ? AppColors.warning : AppColors.textMuted,
              ),
              const SizedBox(width: Insets.sm),
              Text(
                'ALLERGENS',
                style: AppType.micro(
                  color: hasConflict ? AppColors.warning : AppColors.textMuted,
                  weight: FontWeight.w700,
                  spacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          if (hasConflict)
            Text(
              'Contains ${RecipeCopy.allergenList(conflicting)}, which you '
              'told us to avoid.',
              style: AppType.subhead(
                color: AppColors.warning,
                weight: FontWeight.w600,
              ),
            )
          else if (allergens.isEmpty)
            Text(
              'None of the allergens we track.',
              style: AppType.subhead(color: AppColors.textSecondary),
            )
          else
            Text(
              'Contains ${RecipeCopy.allergenList(allergens)}.',
              style: AppType.subhead(color: AppColors.textSecondary),
            ),
          const SizedBox(height: Insets.sm),
          Text(
            RecipeCopy.allergenDisclaimer,
            style: AppType.subhead(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

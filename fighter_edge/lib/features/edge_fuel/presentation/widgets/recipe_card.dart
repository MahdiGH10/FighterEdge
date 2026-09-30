import 'package:flutter/material.dart';
import '../../../../theme/app_icons.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../data/recipe_photos.dart';
import '../../domain/models/food_enums.dart';
import '../controllers/recipe_library_controller.dart';
import '../recipe_copy.dart';
import '../../../../widgets/press_scale.dart';
import 'recipe_photo_image.dart';

/// A recipe in the library list.
///
/// A recipe with a credited photo leads with a thumbnail. One without keeps
/// the meal-type accent stripe rather than a grey placeholder, which reads as
/// broken; a deliberate typographic card looks finished.
class RecipeCard extends StatelessWidget {
  final RecipeListing listing;
  final bool locked;
  final Set<Allergen> conflictingAllergens;
  final VoidCallback onTap;

  const RecipeCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.locked = false,
    this.conflictingAllergens = const {},
  });

  Color get _accent => switch (listing.recipe.mealType) {
        MealType.breakfast => AppColors.carbs,
        MealType.snack => AppColors.fats,
        MealType.lunch => AppColors.protein,
        MealType.dinner => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final recipe = listing.recipe;
    final photo = recipePhotoFor(recipe.id);
    final hasConflict = conflictingAllergens.isNotEmpty;

    // Without this a screen reader reads title, description, three macro
    // stats and any allergen warning as separate unrelated fragments on one
    // sweep through the list.
    final semanticLabel = [
      recipe.title,
      recipe.description,
      '${listing.perServing.kcalRounded} calories',
      '${listing.perServing.proteinRounded} grams protein',
      RecipeCopy.timeLabel(recipe.totalMinutes),
      if (locked) 'locked, Pro required',
      if (hasConflict)
        'contains ${RecipeCopy.allergenList(conflictingAllergens)}',
    ].join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: PressScale(
          onTap: onTap,
          child: ExcludeSemantics(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(
                  color: hasConflict ? AppColors.warning : AppColors.border,
                  width: hasConflict ? 1.2 : 1,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (photo != null)
                      SizedBox(
                        width: LayoutTokens.recipeThumbnail,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(Radii.card),
                          ),
                          child: RecipePhotoImage(
                            photo,
                            displayWidth: LayoutTokens.recipeThumbnail,
                          ),
                        ),
                      )
                    else
                      // Without a photo, an accent stripe keyed to meal type
                      // keeps the list scannable by colour.
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(Radii.card),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    recipe.title,
                                    style: AppType.title2(spacing: -0.2),
                                  ),
                                ),
                                if (locked) ...[
                                  const SizedBox(width: Insets.sm),
                                  const Icon(
                                    AppIcons.lockSimple,
                                    size: 16,
                                    color: AppColors.premium,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: Insets.xs),
                            Text(
                              recipe.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.subhead(
                                color: AppColors.textMuted,
                                weight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            Wrap(
                              spacing: Insets.sm,
                              runSpacing: Insets.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _Stat('${listing.perServing.kcalRounded} kcal'),
                                _Stat(
                                  '${listing.perServing.proteinRounded}g protein',
                                ),
                                _Stat(
                                    RecipeCopy.timeLabel(recipe.totalMinutes)),
                                if (listing.dietTags.contains(DietTag.vegan))
                                  const _Tag('Vegan', AppColors.positive)
                                else if (listing.dietTags.contains(
                                  DietTag.vegetarian,
                                ))
                                  const _Tag('Veggie', AppColors.positive),
                              ],
                            ),
                            if (hasConflict) ...[
                              const SizedBox(height: Insets.sm),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    AppIcons.warning,
                                    size: 14,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: Insets.xs),
                                  Expanded(
                                    child: Text(
                                      'Contains '
                                      '${RecipeCopy.allergenList(conflictingAllergens)}',
                                      style: AppType.subhead(
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String text;
  const _Stat(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppType.subhead(
          color: AppColors.textSecondary,
          weight: FontWeight.w600,
        ),
      );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm, vertical: Insets.xxs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          text,
          // Small text takes slightly positive tracking for legibility
          // (apple-design §15); the display titles above take negative.
          style: AppType.micro(
            color: color,
            weight: FontWeight.w700,
            spacing: 0.3,
          ),
        ),
      );
}

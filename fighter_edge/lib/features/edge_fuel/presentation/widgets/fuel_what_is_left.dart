import 'package:flutter/material.dart';

import '../../../../routing/app_navigation.dart';
import '../../../../routing/app_router.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/stat_card.dart';
import '../controllers/edge_fuel_controller.dart';
import '../controllers/recipe_library_controller.dart';
import '../screens/recipe_library_screen.dart';

/// "What can I eat with what's left?" — the question a daily target raises
/// and a number alone never answers. Opens the recipe library filtered to
/// recipes whose serving fits today's remaining calories, highest protein
/// first (EF3_PLAN §3.1, "Fuel this plan").
class FuelWhatIsLeft extends StatelessWidget {
  final EdgeFuelController edgeFuel;

  const FuelWhatIsLeft({super.key, required this.edgeFuel});

  /// Below this, no real meal fits and the card would only point at an
  /// empty list.
  static const minUsefulKcal = 150;

  /// Whether there is a meaningful amount left today to plan around.
  static bool appliesTo(EdgeFuelController edgeFuel) =>
      edgeFuel.hasUsableTarget &&
      edgeFuel.isToday &&
      edgeFuel.targetCalories - edgeFuel.consumedCalories >= minUsefulKcal;

  @override
  Widget build(BuildContext context) {
    final remaining = edgeFuel.targetCalories - edgeFuel.consumedCalories;
    final filters = RecipeFilters(maxCalories: remaining);
    return Semantics(
      button: true,
      label: '$remaining calories left today. Find recipes that fit.',
      excludeSemantics: true,
      child: AppCard(
        onTap: () => AppNavigation.push(
          context,
          AppRoutes.fuelRecipes,
          extra: filters,
          fallbackBuilder: (_) => RecipeLibraryScreen(initialFilters: filters),
        ),
        child: Row(
          children: [
            Container(
              width: IconSizes.badge,
              height: IconSizes.badge,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu,
                  size: IconSizes.inline, color: AppColors.primary),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.of(context).fuelLeftToday(remaining),
                      style: AppType.headline()),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    L.of(context).fuelLeftTodaySubtitle,
                    style: AppType.subhead(
                        color: AppAccessibility.textSecondary(context)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppAccessibility.textMuted(context)),
          ],
        ),
      ),
    );
  }
}

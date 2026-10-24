import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/glass_surface.dart';
import '../../domain/models/accepted_fuel_week.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/fuel_add_on.dart';
import '../../domain/models/fuel_day_gap.dart';
import '../../domain/models/fuel_day_plan.dart';
import '../../domain/models/fuel_gap.dart';
import '../../domain/models/fuel_guidance.dart';
import '../../domain/models/nutrition_target.dart';

/// The dated plan's classification and the target currently permitted to show.
/// The accepted daily average is labelled as such until day allocation review.
class FuelDayPanel extends StatelessWidget {
  const FuelDayPanel({
    super.key,
    required this.day,
    required this.allocated,
    required this.acceptedTarget,
    required this.adult,
    required this.hints,
  });

  final FuelDayPlan day;
  final AcceptedFuelDay? allocated;
  final NutritionTarget? acceptedTarget;
  final bool adult;
  final List<SessionFuelHint> hints;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final target = adult && acceptedTarget?.isSuccess == true;
    final kcal = allocated?.calories ?? acceptedTarget?.targetCalories;
    final protein = allocated?.proteinGrams ?? acceptedTarget?.proteinGrams;
    final carbs = allocated?.carbGrams ?? acceptedTarget?.carbGrams;
    return GlassCard(
      tone: GlassTone.cool,
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dayLabel(l, day.type),
            key: const ValueKey('fuel-day-type'),
            style: AppType.title2(),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            !adult
                ? l.fuelDayAdultRequired
                : allocated != null
                    ? l.fuelDayTarget
                    : target
                        ? l.fuelDayAcceptedAverage
                        : l.fuelDayNoTarget,
            style: AppType.subhead(
              color: AppAccessibility.textSecondary(context),
            ),
          ),
          if (target && kcal != null && protein != null && carbs != null) ...[
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.lg,
              runSpacing: Insets.sm,
              children: [
                _TargetValue(l.fuelDayKcal(kcal)),
                _TargetValue(l.fuelDayProtein(protein)),
                _TargetValue(l.fuelDayCarbs(carbs)),
              ],
            ),
          ],
          for (final hint in hints) ...[
            const SizedBox(height: Insets.md),
            Text(
              l.fuelSessionNumber(hint.sessionIndex + 1),
              style: AppType.subhead(weight: FontWeight.w700),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              _preHint(l, hint.pre),
              style: AppType.subhead(
                color: AppAccessibility.textSecondary(context),
              ),
            ),
            Text(
              _postHint(l, hint.post),
              style: AppType.subhead(
                color: AppAccessibility.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _dayLabel(L l, FuelDayType type) => switch (type) {
        FuelDayType.rest => l.fuelDayRest,
        FuelDayType.easy => l.fuelDayEasy,
        FuelDayType.hard => l.fuelDayHard,
        FuelDayType.doubleDay => l.fuelDayDouble,
        FuelDayType.fightWeek => l.fuelDayFightWeek,
      };

  static String _preHint(L l, PreSessionFuel hint) => switch (hint.need) {
        FuelHintNeed.recommended => l.fuelHintPrePlan,
        FuelHintNeed.optional => l.fuelHintPreOptional,
        FuelHintNeed.none => l.fuelHintPreNone,
      };

  static String _postHint(L l, PostSessionFuel hint) => switch (hint.need) {
        FuelHintNeed.recommended
            when hint.reasons.contains(FuelHintReason.carbRefillAfter) =>
          l.fuelHintPostCarbProtein,
        FuelHintNeed.recommended => l.fuelHintPostProtein,
        FuelHintNeed.optional => l.fuelHintPostOptional,
        FuelHintNeed.none => l.fuelHintPostNone,
      };
}

class _TargetValue extends StatelessWidget {
  const _TargetValue(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: AppType.subhead(
          weight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
}

/// Up to three domain-ranked portions. The caller owns the existing write gate.
class FuelGapPanel extends StatelessWidget {
  const FuelGapPanel({
    super.key,
    required this.gap,
    required this.canWrite,
    required this.onAddOn,
  });

  final FuelDayGap gap;
  final bool canWrite;
  final void Function(FuelAddOn, FoodItem) onAddOn;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final protein = gap.protein;
    final calories = gap.calories;
    if (gap.status != FuelGapStatus.ready &&
        gap.status != FuelGapStatus.noMatch) {
      return const SizedBox.shrink();
    }
    final options = <({FuelAddOn addOn, FoodItem food, String reason})>[
      if (protein != null)
        for (final option in protein.options)
          if (option.addOn != null && option.food != null)
            (
              addOn: option.addOn!,
              food: option.food!,
              reason: l.fuelGapProteinReason(
                option.reason.addsGrams,
                option.reason.kcal,
                option.reason.leavesGrams,
              ),
            ),
      if (calories != null)
        for (final option in calories.options)
          (
            addOn: option.addOn,
            food: option.food,
            reason: l.fuelGapKcalReason(
              option.reason.addsKcal,
              option.reason.leavesKcal,
            ),
          ),
    ];
    final unmatched = protein?.unmatchedAllergenTerms ??
        calories?.unmatchedAllergenTerms ??
        const <String>[];
    return GlassCard(
      tone: GlassTone.cool,
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            protein != null
                ? l.fuelGapProteinLeft(protein.gramsLeft)
                : l.fuelGapKcalLeft(calories!.kcalLeft),
            key: const ValueKey('fuel-gap-title'),
            style: AppType.title2(),
          ),
          if (options.isEmpty) ...[
            const SizedBox(height: Insets.sm),
            Text(l.fuelGapNoOptions,
                style: AppType.subhead(
                    color: AppAccessibility.textSecondary(context))),
          ],
          if (unmatched.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            Text(
              l.fuelGapCheckAllergens,
              style: AppType.subhead(
                color: AppAccessibility.textSecondary(context),
              ),
            ),
          ],
          for (final option in options) ...[
            const SizedBox(height: Insets.sm),
            TextButton(
              key: ValueKey('fuel-gap-add-${option.addOn.id}'),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(
                  AppAccessibility.minTouchTarget,
                ),
                foregroundColor: AppAccessibility.accentText(context),
              ),
              onPressed:
                  canWrite ? () => onAddOn(option.addOn, option.food) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.fuelGapOption(
                      option.food.name,
                      option.addOn.grams.round(),
                    ),
                  ),
                  Text(
                    option.reason,
                    style: AppType.subhead(
                      color: AppAccessibility.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

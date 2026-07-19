import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/meal.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_chips.dart';
import '../widgets/progress_ring.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.target;
    final consumed = state.consumedCalories;
    final ratio = consumed / t.calories;
    final ringColor = ratio > 1 ? AppColors.negative : AppColors.positive;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: 'Nutrition',
              actions: [HeaderIcon(Icons.calendar_month, onTap: () {})],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: FilterChips(
                options: const ['Today', 'Meals', 'Analytics'],
                selectedIndex: _tab,
                onSelected: (i) => setState(() => _tab = i),
                scrollable: false,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _TodayView(state: state, ratio: ratio, ringColor: ringColor),
                  _MealsView(state: state),
                  const _AnalyticsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab 0 — calorie ring, macros, and the meal checklist.
class _TodayView extends StatelessWidget {
  final AppState state;
  final double ratio;
  final Color ringColor;
  const _TodayView(
      {required this.state, required this.ratio, required this.ringColor});

  @override
  Widget build(BuildContext context) {
    final t = state.target;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        const SectionHeader('Calories'),
        AppCard(
          child: Column(
            children: [
              const SizedBox(height: Insets.sm),
              ProgressRing(
                progress: ratio.clamp(0.0, 1.0),
                size: 160,
                strokeWidth: 12,
                color: ringColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${state.consumedCalories}',
                        style: AppTheme.display(38)),
                    Text('/ ${t.calories} kcal',
                        style: AppTheme.body(12,
                            weight: FontWeight.w500,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: Insets.xl),
              Row(
                children: [
                  _Macro('Protein', state.consumedProtein, t.protein,
                      AppColors.protein),
                  _Macro(
                      'Carbs', state.consumedCarbs, t.carbs, AppColors.carbs),
                  _Macro('Fats', state.consumedFats, t.fats, AppColors.fats),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        const SectionHeader('Meals'),
        for (final m in state.meals)
          _MealRow(meal: m, onToggle: () => state.toggleMeal(m)),
      ],
    );
  }
}

/// Tab 1 — focused meal log with running totals.
class _MealsView extends StatelessWidget {
  final AppState state;
  const _MealsView({required this.state});

  @override
  Widget build(BuildContext context) {
    final eaten = state.meals.where((m) => m.eaten).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
      children: [
        SectionHeader('Meals logged · $eaten/${state.meals.length}'),
        for (final m in state.meals)
          _MealRow(meal: m, onToggle: () => state.toggleMeal(m)),
      ],
    );
  }
}

/// Tab 2 — analytics placeholder until history logging lands.
class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.insights,
      title: 'Analytics',
      message:
          'Weekly calorie and macro trends will appear here\nonce meal history is being logged.',
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final int value;
  final int target;
  final Color color;
  const _Macro(this.label, this.value, this.target, this.color);

  @override
  Widget build(BuildContext context) {
    final over = value > target;
    return Expanded(
      child: Column(
        children: [
          Text(label.toUpperCase(),
              style: AppTheme.body(10,
                  weight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: Insets.sm),
          Text('$value g', style: AppTheme.display(18)),
          Text('/ $target g',
              style: AppTheme.body(11,
                  weight: FontWeight.w500,
                  color: over ? AppColors.negative : AppColors.textMuted)),
          const SizedBox(height: Insets.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: (value / target).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppColors.track,
              valueColor:
                  AlwaysStoppedAnimation(over ? AppColors.negative : color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final Meal meal;
  final VoidCallback onToggle;
  const _MealRow({required this.meal, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        onTap: onToggle,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.name,
                      style: AppTheme.body(15, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(meal.items,
                      style: AppTheme.body(12,
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text('${meal.calories} kcal',
                style: AppTheme.body(13,
                    weight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(width: Insets.md),
            _Check(checked: meal.eaten),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool checked;
  const _Check({required this.checked});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : MotionTokens.fast,
      curve: MotionTokens.emphasized,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: checked ? AppColors.positive : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: checked ? AppColors.positive : AppColors.border,
          width: 2,
        ),
      ),
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : MotionTokens.fast,
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: checked
            ? const Icon(Icons.check,
                key: ValueKey('meal-check'), size: 16, color: Colors.white)
            : const SizedBox(key: ValueKey('meal-empty')),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/first_run_controller.dart';
import '../../theme/app_accessibility.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_haptics.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/stat_card.dart';

/// Four small wins that turn a new account into a used one.
///
/// Everything is read from real state rather than ticked by hand — a meal
/// counts when a meal is logged, a session when a session is completed — so
/// the list can never claim progress the user has not made. The first win it
/// drives toward is one logged meal: the smallest real use of the product.
class FirstWeekChecklist extends StatelessWidget {
  final VoidCallback onStartTour;
  final VoidCallback onLogMeal;
  final VoidCallback onTrain;

  const FirstWeekChecklist({
    super.key,
    required this.onStartTour,
    required this.onLogMeal,
    required this.onTrain,
  });

  @override
  Widget build(BuildContext context) {
    final firstRun = context.watch<FirstRunController>();
    final state = context.watch<AppState>();

    final items = [
      const _Item(
        title: 'Build your plan',
        subtitle: 'Your target and training week are set.',
        icon: Icons.flag_outlined,
        done: true,
      ),
      _Item(
        title: 'Take the 30-second tour',
        subtitle: 'See where everything lives.',
        icon: Icons.explore_outlined,
        done: firstRun.tourDone,
        onTap: onStartTour,
      ),
      _Item(
        title: 'Log your first meal',
        subtitle: 'One tap from Fuel. It starts your day’s score.',
        icon: Icons.restaurant_outlined,
        done: firstRun.firstMealLogged,
        onTap: onLogMeal,
      ),
      _Item(
        title: 'Complete a session',
        subtitle: 'Tick one off in Train to start your streak.',
        icon: Icons.sports_mma,
        done: state.completedSessionCount > 0,
        onTap: onTrain,
      ),
    ];
    final doneCount = items.where((i) => i.done).length;
    final allDone = doneCount == items.length;
    // The first unfinished item is the one to do now; it gets the accent so
    // there is always exactly one obvious next step.
    final nextIndex = items.indexWhere((i) => !i.done);

    return AppCard(
      accent: allDone ? AppColors.positive : AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  allDone ? 'First week: set' : 'Your first week',
                  style: AppType.title2(),
                ),
              ),
              Text(
                '$doneCount of ${items.length}',
                style: AppType.subhead(
                  weight: FontWeight.w700,
                  color: AppAccessibility.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          // The "n of 4" text already says this; the bar is for the eye.
          ExcludeSemantics(
            child:
                _Progress(value: doneCount / items.length, complete: allDone),
          ),
          const SizedBox(height: Insets.md),
          if (allDone) ...[
            Text(
              'Plan built, meal logged, first session done. That is a real '
              'start — keep the streak going this week.',
              style: AppType.callout(
                  color: AppAccessibility.textSecondary(context)),
            ),
            const SizedBox(height: Insets.lg),
            PrimaryButton(
              'Done',
              icon: Icons.check,
              expand: true,
              onPressed: () {
                AppHaptics.commit();
                firstRun.dismissChecklist();
              },
            ),
          ] else
            for (var i = 0; i < items.length; i++)
              _ItemRow(item: items[i], isNext: i == nextIndex),
        ],
      ),
    );
  }
}

class _Item {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool done;
  final VoidCallback? onTap;

  const _Item({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.done,
    this.onTap,
  });
}

class _Progress extends StatelessWidget {
  final double value;
  final bool complete;
  const _Progress({required this.value, required this.complete});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : MotionTokens.standard,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(Radii.chip),
        child: LinearProgressIndicator(
          value: v,
          minHeight: Insets.xs + Insets.xxs,
          backgroundColor: AppColors.track,
          color: complete ? AppColors.positive : AppColors.primary,
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final _Item item;
  final bool isNext;
  const _ItemRow({required this.item, required this.isNext});

  @override
  Widget build(BuildContext context) {
    final muted = AppAccessibility.textMuted(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MotionTokens.fast;
    final tappable = !item.done && item.onTap != null;

    // A button that does the thing, not a checkbox: tapping never ticks the
    // item by itself, so announcing it as toggleable would be a lie. Whether
    // it is done rides along in the label instead.
    return Semantics(
      button: tappable,
      label: item.done ? '${item.title}, done' : item.title,
      hint: item.done ? null : item.subtitle,
      excludeSemantics: true,
      child: InkWell(
        onTap: tappable
            ? () {
                AppHaptics.tap();
                item.onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(Radii.button),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppAccessibility.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: duration,
                  child: Icon(
                    item.done ? Icons.check_circle : item.icon,
                    key: ValueKey(item.done),
                    size: 22,
                    color: item.done
                        ? AppColors.positive
                        : isNext
                            ? AppColors.accentText
                            : muted,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppType.callout(
                          weight: FontWeight.w700,
                          color: item.done ? muted : AppColors.textPrimary,
                        ).copyWith(
                          decoration:
                              item.done ? TextDecoration.lineThrough : null,
                          decorationColor: muted,
                        ),
                      ),
                      if (isNext) ...[
                        const SizedBox(height: Insets.xxs),
                        Text(
                          item.subtitle,
                          style: AppType.subhead(
                              color: AppAccessibility.textSecondary(context)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (tappable)
                  Icon(
                    Icons.chevron_right,
                    color: isNext ? AppColors.accentText : muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

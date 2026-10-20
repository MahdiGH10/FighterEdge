import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../l10n/decimal_format.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../state/app_state.dart';
import '../../../state/sync_tracker.dart';
import '../../../theme/app_accessibility.dart';
import '../../../theme/app_haptics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_scaffold.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/stat_card.dart';
import '../../edge_fuel/data/edge_fuel_repository.dart';
import '../../edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../../edge_fuel/presentation/widgets/fuel_week_card.dart';
import '../../fight_camp/presentation/fight_camp_controller.dart';
import '../../training_plan/presentation/plan_controller.dart';
import '../domain/target_adjustment.dart';
import '../domain/weekly_review.dart';
import 'weekly_review_builder.dart';

/// The weekly review: what the week held, and one recommendation the athlete
/// accepts or declines. Nothing changes until they accept.
class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key, required this.weekStart});

  /// The Monday of the week under review.
  final DateTime weekStart;

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  late final Future<WeeklyReview> _review;

  @override
  void initState() {
    super.initState();
    _review = buildWeeklyReview(
      weekStartDay: widget.weekStart,
      plan: context.read<PlanController>(),
      state: context.read<AppState>(),
      fuel: context.read<EdgeFuelController>(),
      fightCamp: context.read<FightCampController>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    return ScreenScaffold(
      title: l.reviewTitle,
      showBack: true,
      body: FutureBuilder<WeeklyReview>(
        future: _review,
        builder: (context, snapshot) {
          final review = snapshot.data;
          if (review == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Insets.lg, Insets.none, Insets.lg, Insets.xxl),
            children: [
              Text(
                l.reviewWeekOf(
                    DateFormat.MMMd(locale).format(review.weekStart)),
                style: AppType.subhead(
                    color: AppAccessibility.textSecondary(context)),
              ),
              const SizedBox(height: Insets.md),
              _TrainingSection(review: review),
              const SizedBox(height: Insets.md),
              _FoodSection(review: review, weekStart: widget.weekStart),
              const SizedBox(height: Insets.md),
              _WeightSection(review: review),
              const SizedBox(height: Insets.md),
              _RecommendationSection(review: review),
            ],
          );
        },
      ),
    );
  }
}

class _TrainingSection extends StatelessWidget {
  const _TrainingSection({required this.review});
  final WeeklyReview review;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final t = review.training;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.reviewTraining, style: AppType.headline()),
          const SizedBox(height: Insets.xs),
          Text(
            t.planned == 0
                ? l.weeklyCardRestWeek
                : l.reviewSessionsDone(t.completed, t.planned),
            style: AppType.title1(),
          ),
          if (t.planned > 0 && t.target < t.planned) ...[
            const SizedBox(height: Insets.xs),
            Text(l.weeklyCardTarget(t.target),
                style: AppType.subhead(
                    color: AppAccessibility.textSecondary(context))),
          ],
        ],
      ),
    );
  }
}

class _FoodSection extends StatelessWidget {
  const _FoodSection({required this.review, required this.weekStart});
  final WeeklyReview review;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final n = review.nutrition;
    final secondary = AppAccessibility.textSecondary(context);
    final fuel = context.watch<EdgeFuelController>();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.reviewFood, style: AppType.headline()),
          const SizedBox(height: Insets.sm),
          if (n.targetCalories == null)
            Text(l.reviewFoodNoTarget, style: AppType.callout(color: secondary))
          else ...[
            FuelWeekCard(
              key: ValueKey('review-fuel-$weekStart'),
              edgeFuel: fuel,
              embedded: true,
              now: DateTime(weekStart.year, weekStart.month, weekStart.day + 6),
            ),
            const SizedBox(height: Insets.md),
            Text(
              n.averageCalories == null
                  ? l.reviewFoodNoLogs
                  : l.reviewFoodAverage(n.averageCalories!, n.targetCalories!),
              style: AppType.callout(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightSection extends StatelessWidget {
  const _WeightSection({required this.review});
  final WeeklyReview review;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final state = context.watch<AppState>();
    final locale = Localizations.localeOf(context).toString();
    final w = review.weight;
    final secondary = AppAccessibility.textSecondary(context);
    String change(double kg) {
      final shown = state.displayWeight(kg);
      final sign = shown > 0 ? '+' : '';
      return '$sign${formatFixedDecimal(shown, locale)} ${state.weightUnitLabel}';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.reviewWeight, style: AppType.headline()),
          const SizedBox(height: Insets.xs),
          if (w.changeKg == null)
            Text(l.reviewWeightNoData, style: AppType.callout(color: secondary))
          else ...[
            Text(change(w.changeKg!), style: AppType.title1()),
            const SizedBox(height: Insets.xs),
            Text(
              w.expectedChangeKg == null
                  ? l.reviewWeightNoPath
                  : l.reviewWeightPath(change(w.expectedChangeKg!)),
              style: AppType.callout(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({required this.review});
  final WeeklyReview review;

  String _sentence(L l) {
    final r = review.recommendation;
    switch (r.kind) {
      case RecommendationKind.moveSession:
        return l.reviewRecMoveSession;
      case RecommendationKind.adjustCalories:
        return r.calorieDelta < 0
            ? l.reviewRecLower(-r.calorieDelta)
            : l.reviewRecRaise(r.calorieDelta);
      case RecommendationKind.hold:
        return switch (r.reason) {
          ReviewReason.onPath => l.reviewHoldOnPath,
          ReviewReason.noTarget => l.reviewHoldNoTarget,
          ReviewReason.needMoreLogs => l.reviewHoldNeedLogs,
          ReviewReason.intakeOffTarget => l.reviewHoldIntake,
          ReviewReason.noWeightPath => l.reviewHoldNoPath,
          ReviewReason.atFloor => l.reviewHoldFloor,
          _ => l.reviewHoldOnPath,
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final plan = context.watch<PlanController>();
    final decision = plan.reviewDecision(review.weekStart);
    final actionable = review.recommendation.kind != RecommendationKind.hold &&
        decision == null;
    return AppCard(
      accent: AppAccessibility.accentText(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.reviewRecommendation, style: AppType.headline()),
          const SizedBox(height: Insets.sm),
          Text(_sentence(l), style: AppType.body()),
          const SizedBox(height: Insets.md),
          if (decision != null)
            Text(
              decision == ReviewDecision.accepted
                  ? l.reviewAccepted
                  : l.reviewKept,
              style: AppType.subhead(
                  color: AppAccessibility.textSecondary(context)),
            )
          else if (actionable) ...[
            PrimaryButton(l.reviewAccept,
                expand: true, onPressed: () => _accept(context)),
            const SizedBox(height: Insets.sm),
            GhostButton(l.reviewKeepCurrent,
                expand: true, onPressed: () => _keep(context)),
          ] else
            PrimaryButton(l.reviewGotIt,
                expand: true, onPressed: () => _keep(context)),
        ],
      ),
    );
  }

  void _keep(BuildContext context) {
    context
        .read<PlanController>()
        .recordReview(review.weekStart, ReviewDecision.kept);
    Navigator.of(context).maybePop();
  }

  void _accept(BuildContext context) {
    final plan = context.read<PlanController>();
    final r = review.recommendation;
    switch (r.kind) {
      case RecommendationKind.moveSession:
        final row =
            plan.rows.where((row) => row.session.id == r.sessionId).firstOrNull;
        if (row != null && plan.canMoveToToday(row)) {
          plan.move(row.session, plan.today);
        }
      case RecommendationKind.adjustCalories:
        final fuel = context.read<EdgeFuelController>();
        final userId = context.read<AuthController>().user?.id;
        final target = fuel.target;
        final adjusted = target == null
            ? null
            : TargetAdjustment.apply(target, r.calorieDelta,
                now: context.read<AppState>().now);
        if (adjusted != null && userId != null) {
          final repo = context.read<EdgeFuelRepository>();
          final sync = context.read<SyncTracker>();
          sync.run('review-target', 'review_target_save_failed',
              () => repo.saveTarget(userId, adjusted));
        }
      case RecommendationKind.hold:
        break;
    }
    plan.recordReview(review.weekStart, ReviewDecision.accepted);
    AppHaptics.success();
    Navigator.of(context).maybePop();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../billing/subscription.dart';
import '../../../../auth/verification_gate.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../routing/app_navigation.dart';
import '../../../../routing/app_router.dart';
import '../../../../screens/auth/verify_email_screen.dart';
import '../../../../screens/paywall_screen.dart';
import '../../../../theme/app_accessibility.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_haptics.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/app_scaffold.dart';
import '../../../../widgets/empty_state.dart';
import '../../../../widgets/premium_effects.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../widgets/skeleton.dart';
import '../../../../widgets/stat_card.dart';
import '../../../../observability/telemetry.dart';
import '../../ai/edge_fuel_ai_gateway.dart';
import '../../ai/edge_fuel_ai_models.dart';
import '../../domain/calculators/fighter_brief_calculator.dart';
import '../../domain/models/fighter_brief_preview.dart';
import '../../domain/models/nutrition_target.dart';
import '../controllers/edge_fuel_ai_controller.dart';
import '../controllers/edge_fuel_controller.dart';
import '../nutrition_copy.dart';
import 'edge_fuel_setup_screen.dart';

/// Read-only view of the confirmed EdgeFuel plan (master prompt §5.2, §19
/// EF-1: "Plan screen, calculation explanation"). Reachable from the
/// Nutrition tab once setup is confirmed.
class EdgeFuelPlanScreen extends StatelessWidget {
  const EdgeFuelPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final edgeFuel = context.watch<EdgeFuelController>();
    final target = edgeFuel.target;

    return ChangeNotifierProvider(
      create: (ctx) => EdgeFuelAiController(
        gateway: ctx.read<EdgeFuelAiGateway>(),
        telemetry: Telemetry.fromContext(ctx),
      ),
      child: ScreenScaffold(
        title: 'Your plan',
        showBack: true,
        body: target == null || !target.isSuccess
            ? _EmptyPlan(target: target)
            : _PlanBody(target: target, edgeFuel: edgeFuel),
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  final NutritionTarget? target;
  const _EmptyPlan({required this.target});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthController>().user?.id;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.lg, Insets.lg, Insets.xxl),
      children: [
        const EmptyState(
          icon: Icons.restaurant_menu,
          title: 'No plan yet',
          message: 'Run the EdgeFuel setup to get a personalized daily target.',
        ),
        const SizedBox(height: Insets.lg),
        PrimaryButton(
          'Start setup',
          icon: Icons.arrow_forward,
          expand: true,
          onPressed: userId == null
              ? null
              : () => AppNavigation.push(
                    context,
                    AppRoutes.fuelSetup,
                    fallbackBuilder: (_) => const EdgeFuelSetupScreen(),
                  ),
        ),
      ],
    );
  }
}

class _PlanBody extends StatelessWidget {
  final NutritionTarget target;
  final EdgeFuelController edgeFuel;
  const _PlanBody({required this.target, required this.edgeFuel});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.lg, Insets.lg, Insets.lg, Insets.xxl),
      children: [
        AppCard(
          accent: AppColors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DAILY TARGET',
                  style: AppType.micro(
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                      spacing: 0.8)),
              const SizedBox(height: Insets.xs),
              Text('${target.targetCalories} kcal',
                  style: AppType.largeTitle()),
              const SizedBox(height: Insets.xxs),
              Text(
                'Maintenance range ${target.maintenanceRangeLowKcal}–${target.maintenanceRangeHighKcal} kcal',
                style: AppType.subhead(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        Row(
          children: [
            _MacroChip('Protein', target.proteinGrams, AppColors.protein),
            const SizedBox(width: Insets.sm),
            _MacroChip('Carbs', target.carbGrams, AppColors.carbs),
            const SizedBox(width: Insets.sm),
            _MacroChip('Fats', target.fatGrams, AppColors.fats),
          ],
        ),
        const SizedBox(height: Insets.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HOW THIS WAS CALCULATED',
                  style: AppType.micro(
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                      spacing: 0.8)),
              const SizedBox(height: Insets.sm),
              Text(
                'Estimated resting energy: ${target.estimatedRmrKcal} kcal '
                '(Mifflin–St Jeor, ${target.equationProfileUsed != null ? NutritionCopy.equationLabel(target.equationProfileUsed!) : 'midpoint'}). '
                'Multiplied by your activity factor, then adjusted for your goal pace. '
                'This is an estimate, not a diagnosis — recalculate any time by revisiting setup.',
                style: AppType.subhead(
                    weight: FontWeight.w500, color: AppColors.textSecondary),
              ),
              if (target.confidence != null) ...[
                const SizedBox(height: Insets.sm),
                Text(
                  NutritionCopy.confidenceLabel(target.confidence!),
                  style: AppType.micro(
                      weight: FontWeight.w700, color: AppColors.accentText),
                ),
              ],
            ],
          ),
        ),
        if (target.warnings.isNotEmpty) ...[
          const SizedBox(height: Insets.lg),
          AppCard(
            accent: AppColors.warning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: Insets.sm),
                    Text('Worth knowing',
                        style: AppType.subhead(weight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                for (final code in target.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${NutritionCopy.warning(code)}',
                        style: AppType.subhead(color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Insets.lg),
        _FighterBriefPreviewSection(target: target, edgeFuel: edgeFuel),
        const SizedBox(height: Insets.lg),
        _AiCoachSection(target: target, edgeFuel: edgeFuel),
        const SizedBox(height: Insets.lg),
        // Rare and deliberate: kept quiet so the brief's Generate stays the
        // one primary action on the screen.
        GhostButton(
          'Redo setup',
          icon: Icons.tune,
          expand: true,
          onPressed: () => AppNavigation.push(
            context,
            AppRoutes.fuelSetup,
            fallbackBuilder: (_) => const EdgeFuelSetupScreen(),
          ),
        ),
      ],
    );
  }
}

class _FighterBriefPreviewSection extends StatefulWidget {
  final NutritionTarget target;
  final EdgeFuelController edgeFuel;

  const _FighterBriefPreviewSection({
    required this.target,
    required this.edgeFuel,
  });

  @override
  State<_FighterBriefPreviewSection> createState() =>
      _FighterBriefPreviewSectionState();
}

class _FighterBriefPreviewSectionState
    extends State<_FighterBriefPreviewSection> {
  late final Telemetry _telemetry;

  @override
  void initState() {
    super.initState();
    _telemetry = Telemetry.fromContext(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isPro = context.read<AuthController>().allows(
            Feature.edgeFuelAiCoach,
          );
      _telemetry.track(
        TelemetryEvent.fighterBriefPreviewViewed,
        parameters: {'access': isPro ? 'pro' : 'free'},
      );
    });
  }

  void _openPaywall() {
    _telemetry.track(
      TelemetryEvent.premiumCtaTapped,
      parameters: {'surface': 'fighter_brief_preview'},
    );
    AppNavigation.push(
      context,
      AppRoutes.paywall,
      extra: Feature.edgeFuelAiCoach,
      fallbackBuilder: (_) =>
          const PaywallScreen(highlight: Feature.edgeFuelAiCoach),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = FighterBriefCalculator.calculate(
      target: widget.target,
      day: widget.edgeFuel.day,
    );
    final isPro = context.watch<AuthController>().allows(
          Feature.edgeFuelAiCoach,
        );
    final ai = context.watch<EdgeFuelAiController>();
    // Once the full brief is on its way or on screen, the quick read would
    // only repeat it — or worse, contradict it ("log a meal to see your
    // first brief" above a finished one). It steps aside for Pro.
    final showQuickRead = !isPro ||
        !(ai.isBriefLoading ||
            ai.lastBriefResult?.status == EdgeFuelAiStatus.success);

    return AppCard(
      accent: AppColors.premium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: AppColors.premium, size: IconSizes.inline),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'FIGHTER BRIEF',
                  style: AppType.micro(
                    weight: FontWeight.w800,
                    color: AppColors.textMuted,
                    spacing: .8,
                  ),
                ),
              ),
              if (!isPro)
                Text(
                  'FREE PREVIEW',
                  style: AppType.micro(
                    weight: FontWeight.w800,
                    color: AppColors.premium,
                    spacing: .6,
                  ),
                ),
            ],
          ),
          if (showQuickRead) ...[
            const SizedBox(height: Insets.sm),
            Text(
              preview.summary,
              style: AppType.callout(weight: FontWeight.w800),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              preview.nextAction,
              style: AppType.subhead(color: AppColors.textSecondary),
            ),
            if (preview.isReady) ...[
              const SizedBox(height: Insets.md),
              _BriefRemainingRow(preview: preview),
            ],
          ],
          if (!isPro) ...[
            const SizedBox(height: Insets.md),
            Text(
              preview.isReady
                  ? 'Pro adds an exact meal, training timing, and tomorrow\'s adjustment.'
                  : 'Log your first meal in Fuel to unlock this personalized preview. Pro adds the full plan and explanation.',
              style: AppType.micro(color: AppColors.textMuted),
            ),
            const SizedBox(height: Insets.md),
            PrimaryButton(
              'Unlock my Fighter Brief',
              icon: Icons.lock_open_outlined,
              expand: true,
              onPressed: _openPaywall,
            ),
          ] else ...[
            const SizedBox(height: Insets.md),
            _PremiumBriefBody(
              ai: ai,
              target: widget.target,
              edgeFuel: widget.edgeFuel,
            ),
          ],
        ],
      ),
    );
  }
}

class _BriefNeedsVerification extends StatelessWidget {
  final VoidCallback onVerify;

  const _BriefNeedsVerification({required this.onVerify});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm your email to unlock the AI coach. The quick read above '
          'stays accurate in the meantime.',
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.md),
        PrimaryButton(
          'Verify my email',
          icon: Icons.mark_email_unread_outlined,
          expand: true,
          onPressed: onVerify,
        ),
      ],
    );
  }
}

class _PremiumBriefBody extends StatelessWidget {
  final EdgeFuelAiController ai;
  final NutritionTarget target;
  final EdgeFuelController edgeFuel;

  const _PremiumBriefBody({
    required this.ai,
    required this.target,
    required this.edgeFuel,
  });

  Future<void> _generate() async {
    await ai.generateFighterBrief(
      target: target,
      day: edgeFuel.day,
      preferences: edgeFuel.draft,
    );
    // The wait is long enough that the landing deserves to be felt. Failures
    // stay quiet: the notice that replaces the skeleton already says it.
    if (ai.lastBriefResult?.status == EdgeFuelAiStatus.success) {
      await AppHaptics.success();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The server refuses unverified callers outright; catching it here turns a
    // permission error into something the user can act on.
    final auth = context.watch<AuthController>();
    if (!auth.allowsVerified(VerifiedAction.aiCoach)) {
      return _BriefNeedsVerification(
        onVerify: () => AppNavigation.push(
          context,
          AppRoutes.verifyEmail,
          fallbackBuilder: (_) => const VerifyEmailScreen(),
        ),
      );
    }

    if (ai.isBriefLoading) return const _BriefBuilding();

    final result = ai.lastBriefResult;
    if (result == null) return _BriefIdle(onGenerate: _generate);

    final response = result.response;
    return switch (result.status) {
      EdgeFuelAiStatus.quotaReached => const _BriefNotice(
          icon: Icons.hourglass_bottom_rounded,
          title: 'Today’s briefs are used up',
          message: 'The quick read above stays live. The full brief resets '
              'tomorrow.',
        ),
      EdgeFuelAiStatus.entitlementRequired => _BriefNotice(
          icon: Icons.sync_rounded,
          title: 'Pro is still syncing',
          message: 'Your purchase has not reached our server yet. Refresh to '
              'check again.',
          actionLabel: 'Refresh my access',
          onAction: () async {
            await auth.refreshCurrentUser();
            await _generate();
          },
        ),
      EdgeFuelAiStatus.success when response?.brief != null => _BriefResult(
          response: response!,
          brief: response.brief!,
          stale: ai.isBriefStale(edgeFuel.day),
          onRefresh: _generate,
        ),
      // Unavailable, or a success without brief sections (an older server).
      _ => _BriefNotice(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn’t build your brief',
          message: 'The coach couldn’t put a reliable brief together just '
              'now. The quick read above is still accurate.',
          actionLabel: 'Try again',
          onAction: _generate,
        ),
    };
  }
}

class _BriefIdle extends StatelessWidget {
  final VoidCallback onGenerate;
  const _BriefIdle({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Turn today’s target and log into one focused next move, a meal '
          'cue, training timing, and your weekly adjustment.',
          style:
              AppType.callout(color: AppAccessibility.textSecondary(context)),
        ),
        const SizedBox(height: Insets.md),
        PrimaryButton(
          'Generate full Fighter Brief',
          icon: Icons.auto_awesome,
          expand: true,
          onPressed: onGenerate,
        ),
        const SizedBox(height: Insets.sm),
        // Sets the wait up front, so ten seconds reads as work, not a hang.
        Text(
          'Uses only your plan and today’s log. Takes about ten seconds.',
          style: AppType.subhead(color: AppAccessibility.textMuted(context)),
        ),
      ],
    );
  }
}

/// The wait, shaped like what is coming: a summary and four sections.
///
/// The line above the skeleton names what the server is actually doing, in
/// order, holding on the last step rather than looping — a loop would claim
/// progress that is not happening.
class _BriefBuilding extends StatefulWidget {
  const _BriefBuilding();

  @override
  State<_BriefBuilding> createState() => _BriefBuildingState();
}

class _BriefBuildingState extends State<_BriefBuilding> {
  static const _stages = [
    'Reading your plan',
    'Checking today’s log',
    'Writing your brief',
    'Checking it against your numbers',
  ];
  static const _stageInterval = Duration(seconds: 3);
  static const _tileHeight = IconSizes.badge + Insets.md * 2;

  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_stageInterval, (timer) {
      if (_stage >= _stages.length - 1) {
        timer.cancel();
        return;
      }
      setState(() => _stage++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _stages[_stage];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          label: label,
          excludeSemantics: true,
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : MotionTokens.fast,
            child: Text(
              '$label…',
              key: ValueKey(_stage),
              style: AppType.callout(
                weight: FontWeight.w600,
                color: AppColors.premium,
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
        Skeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox.line(),
              const SizedBox(height: Insets.sm),
              const FractionallySizedBox(
                widthFactor: .6,
                child: SkeletonBox.line(),
              ),
              const SizedBox(height: Insets.lg),
              for (var i = 0; i < 4; i++) ...[
                const SkeletonBox(height: _tileHeight, radius: Radii.card),
                const SizedBox(height: Insets.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BriefResult extends StatelessWidget {
  final EdgeFuelAiResponse response;
  final FighterBriefSections brief;
  final bool stale;
  final VoidCallback onRefresh;

  const _BriefResult({
    required this.response,
    required this.brief,
    required this.stale,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = AppAccessibility.textSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (response.requiresProfessionalReview)
          const Padding(
            padding: EdgeInsets.only(bottom: Insets.md),
            child: _InlineNote(
              icon: Icons.health_and_safety_outlined,
              text: 'Please speak with a qualified professional before '
                  'acting on this.',
              color: AppColors.warning,
            ),
          ),
        if (stale)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: _InlineNote(
              icon: Icons.update_rounded,
              text: 'You’ve logged since this brief was written.',
              color: AppAccessibility.accentText(context),
            ),
          ),
        // Each piece arrives in reading order: what the brief says overall,
        // then the one thing to do now, then the rest.
        PremiumReveal(
          child: Text(response.summary, style: AppType.headline()),
        ),
        const SizedBox(height: Insets.md),
        PremiumReveal(
          index: 1,
          child: _BriefSection(
            icon: Icons.flag_outlined,
            label: 'NEXT ACTION',
            value: brief.nextAction,
            lead: true,
          ),
        ),
        PremiumReveal(
          index: 2,
          child: _BriefSection(
            icon: Icons.restaurant_outlined,
            label: 'MEAL SUGGESTION',
            value: brief.mealSuggestion,
          ),
        ),
        PremiumReveal(
          index: 3,
          child: _BriefSection(
            icon: Icons.schedule_outlined,
            label: 'TRAINING TIMING',
            value: brief.trainingTiming,
          ),
        ),
        PremiumReveal(
          index: 4,
          child: _BriefSection(
            icon: Icons.calendar_month_outlined,
            label: 'WEEKLY ADJUSTMENT',
            value: brief.weeklyAdjustment,
          ),
        ),
        for (final warning in response.warnings)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text('• $warning', style: AppType.subhead(color: secondary)),
          ),
        const SizedBox(height: Insets.md),
        // A stale brief makes refreshing the obvious next step; a fresh one
        // keeps it available but quiet.
        if (stale)
          PrimaryButton(
            'Refresh brief',
            icon: Icons.refresh,
            expand: true,
            onPressed: onRefresh,
          )
        else
          GhostButton(
            'Refresh brief',
            icon: Icons.refresh,
            expand: true,
            onPressed: onRefresh,
          ),
      ],
    );
  }
}

class _BriefSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// The next action is the reason to open the brief at all, so it reads a
  /// step louder than the three sections that support it.
  final bool lead;

  const _BriefSection({
    required this.icon,
    required this.label,
    required this.value,
    this.lead = false,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: Insets.sm),
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: lead ? AppColors.surfaceElevated : AppColors.backgroundRaised,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color:
                lead ? AppColors.premiumDeep : AppAccessibility.border(context),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBadge(icon: icon, color: AppColors.premium),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppType.micro(
                      weight: FontWeight.w800,
                      color: AppAccessibility.textMuted(context),
                      spacing: .6,
                    ),
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    value,
                    style: lead ? AppType.headline() : AppType.callout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A state the brief can land in other than success. Always says what
/// happened and, where the user can do something about it, offers that one
/// thing — never a dead end.
class _BriefNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _BriefNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = AppAccessibility.textSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(icon: icon, color: secondary),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.headline()),
                    const SizedBox(height: Insets.xxs),
                    Text(message, style: AppType.subhead(color: secondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: Insets.md),
          GhostButton(
            actionLabel!,
            icon: Icons.refresh,
            expand: true,
            onPressed: onAction,
          ),
        ],
      ],
    );
  }
}

class _InlineNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InlineNote({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: IconSizes.inline, color: color),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            text,
            style: AppType.subhead(weight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: IconSizes.badge,
      height: IconSizes.badge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: IconSizes.inline, color: color),
    );
  }
}

class _BriefRemainingRow extends StatelessWidget {
  final FighterBriefPreview preview;

  const _BriefRemainingRow({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        _BriefMetric(
            label: 'Calories left', value: '${preview.caloriesRemaining} kcal'),
        _BriefMetric(
            label: 'Protein left', value: '${preview.proteinRemaining}g'),
        _BriefMetric(
            label: 'Carbs left', value: '${preview.carbohydratesRemaining}g'),
      ],
    );
  }
}

class _BriefMetric extends StatelessWidget {
  final String label;
  final String value;

  const _BriefMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundRaised,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label · $value',
        style: AppType.micro(
          weight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// "Ask EdgeFuel Coach" — the one AI surface in this release (master prompt
/// §13.1: explain the already-calculated plan in plain language). Never
/// calculates or overrides the target above; only explains it.
class _AiCoachSection extends StatelessWidget {
  final NutritionTarget target;
  final EdgeFuelController edgeFuel;
  const _AiCoachSection({required this.target, required this.edgeFuel});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<EdgeFuelAiController>();
    final isPro =
        context.watch<AuthController>().allows(Feature.edgeFuelAiCoach);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: AppColors.premium, size: IconSizes.inline),
              const SizedBox(width: Insets.sm),
              Text('EDGEFUEL COACH',
                  style: AppType.micro(
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                      spacing: 0.8)),
            ],
          ),
          const SizedBox(height: Insets.sm),
          if (isPro)
            _AiCoachBody(ai: ai, target: target, edgeFuel: edgeFuel)
          else
            const _AiCoachLocked(),
        ],
      ),
    );
  }
}

/// Shown to free users in place of the coach — never the explanation itself.
/// The Ask/Ask-again request must not fire for a free account (master prompt
/// §13.1 pairs with the server quota — this is the client half of "gate the
/// AI behind Pro").
class _AiCoachLocked extends StatelessWidget {
  const _AiCoachLocked();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get a plain-language explanation of your plan, and why it is set '
          'the way it is.',
          style: AppType.subhead(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Insets.md),
        GhostButton(
          'See Pro',
          icon: Icons.lock_outline,
          expand: true,
          onPressed: () => AppNavigation.push(
            context,
            AppRoutes.paywall,
            extra: Feature.edgeFuelAiCoach,
            fallbackBuilder: (_) =>
                const PaywallScreen(highlight: Feature.edgeFuelAiCoach),
          ),
        ),
      ],
    );
  }
}

class _AiCoachBody extends StatelessWidget {
  final EdgeFuelAiController ai;
  final NutritionTarget target;
  final EdgeFuelController edgeFuel;
  const _AiCoachBody({
    required this.ai,
    required this.target,
    required this.edgeFuel,
  });

  @override
  Widget build(BuildContext context) {
    if (ai.isExplaining) {
      return const _AiCoachSkeleton();
    }

    final result = ai.lastResult;
    if (result == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask for a plain-language explanation of your plan. This sends your '
            'target and food log to our server — never medical details beyond '
            'what you already entered in setup.',
            style: AppType.subhead(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Insets.md),
          GhostButton(
            'Ask EdgeFuel Coach',
            icon: Icons.chat_bubble_outline,
            expand: true,
            onPressed: () => ai.explainPlan(
              target: target,
              day: edgeFuel.day,
              preferences: edgeFuel.draft,
            ),
          ),
        ],
      );
    }

    switch (result.status) {
      case EdgeFuelAiStatus.quotaReached:
        return Text(
          "You've reached today's AI limit. Try again tomorrow.",
          style: AppType.subhead(color: AppColors.textSecondary),
        );
      case EdgeFuelAiStatus.entitlementRequired:
        return Text(
          'Pro access is still syncing. Refresh your account status and try again.',
          style: AppType.subhead(color: AppColors.textSecondary),
        );
      case EdgeFuelAiStatus.unavailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EdgeFuel Coach is unavailable right now. Your plan above is still '
              'accurate — this only affects the AI explanation.',
              style: AppType.subhead(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Insets.md),
            GhostButton(
              'Try again',
              icon: Icons.refresh,
              expand: true,
              onPressed: () => ai.explainPlan(
                target: target,
                day: edgeFuel.day,
                preferences: edgeFuel.draft,
              ),
            ),
          ],
        );
      case EdgeFuelAiStatus.success:
        final response = result.response!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (response.requiresProfessionalReview)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Text(
                  'Please speak with a qualified professional before acting on this.',
                  style: AppType.subhead(
                      weight: FontWeight.w700, color: AppColors.warning),
                ),
              ),
            PremiumReveal(
              child: Text(response.summary, style: AppType.callout()),
            ),
            for (final warning in response.warnings)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text('• $warning',
                    style: AppType.subhead(color: AppColors.textSecondary)),
              ),
            const SizedBox(height: Insets.md),
            GhostButton(
              'Ask again',
              icon: Icons.refresh,
              expand: true,
              onPressed: () => ai.explainPlan(
                target: target,
                day: edgeFuel.day,
                preferences: edgeFuel.draft,
              ),
            ),
          ],
        );
    }
  }
}

class _AiCoachSkeleton extends StatelessWidget {
  const _AiCoachSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox.line(),
          SizedBox(height: Insets.sm),
          FractionallySizedBox(widthFactor: .7, child: SkeletonBox.line()),
          SizedBox(height: Insets.sm),
          FractionallySizedBox(widthFactor: .85, child: SkeletonBox.line()),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final int? grams;
  final Color color;
  const _MacroChip(this.label, this.grams, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm, vertical: Insets.md),
        child: Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: Insets.xs),
            Text('${grams ?? 0} g', style: AppType.title2()),
            Text(label.toUpperCase(),
                style: AppType.micro(
                    weight: FontWeight.w700, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

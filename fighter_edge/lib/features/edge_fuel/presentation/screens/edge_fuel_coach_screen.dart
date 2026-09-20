import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../auth/verification_gate.dart';
import '../../../../billing/subscription.dart';
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
import '../../../../widgets/press_scale.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../widgets/skeleton.dart';
import '../../../../widgets/stat_card.dart';
import '../../../../observability/telemetry.dart';
import '../../ai/edge_fuel_ai_gateway.dart';
import '../../ai/edge_fuel_ai_models.dart';
import '../../data/food_catalog_repository.dart';
import '../../data/recipe_catalog_repository.dart';
import '../../domain/models/fuel_match.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/nutrition_day.dart';
import '../../domain/models/nutrition_target.dart';
import '../controllers/edge_fuel_coach_controller.dart';
import '../controllers/edge_fuel_controller.dart';
import '../controllers/fuel_match_controller.dart';
import '../controllers/recipe_library_controller.dart';
import 'recipe_detail_screen.dart';

/// The one AI surface (master prompt §13): a running conversation that can
/// open with the structured Fighter Brief and continue as free-text chat.
/// Replaces the old Plan-screen split between a "Generate full Fighter
/// Brief" button and a separate "Ask EdgeFuel Coach" card — two one-shot
/// requests to the same backend, neither of which let the athlete type a
/// question.
class EdgeFuelCoachScreen extends StatelessWidget {
  const EdgeFuelCoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) => EdgeFuelCoachController(
            gateway: ctx.read<EdgeFuelAiGateway>(),
            telemetry: Telemetry.fromContext(ctx),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => FuelMatchController(
            recipeCatalog: ctx.read<RecipeCatalogRepository>(),
            foodCatalog: ctx.read<FoodCatalogRepository>(),
          ),
        ),
      ],
      child: const ScreenScaffold(
        title: 'AI Fighter Brief',
        showBack: true,
        body: _CoachBody(),
      ),
    );
  }
}

class _CoachBody extends StatefulWidget {
  const _CoachBody();

  @override
  State<_CoachBody> createState() => _CoachBodyState();
}

class _CoachBodyState extends State<_CoachBody> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  static const _maxMessageChars = 600;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: MotionTokens.standard,
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(
    EdgeFuelCoachController coach,
    NutritionTarget target,
    EdgeFuelController edgeFuel,
  ) async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    _scrollToEnd();
    await coach.sendMessage(
      text,
      target: target,
      day: edgeFuel.day,
      preferences: edgeFuel.draft,
    );
    _scrollToEnd();
  }

  Future<void> _requestBrief(
    EdgeFuelCoachController coach,
    NutritionTarget target,
    EdgeFuelController edgeFuel,
  ) async {
    _scrollToEnd();
    await coach.requestBrief(
      target: target,
      day: edgeFuel.day,
      preferences: edgeFuel.draft,
    );
    _scrollToEnd();
    final latest = coach.entries.isEmpty ? null : coach.entries.last;
    if (latest is CoachBrief &&
        latest.result.status == EdgeFuelAiStatus.success) {
      await AppHaptics.success();
    }
  }

  Future<void> _buildFuelMatch(
    FuelMatchController fuelMatch,
    NutritionTarget target,
    EdgeFuelController edgeFuel,
  ) async {
    await fuelMatch.build(
      target: target,
      day: edgeFuel.day,
      preferences: edgeFuel.draft,
    );
    if (!mounted || fuelMatch.match?.isReady != true) return;
    await AppHaptics.success();
  }

  @override
  Widget build(BuildContext context) {
    final edgeFuel = context.watch<EdgeFuelController>();
    final target = edgeFuel.target;
    final auth = context.watch<AuthController>();

    if (target == null || !target.isSuccess) {
      return const _CoachNoPlan();
    }
    if (!auth.allows(Feature.edgeFuelAiCoach)) {
      return const _CoachLocked();
    }
    if (!auth.allowsVerified(VerifiedAction.aiCoach)) {
      return _CoachNeedsVerification(
        onVerify: () => AppNavigation.push(
          context,
          AppRoutes.verifyEmail,
          fallbackBuilder: (_) => const VerifyEmailScreen(),
        ),
      );
    }

    final coach = context.watch<EdgeFuelCoachController>();
    final fuelMatch = context.watch<FuelMatchController>();
    final matchIsStale = fuelMatch.isStaleFor(target, edgeFuel.day);
    void buildFuelMatch() => _buildFuelMatch(fuelMatch, target, edgeFuel);

    return Column(
      children: [
        Expanded(
          child: coach.entries.isEmpty
              ? _CoachIntro(
                  onGenerateBrief: () => _requestBrief(coach, target, edgeFuel),
                  fuelMatch: fuelMatch,
                  matchIsStale: matchIsStale,
                  onBuildFuelMatch: buildFuelMatch,
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                      Insets.lg, Insets.lg, Insets.lg, Insets.md),
                  itemCount: coach.entries.length + 1,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: Insets.md),
                    child: index == 0
                        ? _FuelMatchPanel(
                            controller: fuelMatch,
                            isStale: matchIsStale,
                            onBuild: buildFuelMatch,
                          )
                        : _EntryTile(
                            entry: coach.entries[index - 1],
                            currentDay: edgeFuel.day,
                            onRefreshBrief: () =>
                                _requestBrief(coach, target, edgeFuel),
                            onBuildFuelMatch: buildFuelMatch,
                          ),
                  ),
                ),
        ),
        _InputBar(
          controller: _input,
          sending: coach.isSending,
          maxChars: _maxMessageChars,
          onSend: () => _send(coach, target, edgeFuel),
          // The intro already has the primary brief action. After an athlete
          // starts chatting, the compact action in the input bar keeps the
          // brief available without showing the same CTA twice on first open.
          onGetBrief: coach.isSending || coach.entries.isEmpty || coach.hasBrief
              ? null
              : () => _requestBrief(coach, target, edgeFuel),
        ),
      ],
    );
  }
}

class _CoachNoPlan extends StatelessWidget {
  const _CoachNoPlan();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(Insets.lg),
      child: EmptyState(
        icon: Icons.auto_awesome,
        title: 'No plan yet',
        message: 'Finish EdgeFuel setup first — the coach reads your target '
            'and today\'s log.',
      ),
    );
  }
}

class _CoachLocked extends StatelessWidget {
  const _CoachLocked();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        Text(
          'Ask a real question about your plan and get today\'s Fighter '
          'Brief — a next action, a meal cue, training timing, and your '
          'weekly adjustment, grounded in your own numbers.',
          style:
              AppType.callout(color: AppAccessibility.textSecondary(context)),
        ),
        const SizedBox(height: Insets.lg),
        PrimaryButton(
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

class _CoachNeedsVerification extends StatelessWidget {
  final VoidCallback onVerify;
  const _CoachNeedsVerification({required this.onVerify});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        Text(
          'Confirm your email to talk to the coach.',
          style:
              AppType.callout(color: AppAccessibility.textSecondary(context)),
        ),
        const SizedBox(height: Insets.lg),
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

/// Shown before the first message: a way in without having to type, and a
/// hint that typing is also an option.
class _CoachIntro extends StatelessWidget {
  final VoidCallback onGenerateBrief;
  final FuelMatchController fuelMatch;
  final bool matchIsStale;
  final VoidCallback onBuildFuelMatch;

  const _CoachIntro({
    required this.onGenerateBrief,
    required this.fuelMatch,
    required this.matchIsStale,
    required this.onBuildFuelMatch,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        const Icon(Icons.auto_awesome,
            color: AppColors.premium, size: IconSizes.badge),
        const SizedBox(height: Insets.md),
        Text('Talk to your coach', style: AppType.title1()),
        const SizedBox(height: Insets.xs),
        Text(
          'Get today\'s Fighter Brief, or just ask something — "why is my '
          'carb target lower today?", "what should I eat before training?". '
          'Answers use only your plan and today\'s log.',
          style:
              AppType.callout(color: AppAccessibility.textSecondary(context)),
        ),
        const SizedBox(height: Insets.lg),
        PrimaryButton(
          'Get today\'s Fighter Brief',
          icon: Icons.auto_awesome,
          expand: true,
          onPressed: onGenerateBrief,
        ),
        const SizedBox(height: Insets.md),
        _FuelMatchPanel(
          controller: fuelMatch,
          isStale: matchIsStale,
          onBuild: onBuildFuelMatch,
        ),
      ],
    );
  }
}

/// The paid, deterministic answer to "what should I eat now?". It lives on
/// the coach surface because it is an immediate next action, but it never
/// spends AI quota or uses an LLM for nutrition facts.
class _FuelMatchPanel extends StatelessWidget {
  final FuelMatchController controller;
  final bool isStale;
  final VoidCallback onBuild;

  const _FuelMatchPanel({
    required this.controller,
    required this.isStale,
    required this.onBuild,
  });

  @override
  Widget build(BuildContext context) {
    final match = controller.match;
    if (controller.isLoading) {
      return const AppCard(
        accent: AppColors.premium,
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.premium),
            SizedBox(width: Insets.sm),
            Expanded(child: SkeletonBox.line(width: 180)),
          ],
        ),
      );
    }

    if (match == null || isStale) {
      return AppCard(
        accent: AppColors.premium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FUEL MATCH',
              style: AppType.micro(
                color: AppColors.premium,
                weight: FontWeight.w800,
                spacing: .8,
              ),
            ),
            const SizedBox(height: Insets.xxs),
            Text(
              isStale
                  ? 'Your log changed. Build a fresh match from today\'s remaining target.'
                  : 'Get a real recipe and portion matched to today\'s remaining fuel.',
              style: AppType.callout(),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'Calculated from our curated food catalog — never invented by AI.',
              style: AppType.subhead(
                color: AppAccessibility.textSecondary(context),
              ),
            ),
            if (controller.error != null) ...[
              const SizedBox(height: Insets.sm),
              Text(
                controller.error!,
                style: AppType.subhead(
                  color: AppColors.warning,
                  weight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: Insets.md),
            PrimaryButton(
              isStale ? 'Refresh my Fuel Match' : 'Build my Fuel Match',
              icon: Icons.bolt_rounded,
              expand: true,
              onPressed: onBuild,
            ),
          ],
        ),
      );
    }

    return AppCard(
      accent: AppColors.premium,
      child: switch (match.status) {
        FuelMatchStatus.ready => _FuelMatchReady(
            match: match,
            foodsById: controller.foodsById,
          ),
        FuelMatchStatus.noMealNeeded => _FuelMatchNotice(
            icon: Icons.verified_outlined,
            title: 'You\'re close to your calorie target',
            message:
                'Only ${match.caloriesRemaining} kcal remain. A full meal would be a poor fit right now.',
            actionLabel: 'Refresh my match',
            onAction: onBuild,
          ),
        FuelMatchStatus.noMatch => _FuelMatchNotice(
            icon: Icons.tune_rounded,
            title: 'No catalog match yet',
            message:
                'Your current diet, allergen, budget, or time filters left no verified recipe to suggest.',
            actionLabel: 'Try again',
            onAction: onBuild,
          ),
        FuelMatchStatus.needsMoreData => const _FuelMatchNotice(
            icon: Icons.info_outline,
            title: 'Finish your target first',
            message:
                'Fuel Match needs a complete daily calories and macro target.',
            actionLabel: null,
            onAction: null,
          ),
      },
    );
  }
}

class _FuelMatchReady extends StatelessWidget {
  final FuelMatch match;
  final Map<String, FoodItem> foodsById;

  const _FuelMatchReady({
    required this.match,
    required this.foodsById,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'YOUR FUEL MATCH',
          style: AppType.micro(
            color: AppColors.premium,
            weight: FontWeight.w800,
            spacing: .8,
          ),
        ),
        const SizedBox(height: Insets.xxs),
        Text(
          '${match.caloriesRemaining} kcal left · ${match.proteinRemaining}g protein to close',
          style: AppType.callout(weight: FontWeight.w800),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          'Each portion and macro below is calculated from the ingredient catalog.',
          style:
              AppType.subhead(color: AppAccessibility.textSecondary(context)),
        ),
        if (match.unmatchedAllergenTerms.isNotEmpty) ...[
          const SizedBox(height: Insets.md),
          _InlineNote(
            icon: Icons.warning_amber_rounded,
            text:
                'We could not filter ${match.unmatchedAllergenTerms.join(', ')}. Check ingredients before eating.',
            color: AppColors.warning,
          ),
        ],
        const SizedBox(height: Insets.md),
        for (final option in match.options) ...[
          _FuelMatchOptionCard(option: option, foodsById: foodsById),
          if (option != match.options.last) const SizedBox(height: Insets.sm),
        ],
      ],
    );
  }
}

class _FuelMatchOptionCard extends StatelessWidget {
  final FuelMatchOption option;
  final Map<String, FoodItem> foodsById;

  const _FuelMatchOptionCard({
    required this.option,
    required this.foodsById,
  });

  @override
  Widget build(BuildContext context) {
    final nutrients = option.nutrients;
    final portion = option.servings == 1
        ? '1 serving'
        : '${option.servings.toStringAsFixed(option.servings % 1 == 0 ? 0 : 1)} servings';
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppAccessibility.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(option.recipe.title, style: AppType.headline()),
          const SizedBox(height: Insets.xxs),
          Text(
            '$portion · ${option.recipe.totalMinutes} min',
            style:
                AppType.subhead(color: AppAccessibility.textSecondary(context)),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            '${nutrients.kcalRounded} kcal · ${nutrients.proteinRounded}g protein · ${nutrients.carbsRounded}g carbs · ${nutrients.fatRounded}g fat',
            style: AppType.callout(weight: FontWeight.w800),
          ),
          const SizedBox(height: Insets.md),
          GhostButton(
            'Open recipe',
            icon: Icons.menu_book_outlined,
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => RecipeDetailScreen(
                  listing: RecipeListing(
                    recipe: option.recipe,
                    perServing: option.nutrients.scaled(1 / option.servings),
                    allergens: option.allergens,
                    dietTags: option.dietTags,
                  ),
                  foodsById: foodsById,
                  initialServings: option.servings,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelMatchNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FuelMatchNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _InlineNote(
            icon: icon,
            text: title,
            color: AppAccessibility.textSecondary(context),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            message,
            style:
                AppType.subhead(color: AppAccessibility.textSecondary(context)),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: Insets.md),
            GhostButton(
              actionLabel!,
              icon: Icons.refresh,
              onPressed: onAction,
            ),
          ],
        ],
      );
}

class _EntryTile extends StatelessWidget {
  final EdgeFuelCoachEntry entry;
  final NutritionDay? currentDay;
  final VoidCallback onRefreshBrief;
  final VoidCallback onBuildFuelMatch;

  const _EntryTile({
    required this.entry,
    required this.currentDay,
    required this.onRefreshBrief,
    required this.onBuildFuelMatch,
  });

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      CoachUserMessage(:final text) => _UserBubble(text: text),
      CoachPending(:final isBrief) =>
        isBrief ? const _BriefBuilding() : const _TypingIndicator(),
      CoachReply(:final result) => _ReplyCard(
          result: result,
          onBuildFuelMatch: onBuildFuelMatch,
        ),
      final CoachBrief brief => _BriefCard(
          entry: brief,
          stale: brief.isStaleFor(currentDay),
          onRefresh: onRefreshBrief,
        ),
    };
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.md, vertical: Insets.sm),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Text(
            text,
            style: AppType.body(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        liveRegion: true,
        label: 'EdgeFuel Coach is answering',
        child: const Skeleton(
          child: SkeletonBox.line(width: 160),
        ),
      ),
    );
  }
}

/// The wait for a brief, shaped like what is coming: a summary and four
/// sections. The line above names what the server is doing, in order,
/// holding on the last step rather than looping — a loop would claim
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

/// A plain chat reply, or one of the non-success states the server can hand
/// back for a chat turn.
class _ReplyCard extends StatelessWidget {
  final EdgeFuelAiResult result;
  final VoidCallback onBuildFuelMatch;

  const _ReplyCard({
    required this.result,
    required this.onBuildFuelMatch,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = AppAccessibility.textSecondary(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: AppCard(
          padding: const EdgeInsets.all(Insets.md),
          child: switch (result.status) {
            EdgeFuelAiStatus.quotaReached => Text(
                'You\'ve reached today\'s AI limit. Try again tomorrow.',
                style: AppType.callout(color: secondary),
              ),
            EdgeFuelAiStatus.entitlementRequired => Text(
                'Pro access is still syncing. Refresh your account status '
                'and try again.',
                style: AppType.callout(color: secondary),
              ),
            EdgeFuelAiStatus.unavailable => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'The coach couldn\'t answer that just now. Your plan is '
                    'still accurate — try again in a moment.',
                    style: AppType.callout(color: secondary),
                  ),
                  const SizedBox(height: Insets.sm),
                  GhostButton(
                    'Build a Fuel Match instead',
                    icon: Icons.bolt_rounded,
                    onPressed: onBuildFuelMatch,
                  ),
                ],
              ),
            EdgeFuelAiStatus.success => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (result.response!.requiresProfessionalReview)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.sm),
                      child: Text(
                        'Please speak with a qualified professional before '
                        'acting on this.',
                        style: AppType.subhead(
                            weight: FontWeight.w700, color: AppColors.warning),
                      ),
                    ),
                  PremiumReveal(
                    child: Text(result.response!.summary,
                        style: AppType.callout()),
                  ),
                  for (final warning in result.response!.warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: Insets.xs),
                      child: Text('• $warning',
                          style: AppType.subhead(color: secondary)),
                    ),
                ],
              ),
          },
        ),
      ),
    );
  }
}

class _BriefCard extends StatelessWidget {
  final CoachBrief entry;
  final bool stale;
  final VoidCallback onRefresh;

  const _BriefCard({
    required this.entry,
    required this.stale,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = AppAccessibility.textSecondary(context);
    final result = entry.result;
    return Align(
      alignment: Alignment.centerLeft,
      child: AppCard(
        accent: AppColors.premium,
        child: switch (result.status) {
          EdgeFuelAiStatus.quotaReached => const _BriefNotice(
              icon: Icons.hourglass_bottom_rounded,
              title: 'Today’s briefs are used up',
              message: 'The full brief resets tomorrow.',
            ),
          EdgeFuelAiStatus.entitlementRequired => _BriefNotice(
              icon: Icons.sync_rounded,
              title: 'Pro is still syncing',
              message: 'Your purchase has not reached our server yet.',
              actionLabel: 'Refresh my access',
              onAction: onRefresh,
            ),
          EdgeFuelAiStatus.success when result.response?.brief != null =>
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (result.response!.requiresProfessionalReview)
                  const Padding(
                    padding: EdgeInsets.only(bottom: Insets.md),
                    child: _InlineNote(
                      icon: Icons.health_and_safety_outlined,
                      text: 'Please speak with a qualified professional '
                          'before acting on this.',
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
                PremiumReveal(
                  child:
                      Text(result.response!.summary, style: AppType.headline()),
                ),
                const SizedBox(height: Insets.md),
                PremiumReveal(
                  index: 1,
                  child: _BriefSection(
                    icon: Icons.flag_outlined,
                    label: 'NEXT ACTION',
                    value: result.response!.brief!.nextAction,
                    lead: true,
                  ),
                ),
                PremiumReveal(
                  index: 2,
                  child: _BriefSection(
                    icon: Icons.restaurant_outlined,
                    label: 'MEAL SUGGESTION',
                    value: result.response!.brief!.mealSuggestion,
                  ),
                ),
                PremiumReveal(
                  index: 3,
                  child: _BriefSection(
                    icon: Icons.schedule_outlined,
                    label: 'TRAINING TIMING',
                    value: result.response!.brief!.trainingTiming,
                  ),
                ),
                PremiumReveal(
                  index: 4,
                  child: _BriefSection(
                    icon: Icons.calendar_month_outlined,
                    label: 'WEEKLY ADJUSTMENT',
                    value: result.response!.brief!.weeklyAdjustment,
                  ),
                ),
                for (final warning in result.response!.warnings)
                  Padding(
                    padding: const EdgeInsets.only(top: Insets.xs),
                    child: Text('• $warning',
                        style: AppType.subhead(color: secondary)),
                  ),
                if (stale) ...[
                  const SizedBox(height: Insets.md),
                  PrimaryButton(
                    'Refresh brief',
                    icon: Icons.refresh,
                    expand: true,
                    onPressed: onRefresh,
                  ),
                ],
              ],
            ),
          // Unavailable, or a success without brief sections (an older server).
          _ => _BriefNotice(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn’t build your brief',
              message: 'Try again in a moment.',
              actionLabel: 'Try again',
              onAction: onRefresh,
            ),
        },
      ),
    );
  }
}

class _BriefSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
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
      mainAxisSize: MainAxisSize.min,
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final int maxChars;
  final VoidCallback onSend;
  final VoidCallback? onGetBrief;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.maxChars,
    required this.onSend,
    required this.onGetBrief,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.sm, Insets.lg, Insets.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onGetBrief != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GhostButton(
                    'Get today\'s Fighter Brief',
                    icon: Icons.auto_awesome,
                    onPressed: onGetBrief,
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: TextField(
                      controller: controller,
                      enabled: !sending,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: maxChars,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      style:
                          AppAccessibility.adjustStyle(context, AppType.body()),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        hintText: 'Ask your coach anything',
                        hintStyle: AppType.body(
                            color: AppAccessibility.textMuted(context)),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: Insets.md, vertical: Insets.sm),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.button),
                          borderSide: BorderSide(
                              color: AppAccessibility.border(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.button),
                          borderSide: BorderSide(
                              color: AppAccessibility.border(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.button),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Semantics(
                  button: true,
                  label: 'Send',
                  child: PressScale(
                    onTap: sending ? null : onSend,
                    haptic: AppHaptics.tap,
                    child: Container(
                      width: AppAccessibility.minTouchTarget,
                      height: AppAccessibility.minTouchTarget,
                      decoration: BoxDecoration(
                        color: sending
                            ? AppColors.surfaceElevated
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

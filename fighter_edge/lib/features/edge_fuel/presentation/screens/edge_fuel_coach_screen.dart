import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../auth/verification_gate.dart';
import '../../../../billing/subscription.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../privacy/ai_coach_consent.dart';
import '../../../../privacy/data_consent.dart';
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
import '../../../../widgets/grouped_list.dart';
import '../../../../widgets/premium_effects.dart';
import '../../../../widgets/press_scale.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../widgets/skeleton.dart';
import '../../../../widgets/stat_card.dart';
import '../../../../observability/telemetry.dart';
import '../../../../state/app_state.dart';
import '../../../daily_snapshot/domain/daily_snapshot.dart';
import '../../../daily_snapshot/presentation/daily_snapshot_builder.dart';
import '../../../fight_camp/presentation/fight_camp_controller.dart';
import '../../ai/edge_fuel_ai_gateway.dart';
import '../../ai/edge_fuel_ai_models.dart';
import '../../data/food_catalog_repository.dart';
import '../../data/recipe_catalog_repository.dart';
import '../../domain/models/fuel_match.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/nutrition_target.dart';
import '../controllers/edge_fuel_coach_controller.dart';
import '../controllers/edge_fuel_controller.dart';
import '../controllers/fuel_match_controller.dart';
import '../controllers/recipe_library_controller.dart';
import 'edge_fuel_setup_screen.dart';
import 'recipe_detail_screen.dart';

/// The EdgeFuel Coach (master prompt §13): a running conversation about the
/// athlete's plan, day and camp, next to the catalog-backed Fuel Match. The
/// daily brief lives on Home (the Corner Brief); this is where to ask about
/// it.
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
        title: 'EdgeFuel Coach',
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
        curve: MotionTokens.scroll,
      );
    });
  }

  Future<void> _send(
    EdgeFuelCoachController coach,
    NutritionTarget target,
    EdgeFuelController edgeFuel,
    DailySnapshot? today,
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
      today: today,
    );
    _scrollToEnd();
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
    if (!auth.hasConsent(DataConsentPurpose.aiCoach)) {
      return ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: const [AiCoachConsentPanel()],
      );
    }

    final coach = context.watch<EdgeFuelCoachController>();
    final fuelMatch = context.watch<FuelMatchController>();
    final matchIsStale = fuelMatch.isStaleFor(target, edgeFuel.day);
    void buildFuelMatch() => _buildFuelMatch(fuelMatch, target, edgeFuel);

    // Built fresh on every request, never cached, so the coach never answers
    // from a stale training week, weight trend or fight-camp day.
    final appState = context.watch<AppState>();
    final fightCamp = context.watch<FightCampController>();
    DailySnapshot today() => buildDailySnapshot(
          appState,
          fightCamp,
          ageYears: edgeFuel.draft?.ageYears,
        );

    return Column(
      children: [
        Expanded(
          child: coach.entries.isEmpty
              ? _CoachIntro(
                  hasFight: fightCamp.camp != null,
                  onAsk: (question) {
                    _input.text = question;
                    _send(coach, target, edgeFuel, today());
                  },
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
                            onBuildFuelMatch: buildFuelMatch,
                          ),
                  ),
                ),
        ),
        _InputBar(
          controller: _input,
          sending: coach.isSending,
          maxChars: _maxMessageChars,
          onSend: () => _send(coach, target, edgeFuel, today()),
        ),
      ],
    );
  }
}

class _CoachNoPlan extends StatelessWidget {
  const _CoachNoPlan();

  @override
  Widget build(BuildContext context) {
    // An empty state teaches the next action: the coach needs a plan, so the
    // way to one is right here rather than back through Fuel.
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        const EmptyState(
          icon: Icons.auto_awesome,
          title: 'No plan yet',
          message: 'Finish EdgeFuel setup first — the coach reads your target '
              'and today\'s log.',
        ),
        const SizedBox(height: Insets.lg),
        PrimaryButton(
          'Start setup',
          icon: Icons.arrow_forward,
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

class _CoachLocked extends StatelessWidget {
  const _CoachLocked();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        Text(
          'Ask a real question about your plan, your training or your fight '
          'week, and get your daily Corner Brief on Home — grounded in your '
          'own numbers.',
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
            extra: const PaywallRouteArgs(
              highlight: Feature.edgeFuelAiCoach,
              trigger: PaywallTrigger.coach,
            ),
            fallbackBuilder: (_) => const PaywallScreen(
              highlight: Feature.edgeFuelAiCoach,
              trigger: PaywallTrigger.coach,
            ),
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

/// Shown before the first message: what to ask, and Fuel Match as a way in
/// without having to type.
class _CoachIntro extends StatelessWidget {
  final FuelMatchController fuelMatch;
  final bool matchIsStale;
  final VoidCallback onBuildFuelMatch;

  /// Sends a suggested question as if the athlete had typed it.
  final ValueChanged<String> onAsk;

  /// Whether a fight is set, so the weight question makes sense.
  final bool hasFight;

  static const _questions = [
    'What should I eat before training?',
    'What should my next meal look like?',
    'How is my training week going?',
  ];
  static const _fightQuestion = 'Am I on track to make weight?';

  const _CoachIntro({
    required this.onAsk,
    required this.hasFight,
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
          'Tap a question or type your own. Answers use only your plan, '
          "today's log, your training, your weight trend and your fight "
          'camp.',
          style:
              AppType.callout(color: AppAccessibility.textSecondary(context)),
        ),
        const SizedBox(height: Insets.lg),
        GroupedList(children: [
          for (final question in [
            if (hasFight) _fightQuestion,
            ..._questions,
          ])
            GroupedRow(title: question, onTap: () => onAsk(question)),
        ]),
        const SizedBox(height: Insets.lg),
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
              'Fuel Match',
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
          'Your Fuel Match',
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
  final VoidCallback onBuildFuelMatch;

  const _EntryTile({
    required this.entry,
    required this.onBuildFuelMatch,
  });

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      CoachUserMessage(:final text) => _UserBubble(text: text),
      CoachPending() => const _TypingIndicator(),
      CoachReply(:final result) => _ReplyCard(
          result: result,
          onBuildFuelMatch: onBuildFuelMatch,
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
            style: AppType.body(color: AppColors.onPrimary),
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
            EdgeFuelAiStatus.consentRequired => Text(
                L.of(context).aiConsentRequiredNotice,
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final int maxChars;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.maxChars,
    required this.onSend,
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
                          color: AppColors.onPrimary),
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

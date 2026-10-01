import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_icons.dart';

import '../../../auth/verification_gate.dart';
import '../../../billing/subscription.dart';
import '../../../controllers/auth_controller.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../observability/telemetry.dart';
import '../../../privacy/ai_coach_consent.dart';
import '../../../privacy/data_consent.dart';
import '../../../routing/app_navigation.dart';
import '../../../routing/app_router.dart';
import '../../../screens/auth/verify_email_screen.dart';
import '../../../screens/paywall_screen.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_accessibility.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_haptics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/premium_effects.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/stat_card.dart';
import '../../daily_snapshot/domain/daily_snapshot.dart';
import '../../daily_snapshot/presentation/daily_snapshot_builder.dart';
import '../../edge_fuel/ai/edge_fuel_ai_models.dart';
import '../../edge_fuel/domain/models/nutrition_day.dart';
import '../../edge_fuel/domain/models/nutrition_target.dart';
import '../../edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../../edge_fuel/presentation/screens/edge_fuel_coach_screen.dart';
import '../../edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';
import '../../fight_camp/presentation/fight_camp_controller.dart';
import '../domain/corner_brief.dart';
import 'corner_brief_controller.dart';

/// The daily Corner Brief on Home (product plan, step 3). Free: the one line
/// the app calculates, and, if they choose, one short video a day for the
/// full brief. Pro: three lines the coach writes from today's training,
/// food, weight and camp, rewritten after each new log, and no ads.
class CornerBriefCard extends StatefulWidget {
  const CornerBriefCard({super.key});

  @override
  State<CornerBriefCard> createState() => _CornerBriefCardState();
}

class _CornerBriefCardState extends State<CornerBriefCard> {
  /// The basis a rewrite was last scheduled for, so rebuilds while it is on
  /// its way never schedule a second one.
  String? _rewriteScheduledFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isPro =
          context.read<AuthController>().allows(Feature.edgeFuelAiCoach);
      Telemetry.fromContext(context).track(
        TelemetryEvent.cornerBriefPreviewViewed,
        parameters: {'access': isPro ? 'pro' : 'free'},
      );
    });
  }

  void _openPaywall() {
    Telemetry.fromContext(context).track(
      TelemetryEvent.premiumCtaTapped,
      parameters: {'surface': 'corner_brief'},
    );
    AppNavigation.push(
      context,
      AppRoutes.paywall,
      extra: const PaywallRouteArgs(
        highlight: Feature.edgeFuelAiCoach,
        trigger: PaywallTrigger.cornerBrief,
      ),
      fallbackBuilder: (_) => const PaywallScreen(
        highlight: Feature.edgeFuelAiCoach,
        trigger: PaywallTrigger.cornerBrief,
      ),
    );
  }

  /// Free accounts only, adults only, and only when the athlete taps: one
  /// video for today's full brief.
  Future<void> _watchForBrief({
    required NutritionTarget target,
    required DailySnapshot today,
    required NutritionDay? day,
  }) async {
    final l = L.of(context);
    final auth = context.read<AuthController>();
    final corner = context.read<CornerBriefController>();
    final preferences = context.read<EdgeFuelController>().draft;
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Asked before the video, so nobody watches one for a brief that can't
    // be written.
    if (!auth.hasConsent(DataConsentPurpose.aiCoach)) {
      await showAiCoachConsentSheet(context);
      if (!mounted || !auth.hasConsent(DataConsentPurpose.aiCoach)) return;
    }
    final outcome = await corner.watchForBrief(
      target: target,
      today: today,
      day: day,
      preferences: preferences,
    );
    if (!mounted) return;
    final message = switch (outcome) {
      RewardedBriefOutcome.written => null,
      RewardedBriefOutcome.usedToday => l.cornerBriefRewardUsed,
      RewardedBriefOutcome.closedEarly => l.cornerBriefVideoClosed,
      RewardedBriefOutcome.noVideo => l.cornerBriefNoVideo,
      RewardedBriefOutcome.failed => l.cornerBriefRewardFailed,
      RewardedBriefOutcome.consentRequired => null,
    };
    if (outcome == RewardedBriefOutcome.written) {
      await AppHaptics.success();
    } else if (outcome == RewardedBriefOutcome.consentRequired) {
      await showAiCoachConsentSheet(context);
    } else if (message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _getBrief({
    required NutritionTarget target,
    required DailySnapshot today,
    required NutritionDay? day,
  }) async {
    final auth = context.read<AuthController>();
    final corner = context.read<CornerBriefController>();
    final preferences = context.read<EdgeFuelController>().draft;
    if (!auth.hasConsent(DataConsentPurpose.aiCoach)) {
      await showAiCoachConsentSheet(context);
      if (!mounted || !auth.hasConsent(DataConsentPurpose.aiCoach)) return;
    }
    await corner.request(
      target: target,
      today: today,
      day: day,
      preferences: preferences,
    );
    if (!mounted) return;
    if (corner.lastStatusFor(today.date) == EdgeFuelAiStatus.success) {
      await AppHaptics.success();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final auth = context.watch<AuthController>();
    final state = context.watch<AppState>();
    final fightCamp = context.watch<FightCampController>();
    final fuel = context.watch<EdgeFuelController>();
    final corner = context.watch<CornerBriefController>();

    final today = buildDailySnapshot(state, fightCamp, fuelDraft: fuel.draft);
    // Fuel can be showing another day; the brief is only ever about today.
    final day = fuel.isToday ? fuel.day : null;
    final freeLine =
        CornerBriefCalculator.line(today: today, target: fuel.target, day: day);
    final isPro = auth.allows(Feature.edgeFuelAiCoach);

    final List<Widget> body;
    if (!isPro) {
      body = _freeBody(context, l, auth, corner, fuel, today, day, freeLine);
    } else if (fuel.target case final target? when target.isSuccess) {
      body = _proBody(
          context, l, auth, corner, target, today, day, freeLine, fuel.isToday);
    } else {
      body = [
        _FreeLine(line: freeLine),
        const SizedBox(height: Insets.md),
        GhostButton(l.cornerBriefSetUpAction,
            icon: AppIcons.arrowRight,
            expand: true,
            onPressed: () => AppNavigation.push(context, AppRoutes.fuelSetup,
                fallbackBuilder: (_) => const EdgeFuelSetupScreen())),
      ];
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(AppIcons.clipboardText,
                color: AppColors.premium, size: IconSizes.inline),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Semantics(
                container: true,
                header: true,
                child: Text(l.cornerBriefTitle,
                    style: AppType.micro(
                        weight: FontWeight.w800,
                        color: AppAccessibility.textMuted(context))),
              ),
            ),
          ]),
          const SizedBox(height: Insets.sm),
          ...body,
        ],
      ),
    );
  }

  List<Widget> _freeBody(
    BuildContext context,
    L l,
    AuthController auth,
    CornerBriefController corner,
    EdgeFuelController fuel,
    DailySnapshot today,
    NutritionDay? day,
    CornerLine freeLine,
  ) {
    final unlock = GhostButton(l.cornerBriefUnlock,
        icon: AppIcons.lockSimpleOpen, expand: true, onPressed: _openPaywall);

    final written = corner.briefFor(today.date);
    if (written != null) {
      return [
        ..._lines(written),
        const SizedBox(height: Insets.md),
        _Hint(l.cornerBriefRewardedNote),
        const SizedBox(height: Insets.md),
        unlock,
      ];
    }
    if (corner.isWatching || corner.isLoading) return [const _Writing()];

    final target = fuel.target;
    final age = fuel.draft?.ageYears;
    final canWatch = corner.rewardedAdsAvailable &&
        fuel.isToday &&
        target != null &&
        target.isSuccess &&
        // No ads for minors, and none when the age is unknown.
        age != null &&
        age >= 18 &&
        auth.allowsVerified(VerifiedAction.aiCoach) &&
        !corner.rewardUsedToday(today.date);
    return [
      _FreeLine(line: freeLine),
      const SizedBox(height: Insets.xs),
      _Hint(l.cornerBriefFreeHint),
      const SizedBox(height: Insets.md),
      if (canWatch) ...[
        GhostButton(l.cornerBriefWatchVideo,
            icon: AppIcons.monitorPlay,
            expand: true,
            onPressed: () =>
                _watchForBrief(target: target, today: today, day: day)),
        const SizedBox(height: Insets.sm),
      ],
      unlock,
    ];
  }

  List<Widget> _lines(WrittenCornerBrief written) => [
        if (written.requiresProfessionalReview) ...[
          _Note(
            icon: AppIcons.firstAid,
            text: L.of(context).cornerBriefProfessional,
            color: AppColors.warning,
          ),
          const SizedBox(height: Insets.md),
        ],
        for (final (index, line) in written.lines.indexed) ...[
          if (index > 0) const SizedBox(height: Insets.md),
          PremiumReveal(
            key: ValueKey((written, index)),
            index: index,
            child: _BriefLine(line: line),
          ),
        ],
      ];

  List<Widget> _proBody(
    BuildContext context,
    L l,
    AuthController auth,
    CornerBriefController corner,
    NutritionTarget target,
    DailySnapshot today,
    NutritionDay? day,
    CornerLine freeLine,
    bool fuelIsToday,
  ) {
    if (!auth.allowsVerified(VerifiedAction.aiCoach)) {
      return [
        _FreeLine(line: freeLine),
        const SizedBox(height: Insets.xs),
        _Hint(l.cornerBriefVerify),
        const SizedBox(height: Insets.md),
        GhostButton(l.cornerBriefVerifyAction,
            icon: AppIcons.envelopeSimple,
            expand: true,
            onPressed: () => AppNavigation.push(context, AppRoutes.verifyEmail,
                fallbackBuilder: (_) => const VerifyEmailScreen())),
      ];
    }

    void getBrief() => _getBrief(target: target, today: today, day: day);
    final basis = cornerBriefBasis(today, day);
    final written = corner.briefFor(today.date);
    final status = corner.lastStatusFor(today.date);

    // Rewritten after a new log, once the first brief of the day exists.
    if (fuelIsToday &&
        auth.hasConsent(DataConsentPurpose.aiCoach) &&
        corner.shouldRefresh(today: today.date, basis: basis) &&
        _rewriteScheduledFor != basis) {
      _rewriteScheduledFor = basis;
      final preferences = context.read<EdgeFuelController>().draft;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        corner.request(
          target: target,
          today: today,
          day: day,
          preferences: preferences,
          automatic: true,
        );
      });
    }

    if (written == null) {
      if (corner.isLoading) return [const _Writing()];
      return [
        _FreeLine(line: freeLine),
        const SizedBox(height: Insets.xs),
        switch (status) {
          EdgeFuelAiStatus.quotaReached =>
            _Note(icon: AppIcons.hourglassMedium, text: l.cornerBriefQuota),
          EdgeFuelAiStatus.unavailable =>
            _Note(icon: AppIcons.cloudSlash, text: l.cornerBriefUnavailable),
          EdgeFuelAiStatus.entitlementRequired =>
            _Note(icon: AppIcons.arrowsClockwise, text: l.cornerBriefSyncing),
          _ => _Hint(l.cornerBriefProHint),
        },
        if (status != EdgeFuelAiStatus.quotaReached) ...[
          const SizedBox(height: Insets.md),
          switch (status) {
            EdgeFuelAiStatus.unavailable ||
            EdgeFuelAiStatus.entitlementRequired =>
              GhostButton(l.cornerBriefTryAgain,
                  icon: AppIcons.arrowClockwise,
                  expand: true,
                  onPressed: getBrief),
            _ => GhostButton(l.cornerBriefGet,
                icon: AppIcons.clipboardText,
                expand: true,
                onPressed: getBrief),
          },
        ],
      ];
    }

    final stale = written.basis != basis;
    return [
      ..._lines(written),
      if (corner.isLoading ||
          (stale && status == EdgeFuelAiStatus.success)) ...[
        const SizedBox(height: Insets.md),
        Semantics(
          liveRegion: true,
          child: _Note(
              icon: AppIcons.arrowsClockwise, text: l.cornerBriefUpdating),
        ),
      ] else if (stale && status == EdgeFuelAiStatus.quotaReached) ...[
        const SizedBox(height: Insets.md),
        _Note(icon: AppIcons.hourglassMedium, text: l.cornerBriefQuotaStale),
      ] else if (stale) ...[
        const SizedBox(height: Insets.md),
        _Note(icon: AppIcons.cloudSlash, text: l.cornerBriefUnavailable),
        const SizedBox(height: Insets.sm),
        GhostButton(l.cornerBriefTryAgain,
            icon: AppIcons.arrowClockwise, expand: true, onPressed: getBrief),
      ],
      const SizedBox(height: Insets.md),
      GhostButton(l.cornerBriefAskCoach,
          icon: AppIcons.chatTeardropText,
          expand: true,
          onPressed: () => AppNavigation.push(context, AppRoutes.fuelCoach,
              fallbackBuilder: (_) => const EdgeFuelCoachScreen())),
    ];
  }
}

/// The calculated line, in words.
String cornerCueText(L l, CornerLine line) => switch (line.cue) {
      CornerCue.seeProfessional => l.cornerCueSeeProfessional,
      CornerCue.setUpFuel => l.cornerCueSetUpFuel,
      CornerCue.firstMeal => l.cornerCueFirstMeal,
      CornerCue.protein => l.cornerCueProtein(line.amount ?? 0),
      CornerCue.carbsBeforeTraining =>
        l.cornerCueCarbsBeforeTraining(line.amount ?? 0),
      CornerCue.carbs => l.cornerCueCarbs(line.amount ?? 0),
      CornerCue.calories => l.cornerCueCalories(line.amount ?? 0),
      CornerCue.onTrack => l.cornerCueOnTrack,
    };

class _FreeLine extends StatelessWidget {
  final CornerLine line;
  const _FreeLine({required this.line});

  @override
  Widget build(BuildContext context) =>
      Text(cornerCueText(L.of(context), line), style: AppType.headline());
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: AppType.subhead(color: AppAccessibility.textSecondary(context)));
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _Note({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppAccessibility.textSecondary(context);
    return MergeSemantics(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: IconSizes.inline, color: tone),
        const SizedBox(width: Insets.sm),
        Expanded(
            child: Text(text,
                style: AppType.subhead(weight: FontWeight.w600, color: tone))),
      ]),
    );
  }
}

class _BriefLine extends StatelessWidget {
  final CornerBriefLine line;
  const _BriefLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final (icon, label) = switch (line.topic) {
      CornerTopic.training => (AppIcons.boxingGlove, l.cornerTopicTraining),
      CornerTopic.fuel => (AppIcons.forkKnife, l.cornerTopicFuel),
      CornerTopic.weight => (AppIcons.scales, l.cornerTopicWeight),
      CornerTopic.camp => (AppIcons.flag, l.cornerTopicCamp),
      CornerTopic.recovery => (AppIcons.moon, l.cornerTopicRecovery),
    };
    return MergeSemantics(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: IconSizes.inline, color: AppColors.premium),
        const SizedBox(width: Insets.sm),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: AppType.micro(
                    weight: FontWeight.w800,
                    color: AppAccessibility.textMuted(context))),
            const SizedBox(height: Insets.xxs),
            Text(line.text, style: AppType.callout()),
          ]),
        ),
      ]),
    );
  }
}

/// The wait for the first brief of the day, shaped like it: three lines.
class _Writing extends StatelessWidget {
  const _Writing();

  @override
  Widget build(BuildContext context) {
    final label = L.of(context).cornerBriefWriting;
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label,
            style: AppType.subhead(
                weight: FontWeight.w600,
                color: AppAccessibility.textSecondary(context))),
        const SizedBox(height: Insets.md),
        Skeleton(
          child: Column(children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: Insets.md),
              const Row(children: [
                SkeletonBox(
                    width: IconSizes.inline,
                    height: IconSizes.inline,
                    radius: Radii.chip),
                SizedBox(width: Insets.sm),
                Expanded(child: SkeletonBox.line()),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

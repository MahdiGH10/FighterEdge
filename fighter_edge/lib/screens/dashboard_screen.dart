import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../models/training_session.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import '../widgets/premium_effects.dart';
import '../widgets/press_scale.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/weekly_overview.dart';
import 'round_timer_screen.dart';
import 'weight_tracker_screen.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final state = context.watch<AppState>();
    final user = auth.user;
    final weightDelta = state.weeklyDelta;
    final losing = weightDelta <= 0;
    final nextSession = state.sessions.where((s) => !s.completed).firstOrNull;
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const dayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final completedDays = {
      for (final session in state.sessions.where((s) => s.completed))
        session.day.trim().toLowerCase(),
    };
    final weeklyProgress = [
      for (final day in dayNames)
        completedDays.any((completed) => completed.startsWith(day)) ? 1.0 : 0.0,
    ];
    final recentSessions = state.completedSessionsDesc.take(3).toList();
    final showVerificationBanner = auth.supportsEmailVerification &&
        auth.user != null &&
        !auth.user!.emailVerified;
    return ScreenScaffold.tab(
      title: 'Dashboard',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
        children: [
          PremiumReveal(
            child: _ProfileHeader(
              name: (user?.displayName.isNotEmpty ?? false)
                  ? user!.displayName
                  : 'Fighter',
              tagline: user?.goal.isNotEmpty ?? false
                  ? user!.goal
                  : 'The Grind Never Lies.',
            ),
          ),
          if (showVerificationBanner) ...[
            const SizedBox(height: Insets.lg),
            _EmailVerificationBanner(auth: auth),
          ],
          const SizedBox(height: Insets.lg),
          _TodayFocusCard(onNavigate: onNavigate),
          const SizedBox(height: Insets.xl),
          _DashboardStats(
            cards: [
              StatCard(
                label: 'Weight',
                value: state.latestWeight == 0
                    ? '—'
                    : state
                        .displayWeight(state.latestWeight)
                        .toStringAsFixed(1),
                unit: state.weightUnitLabel,
                delta: state.weights.length < 2
                    ? 'Add weigh-in'
                    : '${state.displayWeight(weightDelta).abs().toStringAsFixed(1)} ${state.weightUnitLabel}',
                deltaColor: losing ? AppColors.positive : AppColors.primary,
                deltaIcon: losing ? Icons.arrow_downward : Icons.arrow_upward,
                onTap: () => AppNavigation.push(
                  context,
                  AppRoutes.weightTracker,
                  fallbackBuilder: (_) => const WeightTrackerScreen(),
                ),
                accent: AppColors.primary,
              ),
              StatCard(
                label: 'Sessions',
                value: '${state.completedSessionCount}',
                unit: '',
                delta: 'completed',
                deltaColor: AppColors.positive,
                deltaIcon: Icons.check_circle_outline,
              ),
              StatCard(
                label: 'Streak',
                value: '${state.currentStreakDays}',
                unit: 'days',
                delta: state.currentStreakDays > 0 ? 'On fire' : 'Log today',
                deltaColor: AppColors.warning,
                deltaIcon: Icons.local_fire_department,
                accent: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader('Weekly Overview'),
          PremiumReveal(
            index: 1,
            child: AppCard(
              elevated: true,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B1B25), Color(0xFF121218)],
              ),
              child: WeeklyOverview(
                dayLetters: dayLetters,
                progress: weeklyProgress,
                todayIndex: DateTime.now().weekday - 1,
              ),
            ),
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader('Next Session'),
          PremiumReveal(
            index: 2,
            child: _NextSessionCard(
              session: nextSession,
              onOpenCamp: () => onNavigate(1),
              onStart: nextSession == null
                  ? null
                  : () => _push(
                        context,
                        RoundTimerScreen(session: nextSession),
                      ),
            ),
          ),
          const SizedBox(height: Insets.xl),
          SectionHeader(
            'Recent Activity',
            trailing: PressScale(
              onTap: () => onNavigate(1),
              child: Text('See all',
                  style: AppType.subhead(
                      weight: FontWeight.w600, color: AppColors.accentText)),
            ),
          ),
          if (recentSessions.isEmpty)
            const _NoRecentActivity()
          else
            for (final session in recentSessions) _ActivityRow(session),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => screen));
  }
}

class _DashboardStats extends StatelessWidget {
  final List<StatCard> cards;

  const _DashboardStats({required this.cards});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStack = constraints.maxWidth < 340 || textScale >= 1.3;
        if (shouldStack) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: Insets.md),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: Insets.md),
            ],
          ],
        );
      },
    );
  }
}

class _TodayFocusCard extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const _TodayFocusCard({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final edgeFuel = context.watch<EdgeFuelController>();
    final nextSession = state.sessions.where((s) => !s.completed).firstOrNull;

    return AppCard(
      accent: AppColors.primary,
      elevated: true,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF201416), Color(0xFF121218)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag_outlined,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today\'s focus', style: AppType.title1(spacing: .3)),
                    const SizedBox(height: Insets.xxs),
                    Text(
                      nextSession == null
                          ? 'Camp work complete — protect recovery.'
                          : '${nextSession.title} · ${nextSession.subtitle}',
                      style: AppType.subhead(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          if (edgeFuel.hasUsableTarget)
            _FuelTargetSnapshot(
              edgeFuel: edgeFuel,
              streakDays: state.currentStreakDays,
            )
          else
            Row(
              children: [
                const Expanded(
                  child: _FocusMetric(
                    label: 'Fuel target',
                    value: 'Set target',
                    icon: Icons.restaurant,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _FocusMetric(
                    label: 'Streak',
                    value: '${state.currentStreakDays} days',
                    icon: Icons.local_fire_department,
                  ),
                ),
              ],
            ),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  nextSession == null ? 'Open camp' : 'Start camp',
                  icon: Icons.play_arrow,
                  expand: true,
                  onPressed: () => onNavigate(1),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: GhostButton(
                  'Log meal',
                  icon: Icons.add,
                  expand: true,
                  onPressed: () => onNavigate(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FuelTargetSnapshot extends StatelessWidget {
  final EdgeFuelController edgeFuel;
  final int streakDays;

  const _FuelTargetSnapshot({
    required this.edgeFuel,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    final target = edgeFuel.targetCalories;
    final consumed = edgeFuel.consumedCalories;
    final remaining = (target - consumed).clamp(0, target);
    final progress = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final overTarget = target > 0 && consumed > target;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.primary, size: 18),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'EdgeFuel target',
                  style: AppType.callout(weight: FontWeight.w800),
                ),
              ),
              Text(
                overTarget ? 'Over target' : '$remaining kcal left',
                style: AppType.subhead(
                  weight: FontWeight.w800,
                  color: overTarget ? AppColors.negative : AppColors.positive,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            '$consumed / $target kcal',
            style: AppType.title2().copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: Insets.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation(
                overTarget ? AppColors.negative : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              _TargetPill(
                label: 'Protein',
                value: '${edgeFuel.targetProtein}g',
                color: AppColors.protein,
              ),
              _TargetPill(
                label: 'Carbs',
                value: '${edgeFuel.targetCarbs}g',
                color: AppColors.carbs,
              ),
              _TargetPill(
                label: 'Fats',
                value: '${edgeFuel.targetFats}g',
                color: AppColors.fats,
              ),
              _TargetPill(
                label: 'Streak',
                value: '${streakDays}d',
                color: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TargetPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TargetPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm, vertical: Insets.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Insets.xs),
          Text(
            '$label $value',
            style: AppType.micro(
              weight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _FocusMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: AppType.micro(
                      weight: FontWeight.w800,
                      color: AppColors.textMuted,
                      spacing: .8,
                    )),
                const SizedBox(height: Insets.xxs),
                Text(value, style: AppType.subhead(weight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String tagline;
  const _ProfileHeader({required this.name, required this.tagline});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const FighterAvatar(size: 52),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppType.title1()),
              const SizedBox(height: Insets.xxs),
              Text(tagline,
                  style: AppType.subhead(
                      weight: FontWeight.w500, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const PremiumBadge('Camp mode'),
      ],
    );
  }
}

class _EmailVerificationBanner extends StatelessWidget {
  final AuthController auth;
  const _EmailVerificationBanner({required this.auth});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.warning,
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mark_email_unread_outlined,
                color: AppColors.warning, size: 21),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verify your email',
                    style: AppType.callout(weight: FontWeight.w800)),
                const SizedBox(height: Insets.xxs),
                Text('Secure your account before fight camp gets serious.',
                    style: AppType.subhead(
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: auth.isBusy
                ? null
                : () async {
                    try {
                      await auth.sendEmailVerification();
                      if (!context.mounted) return;
                      _showDashboardMessage(
                          context, 'Verification email sent.');
                    } catch (e) {
                      if (!context.mounted) return;
                      _showDashboardMessage(
                          context, 'Could not send verification email.');
                    }
                  },
            child: Text('Resend',
                style: AppType.subhead(
                    weight: FontWeight.w800, color: AppColors.warning)),
          ),
        ],
      ),
    );
  }

  void _showDashboardMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(message, style: AppType.subhead(weight: FontWeight.w600)),
      ));
  }
}

class _NextSessionCard extends StatelessWidget {
  final TrainingSession? session;
  final VoidCallback? onStart;
  final VoidCallback onOpenCamp;
  const _NextSessionCard({
    required this.session,
    required this.onStart,
    required this.onOpenCamp,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.primary,
      elevated: true,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF211719), Color(0xFF15141B)],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(session?.icon ?? Icons.task_alt, color: AppColors.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session?.title ?? 'Week complete',
                    style: AppType.callout(weight: FontWeight.w700)),
                const SizedBox(height: Insets.xxs),
                Text(session?.subtitle ?? 'Review your completed sessions',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subhead(
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          PrimaryButton(
            session == null ? 'View' : 'Start',
            onPressed: onStart ?? onOpenCamp,
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final TrainingSession session;
  const _ActivityRow(this.session);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(session.icon, size: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title,
                      style: AppType.callout(weight: FontWeight.w600)),
                  const SizedBox(height: Insets.xxs),
                  Text(
                      session.rpe > 0
                          ? '${session.subtitle} · RPE ${session.rpe}'
                          : session.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.subhead(
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(_relativeDate(session.completedAt),
                style: AppType.micro(
                    weight: FontWeight.w500, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _NoRecentActivity extends StatelessWidget {
  const _NoRecentActivity();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(Insets.lg),
      child: Row(
        children: [
          Icon(Icons.history, color: AppColors.textMuted),
          SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              'Complete your first session to start your history.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeDate(DateTime? completedAt) {
  if (completedAt == null) return 'Logged';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(completedAt.year, completedAt.month, completedAt.day);
  final days = today.difference(date).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '$days days ago';
}

/// Simple monogram avatar (no network image needed for the prototype).
class FighterAvatar extends StatelessWidget {
  final double size;
  const FighterAvatar({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2E), Color(0xFF141416)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child:
          Icon(Icons.person, size: size * 0.55, color: AppColors.textSecondary),
    );
  }
}

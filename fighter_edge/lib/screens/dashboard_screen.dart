import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_data.dart';
import '../models/training_session.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import '../widgets/premium_effects.dart';
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
    const f = MockData.fighter;
    final state = context.watch<AppState>();
    final weightDelta = state.weeklyDelta;
    final losing = weightDelta <= 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppHeader(
                title: 'Dashboard',
                actions: [HeaderIcon(Icons.notifications_none, onTap: () {})],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.lg, 0, Insets.lg, Insets.xxl),
                  children: [
                    PremiumReveal(
                      child: _ProfileHeader(name: f.name, tagline: f.tagline),
                    ),
                    const SizedBox(height: Insets.lg),
                    SizedBox(
                      height: 126,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          SizedBox(
                            width: 142,
                            child: StatCard(
                              label: 'Weight',
                              value: state.latestWeight.toStringAsFixed(1),
                              unit: 'kg',
                              delta:
                                  '${weightDelta.abs().toStringAsFixed(1)} kg',
                              deltaColor: losing
                                  ? AppColors.positive
                                  : AppColors.primary,
                              deltaIcon: losing
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              onTap: () =>
                                  _push(context, const WeightTrackerScreen()),
                              accent: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: Insets.md),
                          const SizedBox(
                            width: 142,
                            child: StatCard(
                              label: 'Body Fat',
                              value: '12.4',
                              unit: '%',
                              delta: '0.6 %',
                              deltaColor: AppColors.positive,
                              deltaIcon: Icons.arrow_downward,
                            ),
                          ),
                          const SizedBox(width: Insets.md),
                          SizedBox(
                            width: 142,
                            child: StatCard(
                              label: 'Streak',
                              value: '${f.currentStreak}',
                              unit: 'days',
                              delta: 'On fire',
                              deltaColor: AppColors.warning,
                              deltaIcon: Icons.local_fire_department,
                              accent: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    const SectionHeader('Weekly Overview'),
                    const PremiumReveal(
                      duration: Duration(milliseconds: 500),
                      child: AppCard(
                        elevated: true,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1B1B25), Color(0xFF121218)],
                        ),
                        child: WeeklyOverview(
                          dayLetters: MockData.weekDayLetters,
                          progress: MockData.weeklyProgress,
                          todayIndex: MockData.todayIndex,
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    const SectionHeader('Next Session'),
                    PremiumReveal(
                      duration: const Duration(milliseconds: 580),
                      child: _NextSessionCard(
                        onStart: () => _push(context, const RoundTimerScreen()),
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    SectionHeader(
                      'Recent Activity',
                      trailing: GestureDetector(
                        onTap: () => onNavigate(1),
                        child: Text('See all',
                            style: AppTheme.body(12,
                                weight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ),
                    for (final a in MockData.recentActivity) _ActivityRow(a),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
              GradientText(name, style: AppTheme.display(24)),
              const SizedBox(height: 2),
              Text(tagline,
                  style: AppTheme.body(13,
                      weight: FontWeight.w500, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const PremiumBadge('Camp mode'),
      ],
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  final VoidCallback onStart;
  const _NextSessionCard({required this.onStart});

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
            child: const Icon(Icons.sports_mma, color: AppColors.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fight Camp',
                    style: AppTheme.body(15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Striking · 60 min',
                    style: AppTheme.body(12,
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          PrimaryButton('Start', onPressed: onStart),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityEntry a;
  const _ActivityRow(this.a);

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
              child: Icon(a.icon, size: 20, color: AppColors.textSecondary),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: AppTheme.body(14, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(a.subtitle,
                      style: AppTheme.body(12,
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text(a.when,
                style: AppTheme.body(11,
                    weight: FontWeight.w500, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
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

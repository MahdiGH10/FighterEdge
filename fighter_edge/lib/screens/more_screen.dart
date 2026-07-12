import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/stat_card.dart';
import 'corner_coach_screen.dart';
import 'profile_screen.dart';
import 'round_timer_screen.dart';
import 'weight_tracker_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <_MoreEntry>[
      _MoreEntry(Icons.timer_outlined, 'Round Timer',
          'Interval timer for your rounds', const RoundTimerScreen()),
      _MoreEntry(Icons.monitor_weight_outlined, 'Weight Tracker',
          'Log weigh-ins and track progress', const WeightTrackerScreen()),
      _MoreEntry(Icons.record_voice_over_outlined, 'Corner Coach',
          'Round-by-round game plan', const CornerCoachScreen()),
      _MoreEntry(Icons.self_improvement, 'Mobility',
          'Recovery & mobility flows', const _MobilityScreen()),
      _MoreEntry(Icons.person_outline, 'Profile',
          'Your fighter stats & goals', const ProfileScreen()),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(title: 'More'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Insets.lg, 0, Insets.lg, Insets.xxl),
                children: [
                  for (final e in entries) _MoreRow(e),
                  const SizedBox(height: Insets.xl),
                  Center(
                    child: Text('FIGHTER EDGE · v1.0',
                        style: AppTheme.body(11,
                            weight: FontWeight.w600,
                            color: AppColors.textMuted,
                            spacing: 1)),
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

class _MoreEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? screen;
  _MoreEntry(this.icon, this.title, this.subtitle, this.screen);
}

class _MoreRow extends StatelessWidget {
  final _MoreEntry e;
  const _MoreRow(this.e);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: AppCard(
        onTap: e.screen == null
            ? null
            : () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => e.screen!)),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(e.icon, color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, style: AppTheme.body(15, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(e.subtitle,
                      style: AppTheme.body(12,
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Lightweight placeholder for the not-yet-built Mobility area.
class _MobilityScreen extends StatelessWidget {
  const _MobilityScreen();

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Mobility',
      showBack: true,
      body: EmptyState(
        icon: Icons.self_improvement,
        title: 'Mobility Flows',
        message: 'Guided recovery and mobility routines\nare coming in a future update.',
      ),
    );
  }
}

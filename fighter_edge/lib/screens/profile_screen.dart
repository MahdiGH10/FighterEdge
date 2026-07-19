import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../data/mock_data.dart';
import '../models/fighter.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import 'dashboard_screen.dart';
import 'paywall_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const f = MockData.fighter;
    final weight = context.watch<AppState>().latestWeight;
    final auth = context.watch<AuthController>();
    return ScreenScaffold(
      title: 'Profile',
      showBack: true,
      actions: [HeaderIcon(Icons.edit, onTap: () {})],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xxl),
        children: [
          Row(
            children: [
              const FighterAvatar(size: 64),
              const SizedBox(width: Insets.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name, style: AppTheme.display(24)),
                  const SizedBox(height: 2),
                  Text(f.division,
                      style: AppTheme.body(13,
                          weight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text('${f.heightCm} cm · ${weight.toStringAsFixed(1)} kg',
                      style: AppTheme.body(12,
                          weight: FontWeight.w500, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader('Subscription'),
          _SubscriptionCard(auth: auth),
          const SizedBox(height: Insets.xl),
          const SectionHeader('Stats'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _StatRow('Training Days', '${f.trainingDays}'),
                _divider(),
                _StatRow('Total Workouts', '${f.totalWorkouts}'),
                _divider(),
                _StatRow('Win / Loss', '${f.wins} - ${f.losses}'),
                _divider(),
                _StatRow('Current Streak', '${f.currentStreak} days'),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader('Goals'),
          AppCard(
            child: Column(
              children: [
                for (int i = 0; i < f.goals.length; i++) ...[
                  if (i > 0) const SizedBox(height: Insets.lg),
                  _GoalRow(f.goals[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          GhostButton(
            'Sign Out',
            icon: Icons.logout,
            expand: true,
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }

  static Widget _divider() =>
      const Divider(height: 1, thickness: 1, color: AppColors.border);
}

/// Plan badge + upgrade/manage entry point.
class _SubscriptionCard extends StatelessWidget {
  final AuthController auth;
  const _SubscriptionCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final isPro = auth.isPro;
    return AppCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(isPro ? Icons.verified : Icons.bolt,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isPro ? 'FighterEdge Pro' : 'Free Plan',
                    style: AppTheme.body(15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    isPro
                        ? 'All features unlocked'
                        : 'Upgrade to unlock everything',
                    style: AppTheme.body(12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (!isPro)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Text('UPGRADE',
                  style: AppTheme.body(11,
                      weight: FontWeight.w700, color: Colors.white)),
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.md + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTheme.body(14,
                  weight: FontWeight.w500, color: AppColors.textSecondary)),
          Text(value, style: AppTheme.body(15, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final Goal goal;
  const _GoalRow(this.goal);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(goal.label, style: AppTheme.body(14, weight: FontWeight.w600)),
            Text('${(goal.progress * 100).round()}%',
                style: AppTheme.body(13,
                    weight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: Insets.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: goal.progress,
            minHeight: 7,
            backgroundColor: AppColors.track,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

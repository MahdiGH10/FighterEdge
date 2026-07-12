import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../billing/subscription.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';

/// Upgrade screen. Payments aren't wired yet — "Upgrade" flips the plan to Pro
/// locally so the entitlement model is fully demoable.
class PaywallScreen extends StatelessWidget {
  /// Optional feature that triggered the paywall, highlighted at the top.
  final Feature? highlight;
  const PaywallScreen({super.key, this.highlight});

  static const _benefits = [
    ('Corner Coach', 'Round-by-round AI game plan', Icons.record_voice_over),
    ('All Timer Presets', 'Boxing, MMA & BJJ interval sets', Icons.timer),
    (
      'Unlimited Weight History',
      'Full trend history & analytics',
      Icons.show_chart
    ),
    ('Nutrition Analytics', 'Weekly macro & calorie insights', Icons.insights),
    (
      'Full Technique Library',
      'Every discipline, unlocked',
      Icons.sports_martial_arts
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isPro = auth.isPro;
    return ScreenScaffold(
      title: 'Fighter Edge Pro',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xxl),
        children: [
          const SizedBox(height: Insets.sm),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg, vertical: Insets.sm),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(Radii.chip),
                border: Border.all(color: AppColors.primary),
              ),
              child: Text('PRO',
                  style: AppTheme.display(16,
                      color: AppColors.primary, spacing: 2)),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text('Unlock your full edge',
              textAlign: TextAlign.center, style: AppTheme.display(24)),
          const SizedBox(height: Insets.xs),
          Text('Everything you need to train like a pro.',
              textAlign: TextAlign.center,
              style: AppTheme.body(13, color: AppColors.textSecondary)),
          const SizedBox(height: Insets.xl),
          for (final b in _benefits)
            _BenefitRow(
              title: b.$1,
              subtitle: b.$2,
              icon: b.$3,
              highlighted: highlight?.title == b.$1,
            ),
          const SizedBox(height: Insets.lg),
          if (isPro)
            Column(
              children: [
                const Icon(Icons.verified, color: AppColors.positive, size: 32),
                const SizedBox(height: Insets.sm),
                Text('You\'re on Pro',
                    style: AppTheme.display(18, color: AppColors.positive)),
                const SizedBox(height: Insets.lg),
                TextButton(
                  onPressed: () => auth.setPlan(Plan.free),
                  child: Text('Downgrade to Free (demo)',
                      style: AppTheme.body(12, color: AppColors.textMuted)),
                ),
              ],
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: AppColors.primary),
              ),
              child: Column(
                children: [
                  Text('\$9.99 / month', style: AppTheme.display(24)),
                  const SizedBox(height: 2),
                  Text('Cancel anytime',
                      style: AppTheme.body(12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            PrimaryButton(
              auth.isBusy ? 'Upgrading…' : 'Upgrade to Pro',
              icon: Icons.bolt,
              expand: true,
              onPressed: auth.isBusy
                  ? null
                  : () async {
                      await auth.setPlan(Plan.pro);
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
            ),
            const SizedBox(height: Insets.sm),
            Text('Demo: no real payment is taken.',
                textAlign: TextAlign.center,
                style: AppTheme.body(11, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool highlighted;
  const _BenefitRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
            color: highlighted ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.body(14, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTheme.body(12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppColors.positive, size: 20),
        ],
      ),
    );
  }
}

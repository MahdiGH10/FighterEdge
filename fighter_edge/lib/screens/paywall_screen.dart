import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_repository.dart';
import '../billing/subscription.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';

/// Upgrade screen. Payments are not wired yet, so this screen collects intent
/// without granting paid entitlements from the client.
class PaywallScreen extends StatefulWidget {
  /// Optional feature that triggered the paywall, highlighted at the top.
  final Feature? highlight;
  const PaywallScreen({super.key, this.highlight});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _annual = true;

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
      title: 'FighterEdge Pro',
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
              highlighted: widget.highlight?.title == b.$1,
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
                GhostButton(
                  'Refresh Status',
                  icon: Icons.refresh,
                  onPressed: auth.isBusy ? null : auth.refreshCurrentUser,
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
                  Row(
                    children: [
                      Expanded(
                        child: _PlanToggle(
                          label: 'Monthly',
                          price: '\$9.99',
                          selected: !_annual,
                          onTap: () => setState(() => _annual = false),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: _PlanToggle(
                          label: 'Yearly',
                          price: '\$79.99',
                          badge: 'Best value',
                          selected: _annual,
                          onTap: () => setState(() => _annual = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  const _ComparisonRow(
                    free: 'Basic tracking',
                    pro: 'Camp analytics + coach loops',
                  ),
                  const _ComparisonRow(
                    free: 'Limited library',
                    pro: 'Full technique progression',
                  ),
                  const _ComparisonRow(
                    free: 'Manual progress',
                    pro: 'Accountability dashboard',
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            PrimaryButton(
              auth.isBusy ? 'Opening checkout...' : 'Join Pro Waitlist',
              icon: Icons.bolt,
              expand: true,
              onPressed: auth.isBusy
                  ? null
                  : () async {
                      try {
                        await auth.startProCheckout();
                      } on AuthException catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.message)),
                        );
                      }
                    },
            ),
            const SizedBox(height: Insets.sm),
            Text('No payment will be taken until store billing is connected.',
                textAlign: TextAlign.center,
                style: AppTheme.body(11, color: AppColors.textMuted)),
            const SizedBox(height: Insets.md),
            TextButton(
              onPressed: auth.isBusy ? null : auth.refreshCurrentUser,
              child: Text(
                'Restore / refresh purchase status',
                style: AppTheme.body(
                  12,
                  weight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanToggle extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PlanToggle({
    required this.label,
    required this.price,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: MotionTokens.fast,
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.backgroundRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            if (badge != null) ...[
              Text(
                badge!.toUpperCase(),
                style: AppTheme.body(
                  9,
                  weight: FontWeight.w900,
                  color: AppColors.premium,
                  spacing: .8,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(label, style: AppTheme.body(13, weight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(price, style: AppTheme.display(22)),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String free;
  final String pro;

  const _ComparisonRow({required this.free, required this.pro});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              free,
              style: AppTheme.body(11, color: AppColors.textMuted),
            ),
          ),
          const Icon(Icons.arrow_forward, color: AppColors.primary, size: 16),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              pro,
              style: AppTheme.body(
                11,
                weight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
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

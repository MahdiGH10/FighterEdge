import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_repository.dart';
import '../billing/billing_gateway.dart';
import '../billing/subscription.dart';
import '../controllers/auth_controller.dart';
import '../observability/telemetry.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';

/// Upgrade screen. Store purchases are initiated here, but paid entitlements
/// are granted only after the server webhook updates the account profile.
class PaywallScreen extends StatefulWidget {
  /// Optional feature that triggered the paywall, highlighted at the top.
  final Feature? highlight;
  const PaywallScreen({super.key, this.highlight});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  static const _benefits = [
    (
      'Corner Coach',
      'Round-by-round plans and post-session feedback',
      Icons.record_voice_over
    ),
    ('All Timer Presets', 'Boxing, MMA and BJJ interval sets', Icons.timer),
    (
      'Unlimited Weight History',
      'Full trend history without deleting your past',
      Icons.show_chart
    ),
    (
      'Nutrition Analytics',
      'Weekly macro trends and plan explanations',
      Icons.insights
    ),
    (
      'Full Technique Library',
      'Every discipline and progression path unlocked',
      Icons.sports_martial_arts
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Telemetry.fromContext(context).track(
        TelemetryEvent.paywallViewed,
        parameters: {
          'feature': widget.highlight?.name ?? 'direct',
        },
      );
      if (mounted) context.read<AuthController>().loadBillingProducts();
    });
  }

  Future<void> _purchase(BillingProduct product) async {
    final auth = context.read<AuthController>();
    try {
      await auth.startProCheckout(product);
      if (!mounted) return;
      final message = auth.isPro
          ? 'Pro is active on your account.'
          : 'Purchase received. We are confirming your Pro access securely.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _restore() async {
    final auth = context.read<AuthController>();
    try {
      await auth.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.isPro
            ? 'Your Pro access is restored.'
            : 'No active Pro access was found yet.'),
        behavior: SnackBarBehavior.floating,
      ));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

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
          Text('Unlock your full edge',
              textAlign: TextAlign.center, style: AppType.title1()),
          const SizedBox(height: Insets.xs),
          Text(
              'Sharper coaching, deeper history, and fuel decisions that make sense.',
              textAlign: TextAlign.center,
              style: AppType.subhead(color: AppColors.textSecondary)),
          const SizedBox(height: Insets.xl),
          if (widget.highlight != null) ...[
            _TriggeredFeatureCard(feature: widget.highlight!),
            const SizedBox(height: Insets.lg),
          ],
          const _ValueStack(),
          const SizedBox(height: Insets.lg),
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
                    style: AppType.title2(color: AppColors.positive)),
                const SizedBox(height: Insets.lg),
                GhostButton(
                  'Refresh Status',
                  icon: Icons.refresh,
                  onPressed: auth.isBusy ? null : auth.refreshCurrentUser,
                ),
              ],
            )
          else ...[
            if (auth.billingState.isPro) const _BillingSyncNotice(),
            if (auth.billingAvailable && auth.billingProducts.isNotEmpty) ...[
              const _LaunchTermsCard(billingActive: true),
              const SizedBox(height: Insets.lg),
              for (final product in auth.billingProducts) ...[
                PrimaryButton(
                  '${product.period == BillingProductPeriod.annual ? 'Annual' : 'Monthly'} · ${product.priceString}',
                  icon: Icons.lock_open,
                  expand: true,
                  onPressed: auth.isBusy ? null : () => _purchase(product),
                ),
                const SizedBox(height: Insets.sm),
              ],
            ] else if (auth.billingAvailable && auth.isBusy) ...[
              const _BillingLoadingNotice(),
            ] else ...[
              const _LaunchTermsCard(billingActive: false),
              const SizedBox(height: Insets.lg),
              PrimaryButton(
                auth.isBusy ? 'Saving interest...' : 'Join Pro Waitlist',
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
            ],
            const SizedBox(height: Insets.sm),
            Text(
                auth.billingAvailable
                    ? 'Your store receipt is verified before Pro is activated.'
                    : 'No payment today. We will ask again before any charge.',
                textAlign: TextAlign.center,
                style: AppType.micro(color: AppColors.textMuted)),
            const SizedBox(height: Insets.md),
            TextButton(
              onPressed: auth.isBusy
                  ? null
                  : auth.billingAvailable
                      ? _restore
                      : auth.refreshCurrentUser,
              child: Text(
                auth.billingAvailable
                    ? 'Restore purchases'
                    : 'Refresh purchase status',
                style: AppType.subhead(
                  weight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (auth.billingManagementUrl case final managementUrl?)
              TextButton(
                onPressed: () => launchUrl(Uri.parse(managementUrl)),
                child: Text(
                  'Manage or cancel subscription',
                  style: AppType.subhead(
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

class _TriggeredFeatureCard extends StatelessWidget {
  final Feature feature;
  const _TriggeredFeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.primary,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_open, color: AppColors.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You found a Pro feature', style: AppType.title2()),
                const SizedBox(height: Insets.xxs),
                Text(
                  '${feature.title} is part of the full Fighter Edge system.',
                  style: AppType.subhead(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueStack extends StatelessWidget {
  const _ValueStack();

  static const _items = [
    (
      Icons.track_changes,
      'Know what matters today',
      'Focus on the session, habit, or recovery signal that moves the week.'
    ),
    (
      Icons.query_stats,
      'See trends, not noise',
      'Keep the full history behind weight, camp, and nutrition progress.'
    ),
    (
      Icons.psychology_alt,
      'Get explanations',
      'Pro surfaces explain why the plan says what it says, not just numbers.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF201416), Color(0xFF121218)],
      ),
      child: Column(
        children: [
          for (final item in _items) _ValueRow(item.$1, item.$2, item.$3),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ValueRow(this.icon, this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.callout(weight: FontWeight.w800)),
                const SizedBox(height: Insets.xxs),
                Text(
                  body,
                  style: AppType.subhead(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchTermsCard extends StatelessWidget {
  final bool billingActive;

  const _LaunchTermsCard({required this.billingActive});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.premium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FOUNDING PRO PREVIEW',
            style: AppType.micro(
              weight: FontWeight.w900,
              color: AppColors.premium,
              spacing: 0.8,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            billingActive
                ? 'Secure store checkout'
                : 'Planned pricing: \$9.99/mo or \$79.99/yr',
            style: AppType.title2(),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            billingActive
                ? 'Subscriptions are processed by Apple or Google. Your '
                    'receipt is verified before Pro access is activated, and '
                    'you can restore or manage it any time.'
                : 'Billing is not active on this build yet. Joining the '
                    'waitlist records interest only; no payment is taken.',
            style: AppType.subhead(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BillingSyncNotice extends StatelessWidget {
  const _BillingSyncNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.primary,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sync, color: AppColors.primary),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              'Your store purchase is recognized. Pro unlocks after the secure account sync completes.',
              style: AppType.subhead(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingLoadingNotice extends StatelessWidget {
  const _BillingLoadingNotice();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: Insets.md),
          Expanded(child: Text('Loading store plans…')),
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
                Text(title, style: AppType.callout(weight: FontWeight.w700)),
                const SizedBox(height: Insets.xxs),
                Text(subtitle,
                    style: AppType.subhead(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppColors.positive, size: 20),
        ],
      ),
    );
  }
}

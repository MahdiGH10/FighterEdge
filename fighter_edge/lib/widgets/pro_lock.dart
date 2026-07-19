import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../billing/subscription.dart';
import '../controllers/auth_controller.dart';
import '../screens/paywall_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'primary_button.dart';

/// Gates [child] behind a Pro entitlement. Free users see a lock CTA that
/// routes to the paywall; Pro users see the real content.
class ProGate extends StatelessWidget {
  final Feature feature;
  final Widget child;
  const ProGate({super.key, required this.feature, required this.child});

  @override
  Widget build(BuildContext context) {
    final allowed = context.watch<AuthController>().allows(feature);
    if (allowed) return child;
    return ProLock(feature: feature);
  }
}

/// The locked-state placeholder shown in place of a Pro feature.
class ProLock extends StatelessWidget {
  final Feature feature;
  const ProLock({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.lock_outline,
                  size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: Insets.lg),
            Text('${feature.title} is Pro',
                textAlign: TextAlign.center, style: AppTheme.display(20)),
            const SizedBox(height: Insets.sm),
            Text('Upgrade to FighterEdge Pro to unlock this feature.',
                textAlign: TextAlign.center,
                style: AppTheme.body(13, color: AppColors.textMuted)),
            const SizedBox(height: Insets.xl),
            PrimaryButton(
              'Unlock with Pro',
              icon: Icons.bolt,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PaywallScreen(highlight: feature))),
            ),
          ],
        ),
      ),
    );
  }
}

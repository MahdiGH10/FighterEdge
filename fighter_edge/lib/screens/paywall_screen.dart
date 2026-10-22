import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_icons.dart';

import '../auth/auth_repository.dart';
import '../billing/billing_gateway.dart';
import '../billing/subscription.dart';
import '../controllers/auth_controller.dart';
import '../l10n/gen/app_localizations.dart';
import '../legal/legal_links.dart';
import 'legal_screen.dart';
import '../observability/telemetry.dart';
import '../theme/app_accessibility.dart';
import '../theme/app_colors.dart';
import '../theme/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_surface.dart';
import '../widgets/press_scale.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_card.dart';

/// Fixed, non-personal source codes for conversion analysis.
enum PaywallTrigger {
  direct,

  /// The entry gate right after the plan reveal in onboarding.
  planReady,
  settings,
  profile,
  cornerCoach,
  techniqueLibrary,
  premiumRecipe,

  /// A locked action in a read-only account opened the paywall.
  readOnly,
}

extension PaywallTriggerCode on PaywallTrigger {
  String get code => switch (this) {
        PaywallTrigger.direct => 'direct',
        PaywallTrigger.planReady => 'plan_ready',
        PaywallTrigger.settings => 'settings',
        PaywallTrigger.profile => 'profile',
        PaywallTrigger.cornerCoach => 'corner_coach',
        PaywallTrigger.techniqueLibrary => 'technique_library',
        PaywallTrigger.premiumRecipe => 'premium_recipe',
        PaywallTrigger.readOnly => 'read_only',
      };
}

class PaywallRouteArgs {
  final Feature? highlight;
  final PaywallTrigger trigger;

  const PaywallRouteArgs({this.highlight, required this.trigger});
}

/// The subscription screen. Store purchases start here, but access is granted
/// only after the server webhook updates the account profile.
///
/// It pops with `true` once the store accepted a purchase, so the onboarding
/// gate can carry on into the app.
class PaywallScreen extends StatefulWidget {
  /// Optional feature that triggered the paywall, highlighted at the top.
  final Feature? highlight;
  final PaywallTrigger trigger;
  const PaywallScreen({
    super.key,
    this.highlight,
    this.trigger = PaywallTrigger.direct,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  /// The plan the athlete picked; null means the default (annual first).
  BillingProductPeriod? _selectedPeriod;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Telemetry.fromContext(context).track(
        TelemetryEvent.paywallViewed,
        parameters: {
          'feature': widget.highlight?.name ?? 'direct',
          'trigger': widget.trigger.code,
        },
      );
      if (mounted) context.read<AuthController>().loadBillingProducts();
    });
  }

  Future<void> _purchase(BillingProduct product) async {
    final l = L.of(context);
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.startProCheckout(product);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
            auth.isPro ? l.paywallPurchaseActive : l.paywallPurchasePending),
        behavior: SnackBarBehavior.floating,
      ));
      // The store accepted the purchase. The onboarding gate carries on; the
      // account itself unlocks only when the server confirms.
      if (widget.trigger == PaywallTrigger.planReady &&
          auth.billingState.isPro) {
        navigator.maybePop(true);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _restore() async {
    final l = L.of(context);
    final auth = context.read<AuthController>();
    try {
      await auth.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(auth.isPro ? l.paywallRestored : l.paywallNothingToRestore),
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

  List<BillingProduct> _orderedProducts(List<BillingProduct> products) {
    final ordered = [...products];
    ordered.sort((a, b) {
      if (a.period == b.period) return 0;
      return a.period == BillingProductPeriod.annual ? -1 : 1;
    });
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final auth = context.watch<AuthController>();
    final access = auth.accessState;
    final paid = access.hasPaidAccess;
    final products = _orderedProducts(auth.billingProducts);
    final selected =
        products.where((p) => p.period == _selectedPeriod).firstOrNull ??
            products.firstOrNull;
    final secondary = AppAccessibility.textSecondary(context);
    final quietLink =
        AppType.subhead(weight: FontWeight.w800, color: secondary);
    final showReadOnlyNote =
        access.isReadOnly && widget.trigger != PaywallTrigger.planReady;
    return ScreenScaffold(
      title: 'FighterEdge',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.none, Insets.lg, Insets.xxl),
        children: [
          const SizedBox(height: Insets.xs),
          Text(l.paywallPlainTitle,
              textAlign: TextAlign.center, style: AppType.title1()),
          const SizedBox(height: Insets.xs),
          Text(l.paywallPlainSubtitle,
              textAlign: TextAlign.center,
              style: AppType.subhead(color: secondary)),
          if (showReadOnlyNote) ...[
            const SizedBox(height: Insets.md),
            Text(l.readOnlyBanner,
                key: const ValueKey('paywall-read-only-note'),
                textAlign: TextAlign.center,
                style: AppType.callout(
                    weight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
          const SizedBox(height: Insets.lg),
          _Benefits(highlight: widget.highlight),
          const SizedBox(height: Insets.lg),
          if (paid)
            _PaidStatus(
              access: access,
              isBusy: auth.isBusy,
              onRefresh: auth.refreshCurrentUser,
            )
          else ...[
            if (auth.billingState.isPro) ...[
              const _BillingSyncNotice(),
              const SizedBox(height: Insets.md),
            ],
            // The plans and the one button sit right under the benefits, so a
            // phone shows what you get and what it costs without scrolling.
            if (auth.billingAvailable && selected != null) ...[
              if (selected.freeTrial != null) ...[
                _TrialSummary(product: selected),
                const SizedBox(height: Insets.md),
              ],
              for (final product in products) ...[
                _PlanTile(
                  product: product,
                  monthlyProduct: products
                      .where((p) => p.period == BillingProductPeriod.monthly)
                      .firstOrNull,
                  selected: product.id == selected.id,
                  onTap: auth.isBusy
                      ? null
                      : () => setState(() => _selectedPeriod = product.period),
                ),
                const SizedBox(height: Insets.sm),
              ],
              const SizedBox(height: Insets.xs),
              PrimaryButton(
                selected.freeTrial != null
                    ? l.paywallStartTrial
                    : selected.period == BillingProductPeriod.annual
                        ? l.paywallContinueAnnual
                        : l.paywallContinueMonthly,
                icon: AppIcons.lockSimpleOpen,
                expand: true,
                onPressed: auth.isBusy ? null : () => _purchase(selected),
              ),
              const SizedBox(height: Insets.sm),
              Text(l.paywallTrust,
                  textAlign: TextAlign.center,
                  style: AppType.subhead(color: secondary)),
              const SizedBox(height: Insets.sm),
              _RenewalDisclosure(product: selected),
            ] else if (auth.billingAvailable && auth.isBusy) ...[
              const _BillingLoadingNotice(),
            ] else ...[
              const _UnavailableCard(),
            ],
            const SizedBox(height: Insets.sm),
            TextButton(
              onPressed: auth.isBusy
                  ? null
                  : auth.billingAvailable
                      ? _restore
                      : auth.refreshCurrentUser,
              child: Text(
                auth.billingAvailable
                    ? l.paywallRestore
                    : l.paywallRefreshStatus,
                style: quietLink,
              ),
            ),
          ],
          if (auth.billingManagementUrl case final managementUrl?)
            TextButton(
              onPressed: () => launchUrl(Uri.parse(managementUrl)),
              child: Text(l.paywallManage, style: quietLink),
            ),
          const _LegalLinksRow(),
        ],
      ),
    );
  }
}

/// The auto-renewal terms App Review Guideline 3.1.2 and Google Play's
/// subscription policy require beside the purchase button (audit M-1). With a
/// trial the wording says when the charge starts and how to avoid it.
class _RenewalDisclosure extends StatelessWidget {
  const _RenewalDisclosure({required this.product});

  final BillingProduct product;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final trial = product.freeTrial;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.xs),
      child: Text(
        trial == null
            ? l.paywallRenewalDisclosure
            : l.paywallTrialRenewalDisclosure(
                trial.days, _priceWithPeriod(l, product)),
        key: const ValueKey('paywall-renewal-disclosure'),
        style: AppType.micro(color: AppAccessibility.textSecondary(context)),
      ),
    );
  }
}

/// "$59.99 / year" or "$7.99 / month".
String _priceWithPeriod(L l, BillingProduct product) =>
    product.period == BillingProductPeriod.annual
        ? l.paywallPerYear(product.priceString)
        : l.paywallPerMonth(product.priceString);

/// The store's free trial for the selected plan, with the price that follows
/// it. One text style for both halves, so the price is never smaller than the
/// word "free". Only built when the store reports a trial.
class _TrialSummary extends StatelessWidget {
  const _TrialSummary({required this.product});

  final BillingProduct product;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final trial = product.freeTrial!;
    return GlassCard(
      tone: GlassTone.gold,
      padding: const EdgeInsets.all(Insets.lg),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.paywallTrialBadge(trial.days).toUpperCase(),
              style: AppType.micro(
                  color: AppColors.premium, weight: FontWeight.w900),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              l.paywallTrialThen(trial.days, _priceWithPeriod(l, product)),
              key: const ValueKey('paywall-trial-line'),
              style: AppType.title2(),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the athlete sees when the account already has paid access.
class _PaidStatus extends StatelessWidget {
  const _PaidStatus({
    required this.access,
    required this.isBusy,
    required this.onRefresh,
  });

  final AccessState access;
  final bool isBusy;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final effective = access.effective;
    final days = access.trialDaysLeft(DateTime.now());
    return Column(
      children: [
        if (effective != null && effective.isTrial && days != null)
          GlassCard(
            tone: GlassTone.gold,
            padding: const EdgeInsets.all(Insets.lg),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.trialChipDaysLeft(days).toUpperCase(),
                      style: AppType.micro(
                          color: AppColors.premium, weight: FontWeight.w900)),
                  const SizedBox(height: Insets.xs),
                  Text(l.paywallTrialActiveTitle, style: AppType.title2()),
                  const SizedBox(height: Insets.xs),
                  Text(l.paywallTrialActiveBody,
                      style: AppType.subhead(
                          color: AppAccessibility.textSecondary(context))),
                ],
              ),
            ),
          )
        else ...[
          const Icon(AppIconsFill.sealCheck,
              color: AppColors.positive, size: IconSizes.badge),
          const SizedBox(height: Insets.sm),
          Text(l.paywallOnPro,
              style: AppType.title2(color: AppColors.positive)),
        ],
        const SizedBox(height: Insets.lg),
        GhostButton(
          l.paywallOnProRefresh,
          icon: AppIcons.arrowClockwise,
          onPressed: isBusy ? null : onRefresh,
        ),
      ],
    );
  }
}

/// Terms of Use (EULA) and Privacy Policy, reachable from the paywall itself.
class _LegalLinksRow extends StatelessWidget {
  const _LegalLinksRow();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = AppType.subhead(
      weight: FontWeight.w700,
      color: AppAccessibility.textSecondary(context),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => LegalLinks.open(context, LegalDocument.terms),
          child: Text(l.legalTermsLink, style: style),
        ),
        TextButton(
          onPressed: () => LegalLinks.open(context, LegalDocument.privacy),
          child: Text(l.legalPrivacyLink, style: style),
        ),
      ],
    );
  }
}

String? _monthlyEquivalent(BillingProduct product, String locale) {
  final price = product.price;
  if (price == null || !price.isFinite || price <= 0) return null;
  return NumberFormat.simpleCurrency(
    locale: locale,
    name: product.currencyCode,
    decimalDigits: 2,
  ).format(price / 12);
}

int? _annualSavingsPercent(
  BillingProduct annual,
  BillingProduct? monthly,
) {
  final annualPrice = annual.price;
  final monthlyPrice = monthly?.price;
  if (annualPrice == null ||
      monthlyPrice == null ||
      !annualPrice.isFinite ||
      !monthlyPrice.isFinite ||
      annualPrice <= 0 ||
      monthlyPrice <= 0) {
    return null;
  }
  final savings = 1 - annualPrice / (monthlyPrice * 12);
  if (!savings.isFinite || savings <= 0) return null;
  return (savings * 100).round();
}

/// One plan to pick. Tapping selects it; the button below buys it.
class _PlanTile extends StatelessWidget {
  final BillingProduct product;
  final BillingProduct? monthlyProduct;
  final bool selected;
  final VoidCallback? onTap;

  const _PlanTile({
    required this.product,
    required this.monthlyProduct,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final annual = product.period == BillingProductPeriod.annual;
    final equivalent = annual
        ? _monthlyEquivalent(
            product, Localizations.localeOf(context).toLanguageTag())
        : null;
    final savings =
        annual ? _annualSavingsPercent(product, monthlyProduct) : null;
    final secondary = AppAccessibility.textSecondary(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: PressScale(
        onTap: onTap,
        haptic: AppHaptics.selection,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : MotionTokens.fast,
          constraints:
              const BoxConstraints(minHeight: AppAccessibility.minTouchTarget),
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.premiumSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: selected
                  ? AppColors.premium
                  : AppAccessibility.border(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? AppIcons.radioButton : AppIcons.circle,
                color: selected ? AppColors.premium : secondary,
                size: IconSizes.row,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          annual ? l.paywallAnnualPlan : l.paywallMonthlyPlan,
                          style: AppType.callout(weight: FontWeight.w800),
                        ),
                        if (annual)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.sm,
                              vertical: Insets.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.premiumSoft,
                              borderRadius: BorderRadius.circular(Radii.chip),
                            ),
                            child: Text(
                              l.paywallBestValue,
                              style: AppType.micro(
                                color: AppColors.premium,
                                weight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Insets.xxs),
                    Text(
                      _priceWithPeriod(l, product),
                      style: AppType.subhead(
                          weight: FontWeight.w700, color: secondary),
                    ),
                    if (equivalent != null || savings != null) ...[
                      const SizedBox(height: Insets.xxs),
                      Wrap(
                        spacing: Insets.sm,
                        children: [
                          if (equivalent != null)
                            Text(l.paywallAboutPerMonth(equivalent),
                                style: AppType.subhead(color: secondary)),
                          if (savings != null)
                            Text(l.paywallSave(savings),
                                style: AppType.subhead(
                                    weight: FontWeight.w700,
                                    color: AppColors.premium)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the subscription is for, in outcomes the athlete can check against
/// the app: the camp week, fuel, the weekly review, the weight path, and the
/// gated features. The one that brought the athlete here leads the features.
class _Benefits extends StatelessWidget {
  final Feature? highlight;
  const _Benefits({required this.highlight});

  static (String, String) _copy(L l, Feature feature) => switch (feature) {
        Feature.edgeFuelPremiumRecipes => (
            l.paywallBenefitRecipesTitle,
            l.paywallBenefitRecipesBody
          ),
        Feature.fullTechniqueLibrary => (
            l.paywallBenefitDrillsTitle,
            l.paywallBenefitDrillsBody
          ),
        Feature.cornerCoach => (
            l.paywallBenefitCuesTitle,
            l.paywallBenefitCuesBody
          ),
      };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final features = [
      for (final feature in Feature.values)
        if (Entitlements.isProOnly(feature)) feature,
    ];
    final first = highlight;
    if (first != null && features.remove(first)) features.insert(0, first);
    final rows = <_BenefitRow>[
      _BenefitRow(
        icon: AppIcons.calendarBlank,
        title: l.paywallBenefitCampTitle,
        body: l.paywallBenefitCampBody,
      ),
      _BenefitRow(
        icon: AppIcons.forkKnife,
        title: l.paywallBenefitFuelTitle,
        body: l.paywallBenefitFuelBody,
      ),
      _BenefitRow(
        icon: AppIcons.chartLineUp,
        title: l.paywallBenefitReviewTitle,
        body: l.paywallBenefitReviewBody,
      ),
      _BenefitRow(
        icon: AppIcons.scales,
        title: l.paywallBenefitWeightTitle,
        body: l.paywallBenefitWeightBody,
      ),
      for (final feature in features)
        _BenefitRow(
          icon: feature.icon,
          title: _copy(l, feature).$1,
          body: _copy(l, feature).$2,
        ),
    ];
    return AppCard(
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const SizedBox(height: Insets.md),
            row,
          ],
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.premium, size: IconSizes.row),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.callout(weight: FontWeight.w800)),
                const SizedBox(height: Insets.xxs),
                Text(
                  body,
                  style: AppType.subhead(
                      color: AppAccessibility.textSecondary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on a build that cannot start a subscription (no store key).
class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AppCard(
      accent: AppColors.premium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.paywallUnavailableTitle, style: AppType.title2()),
          const SizedBox(height: Insets.xs),
          Text(
            l.paywallUnavailableBody,
            style:
                AppType.subhead(color: AppAccessibility.textSecondary(context)),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.arrowsClockwise, color: AppColors.primary),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              L.of(context).paywallSync,
              style: AppType.subhead(
                  color: AppAccessibility.textSecondary(context)),
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
    return AppCard(
      child: Row(
        children: [
          const SizedBox(
            width: IconSizes.inline,
            height: IconSizes.inline,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: Insets.md),
          Expanded(child: Text(L.of(context).paywallLoading)),
        ],
      ),
    );
  }
}

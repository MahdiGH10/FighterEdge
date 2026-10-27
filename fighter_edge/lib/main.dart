import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'auth/auth_repository.dart';
import 'auth/firebase_auth_repository.dart';
import 'billing/billing_gateway.dart';
import 'billing/revenuecat_billing_gateway.dart';
import 'controllers/auth_controller.dart';
import 'data/data_repository.dart';
import 'data/firestore_data_repository.dart';
import 'features/edge_fuel/data/asset_food_catalog_repository.dart';
import 'features/edge_fuel/data/asset_recipe_catalog_repository.dart';
import 'features/edge_fuel/data/edge_fuel_repository.dart';
import 'features/edge_fuel/data/food_catalog_repository.dart';
import 'features/edge_fuel/data/recipe_catalog_repository.dart';
import 'features/edge_fuel/data/firestore_edge_fuel_repository.dart';
import 'features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'features/edge_fuel/presentation/controllers/nutrition_mode_controller.dart';
import 'features/fight_camp/data/fight_camp_repository.dart';
import 'features/fight_camp/data/firestore_fight_camp_repository.dart';
import 'features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'features/fight_camp/presentation/fight_camp_controller.dart';
import 'features/training_plan/presentation/plan_controller.dart';
import 'firebase_options.dart';
import 'notifications/local_reminder_gateway.dart';
import 'notifications/notification_controller.dart';
import 'notifications/reminder_gateway.dart';
import 'notifications/unavailable_reminder_gateway.dart';
import 'observability/boot_failure.dart';
import 'observability/error_reporter.dart';
import 'observability/telemetry.dart';
import 'privacy/consent.dart';
import 'routing/app_router.dart';
import 'screens/paywall_screen.dart';
import 'security/app_check.dart';
import 'state/app_state.dart';
import 'l10n/gen/app_localizations.dart';
import 'state/first_run_controller.dart';
import 'state/glass_policy_controller.dart';
import 'state/locale_controller.dart';
import 'state/sync_tracker.dart';
import 'notifications/push/push_gateway.dart';
import 'notifications/push/push_registrar.dart';
import 'notifications/push/push_token_repository.dart';
import 'training/reaction/coach_voice.dart';
import 'training/reaction/selectable_coach_voice.dart';
import 'training/reaction/tts_coach_voice.dart';
import 'theme/app_accessibility.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_logo.dart';
import 'widgets/premium_effects.dart';
import 'widgets/primary_button.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // The splash shows the mark on its first frame; decode it before then.
  unawaited(BrandMark.preload().whenComplete(
    () => runApp(const FighterEdgeBootstrap()),
  ));
}

class FighterEdgeBootstrap extends StatefulWidget {
  /// Builds every production service. Tests pass a fake to exercise the
  /// failure screen without Firebase.
  final Future<AppDependencies> Function() initialize;

  const FighterEdgeBootstrap({
    super.key,
    this.initialize = _initializeProductionDependencies,
  });

  @override
  State<FighterEdgeBootstrap> createState() => _FighterEdgeBootstrapState();
}

class _FighterEdgeBootstrapState extends State<FighterEdgeBootstrap> {
  late Future<AppDependencies> _boot = _start();

  /// The FutureBuilder only listens on the next build. A step that fails
  /// before then would surface as an uncaught zone error on top of the
  /// failure screen, so the error is marked handled here; the builder still
  /// receives it.
  Future<AppDependencies> _start() {
    final boot = widget.initialize();
    boot.ignore();
    return boot;
  }

  void _retry() {
    // A block body: an arrow would return the Future to setState, which
    // asserts in debug builds.
    setState(() {
      _boot = _start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDependencies>(
      future: _boot,
      builder: (context, snapshot) {
        final dependencies = snapshot.data;
        if (dependencies != null) {
          return FighterEdgeApp.fromDependencies(dependencies);
        }

        return _BootMaterialApp(
          error: snapshot.hasError ? snapshot.error : null,
          onRetry: _retry,
        );
      },
    );
  }
}

/// Each step runs through [bootStep], so a failure leaves one line in the
/// device log naming the step and the kind of error ("[boot] failed at
/// firebase: missing_plugin"). The screen the athlete sees is unchanged.
Future<AppDependencies> _initializeProductionDependencies() async {
  await bootStep(
    BootStage.firebase,
    () =>
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  );
  // Before the first callable request, so every callable request carries a token.
  await bootStep(BootStage.appCheck, activateAppCheck);
  final crashlyticsSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  // Nothing is collected until the athlete decides (audit M-2). Collection
  // is also off natively, so the SDKs stay quiet until the choice applies.
  final consent = await bootStep(BootStage.consent, () async {
    final consent = ConsentController(
      sink: kIsWeb
          ? const NoopConsentSink()
          : FirebaseConsentSink(crashlyticsSupported: crashlyticsSupported),
    );
    await consent.load();
    return consent;
  });
  final errorReporter = await bootStep(BootStage.errorHandlers, () {
    final ErrorReporter reporter = crashlyticsSupported
        ? ConsentGatedErrorReporter(FirebaseErrorReporter(), consent)
        : const NoopErrorReporter();
    if (crashlyticsSupported) {
      installProductionErrorHandlers(reporter);
    }
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    return reporter;
  });

  // Production auth via Firebase. (LocalAuthRepository remains available as an
  // offline/dev fallback — see docs/firebase_setup.md.)
  final authRepo = await bootStep(BootStage.auth, () async {
    final AuthRepository repo = FirebaseAuthRepository();
    await repo.init();
    return repo;
  });

  // Recorded coach clips, with the phone's own voice as the fallback.
  final coachVoice = SelectableCoachVoice.withClips(phone: TtsCoachVoice());
  unawaited(coachVoice.load());

  // Remote pushes: this phone's messaging token is filed under the signed-in
  // account once notifications are allowed (see PushRegistrar).
  final reminders = LocalReminderGateway();
  final pushRegistrar = PushRegistrar(
    push: FirebasePushGateway(),
    tokens: FirestorePushTokenRepository(),
    reminders: reminders,
  );

  return bootStep(
      BootStage.services,
      () => AppDependencies(
            authRepo: authRepo,
            dataRepo: FirestoreDataRepository(),
            edgeFuelRepo: FirestoreEdgeFuelRepository(),
            fightCampRepo: FirestoreFightCampRepository(),
            billingGateway: RevenueCatBillingGateway(),
            reminderGateway: reminders,
            coachVoice: coachVoice,
            pushRegistrar: pushRegistrar,
            telemetry: kIsWeb
                ? const NoopTelemetry()
                : ConsentGatedTelemetry(FirebaseTelemetry(), consent),
            errorReporter: errorReporter,
            consent: consent,
          ));
}

/// Every production service the app is built from.
///
/// [FighterEdgeApp.fromDependencies] is the only way the bootstrap hands
/// these over, so a service cannot be built here and then silently dropped
/// on the way to the widget tree. `reminderGateway` once was, leaving camp
/// reminders permanently unavailable in production (audit A-1).
class AppDependencies {
  final AuthRepository authRepo;
  final DataRepository dataRepo;
  final EdgeFuelRepository edgeFuelRepo;
  final FightCampRepository fightCampRepo;
  final BillingGateway billingGateway;
  final ReminderGateway reminderGateway;
  final CoachVoice coachVoice;
  final PushRegistrar? pushRegistrar;
  final Telemetry telemetry;
  final ErrorReporter errorReporter;
  final ConsentController consent;

  const AppDependencies({
    required this.authRepo,
    required this.dataRepo,
    required this.edgeFuelRepo,
    required this.fightCampRepo,
    required this.billingGateway,
    required this.reminderGateway,
    required this.coachVoice,
    this.pushRegistrar,
    required this.telemetry,
    required this.errorReporter,
    required this.consent,
  });
}

class FighterEdgeApp extends StatelessWidget {
  final AuthRepository authRepo;
  final DataRepository? dataRepo;
  final EdgeFuelRepository? edgeFuelRepo;
  final FightCampRepository? fightCampRepo;
  final FoodCatalogRepository? foodCatalogRepo;
  final RecipeCatalogRepository? recipeCatalogRepo;
  final BillingGateway? billingGateway;
  final ReminderGateway? reminderGateway;
  final CoachVoice? coachVoice;
  final PushRegistrar? pushRegistrar;
  final Telemetry? telemetry;
  final ErrorReporter? errorReporter;

  /// Null in tests: consent counts as already decided (nothing allowed), so
  /// no prompt covers the screen under test.
  final ConsentController? consent;
  const FighterEdgeApp({
    super.key,
    required this.authRepo,
    this.dataRepo,
    this.edgeFuelRepo,
    this.fightCampRepo,
    this.foodCatalogRepo,
    this.recipeCatalogRepo,
    this.billingGateway,
    this.reminderGateway,
    this.coachVoice,
    this.pushRegistrar,
    this.telemetry,
    this.errorReporter,
    this.consent,
  });

  /// The production wiring: every field of [dependencies], none dropped.
  FighterEdgeApp.fromDependencies(AppDependencies dependencies, {Key? key})
      : this(
          key: key,
          authRepo: dependencies.authRepo,
          dataRepo: dependencies.dataRepo,
          edgeFuelRepo: dependencies.edgeFuelRepo,
          fightCampRepo: dependencies.fightCampRepo,
          billingGateway: dependencies.billingGateway,
          reminderGateway: dependencies.reminderGateway,
          coachVoice: dependencies.coachVoice,
          pushRegistrar: dependencies.pushRegistrar,
          telemetry: dependencies.telemetry,
          errorReporter: dependencies.errorReporter,
          consent: dependencies.consent,
        );

  @override
  Widget build(BuildContext context) {
    final resolvedEdgeFuelRepo = edgeFuelRepo ?? InMemoryEdgeFuelRepository();
    final resolvedFightCampRepo =
        fightCampRepo ?? InMemoryFightCampRepository();
    // The catalogs are bundled assets, so the asset-backed implementations are
    // the right default everywhere -- there is no Firebase variant to swap in.
    // They stay injectable so tests can supply fixtures without an asset
    // bundle.
    final resolvedFoodCatalog = foodCatalogRepo ?? AssetFoodCatalogRepository();
    final resolvedRecipeCatalog = recipeCatalogRepo ??
        AssetRecipeCatalogRepository(foodCatalog: resolvedFoodCatalog);
    return MultiProvider(
      providers: [
        Provider<Telemetry>.value(value: telemetry ?? const NoopTelemetry()),
        Provider<ErrorReporter>.value(
          value: errorReporter ?? const NoopErrorReporter(),
        ),
        if (consent case final consent?)
          ChangeNotifierProvider<ConsentController>.value(value: consent)
        else
          ChangeNotifierProvider<ConsentController>(
            create: (_) => ConsentController.decided(ConsentChoices.none),
          ),
        Provider<ReminderGateway>.value(
          value: reminderGateway ?? const UnavailableReminderGateway(),
        ),
        if (pushRegistrar case final registrar?)
          Provider<PushRegistrar>.value(value: registrar),
        ChangeNotifierProvider(
          create: (context) =>
              NotificationController(gateway: context.read<ReminderGateway>())
                ..load(),
        ),
        Provider<CoachVoice>.value(
          value: coachVoice ?? const SilentCoachVoice(),
        ),
        // The picker lists the voices when the app's voice is selectable.
        if (coachVoice case final SelectableCoachVoice selectable)
          Provider<SelectableCoachVoice>.value(value: selectable),
        ChangeNotifierProvider(
          create: (_) => AuthController(
            authRepo,
            billingGateway: billingGateway,
            telemetry: telemetry,
            errorReporter: errorReporter,
            clearDeletedNotifications: () =>
                context.read<NotificationController>().clearDeletedAccount(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SyncTracker(
            errorReporter: errorReporter ?? const NoopErrorReporter(),
          ),
        ),
        ChangeNotifierProxyProvider<AuthController, AppState>(
          create: (context) => AppState(
            dataRepository: dataRepo,
            sync: context.read<SyncTracker>(),
          ),
          update: (context, auth, state) {
            final appState = state ??
                AppState(
                  dataRepository: dataRepo,
                  sync: context.read<SyncTracker>(),
                );
            appState.setUser(auth.user?.id);
            appState.accessSource = () => auth.accessState;
            return appState;
          },
        ),
        Provider<EdgeFuelRepository>.value(value: resolvedEdgeFuelRepo),
        Provider<FightCampRepository>.value(value: resolvedFightCampRepo),
        Provider<FoodCatalogRepository>.value(value: resolvedFoodCatalog),
        Provider<RecipeCatalogRepository>.value(value: resolvedRecipeCatalog),
        ChangeNotifierProvider(create: (_) => LocaleController()..load()),
        ChangeNotifierProvider(create: (_) => GlassPolicyController()..load()),
        ChangeNotifierProxyProvider<AuthController, FirstRunController>(
          create: (_) => FirstRunController(),
          update: (_, auth, firstRun) =>
              (firstRun ?? FirstRunController())..setUser(auth.user?.id),
        ),
        ChangeNotifierProxyProvider<AuthController, NutritionModeController>(
          create: (_) => NutritionModeController(),
          update: (_, auth, controller) =>
              (controller ?? NutritionModeController())..setUser(auth.user?.id),
        ),
        ChangeNotifierProxyProvider<AuthController, FightCampController>(
          create: (_) => FightCampController(
            repository: resolvedFightCampRepo,
            errorReporter: errorReporter ?? const NoopErrorReporter(),
          ),
          update: (context, auth, controller) => (controller ??
              FightCampController(
                repository: resolvedFightCampRepo,
                errorReporter: errorReporter ?? const NoopErrorReporter(),
              ))
            ..writeGate = context.read<AppState>().requireWrite
            ..setUser(auth.user?.id),
        ),
        ChangeNotifierProxyProvider2<AuthController, FightCampController,
            PlanController>(
          create: (context) => PlanController(
            log: context.read<AppState>(),
            repository: dataRepo,
            sync: context.read<SyncTracker>(),
          ),
          update: (context, auth, fightCamp, plan) => (plan ??
              PlanController(
                log: context.read<AppState>(),
                repository: dataRepo,
                sync: context.read<SyncTracker>(),
              ))
            ..configure(
              userId: auth.user?.id,
              fight: fightCamp.camp,
              goal: auth.user?.goal ?? '',
              level: auth.user?.experienceLevel ?? '',
            ),
        ),
        ChangeNotifierProxyProvider<AuthController, EdgeFuelController>(
          create: (context) => EdgeFuelController(
            repository: resolvedEdgeFuelRepo,
            telemetry: telemetry ?? const NoopTelemetry(),
            errorReporter: errorReporter ?? const NoopErrorReporter(),
            sync: context.read<SyncTracker>(),
          ),
          update: (context, auth, controller) {
            final edgeFuel = controller ??
                EdgeFuelController(
                  repository: resolvedEdgeFuelRepo,
                  telemetry: telemetry ?? const NoopTelemetry(),
                  errorReporter: errorReporter ?? const NoopErrorReporter(),
                  sync: context.read<SyncTracker>(),
                );
            edgeFuel.writeGate = context.read<AppState>().requireWrite;
            edgeFuel.setUser(auth.user?.id);
            return edgeFuel;
          },
        ),
      ],
      child: const _FighterEdgeMaterialApp(),
    );
  }
}

class _FighterEdgeMaterialApp extends StatefulWidget {
  const _FighterEdgeMaterialApp();

  @override
  State<_FighterEdgeMaterialApp> createState() =>
      _FighterEdgeMaterialAppState();
}

class _FighterEdgeMaterialAppState extends State<_FighterEdgeMaterialApp> {
  late final GoRouter _router;
  late final VoidCallback _stopSessionReset;
  late final AppState _appState;
  bool _paywallOpen = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _router = createAppRouter(auth: auth);
    _stopSessionReset = resetStackOnSessionChange(_router, auth);
    // A refused write in a read-only account opens the paywall from here.
    _appState = context.read<AppState>();
    _appState.onWriteBlocked = () => unawaited(_openReadOnlyPaywall());
  }

  Future<void> _openReadOnlyPaywall() async {
    if (_paywallOpen) return;
    _paywallOpen = true;
    try {
      await _router.push<void>(
        AppRoutes.paywall,
        extra: const PaywallRouteArgs(trigger: PaywallTrigger.readOnly),
      );
    } finally {
      _paywallOpen = false;
    }
  }

  @override
  void dispose() {
    _appState.onWriteBlocked = null;
    _stopSessionReset();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fighter Edge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      color: AppColors.background,
      locale: context.watch<LocaleController>().locale,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      routerConfig: _router,
      builder: (context, child) => GlassPolicyHost(
        child: AppAccessibility.builder(context, child),
      ),
    );
  }
}

class _BootMaterialApp extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _BootMaterialApp({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fighter Edge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      color: AppColors.background,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      builder: AppAccessibility.builder,
      home: error == null
          ? const _BrandedBootScreen()
          : _BootFailureScreen(onRetry: onRetry),
    );
  }
}

class _BrandedBootScreen extends StatelessWidget {
  const _BrandedBootScreen();

  @override
  Widget build(BuildContext context) {
    return const BrandSplash();
  }
}

class _BootFailureScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _BootFailureScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(scale: 1),
                  const SizedBox(height: Insets.xl),
                  Text(
                    'Could not start Fighter Edge',
                    textAlign: TextAlign.center,
                    style: AppAccessibility.adjustStyle(
                      context,
                      Theme.of(context).textTheme.titleLarge!,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: AppAccessibility.adjustStyle(
                      context,
                      Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: AppAccessibility.textSecondary(context),
                          ),
                    ),
                  ),
                  const SizedBox(height: Insets.xl),
                  PrimaryButton('Retry', onPressed: onRetry),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

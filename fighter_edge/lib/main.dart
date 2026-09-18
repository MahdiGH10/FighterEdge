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
import 'features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'features/edge_fuel/ai/fake_edge_fuel_ai_gateway.dart';
import 'features/edge_fuel/ai/firebase_edge_fuel_ai_gateway.dart';
import 'features/edge_fuel/data/asset_food_catalog_repository.dart';
import 'features/edge_fuel/data/asset_recipe_catalog_repository.dart';
import 'features/edge_fuel/data/edge_fuel_repository.dart';
import 'features/edge_fuel/data/food_catalog_repository.dart';
import 'features/edge_fuel/data/recipe_catalog_repository.dart';
import 'features/edge_fuel/data/firestore_edge_fuel_repository.dart';
import 'features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'firebase_options.dart';
import 'notifications/local_reminder_gateway.dart';
import 'notifications/reminder_gateway.dart';
import 'notifications/unavailable_reminder_gateway.dart';
import 'observability/error_reporter.dart';
import 'observability/telemetry.dart';
import 'routing/app_router.dart';
import 'state/app_state.dart';
import 'state/first_run_controller.dart';
import 'state/streak_controller.dart';
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
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const FighterEdgeBootstrap());
}

class FighterEdgeBootstrap extends StatefulWidget {
  const FighterEdgeBootstrap({super.key});

  @override
  State<FighterEdgeBootstrap> createState() => _FighterEdgeBootstrapState();
}

class _FighterEdgeBootstrapState extends State<FighterEdgeBootstrap> {
  late Future<_AppDependencies> _boot = _initializeProductionDependencies();

  void _retry() {
    setState(() => _boot = _initializeProductionDependencies());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppDependencies>(
      future: _boot,
      builder: (context, snapshot) {
        final dependencies = snapshot.data;
        if (dependencies != null) {
          return FighterEdgeApp(
            authRepo: dependencies.authRepo,
            dataRepo: dependencies.dataRepo,
            edgeFuelRepo: dependencies.edgeFuelRepo,
            edgeFuelAiGateway: dependencies.edgeFuelAiGateway,
            billingGateway: dependencies.billingGateway,
            telemetry: dependencies.telemetry,
            errorReporter: dependencies.errorReporter,
          );
        }

        return _BootMaterialApp(
          error: snapshot.hasError ? snapshot.error : null,
          onRetry: _retry,
        );
      },
    );
  }
}

Future<_AppDependencies> _initializeProductionDependencies() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final crashlyticsSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  final errorReporter = crashlyticsSupported
      ? FirebaseErrorReporter()
      : const NoopErrorReporter();
  if (crashlyticsSupported) {
    installProductionErrorHandlers(errorReporter);
  }
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Production auth via Firebase. (LocalAuthRepository remains available as an
  // offline/dev fallback — see docs/firebase_setup.md.)
  final AuthRepository authRepo = FirebaseAuthRepository();
  await authRepo.init();

  return _AppDependencies(
    authRepo: authRepo,
    dataRepo: FirestoreDataRepository(),
    edgeFuelRepo: FirestoreEdgeFuelRepository(),
    edgeFuelAiGateway: FirebaseEdgeFuelAiGateway(),
    billingGateway: RevenueCatBillingGateway(),
    reminderGateway: LocalReminderGateway(),
    telemetry: kIsWeb ? const NoopTelemetry() : FirebaseTelemetry(),
    errorReporter: errorReporter,
  );
}

class _AppDependencies {
  final AuthRepository authRepo;
  final DataRepository dataRepo;
  final EdgeFuelRepository edgeFuelRepo;
  final EdgeFuelAiGateway edgeFuelAiGateway;
  final BillingGateway billingGateway;
  final ReminderGateway reminderGateway;
  final Telemetry telemetry;
  final ErrorReporter errorReporter;

  const _AppDependencies({
    required this.authRepo,
    required this.dataRepo,
    required this.edgeFuelRepo,
    required this.edgeFuelAiGateway,
    required this.billingGateway,
    required this.reminderGateway,
    required this.telemetry,
    required this.errorReporter,
  });
}

class FighterEdgeApp extends StatelessWidget {
  final AuthRepository authRepo;
  final DataRepository? dataRepo;
  final EdgeFuelRepository? edgeFuelRepo;
  final EdgeFuelAiGateway? edgeFuelAiGateway;
  final FoodCatalogRepository? foodCatalogRepo;
  final RecipeCatalogRepository? recipeCatalogRepo;
  final BillingGateway? billingGateway;
  final ReminderGateway? reminderGateway;
  final Telemetry? telemetry;
  final ErrorReporter? errorReporter;
  const FighterEdgeApp({
    super.key,
    required this.authRepo,
    this.dataRepo,
    this.edgeFuelRepo,
    this.edgeFuelAiGateway,
    this.foodCatalogRepo,
    this.recipeCatalogRepo,
    this.billingGateway,
    this.reminderGateway,
    this.telemetry,
    this.errorReporter,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedEdgeFuelRepo = edgeFuelRepo ?? InMemoryEdgeFuelRepository();
    final resolvedAiGateway =
        edgeFuelAiGateway ?? const FakeEdgeFuelAiGateway();
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
        Provider<ReminderGateway>.value(
          value: reminderGateway ?? const UnavailableReminderGateway(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthController(
            authRepo,
            billingGateway: billingGateway,
            telemetry: telemetry,
            errorReporter: errorReporter,
          ),
        ),
        ChangeNotifierProxyProvider<AuthController, AppState>(
          create: (_) => AppState(dataRepository: dataRepo),
          update: (_, auth, state) {
            final appState = state ?? AppState(dataRepository: dataRepo);
            appState.setUser(auth.user?.id);
            return appState;
          },
        ),
        Provider<EdgeFuelRepository>.value(value: resolvedEdgeFuelRepo),
        Provider<EdgeFuelAiGateway>.value(value: resolvedAiGateway),
        Provider<FoodCatalogRepository>.value(value: resolvedFoodCatalog),
        Provider<RecipeCatalogRepository>.value(value: resolvedRecipeCatalog),
        ChangeNotifierProxyProvider<AuthController, FirstRunController>(
          create: (_) => FirstRunController(),
          update: (_, auth, firstRun) =>
              (firstRun ?? FirstRunController())..setUser(auth.user?.id),
        ),
        ChangeNotifierProxyProvider<AuthController, StreakController>(
          create: (_) => StreakController(),
          update: (_, auth, streak) =>
              (streak ?? StreakController())..setUser(auth.user?.id),
        ),
        ChangeNotifierProxyProvider<AuthController, EdgeFuelController>(
          create: (_) => EdgeFuelController(repository: resolvedEdgeFuelRepo),
          update: (_, auth, controller) {
            final edgeFuel = controller ??
                EdgeFuelController(repository: resolvedEdgeFuelRepo);
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

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _router = createAppRouter(auth: auth);
    _stopSessionReset = resetStackOnSessionChange(_router, auth);
  }

  @override
  void dispose() {
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
      routerConfig: _router,
      builder: AppAccessibility.builder,
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
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: Center(
          child: PremiumReveal(
            child: BrandLogo(scale: 1.15),
          ),
        ),
      ),
    );
  }
}

class _BootFailureScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _BootFailureScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
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

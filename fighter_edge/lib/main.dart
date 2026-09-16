import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'auth/auth_repository.dart';
import 'auth/firebase_auth_repository.dart';
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
import 'routing/app_router.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Production auth via Firebase. (LocalAuthRepository remains available as an
  // offline/dev fallback — see docs/firebase_setup.md.)
  final AuthRepository authRepo = FirebaseAuthRepository();
  await authRepo.init();

  runApp(
    FighterEdgeApp(
      authRepo: authRepo,
      dataRepo: FirestoreDataRepository(),
      edgeFuelRepo: FirestoreEdgeFuelRepository(),
      edgeFuelAiGateway: FirebaseEdgeFuelAiGateway(),
    ),
  );
}

class FighterEdgeApp extends StatelessWidget {
  final AuthRepository authRepo;
  final DataRepository? dataRepo;
  final EdgeFuelRepository? edgeFuelRepo;
  final EdgeFuelAiGateway? edgeFuelAiGateway;
  final FoodCatalogRepository? foodCatalogRepo;
  final RecipeCatalogRepository? recipeCatalogRepo;
  const FighterEdgeApp({
    super.key,
    required this.authRepo,
    this.dataRepo,
    this.edgeFuelRepo,
    this.edgeFuelAiGateway,
    this.foodCatalogRepo,
    this.recipeCatalogRepo,
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
        ChangeNotifierProvider(create: (_) => AuthController(authRepo)),
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
  late final _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fighter Edge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      color: AppColors.background,
      routerConfig: _router,
    );
  }
}

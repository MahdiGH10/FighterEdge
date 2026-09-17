import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/billing/billing_gateway.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/controllers/auth_controller.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/ai/fake_edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/data/asset_food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/asset_recipe_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/recipe_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/state/app_state.dart';

/// Shared test utilities. (No `_test.dart` suffix so the runner ignores it.)

const testEmail = 'ayoub@test.com';
const testPassword = 'secret1';
const testName = 'Ayoub';

/// Builds a fresh [LocalAuthRepository] backed by mocked SharedPreferences,
/// optionally already signed in (and optionally on the Pro plan).
Future<LocalAuthRepository> makeRepo({
  bool signedIn = false,
  Plan plan = Plan.free,
  bool onboarded = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final repo = LocalAuthRepository();
  await repo.init();
  if (signedIn) {
    await repo.signUpWithEmail(
      email: testEmail,
      password: testPassword,
      displayName: testName,
    );
    if (onboarded) {
      await repo.completeOnboarding(
        goal: 'Build fight-camp structure',
        experienceLevel: 'Intermediate',
        weeklyTrainingDays: 4,
        startingWeightKg: 77.2,
      );
    }
    if (plan == Plan.pro) {
      await repo.debugSetPlan(Plan.pro);
    }
  }
  return repo;
}

/// Wraps [home] with the app's providers and a MaterialApp for widget tests.
Widget wrapApp(
  Widget home, {
  required LocalAuthRepository repo,
  AppState? state,
  EdgeFuelRepository? edgeFuelRepo,
  EdgeFuelAiGateway? edgeFuelAiGateway,
  FoodCatalogRepository? foodCatalogRepo,
  RecipeCatalogRepository? recipeCatalogRepo,
  BillingGateway? billingGateway,
}) {
  final resolvedEdgeFuelRepo = edgeFuelRepo ?? InMemoryEdgeFuelRepository();
  final resolvedAiGateway = edgeFuelAiGateway ?? const FakeEdgeFuelAiGateway();
  // Widget tests have no asset bundle, so the catalogs default to reading the
  // real JSON off disk. Tests get the shipped content unless they pass a fake.
  final resolvedFoodCatalog = foodCatalogRepo ??
      AssetFoodCatalogRepository(
        loadString: (path) => File(path).readAsString(),
      );
  final resolvedRecipeCatalog = recipeCatalogRepo ??
      AssetRecipeCatalogRepository(
        foodCatalog: resolvedFoodCatalog,
        loadString: (path) => File(path).readAsString(),
      );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => AuthController(repo, billingGateway: billingGateway),
      ),
      ChangeNotifierProvider(create: (_) => state ?? AppState()),
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
    child: MaterialApp(home: home),
  );
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/l10n/gen/app_localizations.dart';
import 'package:fighter_edge/state/locale_controller.dart';
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
import 'package:fighter_edge/notifications/reminder_gateway.dart';
import 'package:fighter_edge/notifications/unavailable_reminder_gateway.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/state/first_run_controller.dart';
import 'package:fighter_edge/state/streak_controller.dart';

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
  ReminderGateway? reminderGateway,
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
      Provider<ReminderGateway>.value(
        value: reminderGateway ?? const UnavailableReminderGateway(),
      ),
      ChangeNotifierProvider(create: (_) => LocaleController()..load()),
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
    // Mirrors the app: the language switch in Settings has to actually
    // change the words on screen in tests too.
    child: Builder(
      builder: (context) => MaterialApp(
        locale: context.watch<LocaleController>().locale,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: home,
      ),
    ),
  );
}

/// In-memory [ReminderGateway] for tests: reports as available, records what
/// it was asked to do, and never touches a real notifications plugin.
class FakeReminderGateway implements ReminderGateway {
  bool permissionGranted;
  int permissionRequests = 0;
  Set<int>? scheduledWeekdays;
  TimeOfDay? scheduledTime;
  bool cancelled = false;

  FakeReminderGateway({this.permissionGranted = true});

  @override
  bool get isAvailable => true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleTrainingReminders({
    required Set<int> weekdays,
    required TimeOfDay time,
  }) async {
    scheduledWeekdays = weekdays;
    scheduledTime = time;
  }

  @override
  Future<void> cancelAll() async {
    cancelled = true;
    scheduledWeekdays = null;
  }
}

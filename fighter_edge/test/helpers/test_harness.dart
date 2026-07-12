import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/controllers/auth_controller.dart';
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
}) async {
  SharedPreferences.setMockInitialValues({});
  final repo = LocalAuthRepository();
  await repo.init();
  if (signedIn) {
    await repo.signUpWithEmail(
        email: testEmail, password: testPassword, displayName: testName);
    if (plan == Plan.pro) {
      await repo.updatePlan(repo.currentUser!.copyWith(plan: Plan.pro));
    }
  }
  return repo;
}

/// Wraps [home] with the app's providers and a MaterialApp for widget tests.
Widget wrapApp(
  Widget home, {
  required LocalAuthRepository repo,
  AppState? state,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthController(repo)),
      ChangeNotifierProvider(create: (_) => state ?? AppState()),
    ],
    child: MaterialApp(home: home),
  );
}

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../billing/subscription.dart';
import '../debug/component_gallery_screen.dart';
import '../features/edge_fuel/presentation/controllers/recipe_library_controller.dart';
import '../features/edge_fuel/presentation/screens/edge_fuel_plan_screen.dart';
import '../features/edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';
import '../features/edge_fuel/presentation/screens/recipe_library_screen.dart';
import '../screens/auth/auth_gate.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/magic_link_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/paywall_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/round_timer_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/weight_tracker_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const root = '/';
  static const gallery = '/gallery';
  static const forgotPassword = '/auth/forgot-password';
  static const magicLink = '/auth/magic-link';
  static const signup = '/auth/signup';
  static const paywall = '/paywall';
  static const profile = '/profile';
  static const roundTimer = '/round-timer';
  static const settings = '/settings';
  static const weightTracker = '/weight-tracker';
  static const fuelPlan = '/fuel/plan';
  static const fuelSetup = '/fuel/setup';
  static const fuelRecipes = '/fuel/recipes';
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.root,
    routes: [
      GoRoute(
        path: AppRoutes.root,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const AuthGate(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.magicLink,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const MagicLinkScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signup,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const SignupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        pageBuilder: (context, state) {
          final highlight =
              state.extra is Feature ? state.extra as Feature : null;
          return _appPage(
            state: state,
            child: PaywallScreen(highlight: highlight),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.roundTimer,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const RoundTimerScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.weightTracker,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const WeightTrackerScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.fuelPlan,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const EdgeFuelPlanScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.fuelSetup,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const EdgeFuelSetupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.fuelRecipes,
        pageBuilder: (context, state) {
          final filters = state.extra is RecipeFilters
              ? state.extra as RecipeFilters
              : null;
          return _appPage(
            state: state,
            child: RecipeLibraryScreen(initialFilters: filters),
          );
        },
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.gallery,
          pageBuilder: (context, state) => _appPage(
            state: state,
            child: const ComponentGalleryScreen(),
          ),
        ),
    ],
  );
}

Page<void> _appPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CupertinoPage<void>(
    key: state.pageKey,
    name: state.name,
    restorationId: state.pageKey.value,
    child: child,
  );
}

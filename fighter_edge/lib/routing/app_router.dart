import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../billing/subscription.dart';
import '../controllers/auth_controller.dart';
import '../debug/component_gallery_screen.dart';
import '../features/edge_fuel/presentation/controllers/recipe_library_controller.dart';
import '../features/edge_fuel/presentation/screens/edge_fuel_plan_screen.dart';
import '../features/edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';
import '../features/edge_fuel/presentation/screens/recipe_library_screen.dart';
import '../screens/auth/auth_gate.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/magic_link_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/legal_screen.dart';
import '../screens/paywall_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/round_timer_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/weight_tracker_screen.dart';
import 'app_page_transitions.dart';

class AppRoutes {
  AppRoutes._();

  static const root = '/';
  static const gallery = '/gallery';
  static const forgotPassword = '/auth/forgot-password';
  static const magicLink = '/auth/magic-link';
  static const verifyEmail = '/auth/verify-email';
  static const signup = '/auth/signup';
  static String legal(LegalDocument doc) => '/legal/${doc.slug}';
  static const paywall = '/paywall';
  static const profile = '/profile';
  static const roundTimer = '/round-timer';
  static const settings = '/settings';
  static const weightTracker = '/weight-tracker';
  static const fuelPlan = '/fuel/plan';
  static const fuelSetup = '/fuel/setup';
  static const fuelRecipes = '/fuel/recipes';
}

/// Routes a signed-out user may sit on. Everything else needs a session.
const _signedOutRoutes = {
  AppRoutes.root,
  AppRoutes.forgotPassword,
  AppRoutes.magicLink,
  AppRoutes.signup,
  AppRoutes.gallery,
};

/// Routes that only make sense without a session. Reaching one while signed
/// in means the user just finished signing up or in from it.
const _signedOutOnlyRoutes = {
  AppRoutes.forgotPassword,
  AppRoutes.magicLink,
  AppRoutes.signup,
};

/// Guards direct navigation (deep links, `go`) against the session.
///
/// This only sees the location being navigated to. Screens that were
/// `push`ed above the gate are invisible to it — go_router keeps them out of
/// the route information — so session changes are handled by
/// [resetStackOnSessionChange] instead.
String? authRedirect(AuthStatus status, String location) {
  if (status == AuthStatus.unknown) return null;
  final signedIn = status == AuthStatus.authenticated;
  // Legal pages are linked from signup, so they must work without a session.
  final isLegal = location.startsWith('/legal/');
  if (!signedIn && !isLegal && !_signedOutRoutes.contains(location)) {
    return AppRoutes.root;
  }
  if (signedIn && _signedOutOnlyRoutes.contains(location)) {
    return AppRoutes.root;
  }
  return null;
}

/// Sends the stack back to the gate whenever the user signs in or out.
///
/// [AuthGate] already swaps what `/` shows, but it cannot touch screens pushed
/// above it. Without this, signing out or deleting the account from Settings
/// left Settings on screen with no user behind it, and signup had to `pop()`
/// itself back to a gate it could not be sure was underneath.
///
/// Returns a callback that stops listening.
VoidCallback resetStackOnSessionChange(GoRouter router, AuthController auth) {
  var last = auth.status;
  void onChange() {
    final status = auth.status;
    if (status == last) return;
    last = status;
    if (status == AuthStatus.unknown) return;
    router.go(AppRoutes.root);
  }

  auth.addListener(onChange);
  return () => auth.removeListener(onChange);
}

/// [auth] drives [authRedirect]. It is optional only so the router can still
/// be built in isolation; the app always passes it.
GoRouter createAppRouter({AuthController? auth}) {
  return GoRouter(
    initialLocation: AppRoutes.root,
    redirect: auth == null
        ? null
        : (context, state) => authRedirect(auth.status, state.matchedLocation),
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
        path: AppRoutes.verifyEmail,
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: const VerifyEmailScreen(),
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
        path: '/legal/:doc',
        pageBuilder: (context, state) => _appPage(
          state: state,
          child: LegalScreen(
            document: LegalDocument.fromSlug(state.pathParameters['doc']) ??
                LegalDocument.terms,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        pageBuilder: (context, state) {
          final highlight =
              state.extra is Feature ? state.extra as Feature : null;
          // A decision interrupting the current thread, not a step deeper into
          // it — so it rises rather than slides in from the side.
          return AppPageTransitions.modal(
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

/// Forward navigation within a thread — the default for every route that is a
/// step deeper rather than a peer or an interruption. Delegates to
/// [AppPageTransitions.push] so "how does a push look" has one definition.
Page<void> _appPage({
  required GoRouterState state,
  required Widget child,
}) =>
    AppPageTransitions.push(state: state, child: child);

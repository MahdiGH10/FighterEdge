import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../routing/app_navigation.dart';
import '../routing/app_router.dart';
import '../screens/paywall_screen.dart';

/// Runs an action that saves new data, or opens the paywall instead when the
/// account is read-only.
///
/// This is the UI half of the read-only gate. `AppState.requireWrite()` is the
/// safety net underneath it; wrapping a button here additionally lets the
/// screen choose the paywall trigger. Anything that must keep working in a
/// read-only account (history, plan and weight views, settings, sign-out,
/// account deletion, consent withdrawal, Restore, fight-week safety text)
/// must not go through here.
class GatedAction {
  GatedAction._();

  /// Whether [context]'s account may save new data right now. Without an
  /// [AuthController] in the tree (standalone widget tests) nothing is locked.
  static bool canWrite(BuildContext context) {
    try {
      return Provider.of<AuthController>(context, listen: false).canWrite;
    } on ProviderNotFoundException {
      return true;
    }
  }

  /// Runs [action] when writing is allowed; otherwise opens the paywall for
  /// [trigger]. Returns whether [action] ran.
  static bool run(
    BuildContext context,
    VoidCallback action, {
    PaywallTrigger trigger = PaywallTrigger.readOnly,
  }) {
    if (canWrite(context)) {
      action();
      return true;
    }
    AppNavigation.push<void>(
      context,
      AppRoutes.paywall,
      extra: PaywallRouteArgs(trigger: trigger),
      fallbackBuilder: (_) => PaywallScreen(trigger: trigger),
    );
    return false;
  }

  /// A tap handler that goes through [run]. Use it as a button's `onPressed`.
  static VoidCallback wrap(
    BuildContext context,
    VoidCallback action, {
    PaywallTrigger trigger = PaywallTrigger.readOnly,
  }) =>
      () => run(context, action, trigger: trigger);
}

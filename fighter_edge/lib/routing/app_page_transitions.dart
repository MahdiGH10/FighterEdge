import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// The app's page-transition vocabulary.
///
/// Every route used to share one transition, which meant the motion said the
/// same thing everywhere and therefore said nothing. These three name the
/// *relationship* between the pages, which is the only justification a
/// transition has:
///
/// - [push] — the new page is deeper in the same thread. Keeps the iOS
///   edge-swipe back gesture, which is load-bearing on this platform and
///   must not be traded away for a prettier animation.
/// - [fadeThrough] — the pages are peers with no spatial relationship
///   (a lateral swap). Nothing slides, because nothing moved.
/// - [modal] — the page is a decision interrupting the current thread. It
///   rises from the bottom and the caller stays behind it.
///
/// All three collapse to an instant cut when the platform reports reduced
/// motion, checked per-transition rather than globally so a screen that opts
/// out does not have to re-implement the check.
class AppPageTransitions {
  AppPageTransitions._();

  /// Forward navigation within a thread. This is the default and should stay
  /// the default: [CupertinoPage] is what provides swipe-back.
  static Page<void> push({
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

  /// A lateral swap between peers. Cross-fades with a slight scale so the
  /// incoming page reads as arriving rather than blinking into place.
  static Page<void> fadeThrough({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.name,
      restorationId: state.pageKey.value,
      transitionDuration: MotionTokens.standard,
      reverseTransitionDuration: MotionTokens.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: MotionTokens.settle,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            // Starts fractionally small; large enough to feel like arrival,
            // small enough that text never visibly resamples.
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// A decision that interrupts the current thread — a paywall, a destructive
  /// confirmation, anything the user must resolve before continuing.
  static Page<void> modal({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.name,
      restorationId: state.pageKey.value,
      transitionDuration: MotionTokens.standard,
      reverseTransitionDuration: MotionTokens.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: MotionTokens.settle,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      child: child,
    );
  }
}

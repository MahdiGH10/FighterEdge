import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

class AppNavigation {
  AppNavigation._();

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    String location, {
    required WidgetBuilder fallbackBuilder,
    Object? extra,
  }) {
    if (GoRouter.maybeOf(context) != null) {
      return context.push<T>(location, extra: extra);
    }

    return Navigator.of(context).push<T>(
      CupertinoPageRoute(builder: fallbackBuilder),
    );
  }

  static void replace(
    BuildContext context,
    String location, {
    required WidgetBuilder fallbackBuilder,
    Object? extra,
  }) {
    if (GoRouter.maybeOf(context) != null) {
      context.replace(location, extra: extra);
      return;
    }

    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(builder: fallbackBuilder),
    );
  }
}

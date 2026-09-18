import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/state/first_run_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FirstRunController> loaded(String userId) async {
    final controller = FirstRunController()..setUser(userId);
    await pumpEventQueue();
    return controller;
  }

  test('stays off for accounts that never ran setup on this device', () async {
    final controller = await loaded('veteran');
    expect(controller.isActive, isFalse);
  });

  test('begin turns it on and survives a restart', () async {
    final first = await loaded('rookie');
    await first.begin();
    expect(first.isActive, isTrue);

    final restarted = await loaded('rookie');
    expect(restarted.isActive, isTrue);
  });

  test('progress is kept per user', () async {
    final a = await loaded('a');
    await a.begin();
    await a.markTourDone();

    final b = await loaded('b');
    expect(b.isActive, isFalse);
    expect(b.tourDone, isFalse);
  });

  test('the first meal is only celebrated once', () async {
    final controller = await loaded('rookie');
    await controller.begin();
    expect(controller.markFirstMealLogged(), isTrue);
    expect(controller.markFirstMealLogged(), isFalse);
    await pumpEventQueue();

    final restarted = await loaded('rookie');
    expect(restarted.firstMealLogged, isTrue);
  });

  test('dismissing the checklist ends the first-week layer', () async {
    final controller = await loaded('rookie');
    await controller.begin();
    await controller.dismissChecklist();
    expect(controller.isActive, isFalse);

    final restarted = await loaded('rookie');
    expect(restarted.isActive, isFalse);
  });
}

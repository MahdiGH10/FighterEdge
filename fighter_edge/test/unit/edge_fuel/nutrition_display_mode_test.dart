import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_display_mode.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/nutrition_mode_controller.dart';

void main() {
  group('NutritionDisplayMode', () {
    test('normal shows everything', () {
      const m = NutritionDisplayMode.normal;
      expect(m.showsNutrition, isTrue);
      expect(m.showsNumbers, isTrue);
      expect(m.allowsNutritionReminders, isTrue);
    });

    test('hide numbers keeps food but no numbers and no reminders', () {
      const m = NutritionDisplayMode.hideNumbers;
      expect(m.showsNutrition, isTrue);
      expect(m.showsNumbers, isFalse);
      expect(m.allowsNutritionReminders, isFalse);
    });

    test('paused shows no nutrition at all', () {
      const m = NutritionDisplayMode.paused;
      expect(m.showsNutrition, isFalse);
      expect(m.showsNumbers, isFalse);
      expect(m.allowsNutritionReminders, isFalse);
    });

    test('storage names round trip and anything unknown reads as normal', () {
      for (final m in NutritionDisplayMode.values) {
        expect(NutritionDisplayMode.fromStorage(m.storageName), m);
      }
      for (final bad in [null, '', 'Paused', 'off', '3']) {
        expect(
            NutritionDisplayMode.fromStorage(bad), NutritionDisplayMode.normal);
      }
    });
  });

  group('NutritionModeController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('shows nothing nutrition-shaped until the choice has been read',
        () async {
      SharedPreferences.setMockInitialValues({
        'fe_nutrition_mode.u1': 'paused',
      });
      final c = NutritionModeController()..setUser('u1');
      // Before the read finishes, nothing is visible and no reminder is
      // allowed, so a paused athlete never sees a flash of numbers.
      expect(c.loaded, isFalse);
      expect(c.visible, isFalse);
      expect(c.numbersVisible, isFalse);
      expect(c.remindersAllowed, isFalse);

      await pumpEventQueue();
      expect(c.loaded, isTrue);
      expect(c.mode, NutritionDisplayMode.paused);
      expect(c.visible, isFalse);
      c.dispose();
    });

    test('a fresh account is normal', () async {
      final c = NutritionModeController()..setUser('u1');
      await pumpEventQueue();
      expect(c.mode, NutritionDisplayMode.normal);
      expect(c.visible, isTrue);
      expect(c.numbersVisible, isTrue);
      expect(c.remindersAllowed, isTrue);
      c.dispose();
    });

    test('the choice is remembered per account, on this device', () async {
      final c = NutritionModeController()..setUser('u1');
      await pumpEventQueue();
      await c.setMode(NutritionDisplayMode.paused);
      expect(c.visible, isFalse);

      final again = NutritionModeController()..setUser('u1');
      await pumpEventQueue();
      expect(again.mode, NutritionDisplayMode.paused);

      final other = NutritionModeController()..setUser('u2');
      await pumpEventQueue();
      expect(other.mode, NutritionDisplayMode.normal);

      c.dispose();
      again.dispose();
      other.dispose();
    });

    test('switching account loads that account\'s choice, never the last one',
        () async {
      SharedPreferences.setMockInitialValues({
        'fe_nutrition_mode.u1': 'paused',
      });
      final c = NutritionModeController()..setUser('u1');
      await pumpEventQueue();
      expect(c.mode, NutritionDisplayMode.paused);

      c.setUser('u2');
      expect(c.loaded, isFalse);
      expect(c.mode, NutritionDisplayMode.normal);
      await pumpEventQueue();
      expect(c.mode, NutritionDisplayMode.normal);
      expect(c.loaded, isTrue);
      c.dispose();
    });

    test('a slow read for a previous account cannot land after a switch',
        () async {
      SharedPreferences.setMockInitialValues({
        'fe_nutrition_mode.u1': 'paused',
      });
      final c = NutritionModeController()..setUser('u1');
      c.setUser('u2'); // before u1's read returns
      await pumpEventQueue();
      expect(c.mode, NutritionDisplayMode.normal);
      c.dispose();
    });

    test('signing out clears the mode', () async {
      SharedPreferences.setMockInitialValues({
        'fe_nutrition_mode.u1': 'paused',
      });
      final c = NutritionModeController()..setUser('u1');
      await pumpEventQueue();
      c.setUser(null);
      expect(c.mode, NutritionDisplayMode.normal);
      // Nothing is stored for nobody, so the answer is known at once.
      expect(c.loaded, isTrue);
      c.dispose();
    });

    test('the mode is stored only on the device, as one plain word', () async {
      final c = NutritionModeController()..setUser('u1');
      await pumpEventQueue();
      await c.setMode(NutritionDisplayMode.paused);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fe_nutrition_mode.u1'), 'paused');
      expect(prefs.getKeys().where((k) => k.contains('nutrition_mode')),
          hasLength(1));
      c.dispose();
    });

    test('setting the same mode, or with no account, changes nothing',
        () async {
      final c = NutritionModeController();
      await c.setMode(NutritionDisplayMode.paused);
      expect(c.mode, NutritionDisplayMode.normal);

      c.setUser('u1');
      await pumpEventQueue();
      var notified = 0;
      c.addListener(() => notified++);
      await c.setMode(NutritionDisplayMode.normal);
      expect(notified, 0);
      c.dispose();
    });
  });
}

import 'package:fighter_edge/auth/auth_repository.dart';
import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/controllers/auth_controller.dart';
import 'package:fighter_edge/notifications/notification_controller.dart';
import 'package:fighter_edge/notifications/notification_history_store.dart';
import 'package:fighter_edge/notifications/notification_settings_store.dart';
import 'package:fighter_edge/notifications/unavailable_reminder_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
      'delete clears local data across restart without touching another account',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalAuthRepository();
    await repo.init();
    final deleted = await repo.signUpWithEmail(
      email: 'deleted@example.test',
      password: 'secret1',
      displayName: 'Deleted',
    );
    final prefs = await SharedPreferences.getInstance();
    final oldKeys = [
      'fe_food_memory.v1.${deleted.id}',
      'fe_nutrition_mode.${deleted.id}',
      'fe_first_run.${deleted.id}.active',
      'fe_first_run.${deleted.id}.tourDone',
      'fe_first_run.${deleted.id}.firstMeal',
      'fe_first_run.${deleted.id}.remindersAsked',
      'fe_first_run.${deleted.id}.dismissed',
    ];
    for (final key in oldKeys) {
      await prefs.setString(key, 'old');
    }
    const otherKey = 'fe_food_memory.v1.other-account';
    await prefs.setString(otherKey, 'other');
    await prefs.setString(NotificationSettingsStore.settingsKey, 'old');
    await prefs.setString(NotificationHistoryStore.key, 'old');
    await prefs.setBool(NotificationSettingsStore.permissionRequestedKey, true);

    final notifications = NotificationController(
      gateway: const UnavailableReminderGateway(),
    );
    final auth = AuthController(repo,
        clearDeletedNotifications: notifications.clearDeletedAccount);

    await expectLater(
      auth.deleteAccount(currentPassword: 'wrong'),
      throwsA(isA<AuthException>()),
    );
    expect(prefs.getString(oldKeys.first), 'old');
    expect(repo.currentUser, isNotNull);

    await auth.deleteAccount(currentPassword: 'secret1');
    expect(repo.currentUser, isNull);
    for (final key in oldKeys) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(prefs.getString(otherKey), 'other');
    expect(prefs.containsKey(NotificationSettingsStore.settingsKey), isFalse);
    expect(prefs.containsKey(NotificationHistoryStore.key), isFalse);
    expect(prefs.containsKey(NotificationSettingsStore.permissionRequestedKey),
        isFalse);

    auth.dispose();
    notifications.dispose();
    final restarted = LocalAuthRepository();
    await restarted.init();
    expect(restarted.currentUser, isNull);
    await expectLater(
      restarted.signInWithEmail(
          email: 'deleted@example.test', password: 'secret1'),
      throwsA(isA<AuthException>()),
    );
    await restarted.signUpWithEmail(
        email: 'other@example.test', password: 'secret2', displayName: 'Other');
    expect(prefs.getString(otherKey), 'other');
    for (final key in oldKeys) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
  });
}

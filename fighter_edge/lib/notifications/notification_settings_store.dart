import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'domain/notification_channel.dart';
import 'domain/notification_settings.dart';

/// Keeps [NotificationSettings] on the device, as one small versioned JSON
/// value in `SharedPreferences`. Device-local on purpose: nothing here is
/// synced, and a bad or newer value reads as the all-off defaults.
class NotificationSettingsStore {
  NotificationSettingsStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const settingsKey = 'notifications.settings';
  static const permissionRequestedKey = 'notifications.permissionRequested';

  /// The switch an earlier version of the app kept for weekly training
  /// reminders. Read once, by the migration, and then removed.
  static const legacyCampRemindersKey = 'settings.campReminders';

  static const int version = 1;

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  /// The saved settings. The first time this runs for a device that had camp
  /// reminders switched on, the session reminder channel comes on at the
  /// usual 18:00, so nobody loses a reminder they already had. After that the
  /// old switch is never read again.
  Future<NotificationSettings> load() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(settingsKey);
      if (raw != null) return decode(raw) ?? NotificationSettings();

      final migrated = prefs.getBool(legacyCampRemindersKey) == true
          ? NotificationSettings(
              enabledChannels: {NotificationChannel.sessionReminder},
            )
          : NotificationSettings();
      await prefs.setString(settingsKey, encode(migrated));
      await prefs.remove(legacyCampRemindersKey);
      return migrated;
    } catch (_) {
      // Storage unavailable: everything stays off, which is the safe state.
      return NotificationSettings();
    }
  }

  Future<void> save(NotificationSettings settings) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(settingsKey, encode(settings));
    } catch (_) {
      // The in-memory settings still apply for this run.
    }
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(settingsKey);
    await prefs.remove(permissionRequestedKey);
    await prefs.remove(legacyCampRemindersKey);
  }

  /// Whether the OS permission prompt has already been shown. Lets Settings
  /// tell "never asked" from "asked and turned down".
  Future<bool> loadPermissionRequested() async {
    try {
      return (await _prefs).getBool(permissionRequestedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> savePermissionRequested(bool value) async {
    try {
      await (await _prefs).setBool(permissionRequestedKey, value);
    } catch (_) {}
  }

  static String encode(NotificationSettings s) => jsonEncode({
        'v': version,
        'enabled': [for (final c in s.enabledChannels) c.name]..sort(),
        'usualHour': s.usualTrainingHour,
        'usualMinute': s.usualTrainingMinute,
        'sessionLead': s.sessionLeadMinutes,
        'fuelLead': s.fuelWindowLeadMinutes,
        'quietStart': s.quietHours.startMinute,
        'quietEnd': s.quietHours.endMinute,
        'pauseAll': s.pauseAll,
        'pauseNutrition': s.pauseNutrition,
        'pausedUntil': {
          for (final e in s.pausedUntil.entries)
            e.key.name: e.value.toIso8601String(),
        },
      });

  /// Null for text that is not a version-1 settings object.
  static NotificationSettings? decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['v'] != version) return null;
      final defaults = NotificationSettings();
      return NotificationSettings(
        enabledChannels: {
          for (final name in (json['enabled'] as List? ?? const []))
            if (_channel(name) case final c?) c,
        },
        usualTrainingHour:
            _int(json['usualHour'], 0, 23) ?? defaults.usualTrainingHour,
        usualTrainingMinute:
            _int(json['usualMinute'], 0, 59) ?? defaults.usualTrainingMinute,
        sessionLeadMinutes:
            _int(json['sessionLead'], 0, 720) ?? defaults.sessionLeadMinutes,
        fuelWindowLeadMinutes:
            _int(json['fuelLead'], 0, 720) ?? defaults.fuelWindowLeadMinutes,
        quietHours: QuietHours(
          startMinute: _int(json['quietStart'], 0, 1439) ??
              defaults.quietHours.startMinute,
          endMinute:
              _int(json['quietEnd'], 0, 1439) ?? defaults.quietHours.endMinute,
        ),
        pauseAll: json['pauseAll'] == true,
        pauseNutrition: json['pauseNutrition'] == true,
        pausedUntil: {
          for (final e in ((json['pausedUntil'] as Map?) ?? const {}).entries)
            if (_channel(e.key) case final c?)
              if (DateTime.tryParse('${e.value}') case final until?) c: until,
        },
      );
    } catch (_) {
      return null;
    }
  }

  static NotificationChannel? _channel(Object? name) {
    for (final c in NotificationChannel.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  static int? _int(Object? value, int min, int max) =>
      value is int && value >= min && value <= max ? value : null;
}

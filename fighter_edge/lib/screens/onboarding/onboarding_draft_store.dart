import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A device-only draft for an unfinished, consented onboarding flow.
/// Each account has its own key; account deletion removes that key.
class OnboardingDraftStore {
  const OnboardingDraftStore();

  static String key(String userId) => 'fe_onboarding_draft.v1.$userId';

  Future<Map<String, dynamic>?> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key(userId));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String userId, Map<String, dynamic> draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key(userId), jsonEncode(draft));
    } catch (_) {
      // The current screen still works when device storage is unavailable.
    }
  }

  Future<void> clear(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key(userId));
    } catch (_) {
      // Server completion remains authoritative.
    }
  }
}

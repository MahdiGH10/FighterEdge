import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's language, remembered on the device.
///
/// Device-wide rather than per account: the language belongs to the phone in
/// the hand, and someone who switches to German should not see English again
/// after signing into another account.
class LocaleController extends ChangeNotifier {
  static const _key = 'fe_locale';

  /// Languages the app offers. English first — it is the source language and
  /// the fallback for anything not yet translated.
  static const supported = [Locale('en'), Locale('de')];

  Locale? _locale;
  bool _loaded = false;

  /// Null means "follow the system", which is the default.
  Locale? get locale => _locale;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code != null && supported.any((l) => l.languageCode == code)) {
        _locale = Locale(code);
      }
    } catch (_) {
      // No stored preference is the system default, not an error.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, locale.languageCode);
      }
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}

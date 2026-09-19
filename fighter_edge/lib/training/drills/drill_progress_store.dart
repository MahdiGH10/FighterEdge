import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drill.dart';

/// Remembers, per account, how far along each drill is and which are
/// bookmarked. On-device only: it is the athlete's own study log, not data
/// the server needs.
class DrillProgressStore extends ChangeNotifier {
  DrillProgressStore({required String? userId})
      : _key = 'drills.v1.${userId ?? 'guest'}';

  final String _key;
  final Map<String, DrillProgress> _progress = {};
  final Set<String> _bookmarks = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  DrillProgress progressOf(String drillId) =>
      _progress[drillId] ?? DrillProgress.none;

  bool isBookmarked(String drillId) => _bookmarks.contains(drillId);

  int get sharpCount =>
      _progress.values.where((p) => p == DrillProgress.sharp).length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final progress = json['progress'] as Map<String, dynamic>? ?? {};
        for (final entry in progress.entries) {
          final value = DrillProgress.values
              .where((p) => p.name == entry.value)
              .firstOrNull;
          if (value != null) _progress[entry.key] = value;
        }
        _bookmarks.addAll(
          (json['bookmarks'] as List<dynamic>? ?? const []).cast<String>(),
        );
      }
    } catch (_) {
      // A corrupt or unreadable entry starts the log fresh rather than
      // breaking the library.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setProgress(String drillId, DrillProgress progress) async {
    if (progress == DrillProgress.none) {
      _progress.remove(drillId);
    } else {
      _progress[drillId] = progress;
    }
    notifyListeners();
    await _save();
  }

  Future<void> toggleBookmark(String drillId) async {
    if (!_bookmarks.remove(drillId)) _bookmarks.add(drillId);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'progress': {
            for (final e in _progress.entries) e.key: e.value.name,
          },
          'bookmarks': _bookmarks.toList(),
        }),
      );
    } catch (_) {
      // Progress stays correct in memory for this session either way.
    }
  }
}

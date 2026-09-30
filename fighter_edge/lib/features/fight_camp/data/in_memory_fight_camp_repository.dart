import 'dart:async';

import '../domain/fight_camp.dart';
import 'fight_camp_repository.dart';

/// For tests and the offline build (`main_local.dart`).
class InMemoryFightCampRepository implements FightCampRepository {
  final Map<String, FightCamp> _fights = {};
  final Map<String, StreamController<FightCamp?>> _controllers = {};

  @override
  Stream<FightCamp?> watchFight(String userId) {
    final controller = _controllers.putIfAbsent(
      userId,
      () => StreamController<FightCamp?>.broadcast(),
    );
    Future.microtask(() => controller.add(_fights[userId]));
    return controller.stream;
  }

  @override
  Future<void> saveFight(String userId, FightCamp camp) async {
    _fights[userId] = camp;
    _controllers[userId]?.add(camp);
  }

  @override
  Future<void> deleteFight(String userId) async {
    _fights.remove(userId);
    _controllers[userId]?.add(null);
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
  }
}

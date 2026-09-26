import '../domain/fight_camp.dart';

/// Persistence boundary for the athlete's next fight. One fight at a time:
/// setting a new one replaces the old. Follows the `DataRepository` and
/// `EdgeFuelRepository` convention (watchX streams, saveX writes); widgets
/// never see a Firebase type.
abstract class FightCampRepository {
  /// The saved fight, or null when there is none.
  Stream<FightCamp?> watchFight(String userId);

  Future<void> saveFight(String userId, FightCamp camp);

  Future<void> deleteFight(String userId);
}

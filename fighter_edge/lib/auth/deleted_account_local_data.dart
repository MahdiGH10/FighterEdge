import 'package:shared_preferences/shared_preferences.dart';

/// Removes device-only state for the deleted account after server deletion.
/// Other accounts' keys are deliberately left intact.
class DeletedAccountLocalData {
  const DeletedAccountLocalData();

  Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) =>
        key == 'fe_food_memory.v1.$userId' ||
        key == 'fe_nutrition_mode.$userId' ||
        key.startsWith('fe_first_run.$userId.'));
    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
  }
}

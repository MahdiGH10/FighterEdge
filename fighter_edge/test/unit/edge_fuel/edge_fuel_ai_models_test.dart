import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_models.dart';

void main() {
  group('EdgeFuelAiResponse.fromJson', () {
    test('parses a well-formed response', () {
      final response = EdgeFuelAiResponse.fromJson({
        'summary': 'You are on track.',
        'actions': [
          {
            'type': 'logging',
            'title': 'Log dinner',
            'reason': 'Coverage is partial today',
            'recipeIds': <String>[],
          },
        ],
        'warnings': ['pace reduced'],
        'requiresProfessionalReview': false,
        'factsUsed': ['targetCalories'],
        'contentVersion': 'sp1',
      });

      expect(response.summary, 'You are on track.');
      expect(response.actions.single.type, AiActionType.logging);
      expect(response.actions.single.title, 'Log dinner');
      expect(response.warnings, ['pace reduced']);
      expect(response.requiresProfessionalReview, isFalse);
      expect(response.contentVersion, 'sp1');
    });

    test('tolerates a missing/malformed map instead of throwing', () {
      final response = EdgeFuelAiResponse.fromJson(const {});

      expect(response.summary, '');
      expect(response.actions, isEmpty);
      expect(response.warnings, isEmpty);
      expect(response.requiresProfessionalReview, isFalse);
    });

    test('falls back to logging for an unrecognized action type', () {
      final response = EdgeFuelAiResponse.fromJson({
        'summary': 'x',
        'actions': [
          {'type': 'not-a-real-type', 'title': 't', 'reason': 'r'},
        ],
      });

      expect(response.actions.single.type, AiActionType.logging);
    });

    test('parses version-2 premium Fighter Brief sections', () {
      final response = EdgeFuelAiResponse.fromJson({
        'summary': 'Your brief is ready.',
        'brief': {
          'nextAction': 'Log your next meal.',
          'mealSuggestion': 'Anchor it around protein.',
          'trainingTiming': 'Keep your planned session time.',
          'weeklyAdjustment': 'Hold this target for the week.',
        },
      });

      expect(response.brief?.nextAction, 'Log your next meal.');
      expect(response.brief?.mealSuggestion, 'Anchor it around protein.');
      expect(response.brief?.trainingTiming, 'Keep your planned session time.');
      expect(
          response.brief?.weeklyAdjustment, 'Hold this target for the week.');
    });
  });
}

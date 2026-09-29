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

    test('parses a Corner Brief\'s lines', () {
      final response = EdgeFuelAiResponse.fromJson({
        'lines': [
          {'topic': 'fuel', 'text': 'Log your next meal.'},
          {'topic': 'training', 'text': 'Keep your planned session.'},
        ],
      });

      expect(response.lines, hasLength(2));
      expect(response.lines[0].topic, CornerTopic.fuel);
      expect(response.lines[0].text, 'Log your next meal.');
      expect(response.lines[1].topic, CornerTopic.training);
    });

    test('drops a line with an unknown topic or empty text', () {
      final response = EdgeFuelAiResponse.fromJson({
        'lines': [
          {'topic': 'not-a-real-topic', 'text': 'x'},
          {'topic': 'fuel', 'text': ''},
          {'topic': 'weight', 'text': 'Weigh in this morning.'},
        ],
      });

      expect(response.lines, hasLength(1));
      expect(response.lines.single.topic, CornerTopic.weight);
    });
  });
}

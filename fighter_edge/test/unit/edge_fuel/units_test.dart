import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/units.dart';

void main() {
  group('weight conversion', () {
    test('kgToLb matches the known conversion factor', () {
      expect(kgToLb(80), closeTo(176.37, 0.01));
    });

    test('lbToKg matches the known conversion factor', () {
      expect(lbToKg(176.37), closeTo(80, 0.01));
    });

    test('round trip kg -> lb -> kg is stable', () {
      const original = 73.4;
      final roundTripped = lbToKg(kgToLb(original));
      expect(roundTripped, closeTo(original, 0.0001));
    });

    test('round trip lb -> kg -> lb is stable', () {
      const original = 158.0;
      final roundTripped = kgToLb(lbToKg(original));
      expect(roundTripped, closeTo(original, 0.0001));
    });

    test('zero round-trips to zero', () {
      expect(lbToKg(kgToLb(0)), 0);
    });
  });

  group('height conversion', () {
    test('inToCm matches the known conversion factor', () {
      expect(inToCm(70), closeTo(177.8, 0.01));
    });

    test('cmToIn matches the known conversion factor', () {
      expect(cmToIn(177.8), closeTo(70, 0.01));
    });

    test('round trip cm -> in -> cm is stable', () {
      const original = 180.0;
      final roundTripped = inToCm(cmToIn(original));
      expect(roundTripped, closeTo(original, 0.0001));
    });

    test('round trip in -> cm -> in is stable', () {
      const original = 69.5;
      final roundTripped = cmToIn(inToCm(original));
      expect(roundTripped, closeTo(original, 0.0001));
    });
  });
}

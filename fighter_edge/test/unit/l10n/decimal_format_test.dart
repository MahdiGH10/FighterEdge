import 'package:fighter_edge/l10n/decimal_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English keeps the "." toStringAsFixed already used', () {
    expect(formatFixedDecimal(79.5, 'en'), '79.5');
    expect(formatFixedDecimal(79, 'en'), '79.0');
    expect(formatFixedDecimal(1234.5, 'en'), '1234.5', reason: 'no grouping');
  });

  test('German reads with a comma, not a point', () {
    expect(formatFixedDecimal(79.5, 'de'), '79,5');
    expect(formatFixedDecimal(79, 'de'), '79,0');
  });

  test('decimals stays fixed like toStringAsFixed, never dropped', () {
    expect(formatFixedDecimal(80, 'de'), '80,0');
    expect(formatFixedDecimal(80.04, 'de', decimals: 2), '80,04');
  });

  test('decimals: 0 never adds a separator to strip', () {
    expect(formatFixedDecimal(79.6, 'en', decimals: 0), '80');
    expect(formatFixedDecimal(79.6, 'de', decimals: 0), '80');
  });

  test('rounds the same way toStringAsFixed does', () {
    expect(formatFixedDecimal(79.45, 'en', decimals: 1), '79.5');
    expect(formatFixedDecimal(79.45, 'de', decimals: 1), '79,5');
  });
}

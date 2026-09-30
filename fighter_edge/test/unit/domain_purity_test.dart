import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CLAUDE.md: domain code is pure Dart, with no Flutter, Firebase, network,
/// platform, or clock dependency. This keeps that rule from depending on
/// review alone.
const _pureDirectories = [
  'lib/features/edge_fuel/domain',
  'lib/features/fight_camp/domain',
  'lib/features/daily_snapshot/domain',
];

final _forbidden = <RegExp>[
  RegExp(r'''import\s+['"]package:flutter'''),
  RegExp(
      r'''import\s+['"]package:(firebase|cloud_firestore|cloud_functions)'''),
  RegExp(r'''import\s+['"]package:(http|dio|clock|shared_preferences)[/']'''),
  RegExp(r'''import\s+['"]dart:(io|ui|html|isolate)['"]'''),
  RegExp(r'DateTime\.now\('),
];

void main() {
  test('domain directories import nothing impure and never read the clock', () {
    final violations = <String>[];
    var files = 0;
    for (final path in _pureDirectories) {
      final directory = Directory(path);
      expect(directory.existsSync(), isTrue, reason: path);
      for (final file in directory.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        files++;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (_forbidden.any((pattern) => pattern.hasMatch(line))) {
            violations.add('${file.path}:${i + 1}: ${line.trim()}');
          }
        }
      }
    }
    expect(files, greaterThan(10));
    expect(violations, isEmpty);
  });
}

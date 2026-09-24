// Fails CI when line coverage drops below a floor.
//
//   dart run tool/coverage_gate.dart coverage/lcov.info 78
//
// Generated localizations (lib/l10n/gen/) are excluded: they are machine
// written, and counting them would let untested product code hide behind
// thousands of trivially executed getters.
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: coverage_gate.dart <lcov.info> <minimum %>');
    exit(64);
  }
  final file = File(args[0]);
  final minimum = double.tryParse(args[1]);
  if (!file.existsSync() || minimum == null) {
    stderr.writeln('coverage gate: missing ${args[0]} or bad minimum');
    exit(64);
  }

  var found = 0;
  var hit = 0;
  var skip = false;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      skip = line.contains('lib/l10n/gen/');
    } else if (!skip && line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (!skip && line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    }
  }
  if (found == 0) {
    stderr.writeln('coverage gate: no lines found in ${args[0]}');
    exit(1);
  }

  final percent = hit * 100 / found;
  final summary = 'Line coverage ${percent.toStringAsFixed(1)}% '
      '($hit/$found, excluding generated l10n); minimum $minimum%.';
  final stepSummary = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (stepSummary != null) {
    File(stepSummary).writeAsStringSync('### Coverage\n\n$summary\n',
        mode: FileMode.append);
  }
  if (percent < minimum) {
    stderr.writeln('coverage gate FAILED: $summary');
    exit(1);
  }
  stdout.writeln('coverage gate passed: $summary');
}

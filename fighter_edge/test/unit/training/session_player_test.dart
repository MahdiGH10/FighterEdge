import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fighter_edge/features/training_plan/domain/models/intensity.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_block.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_session.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_kind.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_template.dart';
import 'package:fighter_edge/training/session/session_player.dart';

void main() {
  var now = DateTime(2026, 10, 23);
  setUp(() => now = DateTime(2026, 10, 23));

  PlannedSession session(List<PlannedBlock> blocks) => PlannedSession(
        id: '2026-10-23.skill',
        date: now,
        kind: SessionKind.skill,
        intensity: Intensity.moderate,
        titleKey: 'skill',
        estimatedMinutes: 45,
        blocks: blocks,
      );

  test('placeholder session remains one neutral block', () {
    final player = SessionPlayer(
        session(const [
          PlannedBlock(kind: BlockKind.main, minutes: 45),
        ]),
        clock: Clock(() => now));
    expect(player.stages, hasLength(1));
    expect(player.stages.single.kind, BlockKind.main);
    expect(player.totalLength, const Duration(minutes: 45));
  });

  test('wall time crosses stages after suspension, including rests', () {
    final player = SessionPlayer(
        session(const [
          PlannedBlock(kind: BlockKind.warmUp, minutes: 2),
          PlannedBlock(
              kind: BlockKind.drillRounds, rounds: 2, workSec: 60, restSec: 30),
          PlannedBlock(kind: BlockKind.coolDown, minutes: 1),
        ]),
        clock: Clock(() => now));
    player.start();
    now = now.add(const Duration(minutes: 3, seconds: 10));
    final duringRest = player.snapshot();
    expect(duringRest.stage!.isRest, isTrue);
    expect(duringRest.remaining, const Duration(seconds: 20));
    now = now.add(const Duration(minutes: 2, seconds: 20));
    expect(player.snapshot().isDone, isTrue);
  });

  test('pause banks elapsed time and skip advances one stage', () {
    final player = SessionPlayer(
        session(const [
          PlannedBlock(kind: BlockKind.warmUp, minutes: 2),
          PlannedBlock(kind: BlockKind.main, minutes: 5),
        ]),
        clock: Clock(() => now));
    player.start();
    now = now.add(const Duration(seconds: 30));
    player.pause();
    now = now.add(const Duration(minutes: 10));
    expect(player.snapshot().remaining, const Duration(seconds: 90));
    player.skipStage();
    expect(player.snapshot().stage!.kind, BlockKind.main);
    expect(player.snapshot().remaining, const Duration(minutes: 5));
    player.start();
    now = now.add(const Duration(minutes: 5));
    expect(player.snapshot().isDone, isTrue);
  });
}

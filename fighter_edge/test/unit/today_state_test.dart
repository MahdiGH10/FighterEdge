import 'package:fighter_edge/features/training_plan/domain/models/session_status.dart';
import 'package:fighter_edge/screens/home/today_hero.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dated session drives training and done states', () {
    expect(
      todayState(
        hasPlan: true,
        sessionStatus: SessionStatus.today,
        daysToFight: null,
      ),
      TodayState.training,
    );
    expect(
      todayState(
        hasPlan: true,
        sessionStatus: SessionStatus.completed,
        daysToFight: null,
      ),
      TodayState.done,
    );
  });

  test('rest stays recovery and a missing plan gets an entry action', () {
    expect(
      todayState(hasPlan: true, sessionStatus: null, daysToFight: null),
      TodayState.recovery,
    );
    expect(
      todayState(hasPlan: false, sessionStatus: null, daysToFight: null),
      TodayState.noPlan,
    );
  });

  test('fight week takes priority without inventing a session', () {
    expect(
      todayState(
        hasPlan: true,
        sessionStatus: SessionStatus.today,
        daysToFight: 4,
      ),
      TodayState.fightWeek,
    );
    expect(
      todayState(
        hasPlan: true,
        sessionStatus: SessionStatus.today,
        daysToFight: 8,
      ),
      TodayState.training,
    );
  });
}

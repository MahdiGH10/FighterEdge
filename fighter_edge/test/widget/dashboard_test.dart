import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/state/app_state.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('shows the fighter, sections and live weight', (tester) async {
    final repo = await makeRepo(signedIn: true);
    final state = AppState();
    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: state,
    ));
    await tester.pump();

    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('Ayoub'), findsOneWidget);
    expect(find.text('WEEKLY OVERVIEW'), findsOneWidget);
    expect(find.text('77.2'), findsWidgets); // weight stat from AppState
  });

  testWidgets('weight card reacts to AppState changes', (tester) async {
    final repo = await makeRepo(signedIn: true);
    final state = AppState();
    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: state,
    ));
    await tester.pump();

    state.addWeight(DateTime.now(), 75.0);
    await tester.pump();
    expect(find.text('75.0'), findsWidgets);
  });
}

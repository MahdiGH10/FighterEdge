import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fighter_edge/theme/app_icons.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';

void main() {
  testWidgets(
      'bottom navigation announces each tab once and remains actionable',
      (tester) async {
    final handle = tester.ensureSemantics();
    var selected = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: AppBottomNav(
          items: const [
            NavItem(AppIcons.house, 'Home'),
            NavItem(AppIcons.boxingGlove, 'Train'),
          ],
          currentIndex: 0,
          onTap: (index) => selected = index,
        ),
      ),
    ));

    expect(find.bySemanticsLabel('Home'), findsOneWidget);
    expect(find.bySemanticsLabel('Home Home'), findsNothing);
    final home = tester.getSemantics(find.bySemanticsLabel('Home'));
    tester.binding.renderViews.first.owner!.semanticsOwner!
        .performAction(home.id, SemanticsAction.tap);
    expect(selected, 0);
    await tester.tap(find.bySemanticsLabel('Train'));
    expect(selected, 1);
    handle.dispose();
  });
}

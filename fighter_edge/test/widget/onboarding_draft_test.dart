import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/screens/onboarding/onboarding_draft_store.dart';
import 'package:fighter_edge/screens/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_harness.dart';

class _SlowDraftRepository extends InMemoryEdgeFuelRepository {
  final release = Completer<void>();
  int saves = 0;

  @override
  Future<void> saveProfileDraft(
      String userId, NutritionSetupDraft draft) async {
    saves++;
    await release.future;
    await super.saveProfileDraft(userId, draft);
  }
}

void main() {
  testWidgets('onboarding restores its step and answer after restart',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    final userId = repo.currentUser!.id;
    await tester.pumpWidget(wrapApp(const OnboardingScreen(), repo: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Improve technique'));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(OnboardingDraftStore.key(userId)), isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(wrapApp(const OnboardingScreen(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(find.ancestor(
      of: find.text('Improve technique'),
      matching: find.byType(ChoiceChip),
    ));
    expect(chip.selected, isTrue);
  });

  test('draft store separates accounts and clears only the selected account',
      () async {
    SharedPreferences.setMockInitialValues({});
    const store = OnboardingDraftStore();
    await store.write('fighter-a', {'step': 2});
    await store.write('fighter-b', {'step': 4});
    await store.clear('fighter-a');
    expect(await store.read('fighter-a'), isNull);
    expect(await store.read('fighter-b'), {'step': 4});
  });

  testWidgets('rapid submit taps commit the setup once', (tester) async {
    final repo = await makeRepo(signedIn: true);
    final drafts = _SlowDraftRepository();
    await tester.pumpWidget(
        wrapApp(const OnboardingScreen(), repo: repo, edgeFuelRepo: drafts));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    final submit = find.text('Skip detailed target for now');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(drafts.saves, 1);
    drafts.release.complete();
    await tester.pumpAndSettle();
    expect(find.text('Your first Fighter Edge plan is ready'), findsOneWidget);
  });
}

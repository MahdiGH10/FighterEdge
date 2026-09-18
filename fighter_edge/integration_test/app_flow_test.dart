import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/widgets/primary_button.dart';

/// Full end-to-end journey against the local backend:
/// signup → dashboard → hit a Pro gate → upgrade → gate unlocks → sign out.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signup, upgrade, unlock Pro, and sign out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalAuthRepository();
    await repo.init();

    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pumpAndSettle();

    // 1. Land on login, go to signup.
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // 2. Create an account.
    await tester.enterText(find.byType(TextField).at(0), 'Ayoub');
    await tester.enterText(find.byType(TextField).at(1), 'journey@test.com');
    await tester.enterText(find.byType(TextField).at(2), 'journey-pass-1');
    await tester.enterText(find.byType(TextField).at(3), 'journey-pass-1');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    // 3. Dashboard is shown.
    expect(find.text('DASHBOARD'), findsOneWidget);

    // 4. More tab → Corner Coach (Pro-gated).
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corner Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Corner Coach is Pro'), findsOneWidget);

    // 5. Upgrade via the paywall.
    await tester.tap(find.byType(PrimaryButton)); // "Unlock with Pro"
    await tester.pumpAndSettle();
    expect(find.text('Unlock your full edge'), findsOneWidget);
    await tester.tap(find.byType(PrimaryButton)); // "Upgrade to Pro"
    await tester.pumpAndSettle();

    // 6. Back on Corner Coach, now unlocked.
    expect(find.text('Corner Coach is Pro'), findsNothing);
    expect(find.text('ROUND 3'), findsOneWidget);
    expect(repo.currentUser!.isPro, isTrue);

    // 7. Sign out from Profile.
    await tester.tap(find.byIcon(Icons.chevron_left)); // custom header back
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    final signOut = find.byType(GhostButton);
    await tester.scrollUntilVisible(signOut, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    // 8. Back to login.
    expect(find.text('Welcome back'), findsOneWidget);
  });
}

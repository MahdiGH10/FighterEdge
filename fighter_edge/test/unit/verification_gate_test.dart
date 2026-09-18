import 'package:fighter_edge/auth/verification_gate.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({
  required bool verified,
  DateTime? createdAt,
}) {
  return AppUser(
    id: 'u1',
    email: 'fighter@example.com',
    displayName: 'Fighter',
    plan: Plan.free,
    createdAt: createdAt ?? DateTime(2026, 9, 17),
    emailVerified: verified,
  );
}

void main() {
  group('what an unverified account may do', () {
    test('a verified user may do everything gated', () {
      final user = _user(verified: true);
      for (final action in VerifiedAction.values) {
        expect(
          VerificationGate.allows(user, action, supportsVerification: true),
          isTrue,
          reason: '$action should be allowed for a verified account',
        );
      }
    });

    test('an unverified user may not buy Pro or use the AI coach', () {
      final user = _user(verified: false);
      expect(
        VerificationGate.allows(user, VerifiedAction.purchasePro,
            supportsVerification: true),
        isFalse,
      );
      expect(
        VerificationGate.allows(user, VerifiedAction.aiCoach,
            supportsVerification: true),
        isFalse,
      );
    });

    test('the gate is open when the backend has no verification concept', () {
      // Otherwise the local/dev repository could never reach gated surfaces.
      final user = _user(verified: false);
      for (final action in VerifiedAction.values) {
        expect(
          VerificationGate.allows(user, action, supportsVerification: false),
          isTrue,
        );
      }
    });

    test('a signed-out user is refused', () {
      expect(
        VerificationGate.allows(null, VerifiedAction.purchasePro,
            supportsVerification: true),
        isFalse,
      );
    });
  });

  group('how loudly the app asks', () {
    final signedUp = DateTime(2026, 9, 1);

    VerificationStage stageAt(int daysLater, {bool verified = false}) {
      return VerificationGate.stageFor(
        _user(verified: verified, createdAt: signedUp),
        supportsVerification: true,
        now: signedUp.add(Duration(days: daysLater)),
      );
    }

    test('a verified account is never asked', () {
      expect(stageAt(0, verified: true), VerificationStage.none);
      expect(stageAt(30, verified: true), VerificationStage.none);
    });

    test('a fresh account gets a quiet reminder', () {
      expect(stageAt(0), VerificationStage.reminder);
      expect(
          stageAt(VerificationGate.graceDays - 1), VerificationStage.reminder);
    });

    test('past the grace period it becomes urgent', () {
      expect(stageAt(VerificationGate.graceDays), VerificationStage.urgent);
      expect(
          stageAt(VerificationGate.blockingDays - 1), VerificationStage.urgent);
    });

    test('long overdue it blocks', () {
      expect(
          stageAt(VerificationGate.blockingDays), VerificationStage.blocking);
      expect(stageAt(90), VerificationStage.blocking);
    });

    test('the free loop stays open through the whole grace period', () {
      // The product rule is that a free user keeps the core loop. Blocking
      // must not start before the documented window.
      for (var day = 0; day < VerificationGate.blockingDays; day++) {
        expect(
          stageAt(day),
          isNot(VerificationStage.blocking),
          reason: 'day $day should not be blocking',
        );
      }
    });

    test('no stage at all when the backend lacks verification', () {
      expect(
        VerificationGate.stageFor(_user(verified: false),
            supportsVerification: false),
        VerificationStage.none,
      );
    });
  });

  group('refusal copy', () {
    test('every gated action explains itself', () {
      for (final action in VerifiedAction.values) {
        final message = VerificationGate.refusalMessage(action);
        expect(message, isNotEmpty);
        expect(message.toLowerCase(), contains('verify'));
      }
    });
  });
}

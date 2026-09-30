import 'package:cloud_functions/cloud_functions.dart';

/// What our server says before a rewarded video.
enum RewardTicketStatus {
  /// A video can earn today's brief; [RewardTicket.token] is set.
  ready,

  /// A reward is already waiting (e.g. the last brief failed): no video.
  unused,

  /// Today's rewarded brief was already written.
  usedToday,

  /// The AI coach data-sharing consent is missing.
  consentRequired,

  /// Pro, or an unverified email: this offer is not for this account.
  notEligible,

  /// Offline, AI paused, or anything unexpected.
  unavailable,
}

class RewardTicket {
  const RewardTicket(this.status, {this.token});

  final RewardTicketStatus status;

  /// One-time token passed to AdMob in place of the account ID.
  final String? token;
}

abstract class RewardTicketGateway {
  Future<RewardTicket> start();
}

/// Calls the `startRewardedBrief` Cloud Function.
class FirebaseRewardTicketGateway implements RewardTicketGateway {
  FirebaseRewardTicketGateway({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<RewardTicket> start() async {
    try {
      final result = await _functions
          .httpsCallable('startRewardedBrief')
          .call<Map<String, dynamic>>()
          .timeout(const Duration(seconds: 20));
      final data = Map<String, dynamic>.from(result.data as Map);
      final token = data['token'];
      return switch (data['status']) {
        'ready' when token is String && token.isNotEmpty =>
          RewardTicket(RewardTicketStatus.ready, token: token),
        'unused' => const RewardTicket(RewardTicketStatus.unused),
        'usedToday' => const RewardTicket(RewardTicketStatus.usedToday),
        'consentRequired' =>
          const RewardTicket(RewardTicketStatus.consentRequired),
        'notEligible' => const RewardTicket(RewardTicketStatus.notEligible),
        _ => const RewardTicket(RewardTicketStatus.unavailable),
      };
    } catch (_) {
      return const RewardTicket(RewardTicketStatus.unavailable);
    }
  }
}

/// No server: tests and offline previews.
class UnavailableRewardTicketGateway implements RewardTicketGateway {
  const UnavailableRewardTicketGateway();

  @override
  Future<RewardTicket> start() async =>
      const RewardTicket(RewardTicketStatus.unavailable);
}

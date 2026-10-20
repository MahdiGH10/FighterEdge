import 'session_template.dart';

/// A block of a planned session, scaled for the week's phase and length.
class PlannedBlock {
  const PlannedBlock({
    required this.kind,
    this.minutes,
    this.rounds,
    this.workSec,
    this.restSec,
    this.drillIds = const [],
    this.cueKeys = const [],
  });

  final BlockKind kind;
  final int? minutes;
  final int? rounds;
  final int? workSec;
  final int? restSec;
  final List<String> drillIds;
  final List<String> cueKeys;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'minutes': minutes,
        'rounds': rounds,
        'workSec': workSec,
        'restSec': restSec,
        'drillIds': drillIds,
        'cueKeys': cueKeys,
      };
}

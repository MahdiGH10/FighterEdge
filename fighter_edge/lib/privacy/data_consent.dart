import 'package:flutter/foundation.dart';

/// What an account has explicitly agreed to, stored on the profile document
/// under `consents` so it follows the athlete across devices. Device-level
/// analytics and crash-report choices live in `consent.dart` instead.
///
/// The Privacy Policy relies on these as the legal basis for special-category
/// data (Art. 9(2)(a) GDPR), so they are asked for before the data is
/// entered or sent, never assumed.
enum DataConsentPurpose {
  /// Storing and using health, body, nutrition and training data.
  healthData('healthData', currentVersion: 1),

  /// Sending plan facts, food preferences and chat messages to the AI
  /// provider (OpenRouter, USA) when the athlete uses the AI coach.
  aiCoach('aiCoach', currentVersion: 1);

  const DataConsentPurpose(this.key, {required this.currentVersion});

  /// Field name under `users/{uid}.consents`. Shared with the server.
  final String key;

  /// Bump when the disclosure changes materially: every account is asked
  /// again, because it agreed to the old wording.
  final int currentVersion;
}

@immutable
class ConsentRecord {
  final int version;

  /// When the server recorded it. Null while the write is still pending.
  final DateTime? grantedAt;

  const ConsentRecord({required this.version, this.grantedAt});
}

@immutable
class DataConsents {
  final Map<DataConsentPurpose, ConsentRecord> _records;

  const DataConsents._(this._records);

  static const none = DataConsents._({});

  /// Every purpose at its current version. For tests and local demos.
  static DataConsents allCurrent({DateTime? at}) => DataConsents._({
        for (final purpose in DataConsentPurpose.values)
          purpose:
              ConsentRecord(version: purpose.currentVersion, grantedAt: at),
      });

  /// Granted, and to the wording the app shows today.
  bool allows(DataConsentPurpose purpose) =>
      (_records[purpose]?.version ?? 0) >= purpose.currentVersion;

  ConsentRecord? recordFor(DataConsentPurpose purpose) => _records[purpose];

  DataConsents granted(DataConsentPurpose purpose, {DateTime? at}) =>
      DataConsents._({
        ..._records,
        purpose: ConsentRecord(version: purpose.currentVersion, grantedAt: at),
      });

  DataConsents withdrawn(DataConsentPurpose purpose) =>
      DataConsents._({..._records}..remove(purpose));

  /// Reads `users/{uid}.consents`. Unknown purposes and malformed entries
  /// are ignored, which reads as "not granted". [readDate] converts a
  /// backend-specific timestamp (Firestore's `Timestamp`), so this model stays
  /// free of backend imports.
  factory DataConsents.fromProfile(
    Object? raw, {
    DateTime? Function(Object? value)? readDate,
  }) {
    if (raw is! Map) return none;
    final records = <DataConsentPurpose, ConsentRecord>{};
    for (final purpose in DataConsentPurpose.values) {
      final entry = raw[purpose.key];
      if (entry is! Map) continue;
      final version = entry['version'];
      if (version is! num) continue;
      records[purpose] = ConsentRecord(
        version: version.toInt(),
        grantedAt: readDate?.call(entry['grantedAt']) ??
            _parseDate(entry['grantedAt']),
      );
    }
    return DataConsents._(records);
  }

  /// Local persistence (the on-device demo backend), not Firestore.
  Map<String, Object?> toJson() => {
        for (final MapEntry(key: purpose, value: record) in _records.entries)
          purpose.key: {
            'version': record.version,
            'grantedAt': record.grantedAt?.millisecondsSinceEpoch,
          },
      };

  static DateTime? _parseDate(Object? value) => switch (value) {
        DateTime() => value,
        int() => DateTime.fromMillisecondsSinceEpoch(value),
        String() => DateTime.tryParse(value),
        _ => null,
      };

  @override
  bool operator ==(Object other) =>
      other is DataConsents &&
      mapEquals(
        {for (final e in _records.entries) e.key: e.value.version},
        {for (final e in other._records.entries) e.key: e.value.version},
      );

  @override
  int get hashCode => Object.hashAll(
      [for (final p in DataConsentPurpose.values) _records[p]?.version]);
}

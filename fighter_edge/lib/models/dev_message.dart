/// A short message from the developer to one athlete, written into that
/// user's profile document and shown once inside the app.
///
/// Deliberately tiny and read-only on the client: no inbox, no threads, no
/// push plumbing. It exists so a beta tester can be told something that
/// happened to their account — "you have Pro now" — inside the app that
/// changed, rather than in a chat app somewhere else.
class DevMessage {
  /// Stable id, so a dismissed message stays dismissed and a new one shows.
  final String id;
  final String title;
  final String body;

  /// Who it is from, shown as written ("Dev Mahdi").
  final String from;
  final DateTime? sentAt;

  const DevMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.from,
    this.sentAt,
  });

  bool get isValid => id.isNotEmpty && title.isNotEmpty && body.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'from': from,
        'sentAt': sentAt?.toIso8601String(),
      };

  /// Returns null for anything malformed or empty — a broken message must
  /// never take the screen it would appear on down with it.
  static DevMessage? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final message = DevMessage(
      id: (json['id'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      body: (json['body'] as String?)?.trim() ?? '',
      from: (json['from'] as String?)?.trim() ?? '',
      sentAt: _parseDate(json['sentAt']),
    );
    return message.isValid ? message : null;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }
}

import 'dart:ui';

import '../l10n/gen/app_localizations.dart';
import 'domain/notification_planner.dart';

/// A localized notification title and body.
class NotificationText {
  const NotificationText({required this.title, required this.body});

  final String title;
  final String body;
}

/// Turns the planner's content key and plain arguments into the words on the
/// lock screen, from the ARB files (English and German).
///
/// The text is baked in when the notification is scheduled, so the scheduler
/// builds a new [NotificationCopy] and reschedules when the app language
/// changes. Arguments are only ever times as `HH:mm`; nothing here can print a
/// measurement.
class NotificationCopy {
  NotificationCopy(this._l, {required String languageCode})
      : _twentyFourHour = languageCode != 'en';

  /// The copy for [locale]. Anything but German reads as English, the app's
  /// fallback.
  factory NotificationCopy.forLocale(Locale locale) {
    final supported = locale.languageCode == 'de' ? 'de' : 'en';
    return NotificationCopy(lookupL(Locale(supported)),
        languageCode: supported);
  }

  final L _l;
  final bool _twentyFourHour;

  /// Every content key the planner can emit that this class can word. A test
  /// holds the planner to this list.
  static final List<String> contentKeys = List.unmodifiable([
    'notif.session.soon',
    'notif.session.soonFuel',
    'notif.fuel.window',
    'notif.review.weekly',
    'notif.fight.week',
    'notif.fight.tomorrow',
    'notif.weighIn.reminder',
    'notif.protein.evening',
    'notif.trial.ending',
    for (var i = 0; i < NotificationPlanner.tipCount; i++) 'notif.tip.$i',
  ]);

  /// The words for [contentKey], or null for a key this class does not know,
  /// in which case the caller drops the notification rather than show a raw
  /// key.
  NotificationText? resolve(String contentKey, Map<String, String> args) {
    final tip = RegExp(r'^notif\.tip\.(\d+)$').firstMatch(contentKey);
    if (tip != null) {
      final body = _tipBody(int.parse(tip.group(1)!));
      return body == null
          ? null
          : NotificationText(title: _l.notifTipTitle, body: body);
    }
    return switch (contentKey) {
      'notif.session.soon' => NotificationText(
          title: _l.notifSessionSoonTitle,
          body: _l.notifSessionSoonBody(_time(args['sessionAt'])),
        ),
      'notif.session.soonFuel' => NotificationText(
          title: _l.notifSessionSoonFuelTitle(_time(args['sessionAt'])),
          body: _l.notifSessionSoonFuelBody,
        ),
      'notif.fuel.window' => NotificationText(
          title: _l.notifFuelWindowTitle,
          body: _l.notifFuelWindowBody(_time(args['sessionAt'])),
        ),
      'notif.review.weekly' => NotificationText(
          title: _l.notifReviewWeeklyTitle,
          body: _l.notifReviewWeeklyBody,
        ),
      'notif.fight.week' => NotificationText(
          title: _l.notifFightWeekTitle,
          body: _l.notifFightWeekBody,
        ),
      'notif.fight.tomorrow' => NotificationText(
          title: _l.notifFightTomorrowTitle,
          body: _l.notifFightTomorrowBody,
        ),
      'notif.weighIn.reminder' => NotificationText(
          title: _l.notifWeighInTitle,
          body: _l.notifWeighInBody,
        ),
      'notif.protein.evening' => NotificationText(
          title: _l.notifProteinTitle,
          body: _l.notifProteinBody,
        ),
      // The trial notice keeps its own wording, shared with the path that
      // still schedules it directly.
      'notif.trial.ending' => NotificationText(
          title: _l.trialReminderTitle,
          body: _l.trialReminderBody,
        ),
      _ => null,
    };
  }

  String? _tipBody(int index) => switch (index) {
        0 => _l.notifTip0Body,
        1 => _l.notifTip1Body,
        2 => _l.notifTip2Body,
        3 => _l.notifTip3Body,
        4 => _l.notifTip4Body,
        5 => _l.notifTip5Body,
        _ => null,
      };

  /// `18:00` as the reader expects it: `6:00 PM` in English, `18:00` in
  /// German. A value that is not `HH:mm` is returned unchanged.
  String _time(String? hhmm) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm ?? '');
    if (match == null) return hhmm ?? '';
    final hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    if (_twentyFourHour) return '${hour.toString().padLeft(2, '0')}:$minute';
    final suffix = hour < 12 ? 'AM' : 'PM';
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve:$minute $suffix';
  }
}

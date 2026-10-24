import 'notification_channel.dart';

/// A daily window in which nothing is delivered. Minutes since local
/// midnight. May wrap midnight (the default 21:00 to 07:00 does).
///
/// Equal start and end means "no quiet hours".
class QuietHours {
  const QuietHours({this.startMinute = 21 * 60, this.endMinute = 7 * 60})
      : assert(startMinute >= 0 && startMinute < 1440),
        assert(endMinute >= 0 && endMinute < 1440);

  /// Builds from clock times.
  const QuietHours.hm(int startHour, int startMin, int endHour, int endMin)
      : this(
          startMinute: startHour * 60 + startMin,
          endMinute: endHour * 60 + endMin,
        );

  final int startMinute;
  final int endMinute;

  /// True when there is no quiet window at all.
  bool get isEmpty => startMinute == endMinute;

  /// True when the window crosses midnight.
  bool get wraps => startMinute > endMinute;

  /// Whether [minuteOfDay] (0..1439) is inside the window. The start is
  /// inside, the end is not.
  bool contains(int minuteOfDay) {
    if (isEmpty) return false;
    if (wraps) return minuteOfDay >= startMinute || minuteOfDay < endMinute;
    return minuteOfDay >= startMinute && minuteOfDay < endMinute;
  }

  /// [t] itself when it is outside quiet hours, otherwise the wall-clock
  /// moment quiet hours end (possibly the next calendar day).
  DateTime release(DateTime t) {
    final minute = t.hour * 60 + t.minute;
    if (!contains(minute)) return t;
    final nextDay = wraps && minute >= startMinute;
    return DateTime(
      t.year,
      t.month,
      t.day + (nextDay ? 1 : 0),
      endMinute ~/ 60,
      endMinute % 60,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuietHours &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);
}

/// What the user chose about notifications. Immutable. The default object is
/// all-off: the app turns channels on only after the user opts in.
class NotificationSettings {
  NotificationSettings({
    Set<NotificationChannel> enabledChannels = const {},
    this.usualTrainingHour = 18,
    this.usualTrainingMinute = 0,
    this.sessionLeadMinutes = 60,
    this.fuelWindowLeadMinutes = 150,
    this.quietHours = const QuietHours(),
    this.pauseAll = false,
    this.pauseNutrition = false,
    Map<NotificationChannel, DateTime> pausedUntil = const {},
  })  : enabledChannels = Set.unmodifiable(enabledChannels),
        pausedUntil = Map.unmodifiable(pausedUntil);

  /// Channels the user switched on.
  final Set<NotificationChannel> enabledChannels;

  /// The user's usual training time. Planned sessions have a date but no
  /// time of day, so this stands in for it.
  final int usualTrainingHour;
  final int usualTrainingMinute;

  /// Minutes before the usual training time that the session reminder fires.
  final int sessionLeadMinutes;

  /// Minutes before the usual training time that the fuel window opens.
  final int fuelWindowLeadMinutes;

  final QuietHours quietHours;

  /// Silences every channel except the transactional trial notice.
  final bool pauseAll;

  /// Hides the nutrition channels: fuel window, weigh-in, protein.
  final bool pauseNutrition;

  /// A channel stays quiet until this local moment.
  final Map<NotificationChannel, DateTime> pausedUntil;

  bool isEnabled(NotificationChannel channel) =>
      enabledChannels.contains(channel);

  /// [channel] switched on or off.
  NotificationSettings withChannel(NotificationChannel channel, bool enabled) =>
      copyWith(
        enabledChannels: {
          for (final c in enabledChannels)
            if (c != channel) c,
          if (enabled) channel,
        },
      );

  /// [channel] paused until [until], or resumed when [until] is null.
  NotificationSettings withPausedUntil(
    NotificationChannel channel,
    DateTime? until,
  ) =>
      copyWith(
        pausedUntil: {
          for (final e in pausedUntil.entries)
            if (e.key != channel) e.key: e.value,
          if (until != null) channel: until,
        },
      );

  NotificationSettings copyWith({
    Set<NotificationChannel>? enabledChannels,
    int? usualTrainingHour,
    int? usualTrainingMinute,
    int? sessionLeadMinutes,
    int? fuelWindowLeadMinutes,
    QuietHours? quietHours,
    bool? pauseAll,
    bool? pauseNutrition,
    Map<NotificationChannel, DateTime>? pausedUntil,
  }) =>
      NotificationSettings(
        enabledChannels: enabledChannels ?? this.enabledChannels,
        usualTrainingHour: usualTrainingHour ?? this.usualTrainingHour,
        usualTrainingMinute: usualTrainingMinute ?? this.usualTrainingMinute,
        sessionLeadMinutes: sessionLeadMinutes ?? this.sessionLeadMinutes,
        fuelWindowLeadMinutes:
            fuelWindowLeadMinutes ?? this.fuelWindowLeadMinutes,
        quietHours: quietHours ?? this.quietHours,
        pauseAll: pauseAll ?? this.pauseAll,
        pauseNutrition: pauseNutrition ?? this.pauseNutrition,
        pausedUntil: pausedUntil ?? this.pausedUntil,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      _setEquals(other.enabledChannels, enabledChannels) &&
      other.usualTrainingHour == usualTrainingHour &&
      other.usualTrainingMinute == usualTrainingMinute &&
      other.sessionLeadMinutes == sessionLeadMinutes &&
      other.fuelWindowLeadMinutes == fuelWindowLeadMinutes &&
      other.quietHours == quietHours &&
      other.pauseAll == pauseAll &&
      other.pauseNutrition == pauseNutrition &&
      _mapEquals(other.pausedUntil, pausedUntil);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(enabledChannels),
        usualTrainingHour,
        usualTrainingMinute,
        sessionLeadMinutes,
        fuelWindowLeadMinutes,
        quietHours,
        pauseAll,
        pauseNutrition,
        Object.hashAllUnordered(
          pausedUntil.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.every(b.contains);

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) =>
    a.length == b.length &&
    a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);

import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/reminder_gateway.dart';
import 'subscription.dart';

/// The "your free trial ends in 2 days" local notification.
///
/// It only reads the server-fed [AccessState]; it never decides access. The
/// reminder is scheduled while a dated trial is running and removed as soon
/// as the account is anything else (converted, lapsed, signed out).
class TrialReminderCoordinator {
  TrialReminderCoordinator({
    required ReminderGateway gateway,
    DateTime Function()? now,
  })  : _gateway = gateway,
        _now = now ?? DateTime.now;

  /// How long before the trial ends the reminder fires.
  static const Duration lead = Duration(days: 2);

  static const _askedKey = 'trial.reminderPermissionAsked';

  final ReminderGateway _gateway;
  final DateTime Function() _now;

  /// What is currently scheduled, so a rebuild does not reschedule it.
  DateTime? _scheduledFor;

  /// When the reminder should fire for [access], or null when there is none
  /// to send: not a dated trial, or fewer than [lead] left already.
  static DateTime? reminderAt(AccessState access, DateTime now) {
    final state = access.effective;
    final ends = state?.trialEndsAt;
    if (state == null || !state.isTrial || ends == null) return null;
    final at = ends.subtract(lead);
    return at.isAfter(now) ? at : null;
  }

  /// Brings the scheduled reminder in line with [access]. [title] and [body]
  /// are the localized notification text.
  Future<void> sync(
    AccessState access, {
    required String title,
    required String body,
  }) async {
    if (!_gateway.isAvailable) return;
    final at = reminderAt(access, _now());
    if (at == null) {
      // An unknown state may be a passing blip: leave a scheduled reminder
      // in place rather than drop it.
      if (access.isUnknown) return;
      if (_scheduledFor != null) {
        _scheduledFor = null;
        await _gateway.cancelTrialEndReminder();
      }
      return;
    }
    if (_scheduledFor == at) return;
    if (!await _permissionGranted()) return;
    _scheduledFor = at;
    await _gateway.scheduleTrialEndReminder(at: at, title: title, body: body);
  }

  /// Drops the scheduled reminder (sign-out).
  Future<void> cancel() async {
    _scheduledFor = null;
    await _gateway.cancelTrialEndReminder();
  }

  /// Asks for notification permission once, ever. Later calls reuse the
  /// answer the OS already holds without prompting again.
  Future<bool> _permissionGranted() async {
    var asked = false;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      asked = prefs.getBool(_askedKey) ?? false;
    } catch (_) {}
    if (asked) return true;
    final granted = await _gateway.requestPermission();
    try {
      await prefs?.setBool(_askedKey, true);
    } catch (_) {}
    return granted;
  }
}

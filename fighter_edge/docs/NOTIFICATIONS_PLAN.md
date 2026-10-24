# Notifications plan (2026-10-24)

Local, opt-in, calm notifications for Fighter Edge. This file is the handoff
for whoever builds PRs 2 to 4. Read it, `CLAUDE.md`, and
`FUEL_V2_SPEC.md` (slice N6 and rules 3 to 8) first.

## Status

| PR | What | State |
|---|---|---|
| 1 | Pure-Dart planner in `lib/notifications/domain/` | Merged (#82) |
| 2 | Scheduler, permission primer, Settings screen | In review, see "What PR 2 built" |
| 3 | Wire real inputs, deep links, move the trial notice into the planner | Not started |
| 4 | Weigh-in, protein nudge, fighter tips | Not started; waits for the privacy fix (N6) and "Hide numbers" / "Pause nutrition" modes |

One feature, one branch, one PR, merged before the next starts.

## Rules that never change

1. Opt-in per channel. Every channel is OFF until the user turns it on.
   No permission prompt on first launch.
2. At most one non-transactional notification per local day. The planner
   already enforces this and the priority order (fight countdown, session
   with fuel window, weekly review, weigh-in, protein, tip).
3. Quiet hours (default 21:00 to 07:00). Rest days and finished sessions are
   silent.
4. Tone: say what is next and why. Never mention missed sessions, streaks,
   guilt, "over", good/bad food, cheat/earn.
5. Nothing health-like on the lock screen: no weight, calories, body data,
   clinical wording. A payload carries only a route, never data.
6. No fluid, sodium, sauna, fasting or weight-cut content, ever. Under-18 or
   unknown age: no fuel, weigh-in or protein notifications. Weight-cut content
   stays behind the existing sign-off flag and is not part of this plan.
7. Local only. No server push, no per-user notification events to analytics.
   Metrics (sent, opened, ignored) stay on the device.
8. Auto-pause: after 3 ignored notifications in a channel the channel pauses
   and the app asks once whether to keep it. The planner never clears a
   pause itself; the app must call `history.withoutChannel(channel)` after the
   user answers.

## What exists on main

- `lib/notifications/domain/` (PR 1): `NotificationChannel`,
  `NotificationSettings` (+ `QuietHours`, `withChannel`, `withPausedUntil`),
  `NotificationHistory` (+ `autoPausedChannels`, `withoutChannel`),
  `PlannedNotification` (stable `id`, `channel`, local wall-clock `fireAt`,
  `contentKey`, non-sensitive `args`, `route`), and
  `NotificationPlanner.plan(...)`. It takes `ResolvedSession`s from
  `training_plan/domain/session_status_resolver.dart`, a
  `Map<DateTime, FuelDayType>`, `fightDate`, `trialEndsAt`, `ageYears`,
  `weighInWeekdays`, `horizonDays` (7). Pure Dart, no clock: pass `now`.
  Read its tests; they document every decision.
- `lib/notifications/reminder_gateway.dart` and `local_reminder_gateway.dart`:
  the only place that talks to `flutter_local_notifications`. Today it
  schedules weekly training reminders at a fixed 18:00 and a one-off trial-end
  reminder. `UnavailableReminderGateway` is the no-op for web and desktop.
- Old flow to replace in PR 2:
  - `lib/screens/first_run/first_win_sheet.dart` asks for reminders after the
    first win and calls `scheduleTrainingReminders` directly.
  - `lib/screens/settings_screen.dart` `_setCampReminders` does the same from
    a switch, driven by `AppState.campReminders`.
  - `lib/billing/trial_reminder.dart` (`TrialReminderCoordinator`, started in
    `lib/screens/home_shell.dart`) schedules the trial notice.
- Android already has `POST_NOTIFICATIONS`, the reboot receiver, and NO exact
  alarm permission. Keep it that way (inexact, allow-while-idle).

## PR 2: scheduler, primer, Settings (the part users see)

1. **Gateway.** Extend `ReminderGateway` with one method that replaces the
   whole plan-owned set: `replaceScheduled(List<ScheduledReminder>)`, where a
   `ScheduledReminder` is `id`, `fireAt` (wall time), localized `title` and
   `body`, `route`, `channel`. Implementation: read pending requests, cancel
   plan-owned ids that are no longer wanted, schedule the missing ones with
   `zonedSchedule` (inexact, allow-while-idle), convert wall time with the
   `timezone` package at schedule time (this is where DST is handled).
   One Android channel per `NotificationChannel`, one iOS thread id per
   channel. iOS: provisional authorization for the weekly review only.
   Keep `UnavailableReminderGateway` a no-op. Mind the iOS limit of 64 pending.
2. **Copy.** A `NotificationCopy` that maps a `contentKey` + `args` to
   localized title/body from the ARB files (EN and DE together, UTF-8). Keys
   come from the planner (`notif.session.soon`, `notif.session.soonFuel`,
   `notif.fuel.window`, `notif.fight.week`, `notif.fight.tomorrow`,
   `notif.weighIn.reminder`, `notif.tip.0` to `notif.tip.5`, and the review,
   protein and trial keys: read them from the planner). Text is baked in at
   schedule time, so reschedule when the app language changes.
   Add a test that renders EVERY key in EN and DE and runs it through the
   copy lint and the banned-advice validator from the N4 domain, and that
   rejects digits followed by kg, lb, kcal.
3. **Stores.** `NotificationSettingsStore` and `NotificationHistoryStore` on
   `SharedPreferences`, device-local, JSON, versioned. Migration: a user with
   `AppState.campReminders == true` gets the session reminder channel on and
   `usualTrainingTime` 18:00, so nobody loses reminders they already had; then
   stop reading `campReminders`.
4. **Reconciler (`NotificationScheduler`).** Runs on app start, resume,
   training-plan change, settings change, session completion, language change
   and time-zone change. Debounced. It gathers inputs (plan controller,
   fuel day types, fight date, access/trial state, age), calls the planner
   with `DateTime.now()` injected from the outside, maps to copy, and calls
   `replaceScheduled`. Tested with a fake gateway and a fake clock.
5. **History.** On a notification tap record "opened". On app resume mark any
   notification whose `fireAt` passed more than 24 hours ago without an open as
   "ignored". Feed that into `autoPausedChannels`.
6. **Tap handling.** `onDidReceiveNotificationResponse` and the launch
   details open the payload route through the existing router. The payload is
   a route string only.
7. **UI** (use the `fighter-edge-ui` skill; tokens, glass primitives, solid
   fallback, reduced motion, EN + DE, 200% text at 320 px):
   - Settings > Notifications: a row per channel with a one-line explanation,
     usual training time, lead times, quiet hours, Pause all, Pause nutrition.
     Replaces the old `campReminders` switch.
   - A short primer sheet replacing the reminder ask in `first_win_sheet.dart`:
     "Want a reminder before your next session?" then the OS prompt only on
     yes. Ask once. If denied, do not ask again; Settings shows a short
     "turned off in system settings" note with plain instructions (no new
     dependency for opening settings).
   - Hide the whole feature where `isAvailable` is false.
   - When auto-pause triggers, show one gentle in-app question next time the
     app opens: keep this channel or turn it off.
8. **Remove** the old direct scheduling calls once the reconciler owns them.
   Leave the trial notice on its old path until PR 3 so it never double-fires.

Acceptance: no prompt before the first win; denied permission leaves a calm
state; changing settings changes what is scheduled within one reconcile;
no duplicates after repeated reconciles; nothing scheduled beyond 7 days;
unit and widget tests for every point above; manual device check list in the
PR (Android and iOS: delivery, quiet hours, reboot, time-zone change).

### What PR 2 built, and what it left for PR 3

- Code: `notification_scheduler.dart` (reconciler), `notification_controller.dart`
  (settings, permission, taps, the auto-pause question, debounce),
  `notification_copy.dart` (ARB-backed words), the two stores, and
  `screens/notifications/` (host, Settings screen, primer, question sheet).
- The Settings screen has rows for the session reminder and the weekly review
  only. Fuel window, fight countdown, weigh-in, protein and tips get a row
  when their inputs are connected (PR 3 and 4), and so does the Pause
  nutrition switch; until then a switch would do nothing. The planner, stores
  and gateway already handle every channel.
- The reconciler passes sessions only. PR 3 adds fuel day types, the fight
  date and the trial end to `_inputs()` in `notification_host.dart`.
- Taps open a tab: `/fuel` Fuel, `/home` Home, `/review` and
  `/train/session/<id>` Train. PR 3 replaces that with real deep links.
  `NotificationRoute.parse` accepts only those fixed paths.
- A plan-owned pending notification is recognised by its payload starting
  with `/`. The trial reminder (id 6200, no payload) is never touched. The old
  weekly training ids (6101 to 6107) are cancelled on every run.
- A notification counts as delivered once its time passes (the OS does not
  tell a closed app), and as ignored 24 hours after that without a tap. The
  planner treats a not-yet-decided one like an opened one, so auto-pause is
  worked out when the app opens after a day or more without a notification.
- Time zone: the gateway reads the device zone on every run, so a trip is
  fixed the next time the app opens. It cannot react while the app is closed.

## PR 3: real inputs and the trial notice

- Feed fuel day types (from the day planner bridge) so the fuel window works.
- Weekly review notification opens the Sunday review screen.
- Fight countdown reads the fight date from the fight camp state (7 and 1 days
  before; no cut or weigh-in content).
- Move the trial-ending notice into the planner path and delete
  `TrialReminderCoordinator`'s direct scheduling, keeping its behavior: one
  notice, 2 days before the trial ends, cancelled on conversion or sign-out.
- Deep links for every route above, with tests.

## PR 4: the sensitive channels (after the privacy fix)

- Weigh-in reminder: only if weight tracking is on, adults only, never tied to
  a cut target. Hidden in "Pause nutrition" and "Hide numbers".
- Protein nudge: numberless text, off by default, hidden when the safety
  flags show eating-disorder risk or in "Pause nutrition".
- Fighter tips: a small curated library (about 30 items, reviewed, no weight
  cut or dosing content), at most 2 a week, lowest priority, every item run
  through the banned-advice validator in a test.

## Gotchas

- Delivery of local notifications can be delayed on aggressive battery savers
  (some Xiaomi and Samsung phones). Add a short "reminders not arriving?" help
  line in Settings.
- The CI emulator cannot test delivery. Test the planner and reconciler in
  unit tests; check delivery by hand on real devices.
- Sessions have a date but no time of day. The planner uses the user's
  `usualTrainingTime`.
- Do not edit `lib/features/edge_fuel/domain/` from here.
- `flutter pub get` dirties `fighter_edge/windows/`; never commit those files.

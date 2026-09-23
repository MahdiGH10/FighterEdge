# Implementation Plan — Retention, Habit Loop and Subscriptions

**Date:** 2026-09-23
**Implements:** the build order in `docs/UX_RETENTION_RESEARCH_20260923.md` §5.2
**Status:** final after five planning passes (the revision log at the end records
what each pass changed and why). Nothing here is built yet.

---

## How to read this

Work is split into **slices**. Each slice is one branch and one commit set, is
fully tested, and leaves the app shippable, per `CLAUDE.md` ("one bounded
slice per session: implement, test, commit, then reassess"). Each slice
lists:

- **Goal:** what changes for the athlete.
- **Change:** the files and design.
- **Tests:** what proves it works.
- **Done when:** the acceptance criteria.
- **Size:** S (≤ half a session), M (one session), L (split before starting).

Two tracks run in parallel. **Track A** is code I build. **Track B** is set-up
only you can do (accounts, store listings, legal text). Several Track B items
take days of review by Apple or Google, so **start them now**.

---

## The finding that reshaped the plan

The research report assumed the app keeps a training history. **It doesn't.**

- The weekly plan is 4–7 fixed session records (IDs like `Tue-Wrestling`).
  Completing one sets `completed = true` and `completedAt` on that same record.
- **There is no weekly rollover.** In week 2 the Train tab reads "WEEK 2" but
  shows week 1's check marks. To log Tuesday again, the athlete has to untick
  it and tick it again, which **overwrites week 1's date**.
- So the app can never hold more than one week of history. The streak, History,
  profile stats, "Recent activity", and every retention feature in the report
  read from this one-week window.

**Therefore Slice 3 (a real training log) comes before everything else except
the launch fixes (Slice 1) and measurement (Slice 2).** The weekly streak, logging Reaction drills,
History, the heatmap and the Sunday recap all depend on it.

---

## Decisions needed from you (defaults in bold)

| # | Decision | Default I'll use unless you say otherwise |
|---|---|---|
| D1 | Do Reaction drills count toward the weekly training target? | **No.** They're logged and shown in History as extra work. Only a planned session, a round-timer workout or a manually logged session counts as a training day, so a 30-second drill can't stand in for a real session |
| D2 | Streak freeze rules | **New accounts start with 1 freeze; earn 1 for every 4 weeks in a row with the target met; caps stay 2 (free) and 4 (Pro); a freeze is applied automatically when a week is missed** |
| D3 | Terms and Privacy | **Hosted web pages you provide** (Apple and Google ask for URLs anyway); the app opens them. If you'd rather, I bundle text you give me |
| D4 | Pro gating for Reaction drills | **Beginner and Intermediate free; Advanced and Advanced+ Pro**, applied only once billing is live (Slice 9) |
| D5 | Trial and plans | **7-day free trial; annual pre-selected, monthly one tap away**; prices are yours to set in the stores |
| D6 | Branch base | **Merge `feat/reaction-drills` into `main` first**, then one branch per slice |

---

## Track B — your tasks (start now; they gate Slices 1 and 9)

| # | Task | Gates | Notes |
|---|---|---|---|
| B1 | Write or obtain **Terms of Service and Privacy Policy**, host them (any web page) and send me the two URLs | Slice 1 | Both stores reject apps whose privacy link is a placeholder |
| B2 | **Google Play Console:** app entry, internal testing track, subscription products (monthly and annual, each with a 7-day free-trial offer), license testers | Slice 9 | Product review can take days |
| B3 | **RevenueCat:** project, connect Play (and later App Store), create the `pro` entitlement and an offering with both products, and give me the **public** SDK key | Slice 9 | Used via `--dart-define=REVENUECAT_ANDROID_PUBLIC_KEY=…`; never committed |
| B4 | **RevenueCat → Firebase webhook secret** set in Cloud Functions config | Slice 9 | The backend (`functions/src/billing.ts`) already exists and has tests |
| B5 | **Release keystore:** create it, and add its SHA-1 (and later the Play app-signing SHA-1) in Firebase | Slice 9 | Google sign-in breaks in release builds without it |
| B6 | **Apple Developer account and a Mac** (or a cloud Mac) | iOS release, iOS widget | Nothing on iOS can be built or signed from this Windows PC |
| B7 | Approve deploying Firestore rules when a slice adds a collection (`firebase deploy --only firestore:rules`) | Slice 3a | I will prepare and test the rules, then ask before deploying |

---

## Track A — slices in build order

### Slice 1 — Launch blockers · S
**Goal:** nothing unfinished or internal is visible to users.
**Change:**
- `settings_screen.dart:541`: remove "Keep this visible before public
  launch." Move the disclaimer into `app_en.arb` and `app_de.arb`.
- `legal_screen.dart`: open the hosted Terms and Privacy URLs (B1) with
  `url_launcher` (already a dependency), keeping in-app fallback text if a link
  can't open. The URLs live in one constants file.
- `weight_tracker_screen.dart`: its `FilterChips` switches to
  `scrollable: true`. Chips then size to their labels: "Weight / Body Fat /
  Measurements" fit in 390 px, and at large text the row scrolls with the edge fade.
- `edge_fuel_coach_screen.dart` "No plan yet" `EmptyState`: add
  `actionLabel: 'Start setup'` → `EdgeFuelSetupScreen`, the same as Your plan.
- Delete `lib/screens/more_screen.dart`, which is never opened.

**Tests:** a widget test for each change: no internal note; legal tap calls
the launcher; the weight tab labels are untruncated at 1× and on screen at 2×;
the coach empty state navigates to setup.
**Done when:** the full verification passes and the screens are re-rendered and checked.
**Blocked by:** B1 (URLs). The other four fixes can land without it.

### Slice 2 — Funnel telemetry · S
**Goal:** measure activation, habit and conversion before changing them.
**Change:** add to `TelemetryEvent`, all snake_case and ≤ 40 characters (Firebase rules), with
**no personal data in parameters** (per `CLAUDE.md`; parameters are enums, counts and
buckets only):

| Event | Parameters | Fired from |
|---|---|---|
| `onboarding_step_viewed` | `step` (1–7) | onboarding screen |
| `onboarding_completed` | `days_per_week`, `goal` (enum) | onboarding finish |
| `plan_revealed` | — | plan-ready view |
| `training_logged` | `source` (planned/timer/reaction/manual), `is_first` | log write (Slice 3) |
| `meal_logged` | `is_first` | EdgeFuel add entry |
| `reaction_drill_finished` | `discipline`, `level` | drill screen |
| `reminder_prompt_result` | `granted` | Slice 6 primer |
| `week_target_met` | `streak_weeks` bucket | Slice 4 |
| `streak_freeze_applied` | — | Slice 4 |
| `paywall_viewed` (exists) | add `trigger` | every paywall entry point |

D1, D7 and D30 retention come from Firebase Analytics' automatic
`first_open` and `user_engagement` events, so no code is needed for them.
**Tests:** `MemoryTelemetry` assertions per event, plus a test that no parameter
is a free-text string.
**Done when:** a debug run shows the events in Firebase DebugView. That needs your
phone connected and your approval.

### Slice 3 — Training log (the foundation) · L, split into 3a and 3b

#### 3a — Model, storage, migration · M
**Goal:** every training occurrence is kept, forever, and the plan becomes a
weekly *template*.
**Change:**
- New `lib/models/training_log_entry.dart`:
  `id, completedAt, dateKey, source (planned | timer | reaction | manual),
  title, planSlotId?, durationSeconds?, rpe (0 = not rated), note, detail
  (small map: reaction discipline/level/calls)`.
- `DataRepository`: add `watchTrainingLog(userId, {since})`,
  `saveTrainingLogEntry`, `deleteTrainingLogEntry`, implemented in
  Firestore (`users/{uid}/trainingLog/{entryId}`), in-memory and
  `MockData`.
- `firestore.rules`: add `match /trainingLog/{entryId}` with owner-only access,
  the same as `sessions`. Test with the Firestore emulator (Java 17 and the
  Firebase CLI are installed) by adding `@firebase/rules-unit-testing` as a new
  dev dependency in `functions/`.
- `AppState`:
  - add a `log` list;
  - add `isDoneThisWeek(slot)`, which is true when a log entry has
    `planSlotId == slot.id` in the current Monday–Sunday week;
  - `completeSession` now **adds or removes this week's log entry** and never
    rewrites the template;
  - the template's `completed` flag is kept for reading old data only.
- **Migration, idempotent:** on first load, each template with
  `completed && completedAt != null` becomes a log entry with the
  deterministic ID `plan-{slotId}-{dateKey}`, written with `set()`, so a re-run is
  harmless. Old records are never deleted.

**Tests:** model JSON round-trip; the repository contract across in-memory and
fake Firestore; a new week shows every slot not done; logging week 2 keeps
week 1's entry; untick removes only this week's entry; the migration run twice
creates one entry; rules tests (owner can, stranger can't).
**Done when:** after one simulated week, week 1's history survives into week 2.

#### 3b — Everything reads the log · M
**Goal:** every screen shows real history, and all training counts.
**Change:**
- Train › Week: check marks come from `isDoneThisWeek`.
- Train › History: log entries newest first, grouped by week, with source
  icon, duration, and RPE shown only if above 0.
- Home: "Recent activity", the weekly rings and "Next session" (the first slot not
  done this week, starting from today) read the log.
- Profile stats: sessions = log entries that count (D1).
- Round timer: finishing with a planned session adds a `planned` entry with
  duration. Finishing without one adds a `timer` entry.
- Reaction drill: finishing (not stopping) adds a `reaction` entry. The finished
  screen says "Saved to History" with Undo.
- `StreakEngine.completedDateKeys` takes log entries. The rules change in Slice 4.

**Tests:** update `dashboard_test`, `profile_identity_test`,
`app_state_test`; new tests that a timer finish and a drill finish log once, and
a stopped drill logs nothing.
**Done when:** a drill, a timer workout and a planned session all appear in
History with the right source, and survive into the next week.

### Slice 4 — Weekly streak · M
**Goal:** rest days never break a streak, and missing a week's plan does.
**Change** (pure rules in `StreakEngine`, so they're testable without widgets):
- `weekTarget` = number of plan slots, falling back to
  `AppUser.weeklyTrainingDays`.
- A week is **met** when its distinct training days that count (D1) reach the target.
- **Closed weeks are evaluated once and stored** (as `lastEarnedWeek` is today),
  so changing your target later never rewrites past weeks.
- `weeklyStreak` = consecutive met-or-frozen weeks before this one, **+1 once
  this week is met**. The week in progress never breaks the streak.
- `home_shell.dart` `_syncStreakEarn` (today it runs the daily-streak freeze
  sync from the plan records) is replaced by the weekly close-out.
- Freezes (D2) apply automatically at rollover to a missed week. Stored per
  user on the device, as now. Moving them to Firestore for multi-device use
  is noted for later.
- `isAtRisk` changes meaning: the days left this week equal the sessions still needed.
  The copy is non-guilt: "2 sessions left this week — Thu and Sat are open."
- One-time migration of existing streak state: freezes become
  `max(current, 1)`, and daily protected dates are dropped because they no
  longer apply.
- UI: Home shows the streak **once**, as "3 weeks · 2 of 4 this week". Today's focus
  card drops its duplicate streak tile. Profile stats and the Pro freeze cap
  copy are updated. The rest-day copy suggests an optional drill and never scolds.

**Tests:** rest days don't break; a missed week breaks; a freeze auto-covers
exactly one missed week; a mid-week in-progress week isn't a break; changing the target
doesn't rewrite closed weeks; timezone and DST boundaries (local date keys);
a new account starts with 1 freeze.
**Done when:** a simulated 4-day-a-week athlete with 3 rest days keeps a streak for
8 weeks, and loses it after a missed week once freezes run out.

### Slice 5 — Home: one next action · M
**Goal:** open the app and see the one thing that matters today.
**Change:**
- New pure function `NextAction.pick(...)`, which takes today's slot, this
  week's progress, the first-week checklist, whether a plan and fuel target exist, and
  the rest day. It returns one of:
  - "Start Tue · Wrestling 60 min"
  - "Done today — 2 of 4 this week"
  - "Rest day · optional 2-min drill"
  - "Finish your first week" (the checklist)
  - "Build your plan"
- `dashboard_screen.dart` (958 lines) order: **next action** card, then the week
  (rings plus streak line), then quick stats, then recent activity.
  `Selector` replaces the broad `context.watch` where a card needs one field,
  starting the performance work cheaply.

**Tests:** unit tests for every `NextAction` branch; the dashboard widget test
covers each state; 200% text and German renders reviewed.

### Slice 6 — Reminder opt-in at the right moment · S
**Goal:** reminders the athlete asked for, on training days only.
**Change:** after the **first** logged session that counts, show an in-app
primer sheet ("Want a nudge on your training days at 18:00?" with a time picker
and "Not now"), then `requestPermission()`, then schedule on plan weekdays with the
existing `TrainingReminderSchedule`. Copy says what's next, never guilt.
"Not now" asks again only once, after a week.
**Tests:** the primer shows once after the first session; "granted" schedules the plan
weekdays; "denied" stores it and never re-prompts the OS.
**Done when:** a reminder fires on your phone. It must be verified on a real
device, because the local notification path has never been verified on one.
**Deferred:** skipping a reminder on a day already trained needs dated
one-shot scheduling. That's a later refinement.

### Slice 7 — Fight date and camp phases · M (free part)
**Goal:** the app organises itself around the next fight or weigh-in.
**Change:**
- `AppUser` adds `fightDate?`, `fightName?` and `fightWeightKg?`. These are
  profile fields, not billing fields, so the existing rules allow them.
- Set it from:
  - a Home card ("Got a fight or weigh-in date?");
  - the onboarding goal "Get competition ready" (one optional extra field);
  - Settings.
- Pure `CampPhase.of(today, fightDate)`: build (> 6 weeks), sharpen (2–6
  weeks), fight week (< 2 weeks).
- Home shows a countdown chip, and the phase shapes the next-action copy.

**Tests:** phase boundaries; clearing the date; no date means no change to Home.

### Slice 8 — Safe weight path · M (Pro once billing is live)
**Goal:** a weight target the athlete can trust, bounded by published safety limits.
**Change:**
- Pure Dart policy `edge_fuel/domain/policies/weight_cut_policy.dart` (the
  domain stays free of Flutter, Firebase and clock imports, per `CLAUDE.md`).
  Inputs are current kg, target kg, fight date and "today" passed in. The limits:
  - gradual loss of **0.5–1 kg per week** during camp;
  - the final acute cut is at most **4.4% of body mass in 24 h, 5.7% in 48 h and 6.7% in 72 h**
    (ISSN 2025).
- Output: *feasible*, *tight* or *not safe in this time*, with the weekly
  checkpoints. **It never generates dehydration, sauna, fasting or fluid-restriction
  instructions.** For the final days it says "work with your coach or a
  sports dietitian", and the safe-cut disclaimer stays on by default.
- The weight tracker gets a target line, checkpoints and days left.

**Tests:** boundary tables straight from the limits above; an infeasible target
is refused with a reason; no output string contains banned methods.

### Slice 9 — Billing live and an honest personalised paywall · M · blocked by B2–B5
**Goal:** athletes can start a trial and subscribe, with a paywall that passes
Apple 3.1.2 and Play policy.
**Change:**
- Prices and trial terms come **from the store products** through the existing
  `RevenueCatBillingGateway`. Nothing is hard-coded.
- Paywall:
  - a personalised header ("Your 4-day camp to Nov 14", or "Your 4-day camp"
    without a date);
  - annual pre-selected, monthly visible, **no trial toggle**;
  - renewal text, Terms and Privacy links, and Restore;
  - fix the "FighterEdge" spelling, the duplicated "Founding Pro preview", and the
    green checks next to features a free user doesn't have.
- The soft paywall appears after the plan reveal, plus feature-triggered paywalls
  (locked drill, Reaction Advanced per D4, corner cues, weight path), each with
  `paywall_viewed.trigger`.
- Keep entitlements server-owned (the webhook); the client never grants Pro.

**Tests:** paywall widget tests with `FakeBillingGateway` (products, trial,
annual default, restore, errors); existing `functions` billing tests stay green.
**Done when:** a license-tester account on your phone starts a trial, gets Pro
through the webhook, and cancels from Play. **I won't call billing "ready" before
that has actually happened** (`CLAUDE.md`).

### Slice 10 — Android home-screen widget · M
**Goal:** a daily trigger that isn't a notification.
**Change:** add the `home_widget` package, a native Android widget (Kotlin
`AppWidgetProvider` plus an XML layout) showing today's next action and "2 of 4 this
week", updated whenever the log changes. **iOS is deferred** until B6 (it needs
Xcode).
**Tests:** a unit test for the data pushed to the widget. Checked by eye on your phone.

### Slice 11 — Weekly recap, heatmap, sharing · M
**Goal:** reflection, reward, and organic growth.
**Change:**
- A pure `WeeklyRecap` (sessions, minutes, drills, weight trend, streak) shown on
  Home on Monday.
- A share card rendered to an image with `share_plus` (new dependency). It shares
  **no weight numbers** unless the athlete turns them on.
- A 26-week training heatmap in History.

**Tests:** recap maths; heatmap cell mapping; the share image renders at 1× and 2×.

### Slice 12 — Reaction drill progression · S
**Goal:** a reason to come back to the unique feature.
**Change:** per level, record clean runs (finished without pause or stop), a best
calls-per-minute, and a "Recommended next: Intermediate" nudge after 2 clean
runs. **No level locks beyond Pro (D4).** Unlock-plus-paywall would be double
gating.
**Tests:** clean vs interrupted runs; nudge threshold.

---

## Order at a glance

```
Track B (you):  B1 ─────────────┐        B2 ─ B3 ─ B4 ─ B5 ──────────────┐
                                ▼                                        ▼
Track A (me):   S1 ─ S2 ─ S3a ─ S3b ─ S4 ─ S5 ─ S6 ─ S7 ─ S8 ─────────── S9 ─ S10 ─ S11 ─ S12
                        foundation   habit loop          camp          money   triggers & reward
```

Slices 1–6 can all ship before billing exists. They make the free app
genuinely habit-forming, which is what the trial will then convert.

---

## Guardrails every slice follows

- Streaks are for **training only**, never for eating. Fuel numbers stay neutral:
  no red when over, no praise for under.
- No guilt copy in notifications, streak-risk messages or empty states.
- The weight path never exceeds the ISSN limits and never outputs dehydration methods.
- Telemetry carries no personal data. Entitlements stay server-owned.
- Every new string is added in English and German. Every screen is checked at
  200% text and in high contrast.
- Each slice: `dart format`, `flutter analyze`, the full test suite and goldens,
  `npm test` for Functions if touched, the handoff doc updated, and a commit on its
  own branch.
- Deploying rules or Functions, or sending anything to an external service,
  waits for your explicit approval.

---

## Revision log — how the plan changed across passes

**Pass 1 — straight from the report.** Order was: blockers, telemetry, weekly
streak, log drills, Home, reminders, fight date, billing, widget, recap,
Reaction progression.

**Pass 2 — after reading the code.**
- Found there is **no weekly rollover and no history**: the plan records are
  overwritten each week. A **Training log** slice was inserted before the streak, and "log
  drills and timer work" was folded into it. The streak, History, heatmap and recap
  now all build on it.
- `MoreScreen` is unused, so it's deleted in Slice 1.
- Telemetry already exists but covers only paywall and AI events. The
  funnel events were specified rather than "add analytics".

**Pass 3 — dependencies and ownership.**
- Billing code (RevenueCat, webhook, tests) already exists. What's missing is
  **store and RevenueCat set-up that only you can do**, so it became Track B,
  started now because store review takes days.
- The iOS widget and iOS release need a Mac and an Apple account (B6), so the
  widget slice is Android-only.
- The Terms and Privacy fix can't be done without your text or URLs, so Slice 1
  was split so its other fixes don't wait.

**Pass 4 — stress-testing the designs.**
- The weekly streak computed live from the log would let a later **target change
  rewrite past weeks** (raising 3 → 5 days would break a long streak
  retroactively). Changed so closed weeks are **evaluated once and stored**.
- "Unlock the next Reaction level" combined with Pro-gated levels is **double
  gating**. Progression became records and nudges, not locks.
- The migration could double-write on a second launch. It now uses deterministic IDs
  with `set()`.
- A 30-second Reaction drill satisfying a "training day" would cheapen the streak.
  That became decision D1, defaulting to no.
- Skipping a reminder on a day already trained needs dated one-shot
  scheduling. That's deferred rather than half-built.
- The weight path needed a gradual-loss rate, not only the fight-week caps. I
  looked it up: ISSN 2025 recommends 0.5–1 kg per week during camp.

**Pass 5 — feasibility and rules check.**
- Slice 3 was too big for one session and was split into 3a (data) and 3b (screens).
- Every slice was checked against `CLAUDE.md`:
  - domain purity: the weight policy is in pure Dart with the clock passed in;
  - no personal data in telemetry;
  - server-owned entitlements;
  - one slice per session;
  - never claiming store or billing readiness untested.
- Every outward action (rules deploy, DebugView run, store testing) is marked as
  needing your approval or your device.
- A last check of the code the plan names turned up two more places:
  `home_shell.dart` also runs the freeze sync from the plan records (added to
  Slice 4), and the rules-testing library isn't installed yet (added to
  Slice 3a as a dev dependency). Java 17, the Firebase CLI, `url_launcher`,
  `EmptyState.actionLabel` and the RevenueCat gateway were all confirmed present.
- **No further changes found.** The plan is stable.

---

## Sources for the numbers used here

- [ISSN position stand — nutrition and weight cut strategies for MMA and combat sports (2025)](https://pubmed.ncbi.nlm.nih.gov/40059405/)
- [Full text via PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11894756/)
- Research report: `docs/UX_RETENTION_RESEARCH_20260923.md` (all other sources)

# Session Handoff — 2026-09-24

Written for the next session (any tool) that picks up Fighter Edge. Read this
first, then `docs/CLAUDE_CODE_HANDOFF.md` (verified state, newest at the top)
and `docs/IMPLEMENTATION_PLAN_RETENTION_20260923.md` (the build plan). The
repo rules are in the root `CLAUDE.md`.

---

## Repo state

- `main` is pushed to GitHub (`MahdiGH10/FighterEdge`). It is a fast-forward
  of every slice so far, and each slice also has its own local branch:

  | Commit | Branch | What |
  |---|---|---|
  | `a20c83c` | `feat/reaction-drills` | New `google-services.json`: Google sign-in fix (debug SHA-1 registered in Firebase) |
  | `7fddcf5` | `feat/reaction-drills` | Reaction drills (voice-called reaction training) and UX audit fixes |
  | `2b46d51` | — | Docs: retention research and the 12-slice plan |
  | `922da76` | `feat/launch-blockers` | Slice 1: launch blockers |
  | `a3844c2` | `feat/funnel-telemetry` | Slice 2: funnel analytics (made by another session) |
  | `502ade0` | `feat/training-log` | Slice 3a: persistent training log |

- **Never commit these untracked files** (the user's own artifacts; the
  `CLAUDE.md` rule is to preserve them):
  - `.playwright-mcp/`
  - `Fighters_Edge_Product_AI_Technical_Blueprint.md`
  - `docs/SESSION_HANDOFF.md` (an older, 2026-09-05 handoff)
  - `docs/UX_WORKFLOW_HANDOFF.md`
  - `docs/VISUAL_AUDIT_20260917.md` and `docs/audit_screenshots_20260917/`
  - `drills.png`
  - `fighter_edge/google-services.json`: a stray copy; the app uses the one in
    `android/app/`
- `windows/flutter/generated_plugin_registrant.cc` and
  `generated_plugins.cmake` show as modified, but only line endings changed.
  Leave them out of commits.

## Plan progress (see the plan doc for full specs)

| Slice | Status |
|---|---|
| 1 Launch blockers | Done, except the hosted **Terms and Privacy URLs**, which the user must supply (Track B1) |
| 2 Funnel telemetry | Done. **Not yet checked in Firebase DebugView on a phone** |
| 3a Training log | Done. **Firestore rules NOT deployed** (see below) |
| 3b Log everything and show it | **Next** |
| 4–12 | Not started |

Decisions D1–D6 in the plan use their defaults. The user hasn't changed any.
Most relevant now: **D1** says Reaction drills are logged but don't count as
training days. This is already implemented as
`TrainingSource.countsAsTrainingDay`.

## Ship blocker: Firestore rules

Slice 3a added `match /trainingLog/{entryId}` (owner-only) to
`fighter_edge/firestore.rules`. It is **not deployed**. Until it is, the live
database refuses every training-log write and History stays empty on real
accounts. Deploy with `firebase deploy --only firestore:rules`, **only after
the user explicitly approves it**, and before any build with Slice 3a reaches
a phone. The rules are tested locally (`npm run test:rules`, 4 of 4 pass).

## Next: Slice 3b — Everything reads the log

The model and storage are done in 3a. What's left:

1. **Round timer** (`lib/screens/round_timer_screen.dart`, around line 113):
   - A finish *with* a planned session already calls
     `AppState.completeSession`, which now writes a `planned` entry. Add
     `durationSeconds` to it: `completeSession` needs an optional
     `durationSeconds`, passed through `TrainingLogEntry.copyWith`.
   - A finish *without* a session should call
     `AppState.addTrainingLogEntry` with `TrainingSource.timer`, a title like
     "MMA rounds", the duration, and an id such as `timer-<epochMs>`.
2. **Reaction drill** (`lib/screens/reaction_drill_screen.dart`,
   `_onDrillChanged` where the phase becomes `finished`, which already sends
   telemetry):
   - Add a `reaction` entry with the title, `durationSeconds` = the spec
     duration, and `detail: {discipline, level, calls}`, using fixed codes only.
   - **Finishing logs; stopping does not.**
   - Show "Saved to History" with Undo (Undo calls a new
     `AppState.removeTrainingLogEntry`, or deletes via the repository).
3. **Train › History** (`training_camp_screen.dart`, `_HistoryView`):
   - it currently gets a `TrainingSession`-shaped view through
     `completedSessionsDesc`; switch it to `state.trainingLog`;
   - group entries by week ("This week", "Last week", then dates);
   - show a source icon, the duration, and the RPE only when above 0 (today
     it shows "RPE 0");
   - Reaction entries are marked "extra", since they don't count.
4. **Telemetry:** `TelemetryEvent.trainingLogged` already exists, with the
   parameters `source` and `is_first` (0/1) validated in
   `lib/observability/telemetry.dart`, but nothing sends it yet. Send it from
   `AppState.addTrainingLogEntry`, or better from the call sites, since
   AppState has no telemetry. `is_first` = the log had no counting entry before.
5. **Tests:**
   - a timer finish and a drill finish each log exactly once;
   - a stopped drill logs nothing;
   - Undo removes the entry;
   - History groups by week and hides RPE 0;
   - `trainingLogged` is emitted with valid parameters.

   Update `dashboard_test`, `profile_identity_test` and `app_state_test` if
   they break.

After 3b comes **Slice 4 (weekly streak)**. The key design points are
decided in the plan:
- closed weeks are evaluated once and stored;
- the target is the plan slot count;
- a freeze is applied automatically at rollover;
- the streak shows once on Home;
- `home_shell.dart` `_syncStreakEarn` is replaced.

## Verification (run all before every commit)

From `fighter_edge/`:
```
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --exclude-tags golden --reporter expanded   # last line: "All tests passed"
flutter test --tags golden --reporter expanded
```
From `fighter_edge/functions/`: `npm test` (37 pass) and `npm run test:rules`
(4 pass).

At the end of this session: **546** Flutter tests, 3 goldens, 37 functions
tests, 4 rules tests, all passing.

## Gotchas learned the hard way

- **"Asset 'shaders/ink_sparkle.frag' not found"** failing many unrelated
  widget tests means `build/unit_test_assets` is incomplete, e.g. after an
  interrupted run. Delete that folder and rerun.
- **Widget tests render text in the Ahem font,** where every letter is a full
  square, much wider than Inter. Width-based assertions can fail in tests even
  though the layout fits on a phone. To check a layout, render with the real
  fonts: load Oswald, Inter and MaterialIcons with `FontLoader` in a throwaway
  golden test under `test/_tmp/`, then delete it.
- **`find.byType(Scrollable).first`** may now hit a horizontal chip row,
  because scrolling `FilterChips` rows are Scrollables. Filter on
  `axisDirection == AxisDirection.down`.
- **`npm run test:rules`** pins `npx firebase-tools@13.35.1`, because the global
  CLI (v15) needs Java 21 and this PC has Java 17.
- **Pushing:** the git remote uses SSH, and `git fetch`/`git push` fail with
  "Permission denied (publickey)" unless the key is loaded in the same
  shell: `eval "$(ssh-agent -s)"; ssh-add ~/.ssh/id_ed25519; git push …`.
  `gh` is also logged in as MahdiGH10.
- **Long heredocs containing Dart** sometimes break Git Bash quoting ("unexpected
  EOF while looking for matching `'`"). Write the edit script to a file in
  the scratchpad and run it from there.
- **Telemetry parameters are validated per event, by value**
  (`safeTelemetryParameters`). A new parameter must be added there, with its
  allowed codes or range, or it is silently dropped.
- **`Telemetry.fromContext(context)` after an `await`** that can replace the
  screen falls back to a silent no-op. Capture it before the await.
- **Two sessions worked on this repo at once** on 2026-09-23/24. Before
  starting a slice, check the other session with `ListAgents` and
  message it, so two sessions don't edit the same files.

## Waiting on the user (Track B in the plan)

- **B1:** Terms and Privacy hosted URLs.
- **B2–B5:** Play Console subscriptions, a RevenueCat project and its public
  key, the webhook secret, and a release keystore with its SHA-1 registered
  in Firebase.
- **B6:** an Apple account and a Mac, for anything iOS.
- **B7:** approval to deploy the Firestore rules.
- **On the phone:** check the analytics events in DebugView (Slice 2), and
  confirm Google sign-in works after the SHA-1 fix.

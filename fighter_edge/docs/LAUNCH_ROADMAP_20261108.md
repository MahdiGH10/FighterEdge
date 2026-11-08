# Fighter Edge: path to release (2026-11-08)

Plain version of where the app is, what makes people subscribe, and the order of work to launch.
Built from `main` at `908d2b7`, `HANDOFF_2026-11-08.md`, the Codex UI audit (#113) and the V2 plan.
Each statement is marked **Verified** (checked in code or tests today), **Audit** (from the Codex audit, not re-checked) or **Unknown** (needs a phone, a store or the owner).

## 1. One-paragraph state

The product is feature-complete for a first release: onboarding, a dated training week, session player, Fuel logging with safety modes, fight camp and weight path, weekly review, Reaction drill, notifications, a post-reveal paywall with a store trial, read-only mode and a live Firebase backend. The gap is not features. It is (a) proof the paid path works end to end, (b) the first minutes feeling clear, and (c) owner-only release steps (consoles, legal text, signing). Codex scored the UI 5.8/10 and found no P0 blocker.

## 2. What decides conversion (marketplace pattern) and where Fighter Edge stands

Benchmarks (secondary sources, treat as direction, not targets):
- Hard paywalls convert about 5x freemium on download-to-paid (RevenueCat 2026: median 10.7% vs 2.1% at day 35; revenue per install about $3.09 vs $0.38 at day 60). Hard paywalls also self-select for intent and had higher refund rates (5.8% vs 3.4% in the 2025 report, via Airbridge).
- Health and fitness: highest trial-to-paid (about 35%, Adapty 2026 via Airbridge) but the lowest first-renewal retention (about 30%). So the trial gets money, the first month decides if it stays.
- Common winning pattern: a short personal quiz, then a personal result, then the paywall, and onboarding and paywall designed as one flow. The size of the lift is unproven; test it.

| Area | What top apps do | Fighter Edge today | Status |
|---|---|---|---|
| Entry model | Hard paywall after a personal result | Paywall right after the plan reveal, 7-day store trial, read-only after expiry | **Verified** matches. Store products not created yet (owner) |
| Plan reveal | Shows the personal result: the actual plan | Showed one summary line and nutrition numbers, not the training week | **Fixed: #115 merged** (real dated sessions from the Train plan; not yet seen on a phone) |
| Paywall page | Outcome list, price after trial as visible as "free", restore, terms, renewal text | Restore, Terms, Privacy and a renewal disclosure exist; trial wording appears only if the store offers one | **Verified**. Real prices and eligibility **Unknown** until products exist |
| Funnel numbers | Track paywall view, trial start, conversion | `paywall_viewed`, `premium_cta_tapped`, `plan_revealed`, `trial_started`, `trial_converted` exist | **Verified**. No dashboard reading them yet |
| First screen after gate (Home) | One clear next action | Many blocks compete with Today (audit F01, F03) | Open: B2 |
| Core loop (train) | Start, finish, see progress, in one journey | Home logs, Train starts, player, timer and Reaction finish differently (F06, F07, F19) | Open: B3 |
| Nutrition | Fast logging, no guilt | Pinned Log food, remembered foods, Hide numbers and Pause modes (strong). Zero totals shown before a target exists (F18) | Mostly good. Open: B5 |
| Technique content | Visual demos | Text only (F09) | Open: B4. Needs owner-shot clips |
| Retention | Reminders, weekly review, streak that forgives rest | Reminders and weekly review exist; weekly streak never punishes rest. Weigh-in, protein, tips reminders not built | Partly open |
| Trust | Honest copy, no empty promises | Recipes hidden (good), but promotions still lead to them (F12) | Open: Q6 |
| Accessibility and language | Works at big text, no mixed languages | Clipped choices at 200% text, some English on German screens (F04, F05, F16) | Open: Q1, Q4 |
| Crash and analytics | Crash reports, funnel events | Crashlytics and Analytics are in `pubspec.yaml` | **Verified** present. Privacy rules apply (no health data in events) |

## 3. Path to release, in order

Each step has an exit test. Do not skip ahead; a step that fails sends you back.

**Step 0: Housekeeping (days 1-2).**
Commit this roadmap and `HANDOFF_2026-11-08.md`, point `CLAUDE.md` at it. Decide #112 (push) and #114 (Dependabot). Exit: `main` has one current handoff.

**Step 1: Conversion core (about 1 to 2 weeks of work, one PR each, serial).**
1. B1 plan reveal shows the week (done, #115 merged).
2. Quick wins Q1, Q3, Q4, Q5, Q6, Q8 first (each 20 to 50 minutes), then Q2, Q7, Q9, Q10.
3. B2 Home becomes one daily decision.
4. B3 one training journey: Start session everywhere, shared finish form, active-exit guard, Reaction save policy.
5. B5 Fuel: no-target state, loading skeleton, hide-mode edit fix.
Exit: all tests and CI green; owner walks Welcome to Home to first session to finish on a phone without help.

**Step 2: Make payment real (owner steps, start in parallel with Step 1 because stores are slow).**
Create the two subscription products with 7-day trial offers in Play Console and RevenueCat; add license testers; publish live Terms and Privacy URLs; fill the 48 legal placeholders; create an upload keystore and back it up. Exit: a license-tester purchase on a real Android phone goes sign-up, trial, access, restore, expiry to read-only, and the Firebase webhook (not the client) grants Pro.

**Step 3: Device QA (about 1 week).**
Cheap Android phone and one borrowed iPhone if iOS ships: glass blur frame time, coach voices, push notifications, 200% text, TalkBack/VoiceOver, background and resume mid-session. Exit: no crash in 3 days of daily use by 2 people.

**Step 4: Closed test.**
Release build signed with the upload key, internal then closed test with the testers Google requires (check the current rule in Play Console: new personal accounts need a minimum number of testers for a minimum number of days). Exit: crash-free sessions above 99% and at least 5 testers reach the paywall and 1 completes a trial.

**Step 5: Launch Android; iOS after.**
Android first removes the open iOS blockers (Firebase config, APNs key, Xcode capability). Add iOS once Android is stable.

**Step 6: After launch (first 30 days).**
Watch: paywall view to trial start; trial start to paid; day-7 and day-30 retention; sessions logged per week. Fix the biggest drop first.

## 4. Added-value ideas (ranked by value for effort; none built yet)

1. **Share card after a completed week** ("4 of 4 sessions done"): free organic reach, no AI images, uses existing data.
2. **Fight-day countdown on the lock-screen widget / home widget** (Android): daily visibility for fighters with a date.
3. **Training-day reminder that opens the exact session** (audit F20 already notes the route resolves to Train, not the session).
4. **"Why this week" line** in the reveal and Train explaining the chosen days (reason codes already exist in the plan model).
5. **Referral to a training partner**: one shared invite link, no paid tools.
6. **Win-back for read-only users**: one calm local reminder 3 days after expiry ("Your plan is saved"). No guilt copy.
7. **Offline-first logging** hardening (Fuel and sessions) since gyms have bad signal.
8. **Technique clips (owner-shot, 3 first)** for the biggest visual gap (B4). No AI-generated images.
9. **Annual-plan default with monthly equivalent** is already in; later A/B the trial length (7 vs 3 days) once there is traffic.

## 5. Owner-only list (I cannot do these)

1. Answer: merge #112 push? (and why it was interrupted).
2. Answer: recipes (review sheet then publish / tester-only drafts / publish with your own reviewer credit).
3. Play Console and RevenueCat products with 7-day trial, license testers, Data safety form (no ads, push token).
4. Live Terms and Privacy URLs; fill legal placeholders; add push token to the privacy notice.
5. Upload keystore creation and safe backup.
6. Firebase API key restrictions in Google Cloud Console.
7. Sports-dietitian review of weight-cut policy and refuel numbers (keep behind flags until then).
8. Listen to the 3 coach voices on a phone.
9. 3 owner-shot technique clips (when ready; images come last).
10. Borrow one iPhone only if iOS ships.

## 6. Rules I follow while doing this

One feature, one branch, serial. Branch from `origin/main`, PR, green CI, squash-merge, delete branch and worktree. No APK builds until you say so. No deploys or merges of #112 until you answer.

# FIGHTER EDGE — START HERE

> **Current-status notice (2026-09-09):** Read `CURRENT_HANDOFF.md` first for
> the verified repository state, then `APPLICATION_BUILD_PLAYBOOK.md` for the
> active ten-step execution plan. This document remains the launch philosophy
> and detailed checklist, but some progress counts below are historical.

_The single document to read first. Written 2026-09-05. Every fact below was
verified against the code, not remembered._

If you are a new AI session: read this file, then `docs/PROJECT_CONTEXT.md`,
then the file for whatever step you are on. Do not read all ten docs.

If you are Mahdi: this is your checklist. Work top to bottom. Do not skip.

---

## PART 0 — THE RULE THAT KEEPS YOU FROM GETTING LOST

You feel lost because AI agents will happily build anything you point them at,
forever, and nothing ever ships. The fix is a hard rule:

> **One step at a time. Finish it. Test it. Commit it. Then decide the next
> one.**

Concretely, every session:

1. Say which numbered step from PART 4 you are doing. Only that one.
2. When it is done, the agent must run the Definition of Done (PART 6).
3. Commit.
4. Stop. Decide if the next step is still the right one.

**Never let a session do steps 5 and 6 together because it "was already in
there".** That is how the last four weeks produced a great nutrition engine and
zero revenue.

When an agent proposes extra work, the answer is: *"Not this step. Add it to
docs/LATER.md."*

---

## PART 1 — WHAT THIS IS

**Fighter Edge** — a dark, athletic MMA/fight-camp app. Flutter, Firebase.
Solo builder. One external tester.

**The one sentence the whole product must serve:**

> Fighter Edge tells a combat athlete what to eat and what to train today, and
> keeps them consistent.

If a feature does not serve that sentence, it is not in the MVP.

### State today, verified

| | |
|---|---|
| Tests | **250 passing** (`flutter test`) |
| Analyzer | clean |
| Unpushed commits | **5** — blocked, see Step 1 |
| Working tree | clean |
| Platform | Web/Windows confirmed. **Verify `android/` and `ios/` platform folders exist before Step 3** — a filesystem check this session gave an inconsistent result and was not confirmed. If either is missing, `flutter create .` regenerates it safely (additive, does not touch `lib/`). |

**On iOS, corrected:** you do **not** need to own a Mac. Cloud CI services
(Codemagic is the standard choice for Flutter; GitHub Actions with a
`macos-latest` runner also works) build, code-sign, and submit the iOS binary
on remote Mac hardware from a GitHub push — no local macOS required. What you
still need regardless of build method: an **Apple Developer Program
membership ($99/year)**, and Apple's own review process (which runs to its own
timeline, historically slower and stricter than Google's).

**Launch Android first anyway — but as a sequencing choice, not a technical
wall.** Reasons: it is faster to get a first build in front of testers (Google
Play review is same-day to a few days vs. Apple's typically longer review),
it avoids paying $99/yr before you know anyone will subscribe, and it means
building the payment/webhook plumbing once and proving it works before paying
twice for two stores' worth of review cycles. Once Android has real
subscribers, set up Codemagic and submit iOS from the same codebase — no
rewrite required, Flutter already targets both. See `docs/LATER.md` for the
Codemagic setup note.

### What is real vs. fake

**Real and working:** email/Google auth, weight tracking, training sessions and
streaks, round timer, onboarding, settings, and the entire EdgeFuel nutrition
system — deterministic calorie/macro engine, 6-step setup wizard, daily food
logging, 94-food catalog, 24-recipe library with allergen filtering and
serving scaling.

**Fake — looks real, is not:**
- Technique Library (list UI, no videos)
- Corner Coach (static cue cards, not personalised, not AI despite the name)
- Mobility (placeholder)
- Camp Plan (placeholder)
- Legal pages (placeholder text)

**Built but not switched on:** the EdgeFuel AI backend. Code complete, tested,
never deployed. See Step 2.

**Does not exist:** payments, crash reporting, app icon, account deletion.

---

## PART 2 — THE MVP (what ships, what does not)

### Ships in v1

- Account + onboarding
- EdgeFuel: targets, food logging, 24 recipes, allergen filtering
- Training schedule + round timer + session logging
- Weight tracking + chart
- Free/Pro split with **real payments**
- Legal, account deletion, crash reporting

### Does NOT ship in v1 — hide it

- Technique Library videos
- Corner Coach
- Mobility
- Camp Plan
- AI chat (the AI explains the plan, nothing more)
- Meal plans / grocery lists (that is v1.1)
- iOS — not blocked technically (Codemagic builds it without a Mac), deferred
  so you build the payment plumbing once and validate it before paying for a
  second store's review cycle

**A smaller finished app is worth more than a bigger unfinished one.** Every
placeholder screen a reviewer or user opens costs you credibility you cannot
buy back.

### Free vs Pro

**Free** (must be genuinely useful, or nobody trusts you enough to pay):
personalised targets, unlimited food logging, 12+ recipes, basic schedule,
standard timer, 5 weight entries, basic dashboard.

**Pro — $6.99/mo or $49.99/yr, 7-day trial:**
full 24-recipe library, unlimited weight history, nutrition analytics, all
timer presets, AI plan explanations, and — the reason people *stay* — a weekly
review and new recipes added regularly.

> Do not price at $9.99/$79.99 until the weekly review and meal plans exist.
> You are not selling that much yet.

---

## PART 3 — WHAT TO FIX BEFORE ANYTHING NEW

These are not features. They are the difference between an app that can be
sold and one that cannot.

1. **Push your work.** 5 commits exist only on your laptop.
2. **Rotate the leaked OpenRouter key.**
3. **Account deletion** — Google Play *requires* it. Settings currently pops a
   message admitting it is not built.
4. **Real legal copy** — privacy policy, terms, medical disclaimer, hosted on a
   public URL.
5. **Crash reporting** — you currently have no way to know if the app crashes.
6. **Real app icon + release signing** — the APK is debug-signed with the stock
   Flutter icon.
7. **Verify Google Sign-In on real Android** — never confirmed. May be broken
   for your one tester right now.
8. **Delete the dead legacy meal code** — ~120 lines with zero callers.

---

## PART 4 — THE STEPS. IN ORDER. DO NOT REORDER.

Each step says what "done" means. Do not move on until it is true.

### STEP 1 — Push (10 minutes) ⬅ START HERE

```
! gh auth refresh -s workflow
git push origin main
```

Your token lacks the `workflow` scope, which is why the CI commit is stuck.

**Done when:** `git status` says up to date, and GitHub Actions is green.

---

### STEP 2 — Rotate the key + deploy the AI (1 hour, your terminal only)

1. Revoke the old key, make a new one: https://openrouter.ai/keys
2. `firebase functions:secrets:set OPENROUTER_API_KEY` — the ONLY place the
   key is ever typed
3. `firebase deploy --only functions,firestore:rules`
4. Set a $5/month budget alert in Google Cloud billing

Then in the app: gate the AI behind Pro. It is currently free for everyone,
which contradicts every other Pro feature.

**Done when:** "Ask EdgeFuel Coach" returns a real answer, and a free account
cannot use it.

---

### STEP 3 — Store-blockers (3–4 days)

Build in this order:

1. **Account deletion** — Settings → delete account → re-auth → wipe
   `users/{uid}` and all subcollections → sign out. Plus a public web page
   where Android users can request deletion without installing the app.
2. **Legal** — privacy policy, terms, medical/nutrition disclaimer. Host on
   GitHub Pages, free. Must state that you store weight and body data.
3. **Crashlytics** — add the package, verify a forced test crash appears.
4. **App icon + splash** — `flutter_launcher_icons`, `flutter_native_splash`.
5. **Release keystore** — generate it, back it up somewhere you will not lose
   it. **If you lose this key you can never update your app again.**
6. **Verify Google Sign-In on a real Android device** — add SHA-1 and SHA-256
   to Firebase, regenerate `google-services.json`, install, tap the button.

**Done when:** all six are true and you have tested account deletion yourself.

---

### STEP 4 — Hide the fakes (1 day)

Remove from navigation, or clearly label as "coming soon":
Technique Library videos, Corner Coach, Mobility, Camp Plan.
Delete fake dashboard activity and any sample dates.

**Done when:** every button in the app does something real.

---

### STEP 5 — Payments (1 week)

This is the revenue step. It is **not** just an SDK.

1. Google Play Developer account — $25, one time
2. RevenueCat account — free under $2.5k/month revenue
3. `purchases_flutter` in the app
4. Products: monthly $6.99, annual $49.99, 7-day trial
5. **A Cloud Function receiving RevenueCat's webhook** that verifies the
   signature and writes `plan: pro` with the Admin SDK

Point 5 is mandatory. Your Firestore rules already stop the client from
granting itself Pro — that was a deliberate fix, do not undo it. The server
must be the only thing that can make someone Pro.

6. Paywall: real prices from the store, restore purchases, handle
   cancellation and expiry.

**Done when:** you buy your own subscription with a test account, Pro unlocks,
you cancel, and it locks again.

---

### STEP 6 — Beta (2 weeks, mostly not coding)

1. Firebase App Distribution → 20–30 fighters from local gyms
2. Give them Pro free for 30 days
3. **Watch at least 10 people go through onboarding without helping them.**
   Write down every place they hesitate.
4. Fix the top 3 problems only
5. Google Play closed testing track

**Done when:** 10 people have used it for a week and you know why the ones who
stopped, stopped.

---

### STEP 7 — Launch Android

Store listing, screenshots, health-data declaration, reviewer demo account,
then publish.

---

### STEP 8 — Only now: build more

EF-4 (connect nutrition to training), EF-5 (weekly review), meal plans,
grocery lists. These make Pro worth keeping. But they come **after** you have
proven someone will pay.

---

## PART 5 — WHAT NOT TO DO

- Do not start iOS until Android earns money. (Not a technical block — Codemagic
  builds iOS without a Mac — but there is no reason to pay $99/yr and run a
  second review cycle before Android has proven anyone will pay.)
- Do not build meal plans, grocery lists, or AI chat before Step 7.
- Do not add technique videos. Filming or licensing them is a project of its own.
- Do not redesign screens that already work.
- Do not add a state-management library, a router, or any new dependency
  without a concrete problem it solves.
- Do not let an agent "improve" the nutrition calculator. It is deterministic,
  safety-gated, and hand-verified. It is the most trustworthy code you own.
- Do not add features to `AppState`. It is already too big. New features get
  their own controller, the way EdgeFuel does.

---

## PART 6 — TESTING: WHAT KIND, WHEN

**Definition of Done — run all three, every time, before every commit:**

```bash
export PATH="/c/src/flutter/bin:$PATH"
dart format .
flutter analyze          # must say "No issues found"
flutter test             # must be all green
```

CI runs the same three plus the backend tests. **CI uses a newer Flutter than
your laptop** (3.47 vs 3.12) and has caught a real bug your local analyzer
missed. Trust CI over local.

### The four kinds of test in this project, and when to write which

| Kind | Where | Write one when |
|---|---|---|
| **Unit** | `test/unit/` | Any calculation, policy, or data rule. Always. |
| **Content** | `test/unit/edge_fuel/*catalog*` | You add recipes or foods. Asserts the catalog cannot silently degrade. |
| **Widget** | `test/widget/` | A screen has real states — loading, empty, error, locked. |
| **Flow** | `test/flow/` | A journey crosses screens (sign up → onboard → log). |

### Rules learned the hard way — obey these

1. **Widget tests cannot do real file I/O.** They run on a fake clock, so
   `File.readAsString()` never completes and `pumpAndSettle` hangs. Read files
   in `setUpAll` and inject the string.
2. **`ListView` only builds what fits the screen.** If a test cannot find
   something below the fold, it is not missing — use
   `tester.scrollUntilVisible(...)`.
3. **Never call a `ChangeNotifier` method synchronously in `initState()`.**
   Wrap it in `addPostFrameCallback`.
4. **`PrimaryButton` and `AppHeader` uppercase their text.** Test for
   `'ADD TO TODAY'`, not `'Add to today'`.
5. **Test behaviour that matters, not coverage.** The best tests in this repo
   assert that pre-training recipes are low in fat and post-training recipes
   carry protein — those catch *bad advice*, not just bad code.

---

## PART 7 — DESIGN: THE APPLE RULES, TRANSLATED

The `apple-design` and `emil-design-eng` skills are **web** skills. Their code
(CSS, Framer Motion, `backdrop-filter`) does not compile in Flutter. The
principles transfer; the code does not. Translation table:

| Principle | Flutter |
|---|---|
| Spring, damping + response | `SpringDescription.withDampingRatio` |
| Animate from current value | `AnimationController.animateTo` — never rebuild a Tween from the target |
| `backdrop-filter` | `BackdropFilter(filter: ImageFilter.blur(...))` |
| `transform-origin` | `Transform.scale(alignment:)` or `Hero` |
| `prefers-reduced-motion` | `MediaQuery.disableAnimationsOf(context)` |
| Dynamic Type | `MediaQuery.textScalerOf(context)` |
| Haptics | `HapticFeedback` |

### The seven rules that actually matter here

1. **Feedback on press-down, not release.** Use `PressScale` (already built) on
   any custom tappable surface. Waiting for the tap to complete feels dead.
2. **Animate the derived value, not the one being touched.** The serving count
   updates instantly; the macros animate. Animating what the finger controls
   adds lag.
3. **Enter and exit along the same path.** What slides in from the right leaves
   to the right.
4. **Every animation must be interruptible** and start from where it currently
   is on screen.
5. **Respect reduced motion.** Check `disableAnimationsOf` and fall back to a
   cross-fade. Never remove content, only movement.
6. **Restraint.** Ask "should this animate at all?" The answer is usually no.
   Animate: screen transitions, value changes, confirmations. Do not animate:
   list entrances, filter chips, scroll reveals. The brand is discipline.
7. **Type: large text gets negative tracking, small text positive.** Never one
   letter-spacing for all sizes.

### Non-negotiable accessibility

44px minimum touch targets. Semantic labels on icon buttons. Layout must
survive the user's larger text setting. Disabled controls must *look* disabled,
never silently swallow a tap.

---

## PART 8 — MOBILE OPTIMIZATION

Do these at Step 4, not before:

- Animate only `transform` and `opacity`.
- `ListView.builder` for any list that can grow. Never the fixed-children form.
- `const` constructors everywhere the analyzer suggests them.
- `RepaintBoundary` around anything that animates independently.
- Fonts are already bundled — do not reintroduce runtime Google Fonts.
- `flutter build apk --analyze-size` before release; look for anything
  surprising.
- Firestore offline persistence is already on. Logging food must work on a gym
  wifi that drops.
- Test on a **cheap, old Android phone**, not an emulator. Your users are
  fighters, not people with new iPhones.

---

## PART 9 — HOW THIS MAKES MONEY

### The mechanics

Store takes 15% (first $1M/yr). RevenueCat is free under $2.5k/month. So at
$6.99/mo you keep about **$5.94** per subscriber.

| Subscribers | Your monthly revenue |
|---|---|
| 10 | ~$59 |
| 50 | ~$297 |
| 200 | ~$1,188 |
| 500 | ~$2,970 |

**The first goal is not money. It is proof that anyone pays at all.** Ten
paying subscribers is the milestone that matters, because it tells you the
product is worth something. Everything after that is distribution.

### What makes people keep paying

A subscription must keep giving. Static content does not justify a recurring
charge — Apple and Google both take this seriously, and so will your users.
The recurring value is:

- New recipes added monthly
- The weekly fuel review (EF-5)
- Targets that adapt as their weight changes

That is why Step 8 exists. But it comes after payments work.

### Getting the first users

Not ads. Content and gyms.

- Short videos answering real questions: *"What should an MMA fighter eat on
  sparring day?"*, *"How many calories does a fighter actually need?"*, *"How
  to make weight without wrecking your session."*
- Post to TikTok, Reels, Shorts. Consistently.
- Walk into local MMA, boxing, BJJ and kickboxing gyms. Talk to coaches. Give
  the gym free Pro codes.
- Small gyms and coaches beat paid influencers at this size.

**Targets for the beta:** 100 users, 40 coming back weekly, 10 paying, and at
least 5 who say they would be annoyed if the app disappeared.

---

## PART 10 — WHICH CLAUDE SKILLS TO USE, AND WHEN

You have a lot installed. Most are irrelevant. Use these:

| Doing this | Invoke |
|---|---|
| Any Firestore work, rules, indexes | `firebase-firestore` |
| Before any deploy, or touching rules | `firebase-security-rules-auditor` |
| Step 3 crash reporting | `firebase-crashlytics` |
| Writing tests | `dart-add-unit-test`, `flutter-add-widget-test` |
| Before committing | `dart-run-static-analysis` |
| UI polish, motion decisions | `apple-design`, `emil-design-eng` |
| Layout bugs, overflows | `flutter-fix-layout-issues` |
| Reviewing your own diff | `/code-review` |
| Agent proposing too much | `ponytail` — forces the smallest solution |
| Debugging something confusing | `investigate` |

**Ignore:** everything Supabase, Stripe, Next.js, React, Vercel, Remotion,
Cloudflare, Higgsfield. Wrong stack. They are noise in the list.

**One skill worth knowing about:** `ponytail`. When an agent wants to build an
abstraction you do not need, invoke it. It is a bias toward doing less, which
is the bias you need right now.

---

## PART 11 — REALISTIC TIMELINE

| | |
|---|---|
| Steps 1–2 | 1 day |
| Step 3 | 3–4 days |
| Step 4 | 1 day |
| Step 5 | 1 week |
| Step 6 | 2 weeks |
| Step 7 | 2–3 days |
| **Android live, taking money** | **4–5 weeks** |

That assumes you do one step at a time and do not add features.

---

## THE NEXT THING YOU DO

```
! gh auth refresh -s workflow
```

Then `git push origin main`. That is Step 1. Nothing else until it is done.

# FighterEdge — Product, SaaS, Engineering, and Launch Master Plan

**Audit date:** 19 July 2026  
**Repository audited:** `fighter_edge/`  
**Current stage:** Working Flutter prototype / pre-production  
**Recommended product name:** **FighterEdge** (one word, spelled exactly this way everywhere)  
**Primary launch platform:** Android first, then iOS  
**Primary audience:** Amateur MMA and combat-sport athletes who train 3–6 times per week

> This is a product and implementation plan, not medical or legal advice. Any weight-management, nutrition, readiness, injury, or recovery guidance must be reviewed by qualified combat-sport and healthcare professionals before publication.

---

## 1. Executive decision

FighterEdge has a credible UI prototype and good foundations, but it is **not ready to charge users**. The app passes static analysis and all 53 current automated tests, yet the main user data is still mocked or held only in memory, the visible Pro button can grant access from the client, multiple screens contain placeholders, and there is no production purchase lifecycle.

The product should not compete as “another MMA content library.” Content is expensive, slow to build, easy to compare, and already available in huge quantities elsewhere. FighterEdge should become the athlete’s **daily fight-readiness operating system**:

> **Plan the week. Train with focus. Log in seconds. Know when to push and when to recover. Arrive ready.**

The first paid promise should be measurable and recurring:

- a real fight-camp plan tied to a date and weight class;
- fast session logging across MMA, boxing, Muay Thai, BJJ, wrestling, S&C, and mobility;
- hands-free round timing with voice, sound, and haptics;
- readiness and training-load trends that turn logs into decisions;
- safe weight-trend visibility without pretending to provide medical treatment;
- weekly reports that prove progress and tell the athlete what to do next.

### The correct order

1. Make user data real and persistent.
2. Validate the core loop with 12–20 genuine combat athletes.
3. Make the loop fast, reliable, offline-capable, and safe.
4. Add real store billing and server-authoritative entitlements.
5. Charge for recurring decisions and insight—not for basic logging.
6. Add coach/team features only after individual athletes retain.

### Current launch verdict

| Area | Status | Decision |
|---|---|---|
| Flutter code health | Good | Keep and evolve |
| Core visual direction | Promising | Refine, do not redesign from zero |
| Authentication | Partial production | Fix unsupported paths and account lifecycle |
| User data persistence | Missing | P0 blocker |
| Subscription security | Demo only | P0 blocker before money |
| Payments | Missing | Add only after product validation |
| Content/video | Prototype shell | Do not market yet |
| Settings/legal/deletion | Missing | Store-release blocker |
| Testing | Good prototype suite | Expand to Firebase, billing, rules, device, and accessibility |
| Observability | Missing | Add before closed beta |

---

## 2. Audit scope and evidence

The audit reviewed the repository structure, production entry point, authentication repository, Firestore rules, subscription model, application state, models, every screen, shared widgets, theme, Android and web configuration, CI, current documentation, and automated tests.

Verification completed on 19 July 2026:

```text
Flutter 3.44.6 • Dart 3.12.2
flutter analyze: No issues found
flutter test: 53 tests passed
```

Live browser rendering could not be inspected because no in-app or Chrome browser was available in the audit environment. Visual findings below are based on the Flutter widget tree, theme tokens, assets, responsive-layout signals, tests, and platform configuration. A real-device visual QA pass remains a required Phase 0 task.

### Current implemented surface

- Firebase bootstrap and authentication repository abstraction.
- Email/password authentication and Google/Apple provider code paths.
- Local development authentication with magic-code simulation.
- Dashboard and five-tab app shell.
- Training Camp weekly view.
- Functional round timer countdown, pause, reset, phases, and presets.
- Weight log and chart UI.
- Nutrition checklist and calorie/macro calculations.
- Filterable technique-library shell.
- Corner Coach cue-card shell.
- Profile and More screens.
- Free/Pro entitlement model and UI gates.
- Unit, widget, journey, and integration-test scaffolding.
- GitHub CI for formatting, analysis, and tests.

### What the tests currently prove

- Local/demo authentication and persistence behavior.
- Core entitlement decisions.
- Basic `AppState` calculations.
- Timer state changes.
- Several screen/component render paths.
- A demo journey from signup to self-upgrade and sign-out.

### What they do not prove

- Firestore data persistence or offline conflict behavior.
- Firebase Auth repository behavior on devices.
- Android Google sign-in configuration.
- Apple sign-in configuration.
- Email-link authentication.
- Firestore security rules against emulator abuse cases.
- Real purchases, renewals, grace periods, refunds, restores, upgrades, or cancellations.
- Webhook idempotency and entitlement reconciliation.
- Video playback, caching, authorization, captions, or progress.
- Push/local notification delivery.
- Accessibility, large text, screen-reader behavior, or color-blind states.
- Responsive rendering across small phones, tablets, and web.
- Release signing, store bundles, crash reporting, or production monitoring.

---

## 3. Technical and product audit findings

### P0 — blockers before accepting payment

#### 3.1 User-generated data disappears

`AppState` initializes weights and meals from `MockData` and never writes them to a durable repository. Training, activity, fighter statistics, techniques, and coach cues are also mostly mock-backed. A user can believe they are building a record, then lose it on restart.

**Required fix:** create repository interfaces and Firestore implementations for profile, training, weight, nutrition, readiness, camps, techniques/progress, and preferences. Mobile must remain usable offline.

#### 3.2 Entitlements are client-authoritative

`AuthController.setPlan()` calls `AuthRepository.updatePlan()`, and Firestore currently lets users write their whole `users/{uid}` document. Anyone with a modified client can become Pro.

**Required fix:** the client requests purchases but never assigns its own plan. Store/RevenueCat events must become the authority; a verified webhook or trusted integration writes entitlement state. Firestore rules must prevent clients from editing billing fields.

#### 3.3 No real purchase state machine

The paywall displays a hard-coded `$9.99 / month`, performs no purchase, exposes no annual plan, and lacks restore, manage, cancel, billing retry, grace-period, refund, expiry, or cross-device behavior.

**Required fix:** model entitlements independently from UI, integrate store products through RevenueCat or an equivalent subscription backend, and test the full lifecycle.

#### 3.4 No account deletion or associated-data deletion

Both Google Play and Apple require account deletion paths for apps that support account creation. Google also requires a discoverable external web resource for deletion requests. Deleting Firebase Auth alone is insufficient; Firestore, Storage, analytics identifiers where applicable, and third-party customer records need a defined deletion workflow.

#### 3.5 Health and weight-cut safety is not designed

Nutrition and weight features place FighterEdge inside health-and-fitness policy scope. Fight-weight features can become harmful if they optimize aggressive dehydration or present generated recommendations as medical truth.

**Required fix:** define a safety policy before adding calculations. Use trends and education, conservative guardrails, qualified review, source/version metadata, warning states, and an escalation message. Never provide a “guaranteed cut,” diagnose illness, or encourage dangerous dehydration.

### P1 — blockers before a serious closed beta

#### 3.6 Authentication paths misrepresent capabilities

- Apple sign-in is displayed without completed Apple configuration.
- The production Firebase repository deliberately rejects magic-link/code methods.
- Android Google sign-in still needs device-level verification and correct signing fingerprints.
- Email verification exists on signup but has no complete product flow.
- No reauthentication exists for password/account destructive operations.

Add explicit repository capabilities such as `supportsGoogle`, `supportsApple`, and `supportsEmailLink`, and render only verified methods.

#### 3.7 App startup has no resilient failure path

`main()` waits for Firebase initialization and auth repository initialization before rendering. A configuration or network failure can prevent the app from presenting a useful recovery state.

Add a guarded bootstrap state with retry, offline explanation, structured error reporting, and environment validation.

#### 3.8 No environment separation

One Firebase project is used for development and real testers. Create `dev`, `staging`, and `prod` flavors with separate Firebase projects, app IDs, bundle IDs, App Check configuration, analytics streams, and secrets.

#### 3.9 No observability

There is no Crashlytics, structured product analytics, performance monitoring, support diagnostic export, or release correlation.

Add Crashlytics before inviting a wider beta. Track product events only after consent/privacy review; never put health notes, weight values, meal names, email addresses, or tokens in analytics event parameters or crash logs.

#### 3.10 Release identity is unfinished

- Android release builds use the debug signing key.
- Application ID still contains the starter-style `com.fighteredge.fighter_edge`.
- Android and web icons remain unverified/placeholder quality.
- Web manifest and HTML still say “A new Flutter project,” use Flutter-blue colors, and use `fighter_edge` titles.
- The README is still Flutter starter content.
- Version is still `1.0.0+1`, which implies a maturity the product does not yet have.

Choose the permanent package and bundle IDs before publishing; they are expensive or impossible to change later.

### P2 — quality and maintainability

#### 3.11 Architecture will not scale cleanly

The current small-app layout is understandable, but `AppState` is becoming a global feature bucket. Models contain UI types such as `IconData`; mutable `Meal.eaten` state lives inside a model; most domain models lack stable IDs, serialization, ownership, timestamps, schema versions, or sync metadata.

Move toward feature modules with domain entities, repositories, use cases/controllers, and UI. Keep Flutter/UI types out of persisted domain models.

#### 3.12 Navigation is imperative and unguarded

Raw `MaterialPageRoute` calls make deep links, auth redirects, notification routing, web URLs, state restoration, and analytics naming harder. Adopt `go_router` with named routes and route guards before magic links and notifications.

#### 3.13 Accessibility is mostly implicit

Icon buttons often have no tooltip or explicit semantic label. Several tap targets rely on padding and may be below the 48 dp Material recommendation. Red/green is used semantically and should not be the only state signal. Large text and screen-reader flows have no test coverage.

#### 3.14 Runtime fonts create avoidable brand drift

Oswald and Inter are loaded through `google_fonts`. Bundle licensed font files so offline first launch and screenshots retain the intended typography.

#### 3.15 Placeholder actions damage trust

Several icons have empty callbacks; Month and Plan announce “coming soon”; Mobility is a placeholder; Technique play buttons do not play video; profile edit does nothing. Remove, disable with honest labeling, or complete every visible action before store review.

---

## 4. Product positioning

### 4.1 Start with one segment

**Beachhead segment:** English- or French-speaking amateur combat athletes, age 18+, training at a gym 3–6 days per week, preparing for competition or trying to train with more structure.

Do not initially target all of these at once:

- casual UFC fans;
- professional teams with complex staff workflows;
- gym billing/CRM;
- children;
- general weight-loss consumers;
- at-home users seeking thousands of follow-along classes.

Those groups have different acquisition channels, safety expectations, workflows, and willingness to pay.

### 4.2 Jobs to be done

The core user is effectively saying:

- “Help me remember what I trained and whether I am improving.”
- “Help me organize MMA, grappling, striking, S&C, and recovery in one week.”
- “When I am wearing gloves, run the session without making me touch the phone.”
- “Tell me whether my recent load and readiness suggest pushing or recovering.”
- “Show me whether camp and weight are trending in the right direction.”
- “Give me something useful to share with my coach.”

### 4.3 Category and promise

**Category:** Combat-athlete training and fight-camp companion.  
**Short promise:** **Train with a plan. Arrive ready.**  
**Long promise:** FighterEdge connects planning, session execution, fast logging, readiness, and camp trends so combat athletes can make better training decisions every week.

### 4.4 Differentiation

Competitors demonstrate four established value clusters:

| Product | Visible position | Current public price signal | Lesson for FighterEdge |
|---|---|---:|---|
| FightCamp | Hardware tracking + very large guided library | WORK $14.99/mo; All-Access $39.99/mo | Do not compete on library size or hardware first |
| FightTrainer | Adaptive S&C, readiness, camp, offline | $20/mo or $60/yr | Fight-specific planning and readiness are monetizable |
| Athlete Analyzer | Coach/athlete planning, analytics, video | Athlete €5.99/mo or €59/yr | Serious analytics can sit at a moderate athlete price |
| SparLink | Timer, logs, matchmaker, coach/gym tiers | Athlete €3.99/mo or €29.99/yr | Low-cost log/timer utility faces price pressure |
| Seconds Pro | Excellent general-purpose interval timer | One-time paid app | A timer alone cannot justify recurring SaaS pricing |
| Roll MMA | Technique retention, videos, spaced review, community | Subscription model | Technique memory is more defensible than a static catalog |

FighterEdge should combine **combat-specific weekly planning + hands-free execution + reflection + readiness**, while staying much simpler than enterprise athlete-management software.

### 4.5 The core value loop

```text
Set goal/camp
    ↓
Plan this week
    ↓
Start timer or log training in <20 seconds
    ↓
Add 10-second session reflection + next-day readiness
    ↓
Receive a useful weekly insight/recommendation
    ↓
Adjust next week and share with coach
    ↺
```

If the app cannot complete this loop with real data, more features will add surface area rather than value.

---

## 5. Subscription strategy

### 5.1 What users should pay for

Users should subscribe because FighterEdge continuously produces:

- adaptive weekly planning;
- longer-term history and trend analysis;
- fight-camp timeline and progress;
- readiness/load interpretation;
- recurring reviewed programs, mobility routines, and technique drills;
- cloud sync, exports, and coach sharing;
- new insight every week as the athlete adds data.

They should **not** need a subscription to access basic safety, their own recent data, account deletion, purchase restoration, or a usable timer.

### 5.2 Recommended launch tiers

#### Free — build trust and the habit

- Basic account and onboarding.
- Unlimited basic round timer with one MMA preset and custom rounds.
- Training log with a rolling 14-day view.
- Weight log with a rolling 30-day view.
- One active weekly plan.
- Basic streak and weekly summary.
- A small set of reviewed tutorials.
- Export/account deletion/privacy controls.

#### Pro Athlete — recurring decisions and depth

**Initial price to test, not a permanent fact:** `$7.99/month` or `$59.99/year`, localized by the stores. Show the full annual charge clearly. Test willingness to pay with interviews and a purchase-intent screen before locking pricing.

- Unlimited history and advanced analytics.
- Fight Camp mode with event date, phases, taper visibility, and progress.
- Readiness and training-load trends.
- Unlimited custom timer templates, voice cues, haptics, and session chains.
- Weekly “Fighter Report” with useful, explainable observations.
- Advanced weight trend and target range with reviewed safety guardrails.
- Full reviewed drill/mobility collection and offline downloads within limits.
- Technique notes, favorites, review queue, and progress.
- PDF/CSV export and private coach-share link.

#### Coach — later, after athlete retention

Suggested future test: `$19.99–29.99/month` for up to 10 active athletes, then per-seat/team pricing.

- Athlete invitations and consent.
- Coach dashboard and flags.
- Assign plans/drills.
- Comment on sessions and timestamped video.
- Weekly team overview.
- Role-based access and audit history.

Do not build this tier until at least 30 retained athletes repeatedly ask to share data with coaches or 5 coaches commit to a pilot.

### 5.3 Paywall rules

- Show the paywall after demonstrated value, such as completing the first week or opening a clear Pro insight—not immediately after install.
- The paywall must be dismissible when a free tier exists.
- Use outcome copy: “See what is changing across your camp,” not “unlock everything.”
- Show monthly and annual store products, actual localized prices, billing period, renewal behavior, trial terms, cancellation path, Privacy, Terms, and Restore Purchases.
- Never use fake scarcity, hidden dismiss controls, preselected consent, or misleading monthly-equivalent annual pricing.
- Add a post-purchase success state and make entitlement activation idempotent.
- Measure paywall view → product selection → purchase start → purchase success → first Pro value event.

### 5.4 Trial recommendation

Start with **no automatic trial** during the first closed beta; let users earn a 7-day Pro preview after they log three sessions. This ensures they have data that makes analytics valuable. Then A/B test:

- earned 7-day preview;
- 7-day store trial;
- no trial with a generous free tier.

Do not blindly copy short trials. RevenueCat’s 2026 data shows hard paywalls can convert faster, but FighterEdge needs habit and data before its differentiated value becomes visible. Product context matters more than the aggregate benchmark.

---

## 6. Detailed functional blueprint

## 6.1 Onboarding and activation

Goal: first useful plan and first logged session in under three minutes.

Collect only what changes the experience:

1. Primary sport(s): MMA, boxing, Muay Thai, BJJ, wrestling, other.
2. Experience: beginner, amateur competitor, professional.
3. Goal: consistency, first fight, active camp, conditioning, technique.
4. Weekly availability and typical gym sessions.
5. Equipment availability.
6. Preferred units and language.
7. Optional fight date and weight class.

Then generate a simple editable week. Do not ask for biography, record, height, macros, or notification permission before it is relevant.

**Activation event:** user completes onboarding, sees a real week, and starts or logs one session.

## 6.2 Training log

This is the system of record and should be the first real domain.

Each session needs:

- stable ID and owner ID;
- start/end/time zone;
- discipline and session type;
- duration;
- planned vs unplanned;
- RPE/intensity 1–10;
- tags: class, drilling, pads, bag, sparring, rolling, S&C, roadwork, mobility;
- optional rounds and notes;
- optional techniques practiced;
- optional pain/injury flag with non-diagnostic wording;
- completion source: timer, plan, manual, import;
- created/updated timestamps and schema version.

Fast paths:

- repeat last session;
- one-tap “Gym class” then edit later;
- timer completion automatically creates a draft log;
- templates;
- offline creation and retry.

## 6.3 Weekly planner and Fight Camp

Weekly planning must remain editable and explainable. Do not present generated plans as universal truth.

Camp structure:

- event name/date;
- ruleset/discipline;
- weight class and current trend;
- number of available weeks;
- broad phases: base, build, specific, taper, fight week;
- hard gym commitments;
- planned training emphasis;
- rest and recovery days;
- completion and adherence;
- change history.

V1 does not need an AI planner. Use reviewed templates plus deterministic rules and clear user control. A coach or athlete should always be able to edit recommendations.

## 6.4 Round timer

The timer must work when the screen locks or the app is backgrounded, within platform limits. Compute elapsed time from timestamps rather than assuming one periodic callback equals one real second.

Required V1:

- MMA, boxing, Muay Thai, BJJ rolling, Tabata, and custom templates;
- warm-up, work, rest, number of rounds, cool-down;
- 10-second warning;
- bell, voice, haptics, and independent toggles;
- large landscape mode;
- keep screen awake option;
- background/foreground correction;
- pause/resume/reset confirmation where appropriate;
- link completion to a training log draft;
- accessibility labels and non-color phase labels.

## 6.5 Readiness and training load

Start with transparent inputs, not fake precision.

Daily check-in:

- sleep quality 1–5;
- energy 1–5;
- soreness 1–5;
- stress 1–5;
- optional resting heart rate/import later;
- optional note.

Session load can begin with `duration_minutes × session_RPE`. Show the components and avoid claiming medical accuracy. Use personal baselines only after sufficient data. Provide language such as “lower than your recent baseline” rather than “you are overtrained.”

## 6.6 Weight and nutrition

V1 weight:

- unit-aware entries;
- morning/other context;
- seven-day rolling average;
- target range, not only a single line;
- rate-of-change visibility;
- data gaps and scale variance explanation;
- export and delete.

V1 nutrition should stay lightweight:

- hydration and meal-completion habits;
- optional calories/macros for users who choose them;
- editable goals;
- no hard-coded target presented as personalized truth;
- reviewed educational content;
- no aggressive weight-cut calculator in initial launch.

If advanced fight-week guidance is ever added, it requires named expert review, conservative limits, versioned protocols, contraindication and age gates, warning/escalation flows, and ongoing review. The ISSN combat-sport position stand should be one reference, not an excuse to automate risky behavior.

## 6.7 Technique library and learning

A static catalog is weak. Turn techniques into a learning loop:

- short, single-purpose videos;
- prerequisites and common mistakes;
- stance/side information;
- tags and discipline;
- captions and transcript;
- save/favorite;
- personal notes;
- “trained this today” link to session;
- review queue using simple spaced repetition;
- progress: watched, practiced, confident—not fake “mastery.”

Start with 20–30 excellent licensed or original clips, not 500 inconsistent links.

## 6.8 Corner Coach

Rename or reposition the current promise unless it is truly backed by useful data. “Round-by-round AI game plan” overpromises and can create unsafe or low-quality advice.

Safer useful V1:

- athlete-created cue cards;
- coach-authored cue cards;
- voice playback during rest;
- template cues by session goal;
- recent-session reflection prompts;
- deterministic reminders from the current plan.

Later AI can summarize user-owned data or draft options, but it must:

- explain which data informed the suggestion;
- avoid diagnosis and dangerous weight advice;
- allow report/feedback;
- be constrained by reviewed rules;
- never send private health data to a model without explicit disclosure and consent.

## 6.9 Settings

Required sections:

- Account: name, email state, providers, password, export, delete.
- Subscription: plan, expiry/renewal, restore, manage subscription.
- Training: units, week start, sport preferences, timer defaults.
- Audio & haptics: bell, voice, warning, vibration, volume test.
- Notifications: specific reminder toggles and times.
- Downloads: offline video storage and clear cache.
- Appearance: system/dark; high contrast later.
- Language: English first, then French; Arabic only when full RTL QA is funded.
- Privacy: consent choices, privacy policy, data export/deletion.
- Help: tutorial replay, FAQ, contact, diagnostics ID.
- About: version/build, licenses, terms, acknowledgements.

## 6.10 Notifications

Use local notifications first:

- planned-session reminder;
- incomplete weekly plan reminder;
- user-chosen weigh-in reminder;
- readiness check-in reminder;
- technique review reminder.

Ask permission at the moment the user enables a reminder. Avoid shame, injury pressure, or streak threats. Never expose weight or sensitive notes on the lock screen by default.

---

## 7. UX, motion, styling, and brand system

### 7.1 Brand decision

Use **FighterEdge**, not Fighter Eadge, fighter_edge, FIGHTER EDGE, and Fighter Edge interchangeably. The legal entity and store developer name can differ, but the customer-facing product must be consistent.

Before launch:

- search trademark databases in intended markets with qualified advice;
- secure a practical domain and social handles;
- define logo clear space, minimum size, one-color version, app icon, and misuse rules;
- test the icon at 24 px, not only as a large mockup.

### 7.2 Visual direction

The current near-black, warm-red, Oswald/Inter direction fits a disciplined combat brand. Keep the restraint, but avoid the generic “black + red MMA” trap by adding a distinct graphic system:

- **Concept:** the edge as a cut line / corner angle / forward wedge.
- **Primary mark:** an abstract `FE` or corner wedge, not a generic glove icon.
- **Data motif:** thin corner lines and measured ticks, suggesting a fight clock and coaching board.
- **Photography:** real gym texture, imperfect training moments, diverse athletes; no fake championship imagery.
- **Voice:** direct, calm, credible. “Today’s work” rather than “UNLEASH THE BEAST.”

Suggested token refinement:

| Token | Current | Direction |
|---|---|---|
| Background | `#0A0A0B` | Keep |
| Surface | `#151517` | Keep; add clear elevated hierarchy |
| Brand red | `#E63328` | Validate contrast for each use |
| Positive | green | Pair with icon/text, never color alone |
| Warning | amber | Reserve for actual attention states |
| Heading font | Oswald | Bundle locally; use sparingly |
| Body font | Inter | Bundle locally |
| Radius | 14–20 px | Slightly reduce on data-dense screens |

### 7.3 Information architecture

Recommended athlete navigation:

1. **Today** — next session, readiness, camp countdown, quick log.
2. **Plan** — week and fight camp.
3. **Train** — timer, guided session, quick log.
4. **Progress** — load, consistency, weight, skills.
5. **Profile** — settings, subscription, support.

Nutrition, technique, mobility, and coach tools should be reachable as modules, not all promoted as equal primary tabs.

### 7.4 Motion specification

Motion should communicate state under gym conditions.

| Interaction | Motion | Duration | Accessibility |
|---|---|---:|---|
| Tab change | subtle fade-through | 180–220 ms | reduce-motion: crossfade or none |
| Detail push | shared-axis horizontal | 220–280 ms | preserve spatial direction |
| Log saved | check + card settle | 180 ms | haptic optional |
| Counter update | short numeric tween | 250–350 ms | announce final value only |
| Timer last 10 s | controlled ring pulse | 700–900 ms loop | never rely on pulse alone |
| Work/rest change | color + label + bell/haptic | 200 ms | user-configurable |
| Chart load | line reveal | 300–450 ms | skip when reduce motion |
| Paywall appearance | no dramatic trap animation | 200 ms | dismiss remains visible |

Rules:

- never animate every card on every return;
- no confetti for routine actions;
- preserve 60 fps on low/mid-range Android devices;
- cancel or coalesce animations during rapid input;
- respect reduced-motion settings;
- test with large text and screen readers.

### 7.5 Responsive and accessibility plan

Test at minimum:

- 320×568 logical pixels;
- common 360/390 px phones;
- tall Android devices;
- tablet portrait/landscape;
- text scale 1.0, 1.3, and 2.0;
- TalkBack and VoiceOver;
- keyboard navigation on web;
- light glare and low-brightness gym conditions.

Add semantic labels, tooltips, focus order, 48 dp interactive targets, visible focus, text alternatives, and patterns/icons alongside red/green states.

---

## 8. Target engineering architecture

### 8.1 Principles

- Offline-capable for training and logs.
- Server-authoritative billing.
- Repository interfaces around external systems.
- Feature-oriented organization.
- Immutable domain models with stable IDs.
- UTC timestamps plus explicit local date/time zone where calendar behavior matters.
- Idempotent writes and webhooks.
- Versioned schemas and content.
- No sensitive data in logs or analytics.

### 8.2 Suggested Flutter structure

```text
lib/
  app/
    bootstrap/
    routing/
    theme/
    config/
  core/
    analytics/
    errors/
    persistence/
    network/
    widgets/
  features/
    auth/
      data/ domain/ presentation/
    onboarding/
    training/
    planner/
    timer/
    readiness/
    weight/
    nutrition/
    techniques/
    billing/
    settings/
  firebase_options_dev.dart
  firebase_options_staging.dart
  firebase_options_prod.dart
```

Do not rewrite everything before shipping. Move a feature when it receives real persistence or substantial work.

### 8.3 State management

Provider/`ChangeNotifier` is adequate for the prototype. The immediate problem is not the package; it is the oversized mixed `AppState` and missing repository boundaries. Split state by feature first. Consider Riverpod only if the team wants stronger dependency injection, test overrides, and async state handling; do not migrate for fashion.

### 8.4 Initial Firestore model

```text
users/{uid}
  public profile fields
  preferences
  onboarding state
  createdAt / updatedAt / schemaVersion

users/{uid}/trainingSessions/{sessionId}
users/{uid}/plans/{planId}
users/{uid}/readiness/{yyyy-mm-dd}
users/{uid}/weightEntries/{entryId}
users/{uid}/nutritionDays/{yyyy-mm-dd}
users/{uid}/techniqueProgress/{techniqueId}
users/{uid}/deviceTokens/{tokenId}

entitlements/{uid}
  plan
  active
  productId
  store
  expiresAt
  willRenew
  sourceEventId
  updatedAt

content/techniques/{techniqueId}
content/programs/{programId}
contentVersions/{versionId}
```

Keep billing documents separate from client-editable profiles. For coach features, add explicit memberships and roles rather than copying an athlete’s data into coach documents.

### 8.5 Firestore rules

Rules must enforce:

- signed-in ownership on all user subcollections;
- field allowlists and reasonable type/size validation where practical;
- no client write to entitlement, role, moderation, or billing fields;
- coach access only through explicit active membership and athlete consent;
- content writes only by trusted administration;
- deny by default.

Use the Firebase Emulator Suite to test allowed and denied cases in CI.

### 8.6 Offline and sync

Firestore already supports offline persistence on Android and Apple by default; web needs an explicit trust/privacy decision. Design the UI for:

- saved locally / syncing / synced / failed states;
- duplicate submission protection;
- last-write conflicts;
- deleted-while-offline behavior;
- sign-out cache handling;
- account switching on shared devices;
- retry without blocking training.

### 8.7 Video delivery

For beta, use original or properly licensed short clips. Recommended progression:

1. Metadata and transcripts in Firestore.
2. Streaming via a service with adaptive delivery and signed/private access, or carefully managed Storage for a small beta.
3. `video_player`-based player with captions, speed, orientation, analytics, and error recovery.
4. Limited encrypted/private offline downloads only if demand justifies complexity.

Unlisted YouTube is inexpensive but is not true access control, can expose recommendations/UI, and may not support the desired premium experience. Never upload footage without model releases, music rights, and instructor agreements.

---

## 9. Authentication and account plan

### Phase A — immediately

- Add auth capability flags and hide unsupported methods.
- Verify Android Google sign-in using debug and release SHA-1/SHA-256.
- Complete email verification banner, resend, and refresh.
- Improve errors without revealing whether arbitrary accounts exist.
- Add rate-aware retry and offline states.

### Phase B — before store beta

- Add profile editing.
- Add password change/reset and recent-login reauthentication.
- Add full account deletion and data deletion.
- Add external deletion-request page.
- Decide whether magic links are truly needed; implement Firebase email-link deep links correctly or remove the feature.
- Add Apple sign-in only when the Apple developer setup and App Store build are real.
- Enable App Check in monitor mode, validate metrics, then enforce for Auth/Firestore/Functions/Storage as applicable.

### Phase C — later

- Account linking so email and Google/Apple do not create confusing duplicates.
- Optional multi-factor authentication for coaches/admins.
- Admin support tooling with audited, least-privilege access.

---

## 10. Payments and entitlement architecture

### 10.1 Recommended stack

- Google Play Billing and Apple In-App Purchase for digital subscriptions in mobile apps.
- RevenueCat Flutter SDK for cross-platform purchase handling and entitlement normalization.
- RevenueCat customer ID mapped to Firebase UID only after authentication.
- RevenueCat webhooks to a trusted backend/Cloud Function for entitlement mirrors, analytics, and recovery workflows.
- Store management links and RevenueCat Customer Center or a carefully built equivalent.

RevenueCat currently advertises no charge up to `$2,500` monthly tracked revenue, then 1% of tracked revenue. Verify pricing again when implementing.

### 10.2 Required states

Model at least:

```text
unknown
free
trialing
active
gracePeriod
billingIssue
cancelledButActive
expired
refundedOrRevoked
```

The UI must distinguish “cancelled but usable until date” from “expired.” Cache entitlements for offline use with a controlled grace policy, then reconcile on reconnect.

### 10.3 Webhook requirements

- Verify authenticity according to provider documentation.
- Store event IDs and reject duplicate processing.
- Handle out-of-order delivery using event/effective timestamps.
- Retry safely.
- Never trust product ID or plan from the client.
- Keep an audit record without unnecessary personal data.
- Reconcile periodically against the subscription provider.
- Alert on repeated webhook failures.

### 10.4 Tunisia business constraint

Stripe’s official supported-country list does not currently include Tunisia for accepting payments as a locally supported Stripe business. Do not design the business around Stripe until the legal business entity and payout path are confirmed. Mobile store billing can be the first channel; discuss tax, foreign-currency, company structure, and payout obligations with qualified Tunisian accounting/legal professionals.

### 10.5 Store costs and launch constraints

- Google Play Console: `$25` one-time registration fee.
- New personal Play accounts may require 12 opted-in closed testers for 14 continuous days before production access.
- Apple Developer Program: `$99/year` or local equivalent.
- Platform commissions and regional billing rules change; use current console terms in financial models.

---

## 11. Analytics, experiments, and product metrics

### 11.1 North-star metric

**Weekly Planned-and-Reflected Sessions (WPRS):** number of training sessions per week that were started from a plan or timer, completed, and given a quick reflection.

This measures the whole value loop better than opens, timer starts, or logs alone.

### 11.2 Funnel

```text
Install
→ onboarding complete
→ first plan created
→ first session started/logged
→ 3 sessions logged
→ first weekly report viewed
→ second active week
→ Pro value viewed
→ purchase
→ retained subscriber
```

### 11.3 Launch KPI targets

These are decision thresholds, not promises:

| Metric | Closed beta target |
|---|---:|
| Onboarding completion | ≥70% |
| First session within 24h | ≥50% |
| 3 sessions within 7 days | ≥35% |
| Week-2 retained among activated users | ≥35% |
| Week-4 retained among activated users | ≥25% |
| Weekly report viewed by eligible users | ≥50% |
| Crash-free users | ≥99.5% |
| Core write sync success | ≥99% |
| Support-blocking purchase issues | 0 |

Do not buy significant ads until activation and Week-4 retention show a stable signal.

### 11.4 Event taxonomy

Use consistent names and no sensitive values:

```text
onboarding_started/completed
plan_created/edited
session_started/completed/logged
timer_started/completed
readiness_completed
weekly_report_viewed
pro_feature_previewed
paywall_viewed
product_selected
purchase_started/completed/failed/restored
subscription_management_opened
tutorial_started/completed
sync_failed
account_export_requested
account_deletion_requested/completed
```

Never send raw weight, health responses, session notes, meal content, or technique video uploads as analytics parameters.

### 11.5 Research cadence

- Interview 5 users before persistence implementation finishes.
- Observe 5 athletes using the timer/log in an actual gym environment.
- Run a 12–20 person four-week closed beta.
- Speak to churned or inactive testers every week.
- Maintain a problem log, not a feature-request voting contest.
- Require evidence for roadmap promotion: frequency, severity, segment fit, retention/revenue connection, implementation cost.

---

## 12. Testing and quality strategy

### 12.1 Test pyramid

#### Unit

- domain validation and serialization;
- weekly plan calculations;
- streak/time-zone boundaries;
- duration × RPE load;
- readiness baselines;
- weight unit conversion and rolling averages;
- entitlement state mapping;
- timer timestamp correction;
- content eligibility and progress.

#### Repository

- fake repository contract tests;
- Firestore emulator tests;
- offline queue/retry behavior;
- migration from earlier schema versions;
- deletion cascades.

#### Widget

- every loading, empty, partial, success, offline, permission-denied, and error state;
- free/Pro/expired/billing-issue states;
- text scaling and semantics;
- paywall disclosures and restore path.

#### Integration/device

- email signup/verify/reset/delete;
- Google sign-in on Android;
- purchase, restore, cancel, grace period, and expiry in store sandboxes;
- timer background/foreground and screen lock;
- notification deep links;
- video playback on poor network;
- offline log then reconnect;
- account switch and cache isolation.

#### Visual and accessibility

- golden tests for core screens and states;
- phone/tablet breakpoints;
- TalkBack/VoiceOver manual scripts;
- keyboard/focus on web;
- reduced motion;
- contrast audits.

### 12.2 CI/CD

Extend CI to include:

- formatting, analysis, unit/widget tests;
- minimum meaningful coverage thresholds by domain;
- Firestore rules emulator tests;
- Android debug build on pull requests;
- signed AAB build only from protected release workflows;
- dependency and secret scanning;
- artifact retention and release notes;
- staging deployment;
- automated store upload later via Fastlane or equivalent.

### 12.3 Release checklist

- All visible controls work.
- No placeholder or demo purchase copy.
- Crashlytics test event received.
- Analytics debug events validated.
- Privacy/Data Safety/Health declarations match actual SDK behavior.
- Account deletion works end to end.
- Restore Purchases works on a fresh install.
- Release AAB is signed with protected credentials.
- Version/build are correct.
- Store links, privacy, terms, support, and deletion URLs are live.
- 12-tester requirement planned if applicable.
- Roll out gradually and monitor before 100% availability.

---

## 13. Security, privacy, safety, and compliance

### 13.1 Data classification

| Class | Examples | Handling |
|---|---|---|
| Identity | email, UID, provider | strict access, minimal logs |
| Health/fitness | weight, readiness, nutrition, pain flags | sensitive; minimal collection and sharing |
| Training | sessions, plans, notes | private by default |
| Media | technique/user videos | explicit consent, access control, deletion |
| Billing | product, entitlement, transaction references | server-authoritative; no card data stored |
| Analytics | event names, coarse app state | no raw health/user text |

### 13.2 Minimum controls

- Owner-only rules and explicit coach memberships.
- App Check after monitoring.
- Least-privilege service accounts.
- Separate environments.
- Secret manager for server secrets.
- Rate limits and abuse monitoring.
- Upload MIME/size rules and malware/content moderation plan if user video launches.
- Data export and deletion.
- Retention schedule.
- Incident-response contacts and key rotation procedure.
- Dependency review and upgrade cadence.

### 13.3 Health product boundaries

FighterEdge should be positioned as fitness planning/tracking, not diagnosis or treatment. Google Play requires accurate Health Apps declarations and a public privacy policy for health features. Include clear purpose, limits, risks, and professional-consultation language. Apple treats health and fitness data as especially sensitive and limits its use for advertising or data mining.

### 13.4 Weight-content rules

- No functionality for minors at launch.
- No promise of making weight safely.
- No automatic aggressive deficit or dehydration schedule.
- No encouragement to train through alarming symptoms.
- Clear “stop and seek qualified help” flows for concerning input.
- Expert name/credentials and content review date.
- Sources and change log for reviewed protocols.
- Allow users to hide weight/calorie features.

---

## 14. Content, videos, and tutorials plan

### 14.1 Content pillars

1. App skill: how to plan, log, use timer, and read trends.
2. Training organization: session intent, RPE, recovery, reflection.
3. Technique learning: focused drills and common mistakes.
4. Mobility/recovery: short reviewed routines.
5. Safe sport education: responsible weight/nutrition information and escalation.

### 14.2 Production standard

Every instructional asset needs:

- owner/licensor and release documents;
- expert reviewer;
- discipline, level, equipment, duration, and contraindication metadata;
- captions and transcript;
- poster image;
- version/review date;
- localization-ready script;
- clear audio and multiple useful angles;
- no unlicensed music or event footage.

### 14.3 First tutorial set

- 60-second product overview.
- Create your first week.
- Log a class in 15 seconds.
- Build and run a round timer.
- Complete a readiness check-in.
- Understand load and trend language.
- Track weight without reacting to one reading.
- Replay onboarding and get support.

Use contextual coach marks only once. Always make tutorials replayable from Help.

---

## 15. Phased delivery roadmap

Assumption: one focused Flutter developer, part-time design/content support, and access to real athlete testers. Dates should move based on evidence, not be protected at the cost of quality.

### Phase 0 — Product reset and release hygiene (Week 1)

**Outcome:** one clear target, no misleading beta surface.

- [ ] Confirm FighterEdge spelling, package IDs, domains, and audience.
- [ ] Interview five target athletes and two coaches.
- [ ] Define the core event schema and WPRS metric.
- [ ] Remove or hide unsupported Apple/magic-link and empty actions.
- [ ] Create dev/staging/prod plan.
- [ ] Add Crashlytics and safe logging.
- [ ] Replace starter README/web metadata.
- [ ] Create visual QA device matrix.

**Exit gate:** five interviews support the plan/log/readiness problem; no visible button is knowingly dead.

### Phase 1 — Real data foundation (Weeks 2–4)

**Outcome:** users can trust their training record.

- [ ] Introduce training, weight, readiness, plan, and preferences repositories.
- [ ] Add immutable IDs/serialization/schema versions.
- [ ] Implement Firestore storage and rules.
- [ ] Replace mock user data with real empty/onboarding states.
- [ ] Add offline/sync UI.
- [ ] Add Firestore emulator rule tests.
- [ ] Add account/profile editing basics.

**Exit gate:** a tester can create data offline, restart, reconnect, and see the correct data on another device; unauthorized cross-user access tests fail.

### Phase 2 — Core athlete loop (Weeks 5–8)

**Outcome:** FighterEdge is useful every training day.

- [ ] Build onboarding and editable week.
- [ ] Build fast session log and templates.
- [ ] Make timer robust across lifecycle changes.
- [ ] Create timer-to-log completion flow.
- [ ] Add daily readiness.
- [ ] Add weekly report V1 with explainable rules.
- [ ] Add local reminders.
- [ ] Instrument activation and retention events.

**Exit gate:** at least 50% of invited testers log a first session; median quick log time is under 20 seconds.

### Phase 3 — Closed beta and safety (Weeks 9–12)

**Outcome:** evidence of retention and store readiness.

- [ ] Recruit 12–20 actual athletes across devices.
- [ ] Run four-week structured beta.
- [ ] Add account deletion/export and legal pages.
- [ ] Complete Health Apps/Data Safety declarations draft.
- [ ] Implement safe weight trends and reviewed copy.
- [ ] Add accessibility/golden/device tests.
- [ ] Fix top activation and retention failures weekly.

**Exit gate:** Week-4 activated retention ≥25%, crash-free users ≥99.5%, no unresolved P0 security/safety issues.

### Phase 4 — Subscription infrastructure (Weeks 13–15)

**Outcome:** money can be accepted without lying or losing access.

- [ ] Configure store products and RevenueCat.
- [ ] Remove client plan writes and harden Firestore rules.
- [ ] Implement entitlement state model.
- [ ] Add real paywall, annual/monthly, restore, and manage links.
- [ ] Implement and test webhooks/idempotency/reconciliation.
- [ ] Run purchase lifecycle sandbox matrix.
- [ ] Add support workflow for billing issues.

**Exit gate:** purchase, restore, cancellation, expiry, refund/revocation, grace, and offline cases pass; client cannot self-grant Pro.

### Phase 5 — Paid Android launch (Weeks 16–18)

**Outcome:** controlled public availability.

- [ ] Final brand icon/splash/screenshots/store copy.
- [ ] Release keystore and signed AAB.
- [ ] Complete closed-testing requirement if applicable.
- [ ] Publish privacy, terms, support, deletion URL.
- [ ] Stage rollout 5% → 20% → 50% → 100% based on health metrics.
- [ ] Start founder pricing cohort if desired.
- [ ] Interview every early subscriber and churned subscriber possible.

**Exit gate:** stable production metrics and support response process.

### Phase 6 — Paid value expansion (Months 5–8)

Prioritize using observed demand:

- [ ] Fight Camp phases and adherence.
- [ ] Advanced weekly reports.
- [ ] 20–30 excellent technique/mobility videos.
- [ ] Technique notes and review queue.
- [ ] Wearable/Health Connect or HealthKit integrations if requested.
- [ ] French localization.
- [ ] iOS build, Sign in with Apple, TestFlight, and purchase parity.
- [ ] Coach sharing pilot.

### Phase 7 — Coach/team SaaS (after individual PMF)

- [ ] Consent and role model.
- [ ] Coach dashboard.
- [ ] Assignments/comments.
- [ ] Team analytics with strict privacy boundaries.
- [ ] Coach billing and seat management.
- [ ] Audit logs, exports, and organization deletion.

---

## 16. Prioritized backlog

| Priority | Work item | User/business impact | Effort |
|---|---|---|---|
| P0 | Persistent training and weight data | Trust/retention foundation | High |
| P0 | Server-authoritative entitlements | Prevents revenue/security failure | Medium–High |
| P0 | Account/data deletion | Store and privacy requirement | Medium |
| P0 | Health/weight safety policy | Prevents harm and policy failure | Medium |
| P1 | Fast training log | Daily core value | Medium |
| P1 | Robust hands-free timer | High-frequency utility | Medium |
| P1 | Weekly planner | Differentiated workflow | Medium |
| P1 | Readiness + explainable report | Subscription value | Medium |
| P1 | Crashlytics/analytics | Learn and operate | Low–Medium |
| P1 | Auth capability cleanup | Trust and conversion | Low |
| P1 | Settings and subscription management | Production completeness | Medium |
| P2 | Fight Camp mode | Strong Pro value | High |
| P2 | Technique learning loop | Retention/content value | High |
| P2 | French localization | Market expansion | Medium |
| P3 | Generative AI coach | Novelty but high safety/churn risk | High |
| P3 | Social feed/community | Moderation and cold-start burden | Very high |
| P3 | Gym CRM/billing | Different product/company | Very high |

---

## 17. What not to build yet

- Live opponent scouting.
- Public social feed, direct messages, or sparring-partner marketplace.
- Automatic video technique scoring.
- AI-generated medical, nutrition, injury, or dehydration plans.
- Thousands of low-quality tutorial videos.
- Gym membership billing and lead CRM.
- Wear OS/Apple Watch apps before the phone timer retains users.
- Full web dashboard before athletes prove cross-device demand.
- Multiple paid athlete tiers with confusing gates.
- Ads based on health or fitness data.

Each adds major cost, safety, or moderation burden without first proving the central habit.

---

## 18. Business and go-to-market plan

### 18.1 Validation before growth

Recruit through local gyms and coaches in Tunisia plus online English/French combat communities. Offer free lifetime or long-term Pro access to a small founding cohort in exchange for structured usage and interviews—not positive reviews.

Questions to validate:

- How do athletes currently plan and record training?
- What did they forget or misjudge in the last camp?
- Which screen would they open during a gym session?
- What information do coaches repeatedly request?
- Which weekly insight would change tomorrow’s behavior?
- What have they already paid for?
- At what price would FighterEdge feel suspiciously cheap, fair, or too expensive?

### 18.2 Organic acquisition

Build content around the problem, not feature announcements:

- “What my MMA training week actually looked like.”
- “Why one hard session tells you nothing—but four weeks can.”
- “The 15-second post-training log.”
- “How to structure round timers for different sessions.”
- “Camp mistakes your spreadsheet does not show.”

Use authentic athlete stories, weekly progress cards, and coach collaborations. Avoid unsafe weight-cut spectacle.

### 18.3 Referral loop

The strongest natural referral is athlete → coach:

- private weekly report link;
- branded share card with non-sensitive metrics;
- coach can comment without needing a paid account during pilot;
- athlete controls scope and can revoke access.

### 18.4 Customer support

Before paid launch:

- support email and in-app contact;
- billing and restore FAQ;
- deletion/export process;
- diagnostic app/build/user ID without health content;
- response-time target;
- incident template;
- refund/cancellation explanation aligned with stores.

---

## 19. Immediate 14-day execution plan

### Days 1–2 — decide and clean

- Confirm name, audience, product promise, package ID, and Android-first scope.
- Remove/hide broken auth and empty UI actions.
- Replace starter metadata and document current environments.
- Create the interview script and recruit testers.

### Days 3–4 — domain foundation

- Define `TrainingSession`, `WeightEntry`, `ReadinessEntry`, `WeeklyPlan`, and `UserPreferences` with IDs, timestamps, serialization, and validation.
- Define repository contracts and failure types.
- Draft Firestore schema/rules and emulator tests.

### Days 5–8 — persistence

- Implement Firestore repositories for training and weight first.
- Add offline/sync/error/empty UI states.
- Remove seed data for authenticated production users.
- Verify restart and cross-device behavior.

### Days 9–11 — core workflow

- Build the quick training-log form.
- Turn timer completion into a log draft.
- Compute real dashboard streak/session summaries.
- Instrument safe activation events.

### Days 12–14 — beta readiness

- Add Crashlytics and a feedback entry point.
- Run accessibility and small-phone checks.
- Ship a staging build to 5 initial athletes.
- Observe use, record friction, and update Phase 2 priorities.

**Do not spend these two weeks on paywall animation, AI chat, or a large video library.**

---

## 20. Definition of a valuable V1

FighterEdge V1 is valuable when a real athlete can:

1. Create a realistic training week.
2. Start a session or timer in two taps.
3. Use the timer hands-free in a noisy gym.
4. Finish and log the session in under 20 seconds.
5. Add a readiness check-in in under 15 seconds.
6. See a truthful weekly summary based on their own persistent data.
7. Understand one useful trend without being given fake medical certainty.
8. Use the app offline and trust it to sync.
9. Control, export, and delete their data.
10. Subscribe, restore, cancel/manage, and keep correct access across devices.

If those ten points work exceptionally well, FighterEdge has the basis of a SaaS product. If they do not, more tabs will not create subscription value.

---

## 21. Sources and research notes

Product and pricing pages were checked on 19 July 2026. Prices and policies change; re-check them at implementation and launch.

### Competitor/product sources

- [FightCamp memberships](https://joinfightcamp.com/work/memberships)
- [FightTrainer product and pricing](https://www.fighttrainer.app/)
- [Athlete Analyzer pricing](https://www.athleteanalyzer.com/pricing-training-app)
- [SparLink product and pricing](https://www.sparlink.app/)
- [Seconds interval timer](https://www.intervaltimer.com/app)
- [Roll MMA](https://www.rollmma.com/)

### Subscription and payment sources

- [RevenueCat pricing](https://www.revenuecat.com/pricing/)
- [RevenueCat 2026 subscription benchmarks](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/)
- [Google Play subscription policy](https://support.google.com/googleplay/android-developer/answer/9900533)
- [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple Developer Program membership](https://developer.apple.com/programs/whats-included/)
- [Stripe global availability](https://stripe.com/global)

### Account, privacy, health, and platform sources

- [Google Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Apple in-app account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Google Play Health Apps declaration](https://support.google.com/googleplay/android-developer/answer/14738291)
- [Google Play health content and services](https://support.google.com/googleplay/android-developer/answer/16679511)
- [Google Play closed-testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Firebase App Check for Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers)
- [Firestore offline persistence](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Firebase Crashlytics for Flutter](https://firebase.google.com/docs/crashlytics/flutter/get-started)
- [ISSN position stand on nutrition and weight-cut strategies in combat sports](https://pubmed.ncbi.nlm.nih.gov/40059405/)

---

## 22. Final recommendation

The prototype should be preserved, but the next milestone must be called **“trusted training record and weekly loop,” not “more features.”** Build persistence, quick logging, lifecycle-safe timing, readiness, and a real weekly report. Validate that loop with athletes for four weeks. Only then harden billing and ask for a subscription.

FighterEdge will earn recurring revenue when it becomes part of the athlete’s training decisions—not when it merely looks like a complete MMA app.

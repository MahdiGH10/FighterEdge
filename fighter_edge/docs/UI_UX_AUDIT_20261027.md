# Fighter Edge — full UI / UX design audit

**Requested audit date:** 27 October 2026. **Inspection:** 27–28 October 2026. **Baseline:** `origin/main` at `908d2b7`. **Branch:** `docs/ui-ux-audit-20261027`. Audit only; no application changes.

## 1. Owner summary

Fighter Edge looks serious and organised, but it still feels like several useful tools placed together.
The dark theme, new logo and readable text are good foundations.
The next improvement should be editing the experience, not adding more effects.

1. **Too many things ask for attention.** Home repeats information and actions; Drills and Reaction put many controls before useful content. See S47, S55, S58–59. **Observed.**
2. **The plan is not shown strongly enough before payment.** The reveal shows nutrition numbers and a short summary, rather than the actual training week. See S25. **Observed.**
3. **Training does not feel like one complete journey.** Home offers logging, Train offers starting, and the player, timer and Reaction finish differently. See S47, S85, S87–91, S64; routing differences are **Inferred** from code.
4. **The brand lives mainly in the logo and surface effects.** Technique lessons are text-only; repeated cards make different tasks look similar. See S04 versus S55–56. **Observed.**
5. **Small inconsistencies reduce trust.** Some German screens contain English, empty recipe destinations are promoted, and long choices are clipped at large text. See S78, S121, S142. **Observed.**

The three changes with the largest effect are:

- Give Home one clear next action and remove repeated blocks.
- Show the real first week before the existing paywall, then carry that session into training and completion.
- Replace decorative clutter with a small amount of useful technique imagery and consistent controls.

Keep Flutter, the paid model, the post-reveal paywall, and the safety modes. Keep recipes unpublished until reviewed.
There is no verified P0 design blocker here. Fix the P1 journey and accessibility issues before spending time on more glass or a new font.

## 2. Evidence, method and limits

Every finding is labelled **Observed** (visible in a captured screen or interaction), **Measured** (computed from source or instrumentation), or **Inferred** (code inspection or design reasoning). Recommendations and scores are professional judgments, not measured user outcomes. A prepared screen is still an observation of the actual widget, but is not evidence that a normal user reached that state.

Screenshots are external, deliberately excluded from the repository: `C:\Users\Mahdi\Downloads\FighterEdge-audit-screens\`. [Open the screenshot index](../../../FighterEdge-audit-screens/INDEX.md). `S04` means the file beginning `04-` in that index. The index identifies fixtures, diagnostic frames and exclusions; a filename alone is not proof of its intended state. These local links will not resolve for a reviewer on another computer until the screenshot folder is shared with them. Public benchmark captures are S201–208.

**Observed:** the debug Android x64 app ran on AVD `fe_api34`, 1080×2400, density 420, approximately 411×914 logical pixels. Additional captures use 320×640 and 430×932 logical sizes. These are emulator configurations, not physical iPhone tests. Local auth and in-memory repositories avoided real accounts. Runtime-only fixtures rendered unavailable states, published recipe examples, Pro/locked views, sheets, charts and safety-adjacent pages. No recipe publication, entitlement, backend or application source was changed.

**Measured:** Android system font scale 2.0 produced 17→29 logical pixels here; it is nonlinear. S34–40 and S125–132 therefore do **not** establish an exact 200% linear test. S138–147 use a temporary root `MediaQuery` linear scale of 2.0; the checked value was 17→34. Those main-tab captures use the then-current mostly empty local fixtures. S148 is an invalid review capture and is excluded. Existing widget tests also exercise linear 200% and narrow layouts.

**Measured:** debug build succeeded after `flutter pub get`. The following existing checks passed, **130 tests** total:

```text
flutter test test/accessibility test/unit/color_contrast_test.dart test/widget/german_journeys_test.dart --reporter compact
```

No full suite, release profiling, static analysis, store transaction, live Firebase journey, real notification delivery, physical haptic test, VoiceOver or real iPhone test is claimed. The emulator used no audio: voice quality, pronunciation, headphones, music ducking and sound/haptic synchronisation remain untested. Synthetic read failures demonstrate UI states, not real network recovery. Code-only states are identified below. No complete Cartesian matrix of every state × locale × size was captured; see section 13 for the gaps.

**Observed:** initial launch attempts encountered an emulator System UI ANR; initial frames and later forced-route diagnostics are excluded from product evidence. VM inspection required forced rebuilds and sometimes produced stale frames. Those instrumentation problems are not app defects. Do not use these runs to claim startup seconds or production jank. Disk was checked before heavy work; work stopped below 2 GB and resumed after the owner freed space.

## 3. Scorecard

Scores are **Inferred design judgments**, on a 1–10 scale; 10 means exceptionally coherent and well validated. Performance is provisional.

| Area | Score | Reason |
|---|---:|---|
| First five seconds | 5 | Core purposes are visible, but Home, Drills and Reaction divide attention among setup, navigation and action. |
| Hierarchy and layout | 5 | Readable individual blocks compete because too many receive card or hero emphasis. |
| Color | 7 | Strong semantic palette and reading contrast; red action use and some icon roles need discipline. |
| Typography | 7 | Oswald and Barlow form a useful pair, but condensed headings dominate and long choices fail at large text. |
| Components | 6 | Shared primitives exist, yet manual forms, completion sheets and action styles diverge. |
| Imagery and identity | 4 | The logo is distinctive; training content provides little visual evidence of movement or sport. |
| Motion and interaction | 6 | Good reduced-motion helpers and press mechanics coexist with excessive entrance treatment and uneven feedback. |
| States | 6 | Read failure and safety handling have substance; empty, loading and locked presentations vary in quality. |
| Navigation and architecture | 6 | Four main tabs are sensible; nested tabs, tools and alternate completion paths add friction. |
| Apple platform fit | 5 | Restrained navigation blur is sound; persistent condensed titles, Material chips and mixed modal patterns weaken iOS familiarity. |
| Accessibility | 7 | 48 dp helpers, semantics and tests are valuable; fitted labels, clipped choices and untested device behavior remain. |
| Copy and tone | 5 | Primary journeys are mostly translated, but secondary forms and guidance still switch vocabulary or language. |
| Perceived performance | 6 | State retention and bounded blur help; no trustworthy release/device timing was obtained. |
| **Overall** | **5.8** | Arithmetic mean of these judgments, not a usability-study result. |

## 4. What is already working — preserve it

- **Observed, S04/S117:** the fighter mark gives the product a recognisable entrance. Keep it; evaluate small-size legibility separately rather than starting another branding project.
- **Measured:** primary, secondary and muted reading colors exceed 4.5:1 on the defined opaque surfaces. Keep the dark palette and Oswald/Barlow pair; see section 7.
- **Inferred, `lib/screens/home_shell.dart:42`:** four main tabs are understandable, visited tabs stay mounted, and leaving Fuel resets its day appropriately. Keep this structure.
- **Observed, S65–66/S50:** persistent Log food and remembered/search-based entry are useful foundations for daily use.
- **Observed, S98–100:** Hide numbers and Pause nutrition are substantial product choices. Keep their protections and simple language; no guilt messages or upsells in paused views.
- **Inferred, `lib/screens/onboarding/onboarding_screen.dart:227`:** health consent precedes body questions, screening is explicit, and onboarding has draft restoration. Preserve these safeguards.
- **Observed, S26/S78:** unavailable purchasing and unpublished recipes are described honestly. Preserve those gates; remove misleading routes toward empty content instead.
- **Observed, S58–64:** Reaction has one move at a time, previewable voice choice, countdown, pause and readable rest. **Inferred:** background pause and exit confirmation already exist; do not re-open the old multi-move design.
- **Measured:** the 48 dp minimum and 130 passing targeted tests are real assets. Existing contrast tests passing does not mean every semantic color role is covered.
- **Observed, S94/S107:** trend and safety presentations use words and structure as well as color. Preserve that distinction.

## 5. Screen-by-screen audit

For each entry: **works / hurts / fix**. References are actual captures, with code-only gaps called out. These are independent page assessments; shared fixes follow in section 7.

### Launch and authentication

#### Native splash

**Inferred; no accepted native-splash capture.** Android 12 styling sets `#08070C` and the generated splash icon (`android/app/src/main/res/values-v31/styles.xml:10`). This matches the brand ground. The hand-over between OS icon, Flutter mark and login needs a real-device recording; the initial attempt was obstructed by System UI failure. Keep the same visual centre and background across stages. Do not add a minimum delay for branding. iOS storyboard and Android mask behavior need device validation before changing scale.

#### In-app splash — BrandSplash

**Observed prepared widget, S117; Inferred timing:** centered mark and restrained wordmark work. The 900 ms entrance (`lib/widgets/brand_logo.dart:126`) can restart the sense of launching after the OS splash. Wordmark arrival occupies roughly 225–765 ms. Keep an already-visible mark in place as the wordmark appears; finish when the destination is ready. No fixed 900 ms startup wait was verified. The preload has a two-second timeout, not a measured two-second launch.

#### Login

**Observed, S04/S07.** Logo, readable form and account creation route work. Several similarly treated sign-in methods create a tall, form-heavy first impression. Make the most-used method primary, group provider alternatives, and make “Use a sign-in code” secondary. Preserve visibility and inline validation. German/200% login variants were not captured; verify keyboard and autofill on iOS. Source: `lib/screens/auth/login_screen.dart`.

#### Sign-up

**Observed, S10–12.** Explicit fields and password feedback help. Large branding plus the form stack lengthens the task visually. Use a compact title, one benefit sentence and one Create account action; preserve policy/consent links and entered values after errors. Real provider sign-up and duplicate-account responses were not tested. Source: `lib/screens/auth/signup_screen.dart`.

#### Sign-in by code

**Observed, S06/S09.** Sent confirmation is understandable. “Code” and “link” vocabulary should describe the actual operation consistently; the file is `magic_link_screen.dart`. Show destination email, one next step and accessible resend state. Local confirmation does not establish delivery. Source: `lib/screens/auth/magic_link_screen.dart`.

#### Verify email

**Observed prepared, S119–120.** Waiting and success are distinct. Keep one primary verification refresh/continue action, secondary resend and destination address. A small success confirmation is enough. Polling, expiration, email delivery and account switching were not end-to-end verified. Source: `lib/screens/auth/verify_email_screen.dart`.

#### Forgot password

**Observed, S05/S08.** One field and a sent acknowledgement are appropriately simple. Keep privacy-preserving confirmation, a clear return to sign-in and address correction. Use the same compact auth layout/error placement as code sign-in. No real reset link was sent. Source: `lib/screens/auth/forgot_password_screen.dart`.

#### Boot failure

**Observed prepared, S118.** A recovery page is better than an endless splash. Keep Retry primary and explain briefly what can be retried. Put a support identifier behind a disclosure rather than technical prose in the main message. This is the real failure widget rendered with a fixture, not a production boot failure. Source: `lib/main.dart:518`.

### Onboarding

#### Welcome page 1 — camp organisation

**Observed, S13.** “Your camp, organised” communicates the benefit. Giant page number, empty middle and small explanatory copy feel like a generic slide. Replace the number with a small code-made week preview depicting training, weight and Fuel. Keep simple paging and Continue. Source: `lib/screens/onboarding/welcome_pages.dart`.

#### Welcome page 2

**Observed, S14.** Consistent paging and skip help. The composition repeats rather than proving another useful outcome. Show one authentic product example relevant to this page’s promise; no stock athlete purely to fill space. Claims must describe shipped functionality.

#### Welcome page 3

**Observed, S15.** A short final page can lead into setup. Three similar slides before seven questions add ceremony. Cut to one welcome page plus optional “How it works” paging; retain other messages later. This reduces scope instead of requiring three new illustrations.

#### Health-data consent

**Observed, S16.** Consent is separate from marketing and body questions. Keep explicit choices and legal access. Explain which data is needed and why in short language. Keep analytics consent separate; do not replace health review with a preselected switch. Source: consent branch at `onboarding_screen.dart:227`.

#### Question 1 — camp goal

**Observed, S17/S27/S142.** Goal and progress are clear. Long options clip at true linear 200%, including competition preparation. Replace `ChoiceChip`s with full-width selectable rows that wrap, include a selection mark and grow vertically. **Inferred:** goal choices do not identify discipline or an actual bout, limiting how personal the first plan can feel. Source: `onboarding_steps.dart:61`, `onboarding_widgets.dart:70`.

#### Question 2 — nutrition goal

**Observed, S18/S28/S143.** Descriptive rows are clearer than goal chips. Asking nutrition immediately after camp goal makes the product feel like a calorie app. Keep Skip detailed nutrition visible and ask only what is needed for the first training week. Do not weaken screening. At 200%, keep the action reachable by scrolling; do not cap reading text.

#### Question 3 — body and screening

**Observed, S19/S29/S144.** Normal body data, optional target and explicit screening are appropriate. It is the densest question: keyboard fields followed by a long checklist. Give the health check its own named group, brief introduction and visible completion state. Keep every flag reviewable. S24 is an unreliable attempted error capture; validation also has existing test coverage.

#### Question 4 — equation profile

**Observed, S20/S30/S145.** Explanation avoids false precision and permits skipping. A whole physiology page interrupts training setup. Reduce main copy to two sentences, disclose “How this estimate works,” and keep profiles and skip explicit. Do not substitute gender assumptions for the calculation input.

#### Question 5 — activity outside training

**Observed, S21/S31/S146.** Separating everyday activity from training is sensible. Long descriptions increase questionnaire fatigue. Keep one example per row and explain double-counting once. Use wrapping selection rows.

#### Question 6 — training rhythm and experience

**Observed, S22/S32/S147.** Days/week and experience connect directly to training; the stepper is simple. They arrive late. Move them toward the start and show how they change the sample week. Keep plus/minus targets at least 48 dp and announce the updated count.

#### Question 7 — review

**Observed, S23/S33; exact linear-200 review capture not obtained.** Final review can prevent mistakes. The repeated compact sentence does not prove a useful week. Group into Training and optional Fuel, give each Edit, and name the action “Build my week.” Reveal actual generated data next. Source: `onboarding_steps.dart`, `onboarding_screen.dart:286`.

#### Plan-ready reveal

**Observed, S25/S46.** Clear completion and one trial path work. The payoff is a calorie/macro receipt while the product promises a camp. `PlanReadyView` shows a short `PlanPreviewCard` and nutrition metrics (`lib/screens/onboarding/plan_ready_view.dart:92–129`), with no visible dated week. Lead with the actual first week, next session, duration and why the schedule fits chosen days. Fuel becomes a smaller optional summary. Keep the paywall immediately after the reveal and only store-confirmed trial wording. This is the highest-value conversion design change; conversion improvement is unmeasured.

#### First-win sheet

**Observed prepared, S96.** “First meal logged” encourages without excessive celebration. A modal still interrupts the completed task. Prefer a compact inline success/Undo surface; use a sheet only for an explanation the user needs. No confetti. Source: `lib/screens/first_run/first_win_sheet.dart`.

#### First-week checklist

**Observed, S95/S138.** Four tasks and collapsibility help. Its placement before Today competes with the main action. Put collapsed progress after Today, expand on request, hide after completion. Source: `lib/screens/first_run/first_week_checklist.dart`.

#### Notification primer

**Observed prepared, S97.** The timing promise and Not now work. **Inferred:** first-win and reminder prompts can create multiple interruptions near first use. Ask at a chosen reminder moment, show the proposed time, and respect refusal. Real system permission UI is untested. Source: `lib/screens/notifications/notification_primer_sheet.dart`.

### Paywall and access

#### Paywall

**Observed unavailable-store state, S26.** Benefits and purchase unavailability are honest; recipes are no longer sold as a complete library. Benefits still rely on prose. Carry a small preview of the revealed week into the offer. **Inferred:** check session/coaching language against the neutral player; do not imply exercise instruction it does not supply. Prices, eligibility, restore, pending, cancellation and purchase success were not observed. Source: `lib/screens/paywall_screen.dart`.

#### Trial chip

**Inferred; no trustworthy live-trial screenshot.** `lib/widgets/trial_chip.dart:12` provides compact status. Use one calm status row and one subscription destination; do not make remaining time look like danger. Keep the paid product and store trial; discard the old Free vs Pro comparison.

#### Pro locks

**Observed prepared recipe lock, S84; Inferred shared gates.** Name the locked action and use the same subscription route everywhere. One short explanation and See subscription suffice; avoid a badge, gold border and lock all at once. Gold stays exclusive to paid access. Source: `lib/widgets/pro_lock.dart:31`, `gated_action.dart`, `recipe_detail_screen.dart:74`.

#### Read-only

**Observed local fixture, S41.** “Your data is saved” reassures. Gold banner and red hero compete. Keep one access banner, permit reading history, and explain intercepted write actions without discarding input. Expiration during editing was not tested. Source: `lib/widgets/access_status.dart:69`.

### Home

#### Today hero

**Observed, S47/S105/S138.** Today is easy to find. A rest day receives nearly the visual weight of important training; the large gloss card and generic title consume the first viewport. **Inferred:** the training-day action logs a session (`lib/screens/home/today_hero.dart:90`), whereas Train offers starting. Make Start session primary for the next actual session, Log completed training secondary. A rest day becomes a shorter recovery note and next scheduled session.

#### Week strip

**Observed in Train, S49; Inferred Home gap.** Home lacks the strong week strip proposed by the redesign spec. Reuse existing week data once below Today, with today/completion marked by shape and label as well as color. No second calendar subsystem. Source: `training_camp_screen.dart:137`, `dashboard_screen.dart:94–202`.

#### Weekly target card

**Inferred embedded component; review fixtures S111–112 are related evidence, not its own screenshot.** Due reviews are useful, but Home already shows stats and training status. Show the target once; replace that row with Review last week when due. No second progress card above the next action. Source: `lib/widgets/weekly_target_card.dart`, `dashboard_screen.dart:163`.

#### Daily snapshot / Corner Brief

**Observed, S47–48.** The first-day brief explains how a first meal enables useful information. It is tiny beside decorative blocks. **Inferred:** the daily snapshot feeds the Corner Brief; there is no separate snapshot page to add. Keep one useful sentence tied to today and remove redundant adjacent statistics. Source: `lib/screens/dashboard_screen.dart:151`, snapshot builder/Corner line consumer.

#### Fight countdown on Home

**Observed, S105.** Actual days-to-fight make the app specific. The countdown arrives after Today and shortcuts. Promote a short “42 days to fight” context line above Today when a camp exists; keep full weight-path detail on its own page. **Inferred:** number-hiding also removes this component (`fight_countdown_card.dart:79`); consider preserving neutral date context only if consistent with the mode’s intent.

#### Empty / first day

**Observed, S41/S47/S95/S138.** No plan and rest day are distinguished with setup routes. But name, goal, access status, checklist, hero, shortcuts and brief can precede any progress. Cut the developer-message surface from customer builds if exposed; remove the redundant weight/session/streak strip from Home. Keep those facts in their relevant destinations. Source: `lib/screens/dashboard_screen.dart:94–202`.

### Train

#### Training camp / week plan

**Observed, S49/S122/S134.** Dated sessions, weekly timeline and rest rows are useful. Four internal tabs sit below a main tab; future sessions have prominent completion affordances and nearly every session has its own card. Keep Week default, use one grouped week list and give only today/next session a primary action. History and drills/tools remain available through quieter destinations. Validate the actual future-session logging rule rather than assuming the affordance is disabled. Source: `lib/screens/training_camp_screen.dart:42–68,137,369`.

#### Training history

**Observed, S54.** A list is appropriate once logs exist. Empty history is centered text with little help. Add Log a completed session and explain that in-app sessions appear after completion too. Keep the lazy list. Source: `training_camp_screen.dart:488`.

#### Session player

**Observed, S85–87.** Large timing and a control dock are readable. The observed generic “Session” contains little meaningful content; Skip and Finish dominate the empty field. **Inferred:** it is a neutral block timer, not a demonstrated exercise lesson. Show actual session title, current block, duration and next block when available; do not fabricate technique coaching. Guard accidental active exit and align lifecycle handling with Reaction. Source: `lib/screens/session_player_screen.dart:34–80,149`.

#### Session completion

**Observed, S87; Measured options:** the player offers effort 6–10 only (`session_player_screen.dart:94`), versus 1–10 in the manual log. A light session cannot be represented equivalently. Use one shared completion form with labelled effort, optional note, duration and session name. No mandatory celebration before saving.

#### Drill library

**Observed, S55.** Taxonomy, bookmarks and real written content have substance. Large learning-path chooser, search, filters, path rail and progress precede the first useful drill. Reduce Continue learning to one compact row; show useful technique cards immediately. Add owner-shot thumbnails where they identify moves. Source: `lib/screens/drill_library_screen.dart:154–251`.

#### Drill tutorial

**Observed, S56.** Numbered steps, common mistakes and studied/drilled/sharp progression work. Movement instruction is text-only: this is where testers’ image request is most persuasive. Add one short owner-recorded demonstration or a few consented stills with a text equivalent. Start with a few high-use drills in one discipline. Keep the instructions; a gym photograph does not explain a jab. Source: `drill_library_screen.dart:270,851`.

#### Learning paths and empty states

**Inferred:** no-match, saved-empty and curriculum-only states are distinct (`drill_library_screen.dart:235–248,602`). S57 did not reliably render no-match and is excluded. State the amount of available written content before opening a path. Do not imply a video curriculum exists. Add Clear filters to no-match and name the next written drill in path summaries.

#### Session log dialog

**Observed, S88.** Quick logging supports training outside the app. The small dialog differs from player completion and uses another effort treatment. Reuse one form and vocabulary; prefill date/session from context but allow corrections. Do not force a timer to record gym training. Source: `lib/screens/session_log_dialog.dart`.

#### Round timer — ready, running, paused

**Observed, S89–91.** Large clock and sparse controls fit the task. The paused action reads Start rather than Resume. Rename it, preserve progress/settings, distinguish Reset. **Inferred:** the last-ten-second scale pulse makes numerals restless; keep a stable clock and one phase-boundary transition. Preserve reduced-motion handling and existing corner cue. Finish/background were inspected rather than exhaustively exercised. Source: `lib/screens/round_timer_screen.dart:198–207,323`.

#### Reaction picker

**Observed, S58–59.** Preview, discipline, level, pace and summary are individually understandable. Together they push Start below the fold. Show one saved preset, essential choices and pinned Start; move voice choice into a row opening a sheet with Test voice. Put the move list behind Moves in this drill. Source: `lib/screens/reaction_drill_picker.dart`.

#### Reaction countdown

**Observed, S60.** Large 3 and stance instruction prepare the user. Keep them fixed in the first-call field. **Inferred:** use purposeful phase feedback, not feedback for arbitrary repaints. Audio synchronisation was not heard. Source: `reaction_drill_screen.dart:285`.

#### Reaction live call

**Observed, S61.** One move at a time is correct. The move occupies a modest part of a large empty field; long moves only shrink. **Inferred:** `_MoveLine` uses the 52-size display style and scale-down fitting (`reaction_drill_screen.dart:397–425`). Increase a bounded move style based on width, allow long labels to wrap, keep the counter stable. Every call has a new key and a 160 ms cross-fade (`:292–328`); test whether the outgoing move impedes recognition at fast pace. Keep imagery off this screen.

#### Reaction paused / rest

**Observed, S62/S63.** Named phases and remaining-time context are clear. Keep Resume primary, Exit secondary, and the call area stable. No breathing glow to fill blank space. Background pause and exit safeguards already exist in code.

#### Reaction finished

**Observed prepared, S64.** Clear finish and repeat/next-level route work. **Inferred:** completion triggers haptics/telemetry but does not itself persist a normal training log (`reaction_drill_screen.dart:76–88`). Decide whether it counts as training; if yes, offer reviewed one-tap saving through the shared completion form. Do not silently inflate totals or change the one-move model.

### Fuel

#### Daily log — default, empty, no target

**Observed, S50/S77/S108/S109.** Log food and macro grouping help. The initial view gives a huge calorie total, separate ring, three bars and navigation rows despite no meals. No-target zero-like totals suggest precision where no target exists. Show one compact remaining/target summary when configured. Otherwise lead with Set a Fuel target or Log without a target. Make the first meal the focal point. Source: `lib/screens/nutrition_screen.dart:536–650`.

#### Daily log — loading, stale, error

**Observed prepared, S75–76.** Read failures do not masquerade as empty logs and offer retry. Loading replaces the page with a red spinner, while recipes use shaped placeholders. Keep title/day controls stable and skeleton the actual summary/rows. Translate hardcoded error/retry strings. Real offline transitions and stale-data editing were not exercised. Source: `nutrition_screen.dart:73–98`.

#### Add-food sheet

**Observed, S65–66.** Search, remembered foods and manual entry support repeat use. The keyboard/full-height sheet can feel like a separate app; first-use shortlist is sparse. Keep search focused and one stable close/back control. Show Recent/Frequent only with content; manual entry is the fallback. Preserve quantity confirmation and allergen notices. Source: `edge_fuel/presentation/widgets/add_food_sheet.dart:63,328`.

#### Manual food / edit dialog

**Inferred, `nutrition_screen.dart:325–494`; no separate capture.** The raw AlertDialog/six-field form differs from search/portion entry and contains English labels. Move manual/edit entry into the same flow, with optional macros under a disclosure and explicit Save. In Hide numbers, `_editFood` returns early (`:248–253`) while a food row can expose edit (`:1206`): remove that dead affordance or provide a safe names-only editor.

#### Quick meal

**Observed, S67.** Familiar fast choices are practical. Fixed meals, nutrient metadata and another recipe route feel like a catalog preview. Keep two examples, clearly mark quantities as editable estimates, then replace with frequent meals when available. Gate Browse recipes on published availability. A generic meal title must not imply knowledge of the user’s portion. Source: `nutrition_screen.dart:786–951`.

#### Fuel plan

**Observed, S68.** Target, explanation and Low confidence acknowledge estimation. Several numbers and recipe promotion dilute the purpose. Lead with today’s action and target status; collapse calculation detail. Explain how the estimate improves without adding clinical advice. Source: `edge_fuel/presentation/screens/edge_fuel_plan_screen.dart`.

#### Fuel setup 1 — goal

**Observed, S69.** Choice descriptions work. It duplicates onboarding. Prefill saved values and name a returning flow Edit Fuel target. Keep Back. Source: `edge_fuel/presentation/screens/setup_steps/goal_step.dart`.

#### Fuel setup 2 — body

**Observed, S70.** Inputs and screening supply context. Re-entering measurements feels unfinished. Reuse stored values with dates and make changed screening review explicit. Do not assume old consent/screening still applies. Source: `setup_steps/body_step.dart`.

#### Fuel setup 3 — activity

**Observed, S71.** Descriptive levels work. Use the same concise selection rows and explanation as initial onboarding. Source: `setup_steps/activity_step.dart`.

#### Fuel setup 4 — training

**Observed, S72.** Load is relevant. Show the current weekly plan as an editable starting point instead of requiring memory. Editing Fuel must not unexpectedly alter training. Source: `setup_steps/training_step.dart`.

#### Fuel setup 5 — food preferences

**Observed, S73.** Preferences could improve food suggestions. With recipes unpublished, their immediate effect is unclear. State what shipped behavior consumes them; defer nonessential questions when nothing does. Do not unhide recipes to justify a form. Source: `setup_steps/food_step.dart`.

#### Fuel setup 6 — review

**Observed, S74.** Review before applying is sound. Name the action Save target; show changed values with Edit. Share controls/copy with onboarding while keeping this a shorter returning flow. Source: `setup_steps/review_step.dart`.

#### Recipes — unpublished / empty

**Observed, S78.** Await-review copy is honest and intentional. Promotion from Today, Meals and Plan is the problem. Remove prominent entries when published count is zero; retain a quiet explanation on direct access. Source: `recipe_library_screen.dart:94`, `nutrition_screen.dart:634,842,953`.

#### Recipes — loading / error

**Observed prepared, S79–80.** The library skeleton resembles content. Error lacks an equivalent recovery action. Add Retry, retain filters, explain unavailable/stale data concisely. This was a controller fixture, not a network failure. Source: `recipe_library_screen.dart:86–106,450`.

#### Recipes — published library fixture

**Observed test data, S81.** Real photographs, titles and metadata make content tangible. This is not permission to publish. Keep one image ratio, reduce simultaneous filter groups and put result count by active filters. Entities were cloned as published only in process memory. Source: `recipe_library_screen.dart:113–205`.

#### Recipe detail / method

**Observed fixture, S82–83.** Image, servings, ingredients, method and attribution form a complete artifact. Keep credit (including displayed Stacy Spensley / CC BY 2.0), allergen notice and adjustable servings. Make Log meal persistent; avoid repeated nutrient containers. Large-text detail/image download errors were not captured. Source: `recipe_detail_screen.dart:55`, `recipe_photo_image.dart`.

#### Recipe locked

**Observed fixture, S84.** A named recipe and lock explain access. Use the shared lock, preserve Back and avoid a long empty silhouette. Synthetic lock, not an expired purchase. Publication review remains separate from paid access.

#### Pause nutrition

**Observed, S100.** Quiet presentation respects the choice. Resume is the only substantial action. Keep it calm; preferences can be secondary. Do not fill space with calorie education, warning or upsell. Source: `nutrition_paused_view.dart`.

#### Hide numbers

**Observed, S99.** Meal names remain useful without numeric pressure. Check alternate entry routes for leaks/dead controls: recipes, weekly review, manual entry. A meals summary must not become an indirect score. Source: `nutrition_mode_controller.dart`, `nutrition_screen.dart:248`.

### Body and progress

#### Weight tracker — empty / first entry / trend

**Observed, S92–94/S130.** Measurement, average, trend and editable history are useful. Empty chart space plus separate summary/goal cards make one measurement look like a dashboard. Put Log weigh-in in the empty body; explain that a trend needs more data after one entry. With enough data, make one chart main content and current measurement its subtitle. Keep removed Body Fat/Measurements tabs removed. Source: `weight_tracker_screen.dart:227,366,600`.

#### Weigh-in dialog / history actions

**Observed add, S93; Inferred edit/delete.** Preserve existing edit/delete. Add Weigh-In / Cancel / Save remain English and dates use fixed patterns (`weight_tracker_screen.dart:183,212,217,472,544`). Translate and format with app locale; put unit/input guidance beside the field. No destructive deletion was performed.

#### Weekly review

**Observed prepared, S111–112.** Combining training, Fuel and weight creates a useful checkpoint. Similar-weight cards and prose weaken the decision. Lead with one plain-language recommendation/reason, then evidence. Keep acceptance/edit in reach, state insufficient data and preserve nutrition-mode exclusion. **Inferred:** loading/unavailable/retry exist (`weekly_review_screen.dart:60–75,137`), but were not captured. No real adjustment was saved.

#### Charts as a system

**Observed, S94/S106.** Trends/path convey more than decorative rings. Standardise line weights, endpoint labels, locale-aware dates and a text summary of range/direction. **Inferred:** painted points need accessible summaries; do not assume they are individually accessible. Keep unsafe/insufficient-data distinct. VoiceOver and chart gestures were not tested.

### Fight camp

#### Fight setup

**Observed, S102–104/S131.** Date, weigh-in context, limit, competition and camp length are concrete fighter inputs. Save is far below the first viewport. Group Fight details / Weight context / Training camp, with preview before a persistent Save at normal text sizes. At large text, allow the entire page to scroll; no tall footer over inputs. Source: `fight_camp/presentation/screens/fight_setup_screen.dart:201`.

#### Countdown / path

**Observed, S105–106.** Date and named path make the product specific. Empty charts need an explanation and Log weigh-in alongside it. The captured path lacked current measurements; it does not establish a safe or unsafe cut. Keep numeric detail mode-aware. Source: `fight_path_screen.dart`, `weight_path_summary.dart`, `weight_path_chart.dart`.

#### Fight week

**Observed fixture, S107.** Day-by-day structure and safety guidance work. Uniform long rows bury today. Highlight Today once, collapse earlier days, preserve the full week. This audit adds no health advice. Source: `fight_week_screen.dart`.

#### Safety statuses

**Observed insufficient-data, S110; Inferred remaining variants.** Despite its original filename, S110 is not unsafe: it asks for weigh-ins. Keep insufficient data, professional review and unsafe distinct with words/icon/next step. Other caution/review-required/unsafe/blocked variants need visual validation. Do not use alarming red for ordinary missing data. Source: `weight_path_summary.dart`, `camp_screening.dart`, safety models.

### Profile and Settings

#### Profile

**Observed, S51/S124/S136/S141.** Actual data, subscription and grouped destinations improve on the old mock profile. It remains a sparse menu. Keep compact; add editable training preferences only when consumed by the plan. No vanity stats or duplicated Home cards. Source: `lib/screens/profile_screen.dart`.

#### Settings

**Observed, S52/S113/S129.** Grouped rows suit the task and Apple’s structural approach. Keep clear groups, chevrons for navigation and switches for immediate binary changes. Account actions stay distinct at the bottom. Source: `lib/screens/settings_screen.dart`.

#### Notification settings

**Observed local gateway, S53/S132.** Per-channel times are useful. Separate system permission status from preferences, with Open system settings when denied. Toggles do not prove delivery; timezone, quiet hours, scheduling and tap destinations need device checks. Source: `notification_settings_screen.dart`.

#### Notification auto-pause sheet

**Inferred only, `auto_pause_sheet.dart`, `notification_host.dart:108`.** Asking whether reminders remain useful is considerate; the host avoids opening over another modal. Name the reminder/time and offer two plain choices. Do not frame automatic pausing as failure. No capture obtained.

#### Nutrition display settings

**Observed, S98.** Standard / Hide numbers / Pause are clear. Keep consequence text, selection semantics and reversibility. Verify changes across logged meals/review before dismissing, beyond the empty captures here.

#### Legal

**Observed local fallback, S116.** It acknowledges draft/early-access content; this does not establish hosted production content. Keep readable document typography/title/back. **Inferred release gate:** owner must confirm final links before public sale; do not infer a legal compliance failure solely from this fixture. Source: `lib/screens/legal_screen.dart:37`.

#### Change password

**Observed, S114; Inferred errors.** Current/new/confirm and reauthentication are sensible. English title, labels and errors differ from translated settings. Reuse auth field styles and localise the complete operation, including visibility labels. Keep focus visible above the keyboard. No password change submitted. Source: `change_password_sheet.dart:66–180`.

#### Delete account

**Observed confirmation only, S115.** Typed DELETE, reauthentication and subscription warning are appropriate friction. Dense dialog and partial English hinder reading. Use a readable scrolling destructive sheet; Cancel remains easy, Delete disabled until ready. Preserve warning/server checks. Provider prompts, actual deletion and store billing cancellation were not tested. Source: `delete_account_flow.dart:44–138`.

### Other shared surfaces

**Inferred unless illustrated above:** coach marks, analytics consent, sync notices, snackbars/Undo, generic empty states, rings and skeletons are reusable components, not new destinations. Their rules follow below. Not every possible snackbar/dialog variant was captured.

## 6. Benchmark — six public screen sets

**Observed public marketing/screenshots, not hands-on app tests.** Store previews are edited promotional artifacts and can differ by version/region. The comparisons concern visible patterns only. Assets remain reference material; none may be copied into Fighter Edge. S203 is a MacroFactor marketing image without useful interface evidence; use S208 for its logger.

| App and source | What the public screen does better | Apply cheaply to Fighter Edge |
|---|---|---|
| [Apple Fitness](https://apps.apple.com/us/app/apple-fitness/id1208224953), S201 | A recognisable summary graphic anchors the screen; smaller metric modules support it instead of all becoming headlines. | One Today action, a compact week graphic, secondary evidence. Do not add three rings just because Apple has them. |
| [Strava](https://apps.apple.com/us/app/strava-run-bike-walk/id426826309), S202 | Real people/activity photography makes the sport and achievement tangible in the public preview. | A few authentic fighter/technique images convey the activity better than more glow. Do not build a social feed. |
| [MacroFactor](https://apps.apple.com/us/app/macrofactor-macro-tracker/id1553503471), S208 | The food-logging preview shows recognisable food rows, inline add controls and an obvious persistent logging action. | Keep Fuel’s persistent action; prioritise recent/frequent foods and portion confirmation over a huge empty calorie dashboard. |
| [WHOOP](https://apps.apple.com/us/app/whoop/id933944389), S204 | Three summary dials lead into a short interpretation and smaller supporting modules. The screen relates numbers to meaning. | Put a useful Corner sentence beside compact evidence, without three competing rings or an unsupported readiness score. |
| [Nike Training Club](https://apps.apple.com/us/app/nike-training-club/id301521403), S205 | Workout thumbnails and concise equipment/difficulty/duration metadata make choosing a workout concrete. | Real technique thumbnails plus name, level and duration; first useful card above a large taxonomy chooser. |
| [PunchLab](https://apps.apple.com/us/app/punchlab-boxing-workout/id1402134277), S206 | Public combat-training previews connect a demonstrated movement, athlete and timer to the task. | One demonstration at the top of a tutorial, plus honest session context. Do not imply sensor coaching or a video library that does not exist. |

**Inferred conclusion:** the useful common pattern is content plus interpretation plus one action. Photography helps most when it explains what to choose or do. None of these references justifies wallpaper behind live timers, copying metrics without data, or expanding the feature set.

## 7. Cross-app system recommendations

### Hierarchy and visual editing

**Observed, S47/S49/S55/S58:** too many containers have independent title, border, tint, numeral and action treatments. This flattens hierarchy even when each card is well drawn. The app needs fewer visual peaks.

Adopt these rules as **Inferred design recommendations**:

1. One primary action per task view. Secondary routes are labelled rows or quiet buttons; destructive actions stay separate.
2. One hero per screen. Rest, empty and no-target states do not inherit the full treatment of a ready session.
3. One shared surface for a related list. Do not wrap each simple session/stat in another card.
4. Put meaning before metadata: next session → why/when → action → week → evidence.
5. Remove redundant Home stats, most introductory paging, default expanded Reaction move list, unpublished recipe promotion and global decorative glow on working forms/lists. These are deliberate cuts.

### Concrete token proposal

The current system has genuine tokens. Do not restart it. The following changes are **Inferred recommendations** based on the observed layouts; migrate touched screens, not the entire codebase in one PR.

| System | Current — Measured from source | Proposed contract |
|---|---|---|
| Spacing | `Insets`: 2, 4, 8, 12, 16, 20, 28, 40; also hairline 1, clearance 80 (`app_theme.dart:9`) | Retain these; add named 24 and 32 steps. Use 20 screen gutter, 24 between ordinary groups, 32 between major sections, 12 within rows, 8 icon/text gap. Keep legacy 28 until each screen is deliberately migrated. Compute dock clearance from actual dock + safe area rather than assuming 80 always suffices. |
| Display | Oswald 700: 160 countdown, 64 timer, 52 figure, 30 title, 22/18 smaller titles (`app_typography.dart:82–110`) | Keep family. Reserve 160/64 for distance-read timers; 52 only a single meaningful metric. Keep 30 for main screen title; use Barlow for ordinary sections and long selection labels. Add Barlow section 20/600, line-height 1.25 only where 17 cannot carry hierarchy. |
| Reading | Barlow 17/500 body, height 1.4; 17/600 headline 1.3; 16/500 callout 1.35; 14 metadata 1.3; 12 tracked micro 1.2 | Keep body/callout. Use 14 for metadata, not long explanations; 12 only short eyebrows. Buttons 16/600, height ≥48, grow/wrap at large text. Sentence case for task labels; no tracking on paragraphs. Do not globally switch to SF to imitate iOS. |
| Surfaces | `#08070C` ground, `#0E0C13` raised, `#14121A` surface, `#1C1923` alternate, `#26222F` elevated (`app_colors.dart:38–42`) | Keep. Ground for content; one `surface` group; elevated for transient controls. Default content cards flat, no luminous rim. Use the alternate/elevated steps to express nesting only when needed. |
| Crimson | Primary `#E0222B`; accent text `#FF6358`; fill `#C7131E`; dark `#B3121C` | Keep all four, assign roles strictly: small action text/icon = accent; large action fill = fill; pressed fill = dark; primary = graphic accent, not small copy on dark surfaces. Red should say “act,” not flood every region. |
| Semantics | Positive `#46C287`, warning `#F5A623`, danger `#FF4F7B`, gold `#F2C879`; separate macro colors | Keep. Green needs explicit success text/check; warning needs a reason; danger only refusal/destruction/unsafe, not missing data. Gold only subscription/Pro. Keep macro colors with labels; never as the only key. |
| Radius | Card 12, button 10, inset tile 8, hero/sheet 24, chip 100 (`app_theme.dart:28`) | Keep. Premium feel will not come from replacing 12 with 14. Limit pill chips to short peer choices; use rows for long answers. |
| Elevation / glass | Navigation `GlassSurface` blurs; `GlassCard` is painted tint/rim/light without blur | Keep actual blur in navigation/transient sheet layer only. Default content has no rim/glow; at most one restrained tinted hero. No new shadows. Solid fallback remains mandatory. Prefer ≤2 concurrent blur regions while preserving the existing hard budget of 3. |
| Motion | Press 90, fast 160, standard 260, reveal 380, stagger 40 ms; spring snap 380/28, settle 220/30 (`app_theme.dart:152`) | Keep 90 ms press. Trial target: fast 140, ordinary custom change 220, rare reveal 320, stagger 24 ms with at most four items. Tab switch 180 ms opacity only. Keep platform push/pop and sheet physics. Change after device review, not blindly as a global speed-up. |

The red reads more like an alarm when a large background glow, red hero, red shortcuts and red completion control coexist (S47/S49). **Inferred aesthetic judgment:** use less red area, not a duller replacement brand color. Oswald also becomes tiring when nearly every section shouts; change its frequency before changing its family.

### Contrast — computed, not estimated by eye

**Measured:** WCAG relative luminance on sRGB token values, `(Llighter + .05)/(Ldarker + .05)`, with sRGB channels linearised at 0.04045. Values below are rounded to two decimals after computation. These are opaque token pairs, not measurements of antialiased screenshots, transparent borders, every gradient position or every control state.

| Foreground | Ground `08070C` | Surface `14121A` | Elevated `26222F` |
|---|---:|---:|---:|
| Primary text `F7F5FA` | 18.54 | 17.15 | 14.34 |
| Secondary `BDB8C7` | 10.37 | 9.59 | 8.02 |
| Muted `9892A5` | 6.68 | 6.18 | 5.17 |
| Primary crimson `E0222B` | 4.24 | 3.92 | 3.28 |
| Accent text `FF6358` | 6.86 | 6.35 | 5.31 |
| Positive `46C287` | 8.92 | 8.25 | 6.90 |
| Warning `F5A623` | 9.91 | 9.16 | 7.66 |
| Danger `FF4F7B` | 6.36 | 5.88 | 4.92 |
| Pro gold `F2C879` | 12.73 | 11.77 | 9.85 |
| Border `29272F` | 1.36 | 1.26 | 1.05 |
| Strong border `3A383F` | 1.74 | 1.61 | 1.34 |

**Measured:** white on primary fill `C7131E` = **5.93:1**, white on primary `E0222B` = **4.74:1**, white on `ctaTop EC2B34` = **4.23:1**, white on positive `46C287` = **2.25:1**. The CTA-top result is a token warning, not proof that the live flat PrimaryButton fails. The existing PrimaryButton uses the safe `primaryFill`.

Normal text needs 4.5:1; large text needs 3:1. WCAG large-text thresholds are in points (18 pt regular / 14 pt bold), not “all 18 px headings.” [WCAG contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

**Measured/Inferred role finding:** the food check uses a white mark on a solid positive fill (`nutrition_screen.dart:1317–1347`), below the 3:1 meaningful non-text threshold. Use a dark check on green (ground/positive pair 8.92:1). Low-contrast borders are not automatically failures: a decorative separator need not be 3:1 when readable content already identifies the control. Check required focus/selection boundaries separately. [WCAG non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).

### Component inventory and consolidation

**Measured textual inventory**, production `lib/` excluding generated/debug paths: 51 `AppCard(` occurrences in 26 files; 5 `GlassCard(` in 5; 64 `BoxDecoration(` in 45; 10 `showDialog` in 8; 13 `showGlassSheet` in 11; 3 `showModalBottomSheet` in 2; 44 `TextButton(` in 26; 9 `InkWell(` in 8 and 2 `InkResponse(` in 2. These are source occurrences, not rendered counts or proof that every occurrence is a duplicate. Only three `fontSize:` occurrences in one theme file support the conclusion that raw type sizing has largely been consolidated.

| Component | Keep | Merge/change — Inferred recommendation |
|---|---|---|
| Primary/Ghost buttons | 48 dp minimum, wrapping/compact label logic, safe flat fill | Use one primary/secondary/tertiary contract. Ghost is currently filled elevated + border despite being described as outlined; name/document its actual role. Avoid replacing provider-mandated sign-in styling. |
| Cards | `AppCard`, one optional tinted hero | Replace simple session/stat card stacks with `GroupedList`. Keep specialized charts as content, not another nested card. |
| Chips/segments | `FilterChips` for short peer navigation | Share selected-state semantics; long onboarding choices become rows. At large text, do not use a one-line chip to carry a full sentence. |
| Text fields | `AppTextField`, auth helpers, password visibility | Bring manual food/weigh-in/password form spacing/errors into one form pattern; use keyboard-appropriate input and explicit units. |
| Sheets | `showGlassSheet`, safe-area/keyboard handling | Add shared header, close/back, scrolling body and action region. Use medium/large detents where useful; grabber only when resizing/dismissal supports it. Do not nest sheets for simple value changes. |
| Dialogs | Short irreversible confirmation | Move multi-input entry and long delete explanation to sheets; share completion form between player/manual logging. |
| Lists | `GroupedList`, dividers, 48 dp hit areas | Use one row for label/value/chevron, a separate switch row and destructive row. Avoid hand-built lookalikes in every feature. |
| Empty states | Existing `EmptyState` icon/title/message/action | Exactly one useful next action, retain parent context; no generic sad illustration or fake charts. |
| Loading | Recipe skeleton | Match Fuel/review geometry, keep navigation stable. If reduce motion is on, show static placeholders; no shimmer dependency for comprehension. |
| Progress/rings | Meaningful completion or elapsed time | One representation per fact; calories do not need a hero, ring and repeated bars at equal emphasis. Label units/meaning. |
| Bottom navigation | Four tabs, one semantic action per tab | Remove hard 14 px label fitting as the only large-text strategy (`bottom_nav.dart:109–125`). Allow an accessible large-label layout without hiding destinations. |
| Section headers | Shared `SectionHeader` | Barlow for ordinary sections; avoid an all-caps Oswald title above every small group. |
| Snackbars / Undo | Dark floating theme, explicit Undo | One feedback surface per commit, do not cover dock actions; do not announce duplicates from both snackbar and sheet. Test announcement order with a screen reader. |

### Navigation and information architecture

**Inferred:** keep Home / Train / Fuel / Profile. Home decides the next action; Train owns the week and training tools; Fuel owns logging/target; Profile owns preferences/history/account. Avoid creating another Progress tab.

- Home Start and Train Start should open the same actual session. Log completed training remains a separate secondary operation using the same finish form.
- Use push navigation for durable detail (weight, fight path, recipe, weekly review); sheets for short entry/selection; full-screen task mode for running timers/drills. Keep Cancel/Back vocabulary consistent.
- **Inferred, `home_shell.dart:108–143`, `notifications/notification_route.dart:24–41`:** session reminders resolve to Train rather than a session-specific detail. Preserve safe routing; highlight/scroll to the intended session and show the reminder’s context. Do not claim the current `/train/session/...` payload starts that session. Real notification cold/warm launches are untested.
- Standard Cupertino route transitions are already selected on iOS (`app_theme.dart:329`); Flutter and Material imports are not themselves defects. The larger issue is mixed control behavior and task structure. Keep Android conventions where they aid Android users; do not replace everything with imitated SF Symbols.

### Apple lens, accessibility and motion

Apple’s materials guidance places Liquid Glass in the functional control/navigation layer, with content remaining distinct. Fighter Edge’s `GlassSurface`/`GlassCard` split is directionally correct: a painted hero is not real Liquid Glass, nor does it need to become one. Reduce content decoration before adding blur. [Apple materials](https://developer.apple.com/design/human-interface-guidelines/materials).

**Inferred, `glass_policy.dart:29–56,97–110`:** high contrast/in-app Reduce transparency can select solid surfaces; slow raster sampling can downgrade blur to tint; sigma is 16 and the hard concurrent budget is 3. Preserve these. Automatic mapping to the iOS Reduce Transparency preference was not verified; the code comments explicitly describe a Flutter exposure limitation. Do not claim complete OS preference integration.

Apple typography/accessibility guidance favors readable hierarchy, scalable text and operable controls. Brand fonts are compatible with that goal; fitted/shrinking navigation labels and clipped choice text are the issue. Keep the user’s 48 dp target requirement even where Apple’s platform guidance uses other default sizes. [Apple typography](https://developer.apple.com/design/human-interface-guidelines/typography), [Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

**Measured/Inferred:** `AppAccessibility.heroNumeralScaler` caps scale at 1.25 (`app_accessibility.dart:88–91`). This can be reasonable for giant distance-read timers, provided complete accessible values exist. Do not apply the exception to normal text or rely on `FittedBox` as the default answer to Dynamic Type. Fuel’s important totals and long call labels need role-specific review. Test focus order, keyboard navigation, selection announcements and German truncation in addition to layout exceptions.

| Interaction | Evidence and current duration | Impression / decision |
|---|---|---|
| Tab changes | **Observed** settled navigation between main tabs; **Measured code:** 260 ms fade + .98→1 scale, visited content retained (`fade_through.dart`, `home_shell.dart`) | Feels like each dashboard is arriving again. Use a shorter opacity change without scaling all content. No frame-time claim. |
| Push/pop | **Inferred:** iOS Cupertino builder, custom Android fade/slide (`app_theme.dart:324–365`); some direct `MaterialPageRoute`s | Keep platform continuity and back gestures; validate interactive iOS dismissal on device. |
| Splash hand-over | **Observed** prepared splash only; **Measured code:** 900 ms entrance | Keep logo position constant; seamless native hand-over not verified. No launch-time score from debug frames. |
| Button press | **Inferred:** .97 press scale, 90 ms, snap spring; disabled/reduced-motion behavior in `press_scale.dart:120–164` | Small compression is appropriate. Ordinary navigation need not vibrate; keep commit feedback for actual changes. Physical feel untested. |
| Sheet open/close | **Observed** open auth/Fuel/preferences/confirmation surfaces; duration not independently measured | Content expansion and keyboard movement dominate more than the transition. Use common header/body/footer and platform presentation, not another custom spring. |
| Entrance/reveal | **Measured:** 380 ms, 12 px rise, 40 ms/item (`premium_effects.dart:123–182`); Reaction Start index 6 gives ~240 ms delay + reveal | Reserve for real payoff. Do not stagger daily working controls or delay Start for decoration. |
| Reaction countdown/call | **Observed** countdown/live/pause/rest states; **Measured:** call-key cross-fade 160 ms, call color settles over 380 ms | Countdown is legible; live call could use more of the field. Fast-paced overlap/voice alignment must be watched and heard on device. |
| Round timer urgency | **Inferred:** ~3.5% scale pulse over 380 ms in last ten seconds (`round_timer_screen.dart:323`) | Prefer stable digits and phase-boundary feedback. Do not animate merely because the clock changes. |
| Reduced motion | **Inferred:** PressScale, FadeThrough and drill switcher check disable-animations | Preserve instant/static alternatives. Check every custom timer/reveal path; screenshots alone cannot certify coverage. |

No continuous motion recording or reliable frame trace was obtained. The qualitative observations above concern navigation and settled states, with code timings explicitly separated. Apple recommends motion that communicates and respects accessibility; a universal spring on every region is not necessary. [Apple motion](https://developer.apple.com/design/human-interface-guidelines/motion). Sheets should expose clear completion/dismissal and useful sizes rather than merely a glass background. [Apple sheets](https://developer.apple.com/design/human-interface-guidelines/sheets).

**Measured haptic mapping:** selection → selection click; tap → light impact; commit → medium impact; success → light then medium after 70 ms; warning → heavy (`app_haptics.dart:18–38`). **Inferred:** `PressScale` defaults to tap feedback, and PrimaryButton adds commit automatically; callbacks can also haptic, risking duplicates. Choose one owner of feedback. Default ordinary navigation to no impact, selection tick for choices, one commit on accepted action, one success at meaningful completion. Physical intensity/timing requires an iPhone.

**Inferred feedback gap:** the theme globally disables ink/highlights (`app_theme.dart:324`), but raw InkWell/InkResponse remain. Ensure each has a local pressed/selected response, especially before asynchronous state changes. Restore local feedback, not a global Android ripple on every custom button.

### Imagery and identity plan

**Observed:** S04 feels branded; S55–56 are mostly typography and controls; S81–83 immediately feel more content-rich. **Inferred recommendation:** start with content proof, not decoration.

1. Owner shoots three useful sequences: jab, one footwork drill and one defensive move. Obtain participant permission. A few stills or a short compressed clip per lesson are enough for a first slice; text remains available.
2. Reuse a single clear frame as the library thumbnail; label the exact technique/discipline. No random bodybuilding or cage imagery suggesting a different product.
3. Create the week strip, countdown timeline and simple stance/footwork diagrams in Flutter code. Diagrams must match reviewed instruction; do not invent authoritative technique.
4. Use the complete logo on login/launch. Small mark optional on welcome; do not repeat the large mark on every tab, timer or empty state. Test app-icon mask and tiny-size recognition separately.
5. No photos behind live calls, input fields, weight charts or safety messages. No AI-generated images. Openly licensed assets require verified license/attribution; existing recipe credits are a useful model, not proof all future assets are cleared.

### Copy, German and perceived performance

**Observed/Inferred:** primary setup localization improved substantially, but Home shows the saved English goal in German (`dashboard_screen.dart:103`, S121/S138), and weigh-in/password/manual-food/error strings still bypass localisation. Translate stable goal codes at presentation as Profile already does. Use one term each for week, camp, session and drill; label Start / Resume / Finish / Log according to the actual action. Have a native German reader review truncation and idiom; this audit identifies visible leaks, not a certified language review.

**Inferred performance risks and safeguards:** retained tabs and static background painting help. The background gradients are static/repaint-bounded, not proven animated battery drains. Avoid new full-screen blur, nested scrollable lists and eager rebuilds of whole tabs. Keep shimmer optional, images sized/cached and loading geometry stable. Profile a release/profile build on a modest Android device and a real iPhone before making FPS or time-to-first-paint claims. A debug emulator with inspection pauses cannot establish a production performance regression.

## 8. Findings register

Paths below are relative to `fighter_edge/`; line numbers refer to baseline `908d2b7`. Screenshot references resolve through the external index. A screenshot marked context does not prove a code-only behavior. **P0** = blocker, **P1** = important, **P2** = polish. **S** ≈ hours, **M** ≈ 1–3 focused days, **L** = several days/content dependency; estimates exclude store/device availability. No verified P0 is assigned.

| ID | Area | Screen | Evidence (screenshot + file:line) | Observed/Measured/Inferred | Problem | Why it matters (HIG / usability) | Recommendation | Severity | Effort |
|---|---|---|---|---|---|---|---|---|---|
| F01 | Hierarchy | Home | S47/S105; `lib/screens/dashboard_screen.dart:94` | Observed | Many independent blocks compete with Today. | Scanning should reveal one next action. | Cut duplicate stats/shortcuts; one Today action, one week, one brief. | P1 important | M |
| F02 | Value | Plan reveal | S25/S46; `lib/screens/onboarding/plan_ready_view.dart:92` | Observed | Nutrition receipt leads; actual week is absent. | Payment follows weak proof of the promised plan. | Show generated week/next session before existing paywall. | P1 important | M |
| F03 | Navigation | Home → training | S47/S49 context; `lib/screens/home/today_hero.dart:90` | Inferred | Home logging and Train starting express different primary tasks. | Consistent action language makes outcomes predictable. | Same Start session route; secondary manual log. | P1 important | M |
| F04 | Accessibility | Onboarding goal | S142; `lib/screens/onboarding/onboarding_widgets.dart:70` | Observed | Long German choices are clipped at linear 200%. | Users must read the complete answer before selecting. | Wrapping full-width rows, visible selection mark. | P1 important | S |
| F05 | Accessibility | Bottom navigation | S138–141 context; `lib/widgets/bottom_nav.dart:109` | Inferred | Labels are fitted into a fixed 14 px height. | Shrinking labels counteracts accessible text settings. | Large-text-aware label layout; preserve four named destinations. | P1 important | S |
| F06 | Training data | Completion | S87/S88; `lib/screens/session_player_screen.dart:94` | Measured | Player effort options 6–10 vs manual 1–10. | Light training cannot be logged equivalently. | Shared labelled effort scale/form. | P1 important | M |
| F07 | Trust / task | Session player | S85; `lib/screens/session_player_screen.dart:149` | Inferred | Neutral player and direct exit do not match a guided/continuous session expectation. | Active tasks need context and safe dismissal. | Actual block information; active-exit guard; review paywall claims. | P1 important | M |
| F08 | Discovery | Drills | S55; `lib/screens/drill_library_screen.dart:154` | Observed | Navigation/filter machinery precedes first drill. | Recognition and useful content should precede taxonomy effort. | Compact continue row, search and real drill cards. | P1 important | M |
| F09 | Instruction | Tutorial | S56; `lib/screens/drill_library_screen.dart:851` | Observed | Movement is explained only with text. | Users benefit from seeing the actual technique. | A few owner-shot demonstrations with text equivalents. | P1 important | L |
| F10 | Action reach | Reaction picker | S58–59; `lib/screens/reaction_drill_picker.dart:66` | Observed | Configuration pushes Start below fold. | Repeated drills should be quick to begin. | Saved preset, compact choices, voice sheet, pinned Start. | P1 important | M |
| F11 | Live legibility | Reaction call | S61; `lib/screens/reaction_drill_screen.dart:397` | Inferred | Display52 only scales down despite a large available field. | Calls must be legible at training distance. | Bounded responsive call typography; test longest DE/EN cues. | P1 important | S |
| F12 | Content truth | Fuel recipes | S67/S68/S78; `lib/screens/nutrition_screen.dart:842` | Observed | Prominent routes lead to intentionally unpublished content. | Empty promises weaken paid-product trust. | Gate promotions on published availability; preserve review gate. | P1 important | S |
| F13 | Recovery | Recipe error | S80; `lib/features/edge_fuel/presentation/screens/recipe_library_screen.dart:86` | Observed | Unavailable page has no Retry. | Recoverable failures need an explicit next action. | Retry and keep filters. | P1 important | S |
| F14 | Contrast | Food check | S50 context only; `lib/screens/nutrition_screen.dart:1317` | Measured | White on positive fill is 2.25:1. | Meaningful check needs 3:1 non-text contrast. | Dark check on green; extend role contrast check. | P1 important | S |
| F15 | Contrast roles | Shared text/actions | S47 context; `lib/theme/app_colors.dart:56` | Measured | Primary crimson is 4.24:1 on ground and 3.28 on elevated. | Unsuitable for normal-size text; not a blanket button failure. | AccentText for small actions; keep safe PrimaryFill. | P1 important | S |
| F16 | Localisation | Home / forms | S121/S93; `lib/screens/dashboard_screen.dart:103`; `lib/screens/weight_tracker_screen.dart:183` | Observed | English goal/form labels appear in translated journeys. | Language switching suggests incomplete work. | Translate stable codes and remaining field/error strings. | P1 important | S |
| F17 | Mode consistency | Hide numbers | S99 context; `lib/screens/nutrition_screen.dart:248,1206` | Inferred | Edit can be exposed while handler returns without action. | Controls must either work or explain restriction. | Safe names-only edit or remove affordance/semantics. | P1 important | S |
| F18 | States | Fuel no target | S108; `lib/screens/nutrition_screen.dart:536` | Observed | Zero-like totals dominate before a target exists. | Defaults can be mistaken for an actual recommendation. | Explicit no-target summary and setup/log choice. | P1 important | S |
| F19 | Completion | Reaction finished | S64 context; `lib/screens/reaction_drill_screen.dart:76` | Inferred | No normal session-save step in completion handler. | Users may expect completed training to count. | Owner policy, then explicit shared save if appropriate. | P1 important | M |
| F20 | Reminder continuity | Notification tap | S53 context; `lib/screens/home_shell.dart:108`; `lib/notifications/notification_route.dart:34` | Inferred | Session payload resolves to Train, not highlighted session detail. | A reminder should retain what the user tapped. | Highlight/scroll intended session; verify cold/warm launches. | P1 important | M |
| F21 | Loading | Fuel | S75; `lib/screens/nutrition_screen.dart:92` | Observed | Full-page spinner replaces content structure. | Stable layout improves perceived readiness. | Summary/row skeleton with retained navigation. | P2 polish | S |
| F22 | Empty state | History | S54; `lib/screens/training_camp_screen.dart:488` | Observed | No direct first-log action. | Empty pages should explain and enable progress. | Log completed session action. | P2 polish | S |
| F23 | Copy | Paused timer | S91; `lib/screens/round_timer_screen.dart:398` | Observed | Start describes resuming. | Labels should predict the actual result. | Resume, preserving state. | P2 polish | S |
| F24 | Motion / feedback | Shared controls | S65/S98 context; `lib/theme/app_theme.dart:324`; `lib/widgets/press_scale.dart:120` | Inferred | Global ink removal coexists with raw ink controls and default impact on navigation. | Feedback should be perceivable and meaningful. | Local press treatment; one haptic owner per action. | P2 polish | M |
| F25 | Motion | Reaction setup | S58–59 context; `lib/widgets/premium_effects.dart:123` | Measured | Index-six reveal adds ~240 ms delay to a 380 ms entrance. | Everyday controls should feel immediately available. | No staged reveal for setup actions. | P2 polish | S |
| F26 | Modal pattern | Manual log / delete | S88/S115; `lib/screens/delete_account_flow.dart:44` | Observed | Dense multi-input dialogs differ from other entry sheets. | Reading/keyboard space and dismissal should be predictable. | Common scrollable sheet/form pattern. | P2 polish | M |
| F27 | Visual language | Cards / background | S47/S49; `lib/widgets/glass_surface.dart:274`; `lib/widgets/premium_effects.dart:22` | Observed | Tint, gloss and repeated cards imply equal priority. | Content hierarchy should carry emphasis. | Flat grouped content, one restrained hero, no global form glow. | P2 polish | M |
| F28 | Data display | Weight dates | S94 context; `lib/screens/weight_tracker_screen.dart:472,544` | Inferred | Fixed date patterns do not follow selected app locale explicitly. | Dates must be quick and unambiguous. | Locale-aware axis/history formatting. | P2 polish | S |
| F29 | Interruption | First-use sheets | S96/S97 context; `lib/screens/home_shell.dart:156` | Inferred | Success and reminder prompts can stack near first use. | Interruptions reduce control after a simple log. | Inline success; contextual reminder request. | P2 polish | S |
| F30 | Safety display | Missing data | S110; `lib/features/fight_camp/presentation/widgets/weight_path_summary.dart:17` | Observed | This capture shows insufficient data, not an unsafe decision. | Audits and UI must distinguish uncertainty from danger. | Preserve words/next step; validate remaining safety variants separately. | P2 polish | S |

## 9. Ordered roadmap — one reviewable PR at a time

No implementation is included here. Acceptance checks below are instructions for later engineering, not tests claimed by this audit. Reuse existing tests; add coverage only for meaningful behavior/accessibility changes. Avoid huge screenshot-only tests that mirror every line of layout.

### Ten quick wins — approximately one focused day in total

These are narrow slices, roughly 20–50 minutes each for someone familiar with the code, about 6–8 hours collectively before review/device delays. Each is independently reviewable; stop expanding a quick win into a new component framework. Prioritise Q1, Q3, Q4, Q5, Q6 and Q8 first.

| Order / PR | Goal and scope | Likely files | Acceptance check |
|---|---|---|---|
| Q1 | Make long onboarding goal choices readable; use existing selectable-row pattern. | `screens/onboarding/onboarding_widgets.dart`, `onboarding_steps.dart` | All EN/DE options readable at 320 width/linear 200%; selection still announced and tappable. F04. |
| Q2 | Use accentText for small red action copy where primary is being used. No brand recolor. | `theme/app_theme.dart`, touched action sites, `app_colors.dart` comments | Audit actual foreground/background pairs; preserve safe button fill and disabled semantics. F15. |
| Q3 | Change positive-fill check mark to dark and cover the semantic pair. | `screens/nutrition_screen.dart`, existing contrast test | Checked mark ≥3:1, unchanged toggle hit target/selection. F14. |
| Q4 | Translate Home goal and weigh-in Add/Cancel/Save; fix selected-locale dates. Secondary forms are a later pass. | `dashboard_screen.dart`, `weight_tracker_screen.dart`, EN/DE ARB | German journey has no English goal/dialog actions; date output follows selected locale. F16/F28. |
| Q5 | Change paused round-timer action to Resume. | `round_timer_screen.dart`, EN/DE ARB | Ready says Start; paused says Resume/Fortsetzen; no reset on resume. F23. |
| Q6 | Remove prominent recipe promotions when no published recipes exist, using existing availability data. | `nutrition_screen.dart`, `edge_fuel_plan_screen.dart` | Zero published → no promotional dead ends; direct route still honest; published fixture → entry returns. Do not change recipe status. F12. |
| Q7 | Give empty training history a manual Log session action. | `training_camp_screen.dart`, EN/DE ARB | Opens existing log flow; saves appear in history; locked account follows existing gate. F22. |
| Q8 | Add Retry to recipe error using the existing load/reload operation. | `recipe_library_screen.dart`, controller if needed | Error → retry → ready/empty; filters persist; repeated taps do not issue duplicate work. F13. |
| Q9 | Raise primary/secondary button labels to Barlow16/600 using the existing content widget. | `widgets/primary_button.dart` | Long EN/DE labels fit/wrap at 200%, no target below48, provider buttons unchanged. |
| Q10 | Put collapsed first-week checklist after Today; keep progress state intact. | `dashboard_screen.dart`, `first_week_checklist.dart` | Today action appears first at default size; checklist expands, completes and stays dismissed correctly. F01/F29. |

### Five bigger moves — suggested order B1 → B2 → B3 → B5 → B4

| PR | Goal / deliberate cuts | Likely files | Acceptance check |
|---|---|---|---|
| B1 — Show the week before payment | Replace leading nutrition receipt with actual dated first week, next session and chosen-day rationale. Keep optional Fuel and the existing post-reveal paywall. Cut two redundant welcome slides from the mandatory path. | `onboarding/plan_ready_view.dart`, `welcome_pages.dart`, plan read model/controller, EN/DE ARB | Known fixture’s sessions/dates match Train exactly; no fabricated content; trial wording only when store confirms; skipped Fuel and read-only fallback work; 320/200%/DE scroll. F02. **M.** |
| B2 — Make Home a daily decision | One Today action, short fight context, one shared week strip and one brief. Cut stat strip, duplicate shortcuts and full-size rest hero. Home and Train start the same task. | `dashboard_screen.dart`, `home/today_hero.dart`, `home_shell.dart`, shared week row/navigation | Training, rest, no-plan, due-review and read-only fixtures each have an obvious next action; values agree with Train/Fuel; back preserves tabs; no display-mode leaks. F01/F03/F27. **M.** |
| B3 — Finish the training journey | Shared session completion/manual-log form, consistent effort, active-exit/lifecycle rules and actual block context. Decide explicit Reaction save policy. Reduce nested Train chrome and boxed session rows. | `training_camp_screen.dart`, `session_player_screen.dart`, `session_log_dialog.dart`, `reaction_drill_screen.dart`, plan/log controller, shared sheet | Start→pause→background→resume→finish saves once; light RPE allowed; cancel does not save; manual gym log remains fast; accidental exit guarded; Pro restriction preserved; notification context highlights intended session. F06/F07/F19/F20/F26. **L.** |
| B4 — Make techniques visible | Owner supplies a small reviewed set of demonstrations. Compact library header, meaningful thumbnails, demo plus text in tutorial. Cut oversized taxonomy introduction. | `drill_library_screen.dart`, `learning_path_card.dart`, drill assets/catalog metadata | Three initial techniques display licensed/consented media, text equivalent, placeholders and credit where required; no implied unavailable video library; first drill visible early; no image behind live calls. F08/F09. **L**, owner content dependency. |
| B5 — Simplify Fuel and entry surfaces | One compact numeric summary, helpful first log/no-target states, common search/portion/manual edit flow, stable loading layout, mode-safe controls. Lead review with recommendation. | `nutrition_screen.dart`, `add_food_sheet.dart`, `edge_fuel_plan_screen.dart`, `weekly_review_screen.dart`, shared sheet/form helpers, ARB | Log/edit/delete/Undo update once; no-target distinct from zero intake; failure blocks unsafe writes; hide/pause modes leak no restricted values; keyboard/200% do not obscure actions; recipe gate remains. F17/F18/F21/F26. **L.** |

Treat system changes in section 7 as acceptance rules within these slices. Do not begin a separate weeks-long design-system rewrite. After B2/B3, review screenshots with the owner before adding media; the primary hierarchy should already improve without photos. Apply the compact Reaction picker and motion/feedback cleanup as the next bounded PR after B3 if it cannot fit safely inside that task.

### Validation gate after the substantive slices

**Inferred recommendation:** run the existing relevant accessibility/German/widget tests, then inspect normal/empty/error/locked fixtures in EN/DE, 320 width and linear200. On a real iPhone: VoiceOver focus/action labels, interactive back, keyboard avoidance, Reduce Motion/Transparency, haptics, Reaction voice timing, interrupted session behavior and store trial/restore. On Android: Back/system permission and a modest-device profile run. Measure startup and raster timing only in a suitable profile/release configuration. None of these gates authorises publishing or bypassing existing release checks.

## 10. Five proposed wireframes

**Inferred proposals, not screenshots of implemented screens.** Labels below are illustrative English, with dynamic values read from the real plan. Keep content scrolling; a pinned action must account for safe area, keyboard and larger text. At 200%, full readable labels and reachable actions matter more than fitting the default composition into one viewport.

### A. Home — a next action, not a collection of dashboards

```text
TODAY                                      [Profile]
Wed, 28 Oct · 42 days to fight              [camp →]

Next training
<actual session title>
<duration> · <actual focus / block summary>
[                Start session                 ]
Log completed training

THIS WEEK
M ✓   T ·   W TODAY   T session   F ·   S session   S ·
<completed> of <planned> sessions

CORNER
One useful sentence derived from today's actual data.
[Fuel →]                            [Log weigh-in →]

Your first week · 1 of 4                       [⌄]
<Review last week only when due>

Home           Train           Fuel           Profile
```

Rest day substitutes a compact recovery/next-session block, not an equally large red empty hero. No separate weight/session/streak card, duplicate target card or repeated fight promotion. The week row reuses Train’s calendar logic.

### B. Plan ready — show what the payment unlocks

```text
Your first week is ready
Built for <N> training days · <experience>

WEEK OF <actual date>
Mon   <actual session>                       <time>
Tue   Rest
Wed   <actual session>                       <time>
... only actual generated entries ...

NEXT UP
<session name> · <duration>
One honest explanation of this schedule.

Fuel target                                 [View]
<compact optional summary / skipped state>

[ <store-eligible trial CTA / subscription CTA> ]
<short factual subscription/renewal explanation>
```

The next screen is the existing paywall. No imaginary bout-specific plan if the model only knows goal/experience/days. If actual sessions are generic, be honest about them and improve plan content separately; do not disguise that gap with photography.

### C. Train — the week is the main object

```text
TRAIN                                    [History]
<week date range>                         [‹] [›]
M   T   W today   T   F   S   S

TODAY / NEXT
<actual session> · <duration>
<block/focus summary>
[                Start session                 ]

YOUR WEEK                 <one grouped surface>
Mon   <session>                              Done ✓
Tue   Rest
Wed   <session>                              Today
Thu   Rest
Fri   <session>                              [→]

Log completed training

TOOLS
Round timer →      Reaction drill →
Learn techniques →
```

Future rows do not look like primary red completion buttons. History is secondary but easy to reach. Tools remain available without competing with four internal tab labels at the top.

### D. Drills — useful instruction before taxonomy

```text
TECHNIQUES
[Search technique]
<selected discipline>                         [Change]

Continue: <next written drill>                  [→]

[owner still]  Jab
               Boxing · beginner · <real duration>
[owner still]  <defensive technique>
               <discipline> · <level>

Browse paths                                    [→]
Saved drills                                    [→]
```

Tutorial: actual demonstration → one-line purpose → numbered steps → mistakes → practice/progress control. No broad landscape athlete photo unrelated to the selected movement. Start with a few reviewed assets; unillustrated lessons can still use consistent text rows.

### E. Reaction picker — repeat a drill quickly

```text
REACTION
One move at a time. React to the call.

<saved preset summary / last-used settings>
Discipline     <current choice>                [→]
Level          <current choice>                [→]
Pace           <current choice>                [→]
Voice          <current voice>            [Preview]

<round count> × <work> · <rest> between rounds
Moves in this drill                              [⌄]

<scroll clearance>
[                  Start drill                   ]
```

Voice row opens choice + test in a common sheet; preview remains available. Selection changes should be immediate and retained. Live mode contains only phase, round/time context, one large move and reachable pause/exit controls.

## 11. Earlier design documents — what to retain and what to reject

**Inferred comparison to source/documents, supported by current screenshots.** Historical proposals are not the current product contract. The owner’s present constraints take precedence.

| Document | Followed / improved | Still relevant / wrong direction |
|---|---|---|
| `UI_REDESIGN_SPEC.md` (current October revision) | Dark brand, font pair, shared tokens, four-tab structure, first-run work are visible. | Stronger Home hierarchy and compact training structure are only partly realised (S47/S49). Reveal is still nutrition-led (S25). Its Free-vs-Pro/softer-paywall suggestions are obsolete for the paid product: keep post-reveal paywall. Do not treat every V2 color change as accidental drift. |
| `DESIGN_SYSTEM_HANDOFF.md` | Type/color/spacing primitives, press helper, glass policy and accessibility abstractions exist. | Component reuse is not the same as screen editing. Finish forms/sheets still diverge; verify behavior and use, not merely token adoption. |
| `DESIGN_SYSTEM_PLAN.md` | Semantic type roles and bounded effects are stronger than scattered styles. | Do not introduce more tokens/components simply to satisfy a catalog. Existing primitives are enough for the next redesign slices. |
| `UI_UX_DESIGN_AUDIT_20260919.md` | Several concerns now have tests and shared helpers. | High code-based scores cannot establish premium feel, device accessibility or clean hierarchy. This audit uses actual rendered evidence and labels gaps rather than inheriting those scores. |
| `UI_POLISH_AUDIT_20260925.md` | Clearer palette, flat primary buttons and disciplined motion helpers are present. | The subtraction advice remains right: less chrome and repetition. More glow/gradient polish would not solve the current hierarchy. |
| `VISUAL_AUDIT_20260917.md` | Mock Profile values and hardcoded Train dates are no longer representative; current profile/date fixtures use real state/localisation. | Do not repeat fixed issues. Its call for stronger visual content is best applied to technique instruction, not every page. This older file was read read-only from the main checkout because it was not present in the audit baseline. |
| `UX_WORKFLOW_HANDOFF.md` | Navigation/access and first-run improvements have landed since older proposals. | Judge complete current loops, not isolated destination screenshots. It was likewise available only as a main-checkout artifact, read without modification. |
| `REACTION_DRILL_UX_AUDIT_20260922.md` | Countdown, pause/resume, background/exit handling, voice preview and one-call clarity have improved. | Old multi-move guidance is obsolete. Keep exactly one move per call. Current priorities are compact setup, distance legibility, audio/device validation and a clear completion policy. |

## 12. Owner decisions — eight questions with recommendations

These are product decisions for later slices, not permission requests blocking this audit.

1. **What is the main promise: a training week or nutrition management?** Recommend training week first, with optional Fuel support. Current setup/reveal gives the opposite impression.
2. **How specific are the generated sessions today?** Recommend revealing only real content now. Do not sell guided technique coaching unless reviewed instructions actually accompany the player.
3. **Should Reaction count toward training totals?** Recommend an explicit optional save with duration and effort, using the shared completion form; no silent automatic count.
4. **Can you supply consented demonstrations of three techniques?** Recommend a small owner-shot set before any larger media library. If unavailable, prioritise the no-photo hierarchy work and simple reviewed diagrams.
5. **Should Hide numbers keep neutral days-to-fight visible?** Recommend keeping date context without weight/calorie data, only if this matches the intended protective mode. Pause must remain calm and reversible.
6. **Are final production legal URLs and store trial configurations verified?** Recommend a separate owner release check on an actual store build; this local audit did not establish them.
7. **Which EN/DE training vocabulary should be canonical?** Recommend a short glossary reviewed by a German speaker, and presentation translation of stable saved codes. Use it across sessions, reminders and errors.
8. **Can one iPhone be used for the final acceptance pass?** Recommend a small/older supported iPhone first, then largest accessibility text, VoiceOver, headphones and Reduce Motion/Transparency. Avoid buying tooling; a borrowed device/TestFlight pass is sufficient.

## 13. Coverage ledger and remaining verification

This is a broad visual and code audit, **not a claim that every requested state was successfully rendered**. Every named product area has an assessment; incomplete state capture is explicitly recorded here and in INDEX. Do not convert an inferred finding to observed merely because a filename suggests it.

| Family | Accepted visual evidence | Code-only / not tested |
|---|---|---|
| Launch/auth | S04–12, S117–120; waiting/success/failure widgets prepared | Native hand-over, actual bootstrap timing, real email/providers, all auth loading/error/DE/200 variants. `main_local.dart` runs the app directly and is not the production Firebase bootstrap. |
| Onboarding | S13–23/S25, S27–40; all seven default/DE questions; S142–147 exact200 for first six | Exact200 review, restarted-draft visual journey, all safety/error combinations; S24 not trusted as error evidence. |
| First run | S95–97 prepared | Natural sequence/timing of all prompts, coach-mark traversal, analytics consent variants. |
| Access | S26 unavailable, S41 local read-only, S84 locked fixture, S47 Pro fixture | Real trial chip, eligible/ineligible offer, purchase/restore/pending/success, entitlement expiration during active entry. |
| Home | S41/S47–48/S95/S105, S121/S125/S133/S137/S138 | All due-review/target variants in situ; exact200 Home is an empty-plan fixture, not all hero variants. |
| Train | S49/S54–56/S85–91, S122/S126/S134/S139 | Reliable no-match capture, all learning-path/locked histories, session exit/background on physical device, timer finish capture. |
| Reaction | S58–64, voice choice/countdown/live/pause/rest/finish (last phases prepared) | Audible voice, music/headphones, physical haptics, sustained fast-pace recognition, every longest German move at200. |
| Fuel | S50/S65–77/S98–100/S108–109, S123/S127/S135/S140 | Manual/edit dialog capture, populated day after last fixture reset, all add/portion errors and number-mode cross-flow combinations, real offline/stale recovery. |
| Recipes | S78–84, unpublished/loading/error/library/detail/method/lock fixtures | Real published production catalog (intentionally hidden), exact200 detail/image failures/DE full matrix. No publication change made. |
| Body/review | S92–94/S111–112/S130; empty/first/trend and review fixture | Review loading/error screenshots, actual adjustment save, chart VoiceOver, edit/delete operation captures. |
| Fight camp | S102–107/S110/S131; setup/countdown/path/week/missing data | Every caution/review-required/unsafe/blocked rendered variant; S110 is missing data, not unsafe. No clinical safety conclusion. |
| Profile/settings | S51–53/S98/S113–116/S124/S128–129/S132/S136/S141 | Auto-pause sheet, provider reauthentication, deletion operation, real notification permission/delivery/tap lifecycle, production legal content. |
| Shared components | Visible examples across all above; code inventory | Every variant of snackbar, skeleton, semantics/focus sequence, high contrast and reduce-transparency fallback not exhaustively captured. |

**Measured:** existing targeted test success is recorded in section 2; it does not close these device/coverage gaps. **Inferred next verification priority:** (1) iPhone active training + audio/accessibility, (2) real store paywall/trial/restore, (3) all safety status fixtures, (4) populated number modes/review, (5) auth/secondary German and large-text matrix. These are validation follow-ups, not reasons to delay the low-cost fixes already evidenced here.

## 14. Audit handoff

Only this report is intended for the repository commit. Screenshots, their `INDEX.md`, benchmark references and contact sheets stay in the external evidence folder. Generated plugin files changed by dependency resolution were restored; no application implementation is included. The docs-only PR is for review and must not be merged automatically. The report is based on the named baseline, so later UI changes need fresh verification rather than treating these line numbers as permanent.

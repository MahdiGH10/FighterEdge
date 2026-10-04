# UI redesign spec (2026-10-04)

The before-implementation document the owner asked for (redesign brief
§22), plus the visual-system changes (§11–§19 of the brief). It follows the
product changes in `PRODUCT_AUDIT_20261004.md` and
`TRAINING_PLAN_PROPOSAL.md`; Fuel layout follows
`NUTRITION_COMPETITOR_RESEARCH.md`. Load the `fighter-edge-ui` skill before
building any of it.

**Identity is fixed:** near-black ground, crimson actions, gold only for
Pro, Oswald for numbers and titles, Barlow for reading. We are removing
noise and adding state, not changing who the app is.

---

## A. Visual system changes

### A1. Colour roles (no new brand colours)

| Role | Token today | Use | Never |
|---|---|---|---|
| **Action crimson** | `primary` #E63328, `primaryFill` #D22519 | The one primary CTA per screen; active training state (today's session, running timer); selected high-priority choice | Errors, decoration, borders on ordinary cards |
| **Muted crimson** (new role name `accentMuted`) | `primarySoft` 0x22E63328, `crimson800` | Selected chips/segments, week-strip progress fill, the TodayCard edge bar | Text below 18 px |
| **Accent text** | `accentText` #FF4C42 | Small crimson text links | Body copy |
| **Gold** | `premium` #F2C879 | Pro badges, Pro plan tiles, Corner Brief Pro surfaces | Streaks, decoration, any free feature |
| **Success green** | `positive` #3FD07E → **tone down to #46C287** | "Done", "on pace", "hit" | Large fills, competing with crimson CTAs |
| **Amber** | `warning` #F5A623 | Attention, sync pending, approaching a limit, rest-timer phase | Errors |
| **Danger** | `negative` #FF3B5C → **shift to #FF4F7B** (pink-red, clearly not brand crimson), always with icon + words | Errors, destructive actions, over-target, `notSafe` | Primary CTAs |
| Data | `protein`, `carbs`, `fats` | Macro series, always labelled | Status |

**Rule:** brand crimson means "do this"; danger pink-red means "something's
wrong". They never appear as the same colour on one screen. Contrast of
the two changed tokens to be re-measured against `surfaceElevated` (target
≥4.5:1) before merge.

### A2. Surfaces (keep the ramp; use it properly)

| Level | Token | Use |
|---|---|---|
| Background | `background` #09090D | Screens |
| Surface 1 | `surface` #14141B | Grouped lists, the few remaining cards |
| Surface 2 | `surfaceAlt` #191922 | TodayCard, selected rows, input fields |
| Elevated | `surfaceElevated` #21212B | Sheets, dialogs, toasts, nav-bar-adjacent bars |

No gradients, glows, glass, or shadows except the sheet's top edge.

### A3. Radius hierarchy

| Element | Radius | Today |
|---|---|---|
| Sheets, dialogs | 20 (top corners) | mixed |
| TodayCard, the few cards | 12 (`Radii.card`) | 12 ✓ |
| Buttons, inputs | 10 (`Radii.button`) | 10 ✓ |
| Small tiles, thumbnails | 8 (`Radii.tile`) | 8 ✓ |
| Chips/segments | pill only for chips | ✓ |
| Rows | **0, no container** | many are cards today |

The radius scale is already sane; the fix is fewer containers, not new radii.

### A4. Containers: the "card for everything" cut

A container stays only if it **groups, ranks, acts, or holds a distinct
state**. Planned removals (≈30% of visible containers on the main tabs):

| Screen | Containers today | Remove/flatten | After |
|---|---|---|---|
| Home | checklist, hero, Corner Brief, stats, fight row, week card (+ nested fuel week), activity list = 7 | stats card → inline row; Corner Brief card → inside TodayCard; activity → removed; week card → WeekStrip without box | 3 (checklist while active, TodayCard, fight row when no fight) |
| Train week | 5–6 session cards | All → one dated list; only today is a container | 1 |
| Fuel today | ring card (442 px) with nested link + suggestions, meal group | Ring card → open hero (no box); suggestions → row list | 1 (meals list) |
| Profile | 4 grouped lists | keep (they group) | 4 |
| Paywall | benefits card, coming-soon card, plan tiles | benefits → free/Pro table rows; coming-soon box → text | plan tiles only |

### A5. Typography usage

| Role | Font | Use | Change |
|---|---|---|---|
| `heroNumeral` 64 / `stageNumeral` 160 | Oswald | Timer, countdown | — |
| `display` 52 | Oswald | **Only** a task title in the TodayCard on a training day, kcal left, days-to-fight | Remove from "Rest day", empty states |
| `largeTitle` 30 | Oswald | Tab titles (collapsing), reveal title | — |
| `title1` 22 / `title2` 18 | Oswald | Section headings, session names in lists | — |
| `headline` 17/600 | Barlow | Row titles | — |
| `body` 17, `callout` 16 | Barlow | Explanations, food names, settings | — |
| `subhead` 14 | Barlow | Metadata (time, RPE, grams) | — |
| `micro` 12 tracked caps | Barlow | Eyebrows like "TODAY", "THIS WEEK" only | Cut uppercase elsewhere |

Uppercase: tab titles, eyebrows, the timer phase label. Everything else
sentence case.

### A6. Icons

One family (Phosphor, already used), regular weight; fill only for the
active nav tab. Icons appear where they identify a **thing**: session
kind (striking, grappling, conditioning, strength, recovery), fuel, weight,
fight, done ✓, missed, moved. A set of eight "concept glyphs" is used the
same way everywhere (WeekStrip, rows, Today). No icon on settings rows,
stats or explanatory text; no sparkle.

### A7. Bottom navigation

Keep Home · Train · Fuel · Profile. Current bar is flat with a top
hairline (good, not a floating card). Changes: active item = filled icon +
label in `textPrimary` + 2 px crimson indicator above the icon; inactive in
`textMuted`; height 56 + safe area; labels never truncate at 200% (icons
only + tooltip semantics above 1.6× scale). Tab state is preserved
(Phase 0.6).

### A8. Motion (each one communicates something)

| Moment | Motion | Duration |
|---|---|---|
| Session complete | Week-strip segment fills left→right; TodayCard cross-fades to "done" | `standard` 260 ms |
| Food logged | kcal and protein-left count down (`AnimatedCount`) | `reveal` 380 ms |
| Plan reveal | Days assemble top-down with 40 ms stagger | ~1 s total |
| Today state change | Cross-fade + 8 px rise of the new state | `standard` |
| Corner Brief update | Text cross-fade | `fast` |
| Sheets | Native rise; content no extra motion | platform |
| Timer phase change | Phase colour cross-fade, numeral never bounces | `fast` |

Reduced motion: all of the above become instant state changes.

### A9. Haptics (semantic, existing `AppHaptics`)

| Event | Haptic |
|---|---|
| Choice in a picker/segment | `selection` |
| Food logged, weigh-in saved, session moved | `commit` |
| Session complete, target accepted, onboarding finished | `success` (once) |
| Destructive confirm, safety warning shown | `warning` |
| Ordinary taps, navigation | none |

### A10. Empty states

Each answers what / why / what to do, with one action:

| Where | Copy | Action |
|---|---|---|
| Weight, no entries | "Track your morning weight to see the trend your camp uses." | Log first weigh-in |
| Train history | "Finish your first session and your weekly progress appears here." | Start today's session |
| Fuel, nothing logged | "Log your first meal and see what's left for today." | Log food |
| Fight path, no fight | "Add your fight to get a countdown and a safe weight path." | Add fight |
| Week review, first week | "Your first review arrives Sunday, after your first week." | — (shows days remaining) |

---

## B. Shared components (build once)

`TodayCard` (state-driven) · `WeekStrip` (states: completed, today,
planned, rest, missed, moved; used on Home, Train, review) ·
`BottomActionBar` (pinned CTA in safe area) · `AppSheet` · `AppConfirm` ·
`AppToast` (with Undo) · `SegmentedControl` · `AppChoiceChip` (48 px) ·
`ProposalCard` (old → new, why, Accept / Keep).

---

## C. Screen-by-screen

### Login
- **Current:** logo, welcome, email/password, forgot, sign in, Google (+Apple/code on some builds), create account, photo background.
- **Problem:** minor: generic empty-submit error (fixed in #30).
- **New hierarchy / changes:** unchanged layout. Keep photo (provenance is an owner item).
- **Removed / promoted / demoted:** none.
- **Interaction / colour / type / motion:** none beyond #30 merge.

### Sign-up
- **Current:** back, title, 4 fields, terms checkbox, CTA.
- **Problem:** filler subtitle; CTA mid-screen.
- **New:** same fields; subtitle "It takes 2 minutes to build your first week."; CTA in `BottomActionBar` above the keyboard.
- **Removed:** "Track training, weight, nutrition and more." **Promoted:** CTA reach.
- **Interaction:** Next/Done keyboard actions chain fields. **Type/colour/motion:** none.

### Welcome
- **Current:** 3 pages of claims + proof chips, skip, "About 2 minutes · 7 quick questions".
- **Problem:** claims instead of proof; pages 1–2 English only.
- **New hierarchy:** 2 pages. Page 1: "Your corner for camp" + a static **sample week strip and Today card** (real components, sample data, clearly labelled "Example"). Page 2: "Fuel and weight that follow your training". CTA "Build my week".
- **Removed:** proof chips, page 3. **Promoted:** real UI preview. **Demoted:** tagline.
- **Interaction:** swipe + CTA. **Type:** largeTitle, callout. **Motion:** sample strip fills once (reduced motion: static).

### Consent
- **Current:** ~120 words in four blocks, Privacy link, agree / "Not now, sign out".
- **Problem:** reads like a contract; decline = sign out without explanation.
- **New:** one sentence ("We store your body and training data to build your plan. Only you can see it. Never sold, never for ads.") + expandable "What we store and why" (existing text, unchanged) + I agree. Secondary: "Not now" → explains the app can't build a plan without it, then sign out. **[owner/legal]** approve wording.
- **Removed:** nothing legally required (moved behind disclosure). **Promoted:** the one-sentence promise.
- **Type:** title1 + body. **Motion:** disclosure expand only.

### Onboarding (questions)
- **Current:** 7 steps, same layout each, CTA position moves, unlabelled level, skip on every step, unsaved.
- **Problem:** form feel; unused answers; no discipline or fight.
- **New hierarchy:** progress bar → question (title1) → input built for the question type → live **plan preview** that grows → `BottomActionBar` CTA (fixed position).
  - Disciplines: large multi-select tiles with discipline glyphs.
  - Fight booked?: two big choices; "Yes" expands date + weigh-in + limit inline.
  - Goal: four large single-choice rows, **auto-advance**.
  - Body: numeric fields with unit toggles (kg/lb, cm/ft-in); `Next` key chaining.
  - Formula + activity: two compact groups on one screen.
  - Training days: 7 weekday toggles + labelled experience chips; preview becomes a mini WeekStrip.
- **Removed:** eyebrow text, repeated "Skip detailed target" (kept only on Body as "Skip food targets — set later"), review step (merged into reveal).
- **Promoted:** preview → mini week. **Demoted:** progress text to the bar only.
- **Interaction:** answers saved per step; Android back = previous step; double-submit guarded.
- **Colour:** selection = muted crimson fill + crimson outline; CTA action crimson.
- **Motion/haptic:** `selection` on choices; preview rows appear with the stagger.

### Plan reveal
- **Current:** title, explanation, preview line, 4 numbers, two buttons, Pro block, disclaimer.
- **Problem:** a receipt; no week; upsell.
- **New hierarchy:** "Your first week" (largeTitle) → dated week rows assembling (Mon Striking · 6 rounds · 45 min …, rest days shown) → one-sentence why (from reason codes) → fuel line "2,240 kcal/day · 135 g protein" with "Why?" disclosure (maintenance, training energy, goal adjustment) → if fight: "Fight in 38 days · 81.2 → 77.0 kg · on a safe path" → CTA "Start today".
- **Removed:** Pro block, macro tiles grid, repeated title. **Promoted:** the week. **Demoted:** macros to one line.
- **Motion:** ~1 s assembly; `success` haptic once when it finishes.

### Home
- **Current:** date, name, goal, checklist, countdown, TODAY hero, Corner Brief card, verification, risk banner, dev message, stats card, add-fight row, this-week card, recent activity.
- **Problem:** no state machine; day-0 "Rest day" in display type; upsell weight; fight below fold.
- **New hierarchy:** Header (date; "38 DAYS TO FIGHT" when set) → notice slot (one at a time: sync failed / verify email / missed session) → **TodayCard** (states in the audit §11; includes Corner line; one CTA) → quick actions row (Weigh in · Log food, plain buttons) → **WeekStrip** + "3 / 5 this week" → add-fight row (only if none) → first-week checklist (while active, compact).
- **Removed:** name/goal block, stats card, recent activity, separate Corner Brief card, dev message prominence. **Promoted:** Today, fight, week. **Demoted:** checklist below the week.
- **Interaction:** the screen changes shape through the day (morning → done → day complete). Pull nothing; tap WeekStrip day → Train at that day.
- **Colour:** crimson only on the TodayCard CTA and today's strip day; gold only on Pro brief.
- **Type:** display only for a session title or countdown; rest day uses title1 "Recovery day".
- **Motion/haptic:** state cross-fades; strip fill on completion.

### Train
- **Current:** 4 sub-tabs; week = 5 identical cards; history list.
- **Problem:** no hierarchy; past days look open; timer unrelated.
- **New hierarchy:** sub-tabs **Week · Drills** (Reaction inside Drills; History as "Past weeks" link at the bottom of Week). Week: **TODAY** block (session title in title1/display, "6 rounds · ~45 min", Start) → **THIS WEEK** dated list (Mon ✓ Striking · RPE 8 / Tue ← TODAY / Wed Recovery / Sat Rest …) with past muted, missed showing "Move to today", future plain → "Free timer" row.
- **Removed:** card per session, play button per row. **Promoted:** today. **Demoted:** completed and future rows to plain rows.
- **Interaction:** row tap → session detail sheet (blocks, Start, Move, Skip). Long-press none.
- **Colour:** crimson only on Start; ✓ in success green; missed in `textMuted`.
- **Motion:** strip fill on return from session mode.

### Session mode (new)
- **Current:** generic Round Timer.
- **Problem:** no session context, silent auto-log.
- **New hierarchy:** title + round counter → current drill cue (title1) → timer (`heroNumeral`, phase colour crimson work / amber rest) → next → bottom controls (Pause/Resume large, Skip round small). Screen stays awake; minimal chrome; back asks to confirm.
- **Completion:** "Session complete" → 45 min · 6 rounds → "How hard was it?" (5–10 large buttons) → week strip fills → Done.
- **Removed:** style chips, Reset next to Start. **Haptic:** `commit` at phase changes (existing setting), `success` at completion.

### Drills
- **Current:** discipline picker card + search + 4 filters + path carousel + list, "0 of 17 drills sharp".
- **Problem:** five control groups before the first drill.
- **New:** discipline comes from onboarding (changeable in a header chip) → "Up next for you" (the next drill on your path) → search → list. Filters collapse into a single "Filter" sheet. Progress phrased forward: "Next: The Jab".
- **Removed:** discipline card on every visit, carousel above the fold. **Promoted:** next drill. **Interaction:** Reaction appears as a drill type with its own start.

### Fuel
- **Current:** header NUTRITION + "+", date switcher, segments, 442 px ring card (ring, macros, plan link, suggestions), meals, add button.
- **Problem:** add action below fold; card too big; name mismatch.
- **New hierarchy:** header "FUEL" + date switcher → **open hero**: "2,140 KCAL LEFT" (display) with slim ring, then Protein 92 g left · Carbs 185 g left · Fat 42 g left (compact rows, macro colours), day tag ("Hard day · carbs +60 g") → quick row (Repeat breakfast · Recent · Saved · Search · Recipes) → meals list (swipe delete + undo) → "Recipes that fit what's left" → week averages link. `BottomActionBar`: **LOG FOOD**.
- **Removed:** ring card box, segments (Meals/Recipes become rows/links). **Promoted:** remaining, log. **Demoted:** consumed totals.
- **Colour:** over-target uses danger pink-red, not crimson.
- **Motion/haptic:** counts animate down on log; `commit` on log.

### Weight
- **Current:** header +, three tabs (Weight / Body Fat / Measurements), current, 7-day avg, goal gap, chart, list.
- **Problem:** empty tabs; reached via Profile.
- **New:** reached from Home (Weigh in) and Fight. Header: trend weight (display), weekly rate, to-go. Chart: faint dots + trend line + goal/limit line. "Log weigh-in" in `BottomActionBar` (sheet with number pad). Body Fat / Measurements hidden until supported (**[owner]** decide).
- **Removed:** empty tabs, header "+". **Promoted:** trend + rate.

### Profile
- **Current:** identity, subscription, Tools (timer, weight, settings), stats, sign out.
- **New:** identity → subscription → Preferences (units, language, notifications) → Training setup (disciplines, days, level: re-generates plan with confirm) → Privacy → Account → Help (tour lives here) → Sign out.
- **Removed:** Tools, Stats. **Moved:** timer → Train; weight → Home/Fight; stats → Train/review.

### Paywall
- **Current:** title, 4 benefits card, plan tiles or coming-soon + waitlist, restore, legal.
- **New hierarchy:** title "Your full corner" → two-column **Free vs Pro** rows (Today's training ✓ ✓ · Fuel target ✓ ✓ · Weekly review numbers ✓ ✓ · Corner Brief — ✓ · Week review advice — ✓ · Full drills & recipes — ✓ · Adaptive targets (later) — ✓) → one real screenshot preview of the Corner Brief → plan tiles with trial line ("7 days free, then …") → CTA → restore · terms · privacy.
- **Removed:** benefits card, device-only waitlist (**[owner]**). **Triggers:** locked item tap, after the first weekly review, Corner Brief "see full". Not on reveal, max once a week from Home.
- **Colour:** gold on Pro column header and selected tile only.

### Weekly review (new)
- **Hierarchy:** "Week 3 review" → WeekStrip (full week) → four numbers (sessions 4/5 · protein days 5/7 · avg intake vs target · trend −0.6 kg vs −0.5 planned) → **decision** (hold / proposal) as `ProposalCard` with old → new and one-line why → Accept / Keep current → Pro: Corner Brief three lines. Free sees the deterministic proposal too.
- **Motion:** numbers count once; `success` on accept.

### Fight setup
- **Current:** one long form, Save 914 px down.
- **New:** sheet in two steps: (1) date + weigh-in timing; (2) limit + competition type + camp length (default 8 wk under "More"). Live result under step 2 ("81.2 → 77.0 kg · 4.2 kg in 6 weeks · on a safe path"), status from `WeightPathStatus`. `BottomActionBar`: Save fight.
- **Colour:** `notSafe` in danger, `needsSupervision` amber, on track green.

---

## D. Visual validation plan (per UI PR)

Capture at 390×844, 320×640, 430×932 and 200% text, plus high contrast:
offline web build for speed, Android emulator (`fe_api34`) for native
feel. Compare with `audit_screenshots_20261004/`. Checklist per screen:
hierarchy clearer? less noise? primary action obvious and reachable? alive
(state visible)? still unmistakably Fighter Edge? any generic AI-style
pattern reintroduced? key content above the fold? understandable in
2–3 s?

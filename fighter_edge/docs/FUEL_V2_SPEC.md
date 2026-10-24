# Fuel V2 spec (2026-10-22)

Fuel is the nutrition side of Fighter Edge. This spec turns four research
reports into build slices. The reports, with source links and [V]/[S]/[U]
verification tags, are in `nutrition_research_20261022/`:

| Report | Topic |
|---|---|
| `logging.md` | How top apps make food logging fast, and the free food data we may use |
| `targets.md` | How top apps estimate maintenance, set targets and run weekly check-ins |
| `combat.md` | Combat-sport nutrition, camp phases, weight cutting, safety limits |
| `retention.md` | Keeping users, "what should I eat" suggestions, tone, privacy, pricing |

It builds on `NUTRITION_COMPETITOR_RESEARCH.md` §10–14 (approved) and on the
code already merged: policy v2 (`nutrition_target_calculator_v2.dart`,
`session_energy_table.dart`, `weekly_check_in.dart`) and the weekly review.

## Who it is for

Amateur fighters (MMA, boxing, Muay Thai, BJJ, wrestling) at three levels.
The same engine serves all of them. The screen shows more as the level goes up.

| | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Daily screen | kcal and protein left | + carb tier for today | + per-session fuel, hydration and weight log |
| Targets | one number, "eat more on hard days" | training-day / rest-day split | per-session carbs, class what-if |
| Cutting tools | hidden by default, "choose a sustainable class" note | camp weight path with trend | walk-around vs class gap, regain tracker, coach handoff note |

## Rules that never change

1. Deterministic math is authoritative. No AI touches a nutrient number.
2. Targets change only when the user taps Apply. The app recommends only.
3. The app never gives advice on fluid or sodium restriction, water loading,
   sauna, sweat suits, diuretics, laxatives or fasting. No flag, tier or
   subscription unlocks it.
4. Under-18 or unknown age gets no targets and no cut tools.
5. Cut tools show a "talk to a professional" card for: clinical flags, eating
   disorder signals, fainting or dark urine, repeated cuts, and a cut that is
   more than 2% over the limit within about 3 days.
6. Tone is neutral. No red numbers, no "over" warnings, no good/bad food
   labels, no food-logging streaks, no cheat/earn words. A missed day is a
   missed day, nothing more.
7. Meal logs and measurements stay on the device unless the user opts in to
   backup. No health data in iCloud or in analytics events.
8. Anything with weight-cut numbers, carb tiers, refuel volumes, energy
   formulas or screening text is marked "dietitian sign-off pending" in code
   and stays behind a flag until a sports dietitian reviews it.

## Decisions made here (owner can overturn)

| Topic | Decision | Why |
|---|---|---|
| Teen amateurs (14–17) | Stay adults-only for targets. | The evidence says discourage weight making for minors. A junior mode needs a dietitian first. |
| Weight-loss rate outside camp | Cap at 0.75% of body weight per week. | Athlete evidence favours 0.5–0.75%. Policy v2 offers 1.0%. |
| Fight-week day-by-day template | Built, information only, behind a flag, off until sign-off. | Camp-safety doc already says keep prescriptive fight-week guidance out of public release. |
| Photo logging | Not at launch. | The one study found about 30 g fat under-read per meal. |
| Barcode (Open Food Facts) | Later, as a separate attributed layer. | ODbL share-alike needs a licence check first. |
| Food data | USDA FoodData Central (CC0) plus our own foods with a source field. | Safe to bundle, works offline. |

## Build slices

Each slice is one or more PRs. Domain code stays pure Dart in
`lib/features/edge_fuel/domain/`.

### N1 — Targets that adapt (pure domain, then wiring)

From `targets.md`. Data tiers: Tier 0 under 14 days is formula only. Tier 1
(5 of 7 days logged and 3 weigh-ins a week, two weeks running) may propose a
change. Tier 2 (21 days, 6 of 7 logged) may use observed expenditure.

- 21-day slope of weight with a noise band from the residuals and an outlier
  rule. Weigh-in condition tags (morning, fasted, after training).
- Weekly decision: `error = observed - planned` (kg/week);
  `correction = -1100 * error` kcal/day; step = clamp(0.5 * |correction|,
  100, 200); one change a week; never below the floors.
- Complete / partial logging flag per day. Partial days do not count as data.
- Safety escalation inside the check-in: chronically low intake or very fast
  loss shows the referral card, not a bigger cut.
- Energy-availability floor for training athletes (placeholder: resting
  energy + 0.5 * session energy), because "floor = resting energy" does not
  protect someone training five times a week.
- Plateau and deficit-duration rules (optional maintenance week, no
  metabolic claims). Re-ask the safety questions every 8 weeks.
- Wire the recommend-only Apply / Keep / Not now flow with a target history,
  so the weekly review and the check-in are one thing.

### N2 — Daily screen and fast logging (needs glass chrome #62)

From `logging.md`. Remaining kcal and protein first, macros second, micros
hidden. A remembered consumed/remaining toggle.

- One-tap add from recents and "usual at this time", with the last serving
  remembered. Copy yesterday, copy meal, save meal as template.
- Quick Add for calories and protein, plus "about X" meal-size presets.
- Grams-first serving entry. Per-entry source tag (weighed / label /
  estimate). Estimates show a range.
- "On plan, did not log" mode for a day, marked approximate.
- First log in under 60 seconds, pre-filled from the gap picker. Two logged
  meals in a day counts as success.
- Swipe to delete with undo.

### N3 — Day-type fuel and the gap picker (pure domain first)

From `retention.md` and `combat.md`.

- Day types (rest, easy, hard, double, fight week) as a pure function of the
  dated training plan. Carb tiers by load (ISSN/ACSM ranges, pending sign-off)
  plus protein and fat floors.
- Gap picker: "Protein left: 34 g, 3 options". A macro-first mode in
  `FuelMatchCalculator` (today it is calorie-first), about 40 curated add-ons,
  a split suggestion above 0.4 g/kg per meal, one-line reasons.
- Pre- and post-session fuel hints tied to the session in the plan.
- Meal-prep and grocery list: merge ingredients by food id, "cook x4"
  multiplier, works offline.
- Review the 24 draft recipes (all `status: "draft"`) before any is shown
  as published. Grow to about 60 recipes.

### N4 — Fighter safety and camp layer

From `combat.md`.

- Safety screen and referral card on every cut entry (rule 5).
- Validator denylist for rule 3. It also guards any future AI text.
- Camp-length warning: total loss above 12–15% of walk-around weight, or a
  cut in under 8 weeks, shows a caution.
- Hydration and weight log with no cut targets. Sweat-rate and regain tracker.
- Refuel timeline domain (volumes behind a flag, sign-off pending).
- Fight-week information template D-7 to fight day and post-fight, gated to
  adults who are on track or at weight (rule 8).
- Supplement and anti-doping education card. Education only, no doses.
- Eating-disorder and tone layer: "Hide numbers" and "Pause nutrition" modes,
  a copy lint that fails the build on banned words. Status: Pause nutrition is
  built (see `NOTIFICATIONS_PLAN.md`, "Nutrition display modes"); Hide numbers
  is not; the copy lint exists.

### N5 — Level-aware Fuel UI and onboarding questions

The matrix above. The user's level (already asked in onboarding) decides what
Fuel shows. Beginner never sees cut tools unless they turn them on.

### N6 — Privacy and notifications

- Audit what `firestore_edge_fuel_repository.dart` writes (the setup draft)
  and move meal logs and measurements to local-first with opt-in backup.
- Scrub analytics events of anything health-like.
- A consumer-health-data privacy section and a separate consent for backup.
- Four opt-in local notification channels (training, meal gap, weigh-in,
  weekly review), asked after the first session, at most one a day, quiet
  hours. No first-launch permission prompt.

### N7 — Later

Barcode via Open Food Facts, voice or text "describe" logging that maps only
to our own bundled foods, optional junior mode (needs a dietitian), adaptive
expenditure beyond Tier 2.

## Corrections to older docs

- The Duolingo "freeze cut churn 21%" claim is unverified. Duolingo's own
  post reports +0.38% relative daily actives.
- RevenueCat 2026: Health & Fitness trial-to-paid median is 37.7%, not 39.9%.
- The 73% Levinson figure is the share of MyFitnessPal users inside an
  eating-disorder sample who felt it contributed. It is correlational.

## Sign-off needed from a sports dietitian

All numbers in `WeightCutPolicy`, the carb tiers and floors, refuel volumes,
the energy table, the 12–15% and 8-week thresholds, the energy-availability
floor, screening and referral wording, supplement text, and any junior mode.

## Open questions in the research

Barcode licence review (ODbL), primary retention benchmarks, current
competitor prices for four apps, MacroFactor's exact trial and filter,
whether Apple's iCloud rule covers device backups, and the ISSN sodium unit
typo (mmol/dL) that must be checked against the source before any sodium
number is shown.

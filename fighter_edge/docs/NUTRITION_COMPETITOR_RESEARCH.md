# Nutrition competitor research (2026-10-04)

Research pass before any change to the Fuel model, as the owner required.
Read with `PRODUCT_AUDIT_20261004.md` (§13, §15) and the existing engine in
`lib/features/edge_fuel/domain/`.

**Method and honesty rules.** Public help-centre pages, product posts and
reviews, read 2026-10-04 (links at the end). No competitor app was
installed or logged into. Where an algorithm is proprietary, what is written
here is **inferred** from public descriptions and marked so. Formulas and
safety limits are taken from position stands and reviews, not from
competitor marketing. We borrow principles, never layouts, artwork, colours,
copy or animations.

---

## 1. Competitors reviewed

| App | Type | Why it matters |
|---|---|---|
| **MacroFactor** | Adaptive macro coach | Best-in-class adaptive expenditure, trend weight, fastest logging |
| **Carbon Diet Coach** | Adaptive coach (Layne Norton) | Weekly check-in with adherence questions |
| **RP Diet Coach** | Meal-plan coach (Renaissance Periodization) | Training-day vs rest-day eating, diet phases |
| **MyFitnessPal** | Mass-market tracker | The default mental model: goal − food + exercise = remaining |
| **Lose It!** | Mass-market tracker | Simple weekly-rate slider, "budget" language |
| **Cronometer** | Nutrient-precise tracker | Explicit BMR + activity + exercise model, user-editable |
| **YAZIO** / **Lifesum** | European design-led trackers | Long, persuasive onboarding; diet "plans" |
| **Noom** | Behaviour-change programme | Calorie floors, food colour system, coaching |
| **CutCoach** (and FightCamp, Runna, Libra for patterns) | Combat-sport cut / plan-to-event | Studied in `FIGHT_CAMP_PATTERN_BRIEF.md` (09-26) |

## 2. Onboarding approaches

| App | Asks | Notable |
|---|---|---|
| MyFitnessPal | Age, height, weight, sex, daily activity, goal weight, weekly rate | Exercise is logged separately and added back ("net calories") |
| Lose It! | Weight, height, age, gender, goal weight, weekly rate slider (0.5–2 lb/wk) | The slider shows the daily budget change live |
| Cronometer | Sex, age, height, weight, activity; BMR formula and TEF editable later | Exposes every assumption in settings, not in onboarding |
| MacroFactor | Body metrics, goal (lose/maintain/gain), target weight, rate; diet preferences for macros | Initial number is called a **starting estimate**; the app says it will learn |
| Carbon | Body metrics, goal, experience with tracking | Sets expectation of weekly check-ins from day one |
| YAZIO | Very long flow (a design showcase counts ~78 steps) | Builds a feeling of personalisation; reviewers find it slow |
| Lifesum | Goals, preferences, diet-style interests → curated plan | Praised for feeling welcoming; slower |
| Noom | Long psychological questionnaire | Behavioural framing more than nutrition precision |

**Pattern:** the precise apps ask few body questions and are honest that
the first target is a starting estimate. The long flows (YAZIO, Noom) use
length to sell, not to compute.

## 3. Calorie and goal logic (public or inferred)

| App | Expenditure | Goal adjustment | Known limits |
|---|---|---|---|
| MyFitnessPal | Formula from age/height/weight/sex + activity (inferred Mifflin-type) | Fixed deficit per weekly rate (e.g. 0.5 lb/wk) | Floors widely reported (~1,200 women / 1,500 men); **not verified** in official docs |
| Lose It! | BMR from weight/height/age/gender | Weekly rate 0.5–2 lb/wk → daily budget | — |
| Cronometer | **Mifflin-St Jeor** + baseline activity; logged exercise replaces baseline time, avoiding double counting | Custom target | User-editable |
| MacroFactor | **Inferred from intake vs weight trend** (≈3 weeks of data window); starts from a formula estimate | Target weight + chosen rate; "dynamic maintenance" for holding weight | Pauses ("holding") when weight data is missing |
| Carbon | Rolling average weights vs logged intake (inferred) | Hold / raise / lower each week | **Holds targets when logging was partial** |
| RP Diet | Not public | Weekly adjustments; distinct training-day and rest-day meals | — |
| Noom | Formula (not public) | Weight-loss budget | Floors 1,320 kcal (women) / 1,540 kcal (men), raised 10% from 1,200/1,400 |

## 4. Adaptive systems

```text
MacroFactor:  log food (≥6/7 days) + weigh (≥1/week, daily preferred)
              → trend weight (recency-weighted moving average)
              → expenditure = intake − energy implied by trend change (≈3-week window)
              → weekly check-in proposes new macros → user accepts / edits / declines
Carbon:       weekly check-in: "how did you track?" + weight (+ optional BF%)
              → full tracking: adjust from metabolic response
              → partial tracking: HOLD targets (bad data must not drive change)
              → not tracked but compliant: judge on weight change alone
              → report with intake, compliance, adjustment
RP:           weekly weight + adherence → meal amounts up/down; weekly averages over daily perfection
```

Shared mechanics: weekly cadence, trend not single weigh-ins, adherence
checked before blaming metabolism, small steps, a report that explains the
change, and (MacroFactor) **the user accepts or declines**.

## 5. Strong UX patterns

1. **"Remaining" is the hero.** MyFitnessPal's "Goal − Food + Exercise =
   Remaining" made remaining the default question. Every strong app leads
   with what's left.
2. **Logging starts before typing.** MacroFactor shows hourly go-tos,
   favourites and latest foods before the search box is used, and leads
   independent speed tests.
3. **Copy, paste, repeat.** Copy a meal or a day; move foods between times.
4. **Trend over scale.** Faint daily dots, strong trend line, weekly rate.
5. **The first target is labelled an estimate** and the app promises to
   learn (MacroFactor, Carbon).
6. **Check-ins ask about adherence first** (Carbon) and hold when data is
   bad.
7. **Proposals, not silent changes** (MacroFactor check-in can be declined).
8. **Weekly averages over daily perfection** (RP): a big day can be
   balanced by lighter days.
9. **Live consequence while choosing a rate** (Lose It! slider).
10. **Every assumption editable later**, not all asked up front (Cronometer).

## 6. Weak UX patterns

1. 40–80-step onboarding to create a sense of value (YAZIO, Noom).
2. Eating back estimated exercise calories (MyFitnessPal "net"): wearable
   and formula burn estimates are noisy; users over-eat.
3. Fixed calorie floors by sex only, with no link to body size or sport.
4. Daily red/green judgement of single days.
5. Diet "plans" by brand (keto, 5:2) that change macros without a reason
   tied to the goal.
6. Paywalls during onboarding before any target is shown.
7. Food colour/"bad food" labelling, which athletes in weight-class sports
   don't need and which can feed disordered eating.

## 7. Shared winning formula (across the best products)

> **Few inputs → honest starting estimate → effortless logging → trend
> weight → weekly check-in that checks adherence → small, explained,
> accept-or-decline adjustment.**

The winners differ in *how* they estimate expenditure, not in this loop.

## 8. Patterns Fighter Edge should NOT copy

- Net-calorie eat-back of exercise burn estimates.
- Long persuasion onboarding.
- Food colour labels or "good/bad food" language.
- Brand diets (keto, 5:2) as plan types.
- Any water-loading, sauna or fluid-restriction protocol (CutCoach shows
  these). Our product line stays: **food-only, flagged when supervision is
  needed** (`WeightCutPolicy`, validator).
- Silent automatic target changes (owner rule).
- Daily streaks for logging.

## 9. What Fighter Edge already does better

- **Deterministic, versioned engine** with a safety gate before any number
  (`NutritionTargetCalculator`, `NutritionSafetyPolicy`), confidence labels,
  and "needs more data" as a real state.
- **Never below resting energy**; a **carbohydrate performance floor**
  (3 g/kg) under heavy activity that reduces the deficit instead of hiding
  the conflict.
- **Fight-camp weight path** with ISSN 24/48/72 h limits and
  `needsSupervision` / `notSafe` states.
- **Adult-only** automated targets; neutral "prefer not to say" formula path
  with a wider range.
- **AI only explains** facts the app calculated, with validation.

## 10. Recommended Fighter Edge nutrition model

Keep the engine; change four things.

### 10.1 Training-aware expenditure (biggest gap today)

Today: `maintenance = RMR × daily-activity coefficient (1.20–1.90)`. Training
days are asked in onboarding but **never reach the calculator**, so five
sessions a week and zero sessions give the same target.

Proposal (deterministic, documented):

```text
RMR            = Mifflin-St Jeor (unchanged; sex path or neutral midpoint)
Base           = RMR × non-training activity factor (1.20–1.55, the "outside the gym" answer)
Session energy = Σ planned sessions this week × MET(kind, intensity) × weight kg × hours
                 (curated table per session kind, conservative; from the planned week,
                  not from a wearable)
Daily average  = Base + Session energy / 7
```

- Planned sessions come from the new training plan domain, so Fuel and
  Train share one source of truth.
- Conservative METs and a 10% maintenance range stay; confidence stays low
  for the neutral path.
- Logged *extra* sessions do **not** add eat-back calories in v1 (pattern 8.1).
  They feed the weekly check-in instead.

### 10.2 Rate as % of body weight per week, not % of maintenance

Today's deficit is 10/15/20% of maintenance. Competitors and the literature
speak in rate of change. Proposal:

| Goal | Options (per week) | Default | Source |
|---|---|---|---|
| Lose fat | 0.25% · 0.5% · 0.75% · 1.0% of body weight | 0.5% | Helms 2014: 0.5–1%/wk to keep lean mass; ISSN 2025: 0.5–1 kg/wk in camp |
| Fight camp (with fight) | Derived from the weight path; capped at 1%/wk and 1 kg/wk | From path | ISSN 2025 pos. 5 |
| Maintain | 0 | — | — |
| Gain | 0.1% · 0.25% · 0.5% of body weight | 0.25% | Inferred consensus for lean gain; **owner/expert review** |

Deficit kcal/day = rate × weight × ~7,700 kcal/kg ÷ 7 (labelled an
approximation; the weekly check-in corrects it from real data).

### 10.3 Training-day and rest-day split (optional, default on)

Same **weekly** total, shifted: carbohydrate up on planned hard days,
down on rest days; protein constant; fat roughly constant. Bounded by
ACSM carbohydrate bands and the existing 3 g/kg floor during weight
descent (ISSN 2025 pos. 6). Weekly totals are what the check-in judges
(pattern 5.8).

### 10.4 Macro rules (mostly unchanged)

| Macro | Rule | Source |
|---|---|---|
| Protein | 1.6–2.2 g/kg (use 2.0 g/kg target weight when losing, 1.8 maintaining/gaining), floor 1.2 | ISSN 2025 practical 1.6–2.2; ACSM 1.2–2.0 |
| Carbohydrate | Remainder, never below 3 g/kg in descent; higher on hard days | ISSN 2025 pos. 6; ACSM 2016 bands |
| Fat | 25–30% energy, never below 0.5 g/kg | ISSN 2025 pos. 6 |

### 10.5 Adaptive expenditure (v2, after the weekly loop exists)

After ≥3 weeks with ≥6 of 7 days logged and ≥3 weigh-ins a week:
`observed expenditure = average intake − (trend change kg × 7,700 / days)`,
blended with the formula estimate (weight on observed grows with data
quality). Only ever **proposed** at check-in.

## 11. Recommended onboarding questions

| Question | Changes | Keep? |
|---|---|---|
| Disciplines | Plan + session energy | **Add** |
| Fight booked? (date, weigh-in, limit) | Weight path, rate, camp phases | **Add, optional** |
| Goal (make weight / lose fat / hold / gain) | Rate and macros | Merge camp + nutrition goal |
| Age, height, weight (kg/lb, cm/ft-in) | RMR | Keep; add units |
| Formula (male / female / prefer not to say) | RMR | Keep |
| Day-to-day activity outside training | Base factor | Keep (5 → 4 levels; "very high" folds into high since training is now counted) |
| Training weekdays + experience | Plan; session energy | Keep, labelled |
| Rate | Deficit/surplus | **Ask only when goal ≠ hold, with a live preview** ("≈0.4 kg/week → 2,240 kcal") |
| Diet preferences, allergies | Recipes and suggestions | Ask **later** in Fuel, not onboarding |
| Target weight | Milestone | Optional; default from rate × 8 weeks |
| Meals per day | Nothing user-visible yet | Remove from onboarding |

## 12. Recommended daily Fuel experience

Above the fold:
1. **Kcal left** (large Oswald numeral) with a slim ring or bar, not a
   442 px card.
2. **Protein left** (the one macro fighters most often miss), carbs and fat
   left as compact rows. Today's training tag ("Hard day: carbs +60 g").
3. **LOG FOOD** primary button pinned within thumb reach.
4. Quick row: Repeat breakfast · Recent · Saved meals · Search · Recipes.

Below: today's meals as rows (swipe to delete with undo), "Recipes that
fit what's left", week averages link. Day navigation stays.

## 13. Recommended weekly check-in / adaptation loop

```text
Sunday (or the user's chosen day)
 1. Adherence: "How did you log this week?" (all / most / some / none)
 2. Data: days logged, avg intake vs target, trend weight change vs planned rate,
    sessions done vs planned, protein days hit
 3. Decide (deterministic):
      some/none logged or <3 weigh-ins        → HOLD, explain why
      on pace (±25% of planned rate)          → HOLD
      slower than planned & adherent          → propose −100…−150 kcal/day
      faster than planned (loss > planned+50%) → propose +100…+150 kcal/day
      gain goal: mirror rules
    Bounds: never below RMR, never below macro floors, max one step per week,
    fight-camp path limits always win.
 4. Show a proposal card: old → new, one sentence why, Accept / Keep current
 5. Accepted → new NutritionTarget version (policyVersion + history kept)
```

Free: numbers, the decision and the proposal. Pro: the Corner Brief
explains it in three lines and suggests training/food tweaks (AI explains,
never computes).

## 14. Safety constraints (non-negotiable)

- Adults only for automated targets and cuts (existing).
- Never below RMR (existing); never below ISSN 2025 macro floors during
  descent (carbs 3 g/kg, protein 1.2 g/kg, fat 0.5 g/kg).
- Loss rate capped at 1% body weight/week (and 1 kg/week) outside fight
  week.
- Fight-week acute loss limited to ISSN 4.4% / 5.7% / 6.7% at 24/48/72 h,
  food-only guidance in-app; anything beyond is `needsSupervision`.
- **No** fluid restriction, sauna, water loading or diuretic guidance.
- Low-energy-availability caution: the IOC 2023 REDs consensus treats
  <30 kcal/kg FFM/day as a risk indicator, not a hard threshold; where body
  fat is known, warn below it; never present it as a target.
- No single weigh-in or single day drives a change.
- Clear separation in UI and copy: **fat loss (weeks)** vs **making weight
  (fight week)**.

## 15. Free vs Pro boundaries

| Free | Pro |
|---|---|
| Target, training-aware; daily logging; repeat/recent/saved; weight trend | Corner Brief explaining today and the week |
| Weekly check-in numbers and the deterministic proposal | Adaptive expenditure (v2) and multi-week trend insights |
| Fight countdown and weight path status | Full fight-camp phase guidance and fight-week food plan |
| Starter recipes | Full recipe library, allergen-checked scaling |

Safety information is never Pro-only.

## 16. Implementation implications

- `NutritionPolicy.version` → 2; targets store which version made them.
- New pure inputs to the calculator: planned week (from training plan
  domain), rate per week, day kind (hard/light/rest).
- New pure modules: `session_energy.dart` (curated MET table),
  `weekly_checkin.dart` (decision table §13), `trend_weight.dart` (EMA).
- Migration: existing profiles keep v1 targets until the user reviews a
  proposal (no silent change).
- Tests: table tests per profile × goal × week; property tests for floors.
- **Owner/expert review** of the MET table and gain rates before release.

## 17. UI patterns worth adapting (principle, not copy)

- Remaining-first hero (MyFitnessPal/MacroFactor principle).
- Pre-typed suggestions in the log sheet (MacroFactor principle).
- Proposal card with old → new and Accept / Keep (MacroFactor/Carbon
  principle).
- Weight trend: faint dots + strong line + weekly rate text (Libra/
  MacroFactor principle; already in the fight-camp brief).

## 18. Layout patterns worth adapting

- One large number + 2–3 compact rows above the fold; detail below.
- Bottom-anchored primary log action.
- Weekly report as one scrolling page: summary numbers → decision →
  details.

## 19. Colour and data-visualisation patterns

- One colour per macro, used consistently, always with a label (existing
  protein/carbs/fat tokens).
- Remaining shown in neutral white; over-target in the danger role, not the
  brand crimson (see the colour roles in `UI_REDESIGN_SPEC.md`).
- Trend lines solid, raw data faint; goal lines flat and labelled.
- No red/green day judgement; green only for "on pace" or "hit".

## 20. Interaction patterns worth adapting

- Repeat yesterday's meal / copy meal in one tap.
- Swipe to delete with undo.
- Rate slider that shows the consequence live.
- Check-in that can be declined, and holds on bad data.

---

## THE FIGHTER EDGE WINNING FORMULA

```text
Goal (+ optional fight)
 → bounded starting target, built from your body AND your planned training week
 → your personal week (sessions on the days you chose)
 → logging in seconds (repeat, recent, saved)
 → fuel that shifts toward hard days, same weekly total
 → trend weight, not daily noise
 → Sunday review: what you did, how your body responded
 → one explained recommendation
 → you accept it (or keep your plan)
 → next week adapts; fight-camp safety limits always win
```

In one line: **a normal, evidence-based nutrition coach that knows your
training week and your fight, and never cuts unsafely.**

---

## Sources (read 2026-10-04)

Science and position stands:
- [ISSN position stand: nutrition and weight cut strategies for MMA and combat sports (Ricci et al., 2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11894756/)
- [Helms, Aragon, Fitschen 2014: evidence-based recommendations for natural bodybuilding contest preparation](https://pmc.ncbi.nlm.nih.gov/articles/PMC4033492/)
- [ACSM/AND/DC Joint Position Statement: Nutrition and Athletic Performance (2016)](https://pubmed.ncbi.nlm.nih.gov/26891166/)
- [Frankenfield et al. 2005: comparison of predictive equations for RMR](https://www.jandonline.org/article/S0002-8223(05)00149-5/abstract)
- [IOC 2023 consensus statement on REDs](https://stillmed.olympics.com/media/Documents/Athletes/Medical-Scientific/Consensus-Statements/REDs/BJSM-IOC-consensus-statement-on-Relative-Energy-Deficiency-in-Sport-REDs.pdf)

Competitors:
- [MacroFactor: weight trend](https://help.macrofactorapp.com/en/articles/21-weight-trend)
- [MacroFactor: weight logging frequency and expenditure](https://help.macrofactorapp.com/en/articles/109-how-frequently-do-i-need-to-log-my-weight-for-the-expenditure-algorithm-and-weekly-coaching-updates)
- [MacroFactor: goal features](https://macrofactor.com/goal-features/)
- [MacroFactor: check-ins and coaching modules](https://help.macrofactorapp.com/en/articles/247-introduction-to-check-ins-and-coaching-modules)
- [MacroFactor: fastest food logger (FLSI update)](https://macrofactorapp.com/best-food-logging-app/)
- [MacroFactor: timeline-based food log](https://macrofactor.com/timeline-based-food-logger/)
- [Carbon: weekly check-in](https://help.joincarbon.com/en/articles/6004812-weekly-check-in-in-carbon-how-it-works-and-what-to-expect)
- [RP Diet Coach app](https://rpstrength.com/pages/diet-coach-app)
- [MyFitnessPal: how initial goals are calculated](https://support.myfitnesspal.com/hc/en-us/articles/360032625391-How-does-MyFitnessPal-calculate-my-initial-goals)
- [Lose It!: personalised plan tutorial](https://loseit.zendesk.com/hc/en-us/p/tutorial)
- [Cronometer: energy summary](https://support.cronometer.com/hc/en-us/articles/360060616191-Energy-Summary)
- [Cronometer: target, energy and weight settings](https://cronometer.com/blog/sp-2/)
- [YAZIO vs Lifesum comparison](https://calorierankings.com/compare/yazio-vs-lifesum/)
- [YAZIO onboarding showcase](https://screensdesign.com/showcase/yazio-calorie-counter-diet)
- [Noom review (calorie floors)](https://health.usnews.com/best-diet/noom-diet)
- Combat-sport and plan-to-event apps: `FIGHT_CAMP_PATTERN_BRIEF.md` (Google Play screenshots, 2026-09-26)

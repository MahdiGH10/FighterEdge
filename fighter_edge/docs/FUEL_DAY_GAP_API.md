# Fuel day and gap domain contract

These APIs are prerequisites for the N3 screen wiring. They do not write a
target or a meal, enable a pending flag, or change the screen.

## Accepted daily targets

Use `TrainingPlanFuelBridge.planWeek` to obtain the dated day classifications,
then pass those seven consecutive days and the accepted `NutritionTarget` to
`AcceptedFuelWeekAllocator.allocate`.

- The accepted calorie average is the budget. Maintenance and goal rates are
  not recalculated. No proposed target is accepted on the user's behalf.
- The allocation preserves seven times the accepted calories and carbohydrate
  grams exactly. Protein and fat stay at the accepted values each day.
- The existing V2 shift/rounding algorithm is shared. RMR and the existing
  macro floors constrain the split. An exact flat accepted week is the only
  fallback; an incompatible target is refused rather than raised.
- Unknown or minor age produces `adultRequired` with no amounts. Missing or
  malformed inputs produce `needsMoreData`.
- `amountsEnabled` defaults to the existing **off** policy flag. While pending,
  the result is `awaitingSignOff` with no day targets. An accepted stored
  target does not count as sign-off for a different day-type policy.
- A week intersecting fight week produces `fightWeek` with no day targets.
  This allocator does not redistribute intake for fight week. The UI may
  still show the classification and the appropriate existing accepted-target
  view; it must not label that view as a newly calculated fight-week target.

## Suggestions

Presentation code uses `FuelMatchCalculator.dayGap`, with the confirmed age,
accepted target, selected day's log, catalog foods and existing preferences.
Pass `allocatedDay` when an enabled daily allocation is available so the
picker uses the same numbers as the display. A log from another date is
refused. The accepted target is never reconstructed or saved.

`reviewedAmountsEnabled` defaults to **false**, derived from the existing
day-policy and catalog sign-off flags. It covers the unreviewed portions and
protein-dose assumptions. It must be a recorded reviewed-build decision,
never a user or billing switch. Tests may explicitly enable reviewed fixtures.

The result contains a protein gap first, or a typed kcal-only gap once the
useful protein gap is closed. Kcal reasons use `addsKcal`/`leavesKcal`; gram
reasons remain separate. Both retain the existing calorie cap, preference
filters, maximum three options and food-group diversity. The raw picker
methods are lower-level calculations without eligibility checks.

Day labels and qualitative hints remain available through `FuelDayPlanner`.
Pending timing/amount fields must stay hidden. Logging the chosen item later
must use the existing `requireWrite` gate and food logging path; viewing a
suggestion never grants write access.

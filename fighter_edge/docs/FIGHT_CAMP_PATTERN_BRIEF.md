# Fight camp screens: pattern brief (2026-09-26)

Design research for plan step 6 (fight date, camp phases, weight path, fight
week), done before any UI is built. Read with `.claude/skills/fighter-edge-ui`
(tokens, motion, accessibility) and the domain in
`lib/features/fight_camp/domain` (what the screens can actually show).

**Sources.** Public Google Play screenshots of six apps, viewed 2026-09-26 for
internal research only. They are marketing images (idealised data, no error
states) and are not stored in the repo. We borrow structure, never visuals.

| App | Why it is relevant | What was studied |
|---|---|---|
| CutCoach | Direct competitor: combat-sport weight cuts | Fight-week home, day strip, refuel protocol, event header |
| Runna (Strava) | A plan built backwards from an event date | Plan header with week progress, training calendar |
| MacroFactor | Best-in-class weight trend | Scale vs trend chart, average and difference header |
| Libra | Trend-weight tracker | Trend through noisy weigh-ins, goal line, weekly rate |
| Lose It! | Mainstream goal tracking | Goal header, weekly rate, milestone tiles |
| FightCamp | Combat-sport brand | Program cards, weekly stats, streak |

## Patterns that repeat

1. **The event anchors everything.** Runna's home card is the race: name,
   date, "Weeks completed 2/19" on a segmented bar, one number beside it.
   CutCoach's plan header is the event name over three numbers: starting,
   target, to cut.
2. **Three numbers, then detail.** CutCoach (start / target / to cut), Lose
   It! (low, change, weekly rate, milestone) and Runna (weeks, distance) all
   lead with a row of 2–4 labelled numbers before any chart.
3. **Fight week is day-numbered.** CutCoach titles the screen "Fight Week,
   Day 25/30" over a Mon–Sun strip: past days ticked, today bold. Each day
   carries its phase ("Day before: Refuelling protocol, 24 h to
   competition").
4. **Trend over scale.** MacroFactor draws scale weight as a faint line and
   trend weight as the strong one, headed by "Average 153.5" and "Difference
   −1.6", with 1W / 1M / 3M / All chips. Libra draws the trend through noisy
   dots with a flat goal line and states "0.2 kg/week" underneath. Both teach
   that one weigh-in is noise.
5. **The plan is a calendar of weeks.** Runna shows each week as a block
   ("WEEK 2", total, one row per day with a colour stripe by session type
   and a tick when done). Our Train > Week already works this way; camp adds
   the week number and phase.
6. **Protocols are cards of targets with timing.** CutCoach's refuel day is
   a list of target cards, each with a value and a timing chip ("1 L/hr",
   "Throughout day").

## What we deliberately do not copy

- **Water manipulation.** CutCoach shows "Water Loading" and fluid and sodium
  targets for the cut itself. Our policy (`WeightCutPolicy`, system prompt,
  validator) plans food-only fight-week loss and flags anything more as
  `needsSupervision`. This is the product's safety line and a selling point:
  say so plainly, never hide it.
- Leaderboards, community feeds and XP (CutCoach, FightCamp): not in scope.
- Light, pastel surfaces: we stay dark crimson/black per the design contract.
- Marketing density: store images pack every feature into one frame. Our
  screens keep one primary action each.

## The four screens

Each maps to domain output that already exists; nothing here needs a number
the calculator does not produce.

### A. Fight setup (one sheet, one primary action)

Fields: fight date; weigh-in (same day / day before / two days before);
weight limit in the user's unit; competition type in plain words
(Grappling and wrestling / Amateur boxing or Muay Thai / Olympic combat
sports / Professional); camp length (default 8 weeks, under "More").
Show the result **live under the form** before saving, using pattern 2:
current trend, limit, to go. Then one status line from `WeightPathStatus`.
Primary action "Save fight". `FightCamp.tryCreate` returning null is a field
error, not a snackbar.

### B. Countdown on the dashboard (pattern 1)

When a fight exists, the dashboard hero leads with it: micro label "Fight
night · Sat 12 Dec", `heroNumeral` days to go, a segmented bar of camp weeks
(done weeks filled), phase chip ("Camp · week 3 of 8"). In fight week the
number becomes "Day 5 of 7". Today's session stays directly below as the
one action. The day count is a fact, so it never counts up or bounces
(motion rule 4).

### C. Weight path (patterns 2 and 4)

Header: trend weight, limit, to go, weekly pace (`weeklyLossKg`). Chart:
weigh-ins as faint dots, 7-day trend as the solid line, the planned path as a
dashed line to `fightWeekEntryKg`, the limit as a flat line. Range chips
only once there is more than a month of data. Status card below, by
`WeightPathStatus`:

| Status | Tone | Says |
|---|---|---|
| `onTrack` | positive | "On pace: 0.5 kg a week to 75.0 kg by fight week." |
| `needsSupervision` | warning | Planned at the safe maximum; the rest needs a coach or dietitian; lightest safe limit. |
| `notSafe` | negative | Beyond safe limits for this date; lightest safe limit; heavier class or later fight. |
| `atWeight` | positive | At weight: hold steady. |
| `needsMoreData` | neutral | "Log a weigh-in" as the action (no fake chart). |
| `notSupported` | neutral | Weight cut plans are for adults; point to a coach. |

The chart needs a text alternative for screen readers (the header numbers
and status already are one).

### D. Fight week (patterns 3 and 6)

Title "Fight week", day strip from fight-week start to fight day with ticks,
today bold, weigh-in and fight days marked. One card per day from the policy:
food-only steps (lower fibre, carbohydrate reduction), never fluid
restriction. After the weigh-in: a refuel card of targets with timing chips
(pattern 6). **Needs domain work first:** refuel targets and the daily
fight-week steps are not in `lib/features/fight_camp/domain` yet; they must
come from the same ISSN source (points 9 and 12–14) with tests, like the
weight path.

## Build order

1. Persist a fight (Firestore `users/{uid}/fight`, rules, repository) and the
   setup sheet (A).
2. Dashboard countdown (B).
3. Weight path screen (C), replacing or extending the weight tracker's
   chart.
4. Fight-week domain additions, then fight week (D).
5. Send `DailySnapshot.toJson()` to the AI once A–C exist.

Each is one slice with widget tests at 320 px and 200% text, per the
contract.

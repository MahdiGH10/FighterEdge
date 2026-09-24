# Product plan: one daily loop and an AI coach worth paying for

Approved by the owner on 2026-09-24. The readable version is the "Fighter
Edge Game Plan" page shared in the session; this file is the record for
future sessions. It builds on `PRODUCT_MONETIZATION_STRATEGY.md` and
`UX_RETENTION_RESEARCH_20260923.md`.

## Why the app doesn't feel connected yet

1. The AI only sees food numbers (target, today's log, food preferences). It
   doesn't know the training plan, the weight trend or a fight date, so it
   mostly repeats what is on screen.
2. Food targets ignore training: a sparring day and a rest day look the same.
3. There is no fight date, the thing fighters organise their lives around.
4. The streak is daily, so a planned rest day breaks it.

## The loop

Fight date or goal → this week's plan → **Home: one next action** → log in
seconds (one "+" for meal, weight or session) → Sunday review → next week
adapts. The streak becomes weekly: "hit your planned sessions this week".
Timer rounds and Reaction drills count toward the week.

## AI features, in priority order

The app calculates every number; the AI explains and prioritises. The
existing validators (schema, safety patterns, fabricated numbers) apply to
all of them.

| Feature | AI sees | Free | Pro |
|---|---|---|---|
| Daily Corner Brief (replaces today's Fighter Brief) | Today's sessions and times, last 7 days of training, food log, weight trend, days to fight | One calculated line, no AI | Full three-line brief, refreshed after logs |
| Sunday Camp Review | Sessions done vs planned, minutes, protein days hit, intake vs target, weight change vs planned pace | Weekly numbers | Review, calculated target adjustment, shareable card |
| Log by typing or voice | The typed text and candidate foods from the app's food list | 3 a day | Unlimited |
| Fight camp and weigh-in plan | Camp phase, weight path (calculated, refuses plans beyond ISSN limits) | Countdown | Phases, weight path, fight-week mode |
| Session debrief | RPE, one line of notes, the drill library IDs | — | 1-2 drills and a Reaction level for next time |
| Ask the Coach (exists) | The same full picture; "Why?" buttons open it with context | — | Pro |

Never: AI-invented calories or portions, cuts beyond the ISSN limits
(4.4% of body mass in 24 h, 5.7% in 48 h, 6.7% in 72 h), calories from
photos, guilt notifications, AI without consent.

## Owner decisions (2026-09-24)

- Direction and build order: approved.
- Fight date and weight plan: yes.
- Paid AI provider with no data retention before launch: yes.
- Free users get 3 typed food logs a day: yes.
- Pricing and trial stay as in the monetization strategy: $7.99/month,
  $59.99/year, 7-day trial.

## Build order

0. Protect the AI budget: App Check, bounded request facts, per-task
   limits, usage totals and a daily token budget, a no-data-retention
   routing option.
1. Weekly streak and a "one next action" Home (no AI).
2. Daily snapshot: one calculated summary of training, food and weight
   that every AI feature reads (pure Dart domain, tested).
3. Daily Corner Brief (Pro).
4. Sunday Camp Review with calculated target adjustments and a Sunday
   notification.
5. Log by typing, then by voice.
6. Fight date, camp phases, safe weight path, then fight-week mode.
7. Session debrief.
8. Paywall moments and the trial; measure trial conversion.

Each step is its own PR with tests.

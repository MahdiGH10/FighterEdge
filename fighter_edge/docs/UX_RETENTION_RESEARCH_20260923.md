# Fighter Edge — Interface Analysis, Niche Research, and a Retention & Subscription Plan

**Date:** 2026-09-23
**Inputs:** a render-and-review of every screen in the app (28 of 29 states
rendered with the real theme and fonts; 2 described from code), a read of the code
behind them, and online research on combat-sports apps, fitness/nutrition app
retention, subscription benchmarks, and the safety literature on diet tracking
and weight cutting. Sources are listed at the end.

**One framing choice up front.** The brief was "addictive". This plan aims for
*habit-forming*: the athlete comes back because the app makes their training
better, not because it makes them feel guilty or anxious when they leave.
That is an ethical line, and in this category it is also the better business: the
research below shows that guilt-driven tracking mechanics harm a measurable
share of diet-app users, app stores now reject manipulative paywalls, and
regulators are actively pursuing subscription dark patterns.

---

## 1. The short version

Fighter Edge already has a solid base: a real design system, accessibility
that passes automated checks, two languages, a deterministic nutrition
engine, a first-week checklist, and a streak freeze. What it lacks is a
**spine that gives an athlete a reason to open it every day**, and a few
mechanics that currently **work against** the audience.

The eight moves that matter most, in order:

1. **Fix the streak so rest days don't break it.** Today a 4-day-a-week
   athlete loses the streak on the first rest day of their own plan (§3.1).
   Switch to a *weekly* streak: "hit your planned training days this week".
2. **Make the fight date the organising idea.** Every combat-sports app that
   athletes pay for is built around the next fight or weigh-in. Fighter Edge
   has no fight date at all (§4.1).
3. **Make everything count.** Reaction drills and round-timer sessions
   should credit the week, history and streak. Today only the 7 planned
   sessions do.
4. **Turn "Today" into one next action.** Home is currently a dashboard of
   numbers. The research on retention says the first thing an athlete sees
   should be the next action that matters today.
5. **Ship real billing, with an honest, personalised paywall right after onboarding and a free
   trial**, keeping each pillar genuinely useful for free (§5).
6. **Reminders that follow the athlete's own training days,** asked for after
   the first completed session, capped at one a day (§4.3).
7. **Keep nutrition adherence-neutral:** no red numbers, no shaming, no
   rewards for eating less, and no streaks on food logging (§6).
8. **Measure it.** Add funnel events and track D1 / D7 / D30 retention and
   trial conversion against the benchmarks in §4.2 before tuning anything.

Before any of that, fix the four launch blockers found in the screen review
(§2.4).

---

## 2. How the interfaces are built

### 2.1 Stack and structure

| Layer | What it is |
|---|---|
| UI | Flutter, 164 Dart files, about 32,000 lines (excluding generated translations) |
| Navigation | `go_router` (auth-aware redirects, deep links for legal, paywall, profile, timer, settings, weight, fuel plan and coach) plus a 4-tab `HomeShell` |
| State | `provider`: `AuthController`, `AppState` (weights, meals, sessions), `EdgeFuelController`, `StreakController`, `FirstRunController`, `LocaleController` |
| Data | Firestore in production; in-memory and seeded mock data for offline/dev and tests |
| Features | `features/edge_fuel` is layered as `domain/` (pure Dart calculators, policies, validation), `data/`, `ai/`, `presentation/` |
| Design system | Tokens in `theme/` (`AppType`, `AppColors`, `Insets`, `Radii`, `MotionTokens`, `AppHaptics`, `AppAccessibility`) and 21 shared widgets (`PrimaryButton`, `GhostButton`, `AppCard`, `StatCard`, `FilterChips`, `ProgressRing`, `EmptyState`, `Skeleton`, `ProLock`, `CoachMarks`, `PremiumReveal`, …) |
| Language | English and German, generated `L` class |
| Quality | 525 tests + 3 golden images; accessibility, contrast and 200% text checks; telemetry and crash reporting |

### 2.2 What the build does well

- **One visual language.** Every screen uses the same tokens, so the app
  looks like a single product: dark crimson and black, Oswald headings, Inter body text.
  Nothing looks bolted on.
- **Accessibility is real, not decorative.** 48 dp tap targets, labelled
  controls, reduced-motion support, large-text layouts that wrap instead of
  truncating, contrast checked by tests.
- **Trust signals are built in:** deterministic nutrition maths with AI only
  explaining it, a safe-cut guidance toggle, and entitlements only granted by a
  verified server webhook.
- **Onboarding already personalises:** seven questions build a live summary
  ("4-day Beginner camp · Maintain · …"), then a plan with real numbers
  (2,500 kcal, macros). This is exactly the "invest, then see your plan"
  pattern the research recommends (§4.4).
- **Retention scaffolding exists:** first-week checklist, coach-mark tour,
  "first meal logged" celebration, streak with freezes (a Pro perk doubles
  the cap), local training reminders, telemetry.

### 2.3 Structural weaknesses that show up as UX problems

- **The streak is a daily streak on a weekly plan** (§3.1).
- **Only planned sessions count.** `StreakEngine.completedDateKeys` reads
  only the 7-slot weekly plan, so Reaction drills, round-timer rounds and
  unplanned training are invisible to the streak, history and the week view.
- **Broad rebuilds.** 49 `context.watch` calls across 27 files; Home watches
  six controllers. Not a visible problem yet, but it is the first place to
  look when the on-device performance baseline is taken.
- **Dead and placeholder surfaces.** `MoreScreen` is never opened; Terms and
  Privacy are placeholders; the offline build seeds 2024 demo data.
- **No growth surfaces.** There is no sharing, no home-screen widget, no
  Health Connect or Apple Health integration, and no fight date.

### 2.4 Launch blockers from the screen review

1. **Settings shows an internal note to users.** The disclaimer ends "Keep this visible before
   public launch." (`settings_screen.dart:541`).
2. **Terms and Privacy are placeholders.** Both stores require real policies,
   and Apple checks the paywall links to them (guideline 3.1.2).
3. **Weight tracker truncates its third tab** to "Measure…" at normal text size.
4. **The AI Fighter Brief empty state is a dead end.** It has no action, while
   Your plan's empty state has "Start setup".

---

## 3. Screen-by-screen: what works and what to change

### 3.1 Home (Dashboard) — the most important screen, and the weakest
**Works:** clear hierarchy, Today's focus card, one strong primary action.
**Change:**
- **The streak is broken by design.** It counts consecutive calendar days with a
  completed session. Onboarding creates a 4-day week, so the streak dies on
  the first rest day of the athlete's own plan. Freezes (at most 2 banked, and
  one earned only in a week with 3+ training days) cannot cover 3 rest days a week. Combat athletes are
  taught to respect recovery; the app currently punishes it.
  **Fix:** a weekly streak: "weeks in a row you hit your planned training
  days". Rest days are part of the plan and never break anything. Freezes
  then cover a missed *week target*, which is what they are for.
- **The streak is shown twice** (Today's focus and the stat tile). Show it
  once, with its weekly progress ("3 of 4 this week").
- **Too many numbers and too little direction.** It shows weight, sessions, streak, weekly
  rings, next session and recent activity. Put **one next action** at the top
  ("Tuesday · Wrestling · 60 min → Start"), then this week's progress, then
  everything else below.

### 3.2 Train
**Works:** the week list is scannable, and start and log are one tap each. The drill
library has search, filters, technique paths, progress bars and clear Pro
locks. Reaction drills are unique in the market (§4.1).
**Change:**
- Log Reaction drills and round-timer work as sessions in History and the
  week.
- History shows only "Logged" and an effort rating. Add duration, date and a
  **calendar heatmap** (BJJ journals use this as their main progress view,
  and it is the most shareable screen they have).
- Add a **"sharp" progression** for drills (Not started → Learning → Sharp),
  surfaced on Home ("2 drills to sharpen this week").

### 3.3 Fuel
**Works:** a friendly empty state with two example meals, fast search, and a
recipe library with clear macros and tags. Deterministic targets are
explained.
**Change:**
- Keep the calorie ring and macros **adherence-neutral** (§6): no red when over,
  no celebration for being under.
- The first thing after setup should be "log what you ate today in under 10
  seconds": recent foods, then saved meals, then search.
- Tie the target to the training day ("Training day +250 kcal") so that Fuel and
  Train feel like one plan.

### 3.4 Profile, Settings, Weight
**Works:** a clean list with clear groupings; weight trend and 7-day average.
**Change:** the weight screen should be framed around the **fight or weigh-in
date** (target line, days left, safe weekly rate), not an open-ended chart.

### 3.5 Paywall
**Works:** plain-language benefits, honest billing note, "no payment today".
**Change:**
- It's generic. Personalise it with the plan just built ("Your 8-week camp to
  Nov 14").
- Fix the brand spelling (the title says "FighterEdge"; everywhere else it's
  "Fighter Edge"), the duplicated "Founding Pro preview", and the
  green checks next to features a free user does not have.
- When billing goes live, follow §5.3.

---

## 4. What the research says

### 4.1 The niche: what combat-sports apps are built around

| App type | Examples | What athletes pay for |
|---|---|---|
| Audio-called combos | Heavy Bag Pro (1,000+ combos for boxing, kickboxing and Muay Thai) | The voice calls the combo so eyes stay on the bag; the timer "actually gives you time to hit the combo" |
| Video classes plus hardware | FightCamp | Coach-led classes; punch trackers (entry cost in the hundreds) |
| AI coach | JAB AI, MMA AI: Cage Coach, Combat FIT | Personal plans, voice-guided rounds, video analysis, fight-camp tracking |
| BJJ journals | BJJ Notes, Post Black Belt, Grappling AI, BJJ Buddy | Logging rolls and techniques, "technique in focus" goals, **year heatmaps, streaks, sessions per week**, voice journaling |
| Weight-cut tools | CutCoach, The Fight Dietitian app, Weight Cut | **Fight date plus fight weight → a dated plan**, weigh-in checkpoints, fight-week support |

**Where Fighter Edge fits:** no competitor combines *camp structure,
nutrition, technique and reaction training* in one place. That is the
positioning. But the category's shared organising idea, **the fight or
weigh-in date**, is missing from Fighter Edge entirely. Add it (optional,
for athletes with a date): a countdown on Home, camp phases
(build → sharpen → fight week), and a weight path that respects the
safety limits in §6.

Reaction drills are a genuine differentiator. Heavy Bag Pro proves
audio-called training is valued. Fighter Edge's drills are spec-driven
per level and tested against a coaching brief, which few apps can claim.

### 4.2 Benchmarks to measure against

| Metric | Health & Fitness benchmark |
|---|---|
| Day-30 retention | about 3% median; about 8% is roughly average for serious apps; 10–12% for apps tied to real-world training |
| Download → paid | **2.9%** median |
| Trial → paid | **39.9%** median, **68.3%** top decile |
| Annual-plan share | **68%** (highest of any category) |
| Month-1 realised LTV | **$24.23** median |
| Trial cancellations | For 3-day trials, **55% cancel on Day 0** and 84% by Day 1; value must land in the first hour |
| Trial length | 17–32-day trials convert **42.5%**, versus 25.5% for trials under 4 days |
| Annual churn | 35% of annual subscribers turn off auto-renew in month 1; the year-1 cancel rate is 72% |
| Billing failures | 31% of Google Play cancellations are involuntary (payment failure) |

### 4.3 Habit mechanics that are proven

- **Streaks work through loss aversion, and freezes are what make them
  humane.** Duolingo's streak freeze cut churn by **21%** among users at
  risk of losing their streak. Giving **new** users two freezes when they start a streak raised
  retention. A "streak wager" lifted Day-7 retention by **14%**. The lesson:
  never let one bad day be catastrophic. Fighter Edge's version should be
  weekly (§3.1).
- **The hook loop** is trigger → small action → reward → investment. For
  Fighter Edge that is: reminder on your training day → start today's
  session or a 2-minute Reaction drill → progress visibly moves (week ring,
  drill "sharp", personal best) → the plan adapts and history grows.
- **Push notifications:** event-triggered messages beat scheduled
  broadcasts. Ask for permission *after* a first real success, using an
  in-app primer first. Cap non-transactional pushes at **one a day**, use
  local time, and back off after repeated dismissals.
- **Hardware and widgets anchor habit.** Apps tied to devices people already
  use every day (a watch, the home screen) retain longer. A home-screen widget
  ("Today: Wrestling 60 min · week 2/4") is cheap in Flutter and works
  every day.
- **Why people quit:** over half of habit-app users drop off within 30 days,
  mostly because of **overwhelming interfaces or lack of personalisation**.
  That argues for the "one next action" Home.

### 4.4 Onboarding and the "aha" moment

- Longer, personalised onboarding (Noom runs to over 100 screens) converts
  when every question visibly feeds the plan. Fighter Edge's live summary
  card already does this.
- **The aha moment must happen before the paywall.** Fitbod asks one
  question and immediately produces a doable workout, then shows a
  three-month projection before its paywall. Fighter Edge's aha is the plan
  reveal, and it can be stronger: show *this week's* sessions and today's
  fuel target, and offer a **2-minute Reaction drill right there**.
- Apps that deliver value before gating see **1.5–2×** higher trial→paid
  than apps that gate immediately. The sweet spot is **2–4 completed
  workouts** before asking.

### 4.5 Monetisation

- **Paywall placement:** onboarding paywalls with a trial produce the
  highest install→paid rate (about 1.78% average). Users convert either on Day 0
  or on Days 4–7, with almost nothing in between.
- **Hard paywalls out-earn freemium** (Day-35 trial→paid 10.7% versus 2.1%, and 8×
  revenue per install at Day 60), but in fitness, metered access that proves value
  first converts better than an immediate gate. The best of both: a
  **soft onboarding paywall with a trial**, plus a **useful free tier**.
- **Honesty is now required.** Apple has been rejecting trial-toggle
  paywalls under guideline 3.1.2 since early 2026. Paywalls need clear price,
  trial terms, renewal terms, and links to Terms and Privacy. In the US the
  FTC restarted its "click-to-cancel" rulemaking in March 2026. It found dark
  patterns in 76% of subscription sites and apps it reviewed.

---

## 5. Recommendations for Fighter Edge

### 5.1 The core loop (what brings an athlete back)

**Daily:** a reminder on training days only, at the athlete's usual time →
Home shows **one next action** → do it (a session, or a 2-minute Reaction
drill on rest days, which is optional and never required) → the week ring
fills.

**Weekly:** "3 of 4 sessions this week" → the weekly streak (weeks in a row
you hit your plan) → a **Sunday recap** (sessions, minutes, drills sharpened,
weight trend) that can be shared.

**Camp:** fight date → camp phase → the countdown and weight path on Home →
fight-week mode.

### 5.2 Build order

| # | Item | Why |
|---|---|---|
| 0 | Fix the four launch blockers (§2.4) | Store approval and trust |
| 1 | Funnel telemetry: onboarding step reached, plan revealed, first session, first meal, first drill, paywall viewed, trial started, reminder opt-in | You cannot improve D7 without measuring it |
| 2 | **Weekly streak** replacing the daily one; freezes cover a missed week target; new users start with 1 freeze | Stops punishing rest; biggest retention fix |
| 3 | Log Reaction drills and timer rounds as sessions (the E1 decision from the UX audit) | Everything the athlete does counts |
| 4 | Home = one next action, then the week, then stats; the streak shown once | Less overwhelm, clearer habit |
| 5 | Reminder opt-in after the first completed session, with an in-app primer; training days only; max 1/day | Trigger without spam |
| 6 | **Fight date** (optional): countdown, camp phases, weight path within ISSN limits | The category's organising idea |
| 7 | Billing live via RevenueCat; personalised paywall after the plan reveal; trial; annual default with monthly visible; no toggles | Revenue, compliant with Apple 3.1.2 |
| 8 | Home-screen widget (today's session and week progress) | A daily trigger that isn't a notification |
| 9 | Sunday recap card, shareable; History heatmap | Reward, reflection, organic growth |
| 10 | Reaction progression: personal bests per level, "unlock" the next level after two clean runs | Variable, earned reward inside the unique feature |

### 5.3 Free versus Pro

The principle: **free must deliver the aha moment and a real weekly habit; Pro
makes it personal, deeper and smarter.**

| Free | Pro |
|---|---|
| Weekly plan, logging, history, weekly streak (2 freezes) | AI Fighter Brief (daily next-action coaching) |
| Fuel target and food logging | Full recipe library, allergen-checked and scaled |
| Starter drills (current free set) | Full drill library and technique paths |
| Reaction drills: Beginner and Intermediate in all disciplines | Reaction Advanced and Advanced+, plus personal-best history |
| Round timer | Corner cues between rounds |
| Fight date countdown | Camp phases, weight path and fight-week mode |
| — | 4 streak freezes (already implemented) |

**Paywall moments,** each tied to a feature the user just reached for:
after the plan reveal (a soft paywall with a trial), a locked drill, Reaction
Advanced, corner cues, and fight-week mode.

**Trial:** research favours longer trials (17–32 days convert far better than
3-day ones), and a fight camp lasts weeks. Start with **7 days**, and A/B test
14 days once there is traffic. Default the selection to **annual**, since 68% of
Health & Fitness subscribers choose it, while keeping monthly one tap away.

**Billing hygiene:** turn on grace periods and billing-retry handling in
RevenueCat. 31% of Android cancellations are payment failures, which are
recoverable.

---

## 6. Guardrails: what not to build

This app touches weight, food and weight cutting. The research is specific:

- Among adults in eating-disorder treatment who used calorie trackers,
  **73% said the app contributed** to their disorder. Red/green calorie
  colours, rewards for eating under target, **streaks on food logging**, and
  "you're over" warnings are the named risk features.
- MacroFactor's **adherence-neutral** design is the model: no red numbers,
  no pop-ups, no guilt, and targets that adapt to what was logged, however close
  the athlete came.
- The ISSN's 2025 position stand for combat sports: no more than **6.7% of
  body mass within 72 h, 5.7% within 48 h, or 4.4% within 24 h** before
  weigh-in. Rehydrate to regain ≥10% of body mass afterwards. It does not
  endorse fasting, fluid restriction, saunas, diet pills, laxatives or
  purging.

Rules for Fighter Edge:
1. **Streaks are for training, never for eating.**
2. Fuel numbers stay neutral: no red when over and no praise for being under.
3. The weight path refuses plans beyond the ISSN limits, shows why, and keeps
   the "not medical advice" line visible.
4. Notifications never guilt ("Don't lose your streak!"). Say what's next
   ("Wrestling today, 60 min").
5. Cancel is as easy as subscribe, and a paywall is always dismissible.
6. The safe-cut guidance toggle stays **on by default**.

---

## 7. What to measure

| Metric | Target for launch | Stretch |
|---|---|---|
| Onboarding completion | 70% | 80% |
| First session or drill within 24 h | 40% | 55% |
| Reminder opt-in | 50% | 65% |
| D1 / D7 / D30 retention | 30% / 15% / 8% | 40% / 22% / 12% |
| Trial start (of onboarded users) | 8% | 15% |
| Trial → paid | 40% (median) | 55% |
| Weeks with the weekly target hit, per active user | 50% | 65% |

Review weekly; change one lever at a time.

---

## Sources

- [RevenueCat — State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps)
- [RevenueCat — Subscription app trends and benchmarks 2026](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)
- [Adapty — Health & Fitness subscription benchmarks](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)
- [RocketShip HQ — Paywall structure for fitness apps](https://www.rocketshiphq.com/paywall-structure-fitness-app-workouts/)
- [RevenueCat — Hard paywall activation journey](https://www.revenuecat.com/blog/growth/hard-paywall-activation-journey)
- [RevenueCat — Noom's web-to-app onboarding funnel](https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel)
- [RevenueCat — R.I.P. toggle paywall](https://www.revenuecat.com/blog/growth/rip-toggle-paywall)
- [Business of Apps — Health & Fitness app benchmarks 2026](https://www.businessofapps.com/data/health-fitness-app-benchmarks/)
- [SEM Nexus — D1/D7/D30 retention benchmarks 2026](https://semnexus.com/day-1-day-7-day-30-retention-benchmarks-app-category-2026)
- [Sahha — Why health app users churn within 90 days](https://sahha.ai/blog/health-app-churn-retention/)
- [Orangesoft — Fitness app engagement and retention strategies](https://orangesoft.co/blog/strategies-to-increase-fitness-app-engagement-and-retention)
- [Habit Streak — State of habit tracking 2026](https://habit-streak.com/en/blog/habit-tracking/state-of-habit-tracking-2026)
- [Propel — Duolingo's customer retention strategy](https://www.trypropel.ai/resources/blogs/duolingo-customer-retention-strategy)
- [Just Another PM — The psychology behind Duolingo's streak](https://www.justanotherpm.com/blog/the-psychology-behind-duolingos-streak-feature)
- [OneSignal — Push notification best practices 2026](https://onesignal.com/blog/onesignal-guide-push-notification-best-practices-2026/)
- [SEM Nexus — Push notification timing and opt-in data](https://semnexus.com/push-notification-timing-data-opt-in-rates)
- [Heavy Bag Pro — Best boxing apps 2026](https://heavybag.pro/the-best-boxing-apps-of-2026-ranked-for-punching-bag-training/)
- [Titans Grip — Best MMA training apps 2026](https://www.titans-grip.com/blog/best-mma-app-2026/)
- [FightFlow — Top boxing training apps](https://fightflow.app/blog/best-boxing-apps-2025)
- [BJJ Notes — Best BJJ apps](https://www.bjjnotes.app/blog/best-bjj-apps)
- [Grappling AI — Best BJJ apps 2026](https://blog.grapplingaiapp.com/posts/best-bjj-apps-2026/)
- [CutCoach](https://spark.mwm.ai/us/apps/cutcoach/6751152119) · [The Fight Dietitian app](https://thefightdietitian.com/pages/tfd-fight-camp-app) · [Weight Cut](https://weightcut.app/)
- [MacroFactor — What "adherence neutral" means](https://macrofactorapp.com/adherence-neutral/)
- [Systematic review — Fitness/diet tracking and disordered eating (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12547374/)
- [BJPsych Open — Diet and fitness apps and eating-disorder behaviours](https://www.cambridge.org/core/journals/bjpsych-open/article/effects-of-diet-and-fitness-apps-on-eating-disorder-behaviours-qualitative-study/2D1EE739D97AB3EFC6573835E4C527BD)
- [ISSN position stand — Nutrition and weight cut strategies for MMA and combat sports (2025)](https://pubmed.ncbi.nlm.nih.gov/40059405/)
- [Jones Day — FTC revives click-to-cancel (2026)](https://www.jonesday.com/en/insights/2026/05/ftc-revives-clicktocancel-rule-new-risks-for-subscription-businesses)
- [Adapty — Banned dark patterns vs permitted tricks](https://adapty.io/blog/dark-patterns-and-tricks-in-mobile-apps/)

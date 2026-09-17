# FighterEdge Product and Monetization Strategy

Status: approved direction for the next implementation phases

## Product promise

FighterEdge is a daily fuel and training system for combat athletes. It is not
another generic calorie counter and it must not sell a subscription by hiding
basic health information.

The product loop is:

`set a goal -> see today's target -> log food/training -> get the next action -> return for the weekly brief`

The free plan creates trust and habit. Pro saves time, explains decisions, and
adapts the plan as the athlete's data changes.

## Free plan

Free must be useful without a credit card:

- account creation and fresh onboarding;
- personalized calorie and macro target;
- daily food logging and basic progress;
- basic recipes and quick-add meals;
- one reliable round timer preset;
- current training week, streak, and basic weight tracking;
- one deterministic daily Fighter Brief preview;
- account deletion, privacy controls, and data export;
- safety explanations and non-medical disclaimers.

Free users should reach the first value moment: a target they understand and a
real meal or session logged against it.

## Pro plan

Launch with one paid tier. Do not add a Coach tier until real gyms request
team workflows.

Recommended launch pricing to validate, not to treat as permanent:

- `$7.99/month`;
- `$59.99/year` as the highlighted value plan;
- a trial only after the user has seen a real preview, with clear renewal terms.

Pro unlocks outcomes rather than arbitrary limits:

- full Fighter Brief: next meal, training timing, explanation, and adaptation;
- weekly fuel and training report;
- adaptive targets after meaningful weight or training changes;
- AI EdgeFuel Coach with a server-enforced monthly allowance;
- premium recipes, meal plans, and grocery lists;
- advanced nutrition and weight trends;
- unlimited history;
- advanced timer templates and full reviewed training content;
- coach-ready exports and private sharing.

Never market a Pro feature before it is complete, tested, and available in the
same build as the paywall.

## The conversion moment

The premium hook is the **Fighter Brief**. Free gives the numbers; Pro gives the
next decision.

Free preview example:

> You are 42g short on protein today. A protein-first meal is the best next
> move.

Pro continuation:

> Here are three meals that fit your remaining calories, when to eat them
> around today's session, and what tomorrow's target should be if this trend
> repeats.

Show this after the user has a target plus enough logged context. Do not show a
day-zero blocking paywall, fake countdown, fake scarcity, or a blurred result
that hides all value.

## Growth strategy

The first distribution channel is combat-sport gyms and coaches, supported by
short educational videos answering real fighter questions. Start with direct
feedback and referrals before paid ads.

North-star behavior: an activated athlete completes onboarding, logs a first
meal, completes a training session, and returns for a weekly brief.

Internal launch targets:

- 60% onboarding completion;
- 50% first meal logged within 48 hours;
- 35% week-one retention;
- 20% week-four retention;
- 5–10% Pro conversion among activated users;
- 10 paying users before meaningful ad spend;
- five users who say they would be disappointed if FighterEdge disappeared.

## Unit economics guardrails

- Keep AI behind a backend boundary and a per-user quota.
- Cap output tokens and reject requests after the quota.
- Set an explicit monthly AI budget alert.
- Separate store fees, taxes, AI, Firebase, support, refunds, and RevenueCat
  costs when measuring contribution margin.
- Do not use health or weight values as analytics event parameters.

## Product rules

1. Basic safety, user-owned history, account deletion, and purchase restoration
   are never Pro-only.
2. A subscription must earn its recurring price through new insight, adaptive
   decisions, or continually refreshed content.
3. AI explains and recommends; deterministic domain logic owns targets and
   safety decisions.
4. Every premium promise must have a working empty, loading, error, quota, and
   restore state.

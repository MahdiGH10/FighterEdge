# Phase 7 — Premium Fighter Brief

## Objective

Create the first premium moment that makes the value of Pro obvious without
damaging the free experience or making medical claims.

## Phase 7A — domain contract and free preview — implemented

- Add a pure-Dart `FighterBriefPreview` model.
- Derive the preview from the saved target and today's consumed totals.
- Keep the preview deterministic, fast, and free of AI cost.
- Return an honest `needsMoreData` state when no target or meal context exists.
- Prioritize one next action: protein, carbohydrates around training, remaining
  calories, or logging the first meal.
- Unit-test every boundary and zero-data path.

The first implementation lives in:

- `lib/features/edge_fuel/domain/models/fighter_brief_preview.dart`;
- `lib/features/edge_fuel/domain/calculators/fighter_brief_calculator.dart`;
- `test/unit/edge_fuel/fighter_brief_calculator_test.dart`.

EdgeFuel Plan now shows this preview to free users and presents a concrete
`Unlock my Fighter Brief` path to the existing Pro paywall. The preview never
calls AI and never overrides the deterministic nutrition target.

## Phase 7B — premium brief contract

- Extend the server AI response with structured brief sections:
  summary, next action, meal suggestion, training timing, weekly adjustment,
  warnings, facts used, and content version.
- Validate the response on the server before it reaches Flutter.
- Keep deterministic target and safety outputs authoritative.
- Add quota, unavailable, professional-review, and retry states.

## Phase 7C — activation UI

- Add a Dashboard/EdgeFuel preview card after the user has enough context.
- Show one real free insight and a concrete Pro continuation.
- Use a clear action label such as `Unlock my Fighter Brief`.
- Keep the paywall honest: benefits, price, renewal terms, restore purchase,
  privacy, and terms are visible.
- Respect large text, reduced motion, screen readers, narrow devices, and
  loading/error states.

## Phase 7D — measurement and optimization

Track privacy-safe funnel events only:

`brief_preview_viewed -> premium_cta_tapped -> paywall_viewed -> trial_started -> subscription_started -> brief_completed`

Do not include weight, calories, meal names, health notes, email addresses, or
AI prompt content in event parameters.

## Definition of done

- A free user can understand the preview in under ten seconds.
- A Pro user receives a useful brief or a clear recoverable error.
- No premium request can bypass entitlement or quota checks.
- The feature works offline with a deterministic fallback preview.
- Domain, widget, flow, integration, performance, and accessibility tests pass.

## Implementation status — September 2026

The first 7B/7C slice is now shipped:

- `fighterBrief` is a distinct server task and premium tasks verify
  `users/{uid}.plan == 'pro'` before consuming AI quota.
- OpenRouter output now uses a version-2 Fighter Brief schema with explicit
  next action, meal suggestion, training timing, and weekly adjustment sections.
- The server validates every section, scans it for unsafe language and
  fabricated numbers, and rejects the whole response on any failure.
- Flutter parses and renders the four premium sections with typed
  entitlement-required, quota, unavailable, and success states.
- The paywall supports configured monthly/annual products, restore, pending
  server sync, and store management links, with a safe local waitlist fallback.

The next 7B/7D slice is privacy-safe funnel measurement and production
observability. The full brief still only appears after the server confirms the
entitlement; the deterministic free preview remains available offline.

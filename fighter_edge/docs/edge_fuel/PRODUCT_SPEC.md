# EdgeFuel AI — Product Spec (Sprint EF-0)

Condensed implementation reference for the deterministic nutrition domain.
Full product rationale, IA, packaging, and roadmap live in
`docs/EDGEFUEL_AI_CLAUDE_CODE_MASTER_PROMPT.md` — this file summarizes only
what EF-0's domain layer implements and why, so later sprints (and reviewers)
don't have to re-derive it from the 1400-line master prompt.

## What EdgeFuel AI is

The premium nutrition and activity system inside Fighter Edge. Not a generic
calorie counter — it combines nutrition, weight trend, MMA training load, and
transparent weekly adaptation. See master prompt §1 for the full mission.

## Naming (must stay consistent — master prompt §3)

| Concept | Name |
|---|---|
| Product module | EdgeFuel AI |
| Nav label | Fuel |
| Feature folder | `lib/features/edge_fuel/` |
| Deterministic calculator | `NutritionTargetCalculator` |
| Safety policy | `NutritionSafetyPolicy` |
| AI boundary (later sprint) | `EdgeFuelAiGateway` |

## Non-negotiable boundaries (master prompt §4) — what EF-0 encodes

1. No language model ever calculates or alters a health-critical target.
   **EF-0 has no AI dependency at all** — `NutritionTargetCalculator` is pure
   Dart with zero Flutter/Firebase/clock/network imports.
2. All targets come from a deterministic, versioned, unit-tested engine —
   this **is** EF-0's deliverable.
3. Adults 18+ only for the first release — enforced by
   `NutritionSafetyPolicy` returning `NutritionTargetStatus.unsupported` for
   under-18 profiles.
4. No automated fight-week dehydration/rapid-cut system — EF-0 defines no
   such feature; `NutritionPolicy` only exposes conservative fat-loss/gain
   percentage ranges (§7.4 of the master prompt).
5. Every calculated plan must expose: that it's an estimate, the
   equation/policy version used, its assumptions, when calculated, and the
   reference weight used. `NutritionTarget` carries `policyVersion`,
   `equationProfileUsed`, `activityCoefficientUsed`, `referenceWeightKg`, and
   `calculatedAt` for exactly this reason.

## Domain engine summary (master prompt §7)

**Resting energy (Mifflin–St Jeor):**
```
base = 10 × weightKg + 6.25 × heightCm - 5 × ageYears
higher-offset = base + 5
lower-offset  = base - 161
neutral       = midpoint of both
```
Named `estimatedRmrKcal`, never "exact metabolism."

**Activity coefficients** (versioned in `NutritionPolicy`, not hardcoded in
widgets): veryLow 1.20, light 1.35, moderate 1.50, high 1.70, veryHigh 1.90.
`estimatedMaintenanceKcal = estimatedRmrKcal × activityCoefficient`, exposed
as a ±10% range, never false precision.

**Goal adjustment:** fat loss 10–15% deficit (default 15%), maintenance 0%,
muscle gain 5–10% surplus (default 8%). Target is never allowed below
estimated RMR in the automated flow — the calculator reduces pace and
surfaces a warning instead.

**Macros:**
- Protein: 1.8 g/kg (lose/gain) or 1.6 g/kg (maintain) of a *reference
  weight* — the lower of current/target weight when losing (only if the
  target is valid), else current weight. Allowed automated range 1.4–2.2 g/kg.
- Fat: 25–30% of target energy, never silently dropped below the safety
  floor.
- Carbohydrate: remaining calories after protein and fat; flags a
  performance-threshold conflict on high training load rather than hiding it.
- Fiber: ~14 g per 1,000 kcal, shown as a range.

**Rounding/invariants:** calories to nearest 10 kcal, macro grams to whole
numbers, macro-derived calories must reconcile within ±20 kcal of the
target, NaN/Infinity/zero-division are rejected at the domain boundary — as
a typed result, never a raw exception (master prompt §7.6).

**Result type:** every calculation returns one of
`success | needsMoreData | unsupported | needsProfessionalReview` — safety
problems are never encoded as generic exception strings.

## What EF-0 explicitly does NOT include

Per the master prompt's own staging (§19, §22): no UI redesign, no AI
gateway, no recipes, no daily logging/migration, no activity-recommendation
service, no weekly adaptive review. Those are Sprints EF-1 through EF-6 and
require this domain foundation to exist and be reviewed first.

## Review status

Calculation and safety policy values in this sprint are **implementation
defaults from the evidence list**, not yet signed off by a qualified sports
dietitian. Master prompt §20 (Definition of done) requires that expert
review before any public health claim is enabled. Tracked as an open item —
see `SAFETY_AND_EVIDENCE.md`.

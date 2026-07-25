# EdgeFuel AI — Safety Policy and Evidence Notes (Sprint EF-0)

> This is a product and engineering implementation record, not medical or
> legal advice. Calculation and safety-policy defaults below are starting
> points from public evidence sources; they require sign-off by a qualified
> sports dietitian and, where applicable, legal/privacy review before any
> public health claim is enabled (master prompt §17, §20).

## Access/review log

| Date | Reviewer | Scope | Status |
|---|---|---|---|
| 2026-07-25 | Claude (implementation) | Encoded formulas/thresholds from the sources below into `NutritionPolicy` and `NutritionSafetyPolicy` | Implementation only — **not** an expert clinical review |

Add a new row each time a qualified professional reviews or changes a
threshold. Do not remove prior rows — this is an audit trail.

## Hard safety rules encoded in `NutritionSafetyPolicy` (EF-0)

These map directly to master prompt §4 and §6:

1. **Under 18 → `unsupported`.** Automated plans are not offered to minors
   in the first release. No exception path.
2. **Fat-loss request with an invalid target → `unsupported`.** Blocked when
   available inputs indicate underweight status (BMI < 18.5, WHO adult
   reference — see sources below) or when the requested target is not below
   current weight.
3. **Muscle-gain request with an invalid target → `unsupported`.** Blocked
   when the requested target is not above current weight.
4. **Clinician-managed conditions → `needsProfessionalReview`, not a hard
   block.** Pregnancy/breastfeeding, eating-disorder history or active
   symptoms, medicated diabetes, kidney disease, serious liver disease, or
   another clinician-managed diet. The user is asked to consult a qualified
   professional before an automated plan is generated; the app does not
   diagnose or refuse service outright.
5. **Automated target is never allowed below `estimatedRmrKcal`.** If the
   requested pace would cross that floor, the calculator reduces the pace
   and returns a warning explaining why, rather than silently applying it.
6. **Carbohydrate/performance conflict is surfaced, never hidden.** When a
   high training load combined with a deficit would push carbohydrate below
   a reviewed performance threshold, the result includes a warning rather
   than silently under-fueling training.

## Explicitly out of scope for the automated flow (master prompt §4)

The domain layer contains **no** code path for: water loading, fluid
restriction, sauna suits, laxatives, diuretics, purging, vomiting,
starvation, "sweating off" food, or any rapid fight-week weight-cut
protocol. This is a design boundary, not a feature to add later without a
separate, named-expert-reviewed safety process (master prompt §6, final
paragraph).

## BMI-based underweight threshold — flagged as a placeholder guardrail

EF-0 uses the WHO adult BMI underweight cutoff (< 18.5) as a coarse guard
against approving a fat-loss plan for someone who should not be losing
weight. This is a standard, widely-cited threshold, **not** a substitute for
individualized clinical assessment — it is a guardrail to prevent the worst
automated-flow failure, not a diagnostic tool. A qualified sports dietitian
should confirm whether this cutoff is appropriate for the amateur combat-sport
population FighterEdge targets, or whether a sport-specific threshold is
needed, before public launch.

## Evidence sources (from master prompt, access date recorded here)

Accessed 2026-07-25 for the values encoded in `NutritionPolicy`:

- Mifflin MD et al., "A new predictive equation for resting energy
  expenditure in healthy individuals" —
  https://pubmed.ncbi.nlm.nih.gov/2305711/
  (resting-energy formula, §7.2 of the master prompt)
- CDC, "Steps for Losing Weight" —
  https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html
- U.S. Physical Activity Guidelines, 2nd edition —
  https://health.gov/paguidelines/second-edition/pdf/Physical_Activity_Guidelines_2nd_edition.pdf
- International Society of Sports Nutrition position stand: protein and
  exercise — https://pubmed.ncbi.nlm.nih.gov/28642676/
  (protein g/kg reference-weight ranges)
- International Society of Sports Nutrition position stand: nutrition and
  weight-cut strategies for MMA/combat sports —
  https://pubmed.ncbi.nlm.nih.gov/40059405/
  (basis for the explicit rapid-cut exclusion above)
- IOC consensus statement on Relative Energy Deficiency in Sport —
  https://bjsm.bmj.com/content/57/17/1073
- IOC best-practice recommendations for body-composition considerations in
  sport — https://bjsm.bmj.com/content/57/17/1148
- FDA Nutrition Facts reference and Daily Values —
  https://www.fda.gov/food/nutrition-facts-label/how-understand-and-use-nutrition-facts-label
- USDA FoodData Central API guide — https://fdc.nal.usda.gov/api-guide/
  (not used until Sprint EF-3/V1.5 food-catalog work)
- Current Dietary Guidelines for Americans —
  https://www.dietaryguidelines.gov/

## Open items before public health claims are enabled

- [ ] Qualified sports dietitian review of `NutritionPolicy` constants
      (activity coefficients, goal-adjustment percentages, protein/fat/fiber
      rules)
- [ ] Qualified review of the BMI underweight guardrail for this population
- [ ] Legal/privacy review of safety-flag storage (master prompt §17)
- [ ] Contraindication copy review (master prompt §6, §17)

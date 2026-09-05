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

## Food catalog provenance (Sprint EF-3a)

`assets/data/edge_fuel_foods_v1.json` — 94 foods, nutrients per 100 g of edible
portion.

- **Source:** USDA FoodData Central (https://fdc.nal.usda.gov/), which is in the
  public domain and may be reproduced without permission. Values were
  transcribed by hand for V1; a backend proxy to the FDC API is deferred to
  V1.5 per master prompt §9.3.
- **Exceptions**, carrying their own `source` field because no USDA record was
  used: `labneh`, `harissa-paste` (typical commercial label values) and
  `whey-protein-isolate` (typical manufacturer label). These are the least
  reliable records in the table and should be first in line for review.
- **Status:** every record ships as `draft`. A unit test asserts this, so
  promoting any record to `reviewed` will fail CI until the promotion is
  accompanied by a real reviewer credit here.
- **No pork** is stocked, and meat is deliberately *not* tagged
  `DietTag.halal` — halal status depends on certified slaughter, which a
  nutrient table cannot establish. Only plant, dairy, egg and fish records
  carry the halal tag.
- **Allergen tags are a filtering aid, not a safety guarantee.** The catalog
  tracks twelve widely regulated allergens; absence of a tag means "not one of
  the tracked allergens in this record", never "safe to eat". Oats are not
  tagged gluten (they are gluten-free by botany) despite common
  cross-contamination in commercial supply — user-facing copy must not imply
  the app can clear a food for someone with coeliac disease.

### Automated integrity checks (not a substitute for review)

`FoodCatalogValidator` runs in unit tests and in debug at startup. It catches
transcription errors — duplicate ids, macros summing past 100 g/100 g, fibre
exceeding carbohydrate, missing attribution, and stated energy drifting from
macro-implied energy. Implied energy uses net carbohydrate at 4 kcal/g plus
fibre at 2 kcal/g; scoring fibre at the full 4 kcal/g over-states high-fibre
foods enough to false-flag correct records (raw spinach drifts 28% under the
naive formula, 9% under this one). A record is only flagged when it breaches
both a 25% relative and a 15 kcal absolute tolerance.

**These checks cannot tell you a value is the wrong USDA figure.** Only a
qualified reviewer can.

## Open items before public health claims are enabled

- [ ] Qualified sports dietitian review of `NutritionPolicy` constants
      (activity coefficients, goal-adjustment percentages, protein/fat/fiber
      rules)
- [ ] Qualified review of the BMI underweight guardrail for this population
- [ ] Legal/privacy review of safety-flag storage (master prompt §17)
- [ ] Contraindication copy review (master prompt §6, §17)
- [ ] Qualified review of the EF-3a food catalog, especially the three
      non-USDA records (`labneh`, `harissa-paste`, `whey-protein-isolate`)

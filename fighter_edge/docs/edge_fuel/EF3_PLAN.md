# EF-3 — Curated recipe system: feature, flow, and design plan

_Written before any EF-3 code. Grounded in `EDGEFUEL_AI_CLAUDE_CODE_MASTER_PROMPT.md`
§5.3, §9, §10, §11, §12, §19, and verified against the code as it exists at commit
`9a14df4`. Design direction draws on the `apple-design` and `emil-design-eng`
skills, translated from web to Flutter (see §4.0 — the translation is not
optional, both skills are CSS/Motion-native and their code samples do not apply
to this codebase)._

---

## 1. Scope correction — EF-3 is bigger than "add recipes"

The sprint line in §19 reads as one deliverable. It is actually three, because
of a hard constraint stated twice in the spec:

> §2.4: "Recipe nutrition is calculated from structured ingredient data. It is
> never [fabricated]."
> §9.2: ingredients carry a "food-data ID, grams, household unit"

You cannot author 24 recipes with per-serving macros by hand. The macros must be
**derived** from a food table. So EF-3 decomposes into:

| Part | What | Why it must come first |
|---|---|---|
| **3a** | `FoodCatalogRepository` + bundled food table (§9.3 V1) | Recipe nutrients are computed from it. Nothing else can be built until it exists. |
| **3b** | Recipe domain model, catalog asset, validation, nutrient aggregation | The catalog is meaningless without the food table to resolve against. |
| **3c** | Library + detail UI, serving scaling, add-to-day, save, Pro gating | The user-facing half. |

This ordering is also the test ordering: 3a and 3b are pure Dart and unit-testable
with zero Flutter dependencies, consistent with how EF-0 was built.

**Estimate:** 3a ≈ 1–2 days, 3b ≈ 3–4 days (most of it content authoring), 3c ≈
3–4 days. Content is the long pole, not code.

---

## 2. Features

### 2.1 Food catalog (3a)

Provider-neutral `FoodCatalogRepository`, per §9.3. V1 only:

- A bundled, reviewed food table covering exactly what the 24 recipes need —
  roughly 80–120 foods. Per 100g nutrients: kcal, protein, carbs, fat, fibre.
- Custom foods (user-created).
- Recent + favourite foods.
- Manual quick-add retained (already exists — do not regress it).

Explicitly **out of scope**: USDA FoodData Central proxy (V1.5), barcode/label/photo
scanning (V2). The repository interface is shaped so V1.5 slots in behind it
without touching callers.

### 2.2 Recipe catalog (3b)

`assets/data/edge_fuel_recipes_v1.json`, registered in `pubspec.yaml`, validated
at startup in debug **and** in unit tests (§9.2).

Composition floor from §9.1 — this is a checklist, not a suggestion:

| Requirement | Count |
|---|---|
| Breakfast / snack | 8 |
| Lunch / dinner | 8 |
| Pre-training | 4 |
| Post-training / recovery | 4 |
| **Total** | **24 minimum** |
| Vegetarian | ≥ 8 |
| Vegan | ≥ 4 |
| Halal-compatible filtering | required |
| North African / Mediterranean, affordable | "several" |
| No-oven options | required |
| Under 20 minutes | required |

Every recipe carries the full §9.2 schema — including `status`
(draft/reviewed/published/retired), `contentVersion`, and reviewer
name/credentials **placeholder**. Ship as `draft`; nothing claims dietitian review
until a dietitian actually reviews it (§18 / SAFETY_AND_EVIDENCE.md precedent).

**Original content only.** No copying from recipe sites. Concise, plain-language
numbered steps.

### 2.3 Recipe UI (3c)

Per §5.3:

- Search.
- Filters: meal type, cooking time, diet, allergens, cost, equipment, training moment.
- Detail: ingredients in **grams and household units**, numbered steps, allergen
  statement, substitutions, prep/cook/total time, per-serving nutrients.
- Serving adjustment, recalculating nutrients live.
- Add-to-today → writes `FoodLogEntry` into the existing `NutritionDay`.
- Save → `users/{uid}/savedRecipes/{recipeId}` (§12).
- Source/reviewer/version metadata visible.

### 2.4 Entitlements

§10 requires four **distinct** entitlements, not one vague nutrition gate. EF-3
introduces one of them:

- `edgeFuelPremiumRecipes` ← this sprint
- `edgeFuelAdaptiveReview`, `edgeFuelMealPlans`, `edgeFuelAdvancedInsights` ← later sprints

This means extending the existing `Feature` enum in `lib/billing/subscription.dart`.
Today it has five coarse values (`nutritionAnalytics` being the closest). The new
entitlement is additive — do not repurpose `nutritionAnalytics`.

**Free floor: ≥ 12 complete, genuinely useful recipes** (§9.1). The premium half
earns its price through convenience, depth, adaptation, and review quality —
**not** by crippling the free set. A free recipe is a whole recipe.

---

## 3. Flow

### 3.1 Entry points

```
Nutrition tab
├── Today (exists)          → "Add from recipes" CTA on the log
├── Meals (exists)
├── Recipes (NEW)           → Recipe Library
└── Analytics (exists, Pro)

Plan screen (exists)        → "Fuel this plan" → Recipe Library, pre-filtered
                              to the user's remaining macros for today
```

The second entry point is the one that makes the feature feel intelligent: arriving
from the plan screen pre-filters to what actually fits the day's remaining budget.

### 3.2 Primary journey

```
Recipe Library
  │  search + filter chips (horizontal, scrollable)
  │  cards: image, title, kcal/serving, time, diet badges
  │  premium cards show a lock affordance, NOT a blur-and-tease
  ▼
Recipe Detail
  │  hero image → title → per-serving macro row
  │  serving stepper  ── live nutrient recalculation
  │  ingredients (grams + household units)
  │  numbered steps
  │  allergen statement + substitutions
  │  reviewer / version metadata (honest: "draft, not yet reviewed")
  ▼
Add to today  → choose meal slot → writes FoodLogEntry → returns to the log
                with the day's ring already updated
```

### 3.3 Paywall placement

§10 is explicit: **do not show the paywall while the user is actively logging food.**

Allowed in EF-3: opening a premium recipe. That is the only upgrade moment this
sprint introduces. Do not add one to add-to-day, search, or the library itself.

### 3.4 Allergen behaviour — **open decision, needs your call**

The setup wizard already collects allergies (`food_step.dart`). The `apple-design`
skill's Responsibility principle uses this exact scenario as its example: *"an
allergy-aware recipe app must not suggest a harmful ingredient."*

Three options:

- **A — Hard filter.** Recipes containing a declared allergen never appear.
  Safest; can silently hide most of a small 24-recipe catalog.
- **B — Filter with an explicit escape hatch.** Hidden by default, with a visible
  count ("3 recipes hidden by your allergen filters") and a deliberate opt-in to
  view, each carrying a warning banner. Preserves agency (Apple principle 2)
  without defaulting to risk.
- **C — Show with warnings.** Everything visible, conflicts flagged. Most content,
  most risk.

**Recommendation: B.** It satisfies both Responsibility and Agency, and it degrades
gracefully while the catalog is small. It is a genuine product/safety fork, so it
is your decision, not mine.

---

## 4. Design

### 4.0 Translating the skills to Flutter

Both design skills are web-native. Every code sample in them — `backdrop-filter`,
`@starting-style`, `clip-path`, Motion/Framer Motion, Pointer Events — is
inapplicable here. The **principles** transfer; the implementations must be
re-derived:

| Skill concept | Flutter equivalent |
|---|---|
| Spring, damping ratio + response | `SpringDescription.withDampingRatio()` + `controller.animateWith(SpringSimulation(...))` |
| Animate from *presentation* value | `AnimationController.animateTo()` from its current value — never rebuild a `Tween` from the target |
| `backdrop-filter: blur()` | `BackdropFilter(filter: ImageFilter.blur(...))` |
| `transform-origin` | `Transform.scale(alignment: ...)`, or `Hero` for true anchoring |
| `prefers-reduced-motion` | `MediaQuery.disableAnimationsOf(context)` |
| Dynamic Type | `MediaQuery.textScalerOf(context)` — spacing must scale with it |
| Haptics | `HapticFeedback` (already used by the round timer) |
| `will-change` / compositor hints | `RepaintBoundary` |

The existing `MotionTokens` (`fast` 160ms, `standard` 260ms, `reveal` 420ms,
`emphasized` cubic) is a solid duration-based system. EF-3 **adds** a spring
alongside it rather than replacing it — durations stay correct for non-gestural
transitions; springs are for anything the finger touches.

### 4.1 What the skills actually change about this sprint

**Response — feedback on press-down, not release.** (`apple-design` §1,
`emil-design-eng` "Buttons must feel responsive"). Recipe cards and the serving
stepper must highlight on `onTapDown`, not `onTap`. Flutter's default `InkWell`
ripple already does this; custom `GestureDetector` cards in this codebase do not.
Audit every tappable surface added in EF-3.

**The serving stepper is the signature interaction.** It is the one control where
1:1 continuous feedback matters: every tap must recalculate and re-render macros
*immediately*, with the numbers animating from their current value, not snapping.
`TweenAnimationBuilder` re-targeting from the presentation value. This is the
detail that makes the feature feel engineered rather than assembled.

**Anchored origins.** Recipe card → detail should be a `Hero` on the image, so the
detail screen visibly emerges from the card that opened it (`apple-design` §7).
Symmetric on dismiss.

**Typography — size-specific tracking.** `AppTheme.display()` takes an optional
`spacing` but callers pass it inconsistently. Recipe titles at display sizes want
*negative* tracking; the small-caps metadata labels want *positive*. Fix at the
call sites in EF-3 rather than repainting the whole app.

**Materials.** The filter bar should be a translucent `BackdropFilter` layer with
cards scrolling under it, with a scroll-edge fade rather than a 1px divider
(`apple-design` §12). This is a real improvement over the current opaque-strip
pattern used elsewhere in the app.

**Reduced motion is not optional.** Every spring and Hero added must check
`MediaQuery.disableAnimationsOf(context)` and degrade to a cross-fade. The app has
zero reduced-motion handling today — EF-3 should not add to that debt.

**Restraint.** `emil-design-eng`'s first question is "should this animate at all?"
The answer for most of the recipe library is no. Animate: card→detail transition,
serving recalculation, add-to-day confirmation. Do not animate: list entrance
staggers, filter chip selection, scroll-triggered reveals. The brand is discipline.

### 4.2 Design work that is explicitly *not* EF-3

Deferred so the sprint stays shippable: app-wide reduced-motion audit, golden
tests, the dashboard/technique-library visual pass, animated page transitions
between tabs. Those belong to a later design sprint, on top of a launched feature.

---

## 5. Architecture

Per §11, additive to the existing feature module:

```
lib/features/edge_fuel/
  domain/
    models/
      recipe.dart              NEW  immutable, copyWith, schemaVersion
      food_item.dart           NEW
      recipe_ingredient.dart   NEW
    calculators/
      recipe_nutrient_calculator.dart  NEW  the ONLY place recipe macros are derived
  data/
    food_catalog_repository.dart        NEW  interface
    asset_food_catalog_repository.dart  NEW
    recipe_catalog_repository.dart      NEW  interface
    asset_recipe_catalog_repository.dart NEW
  presentation/
    controllers/
      recipe_library_controller.dart    NEW  search/filter/loading state
    screens/
      recipe_library_screen.dart        NEW
      recipe_detail_screen.dart         NEW
    widgets/
      recipe_card.dart, serving_stepper.dart, allergen_notice.dart  NEW
```

Standing rules from §11 that EF-3 must not break: domain is pure Dart; widgets do
not calculate nutrition; repositories never return Firebase classes; nothing goes
into `AppState`; inject clock and repositories for tests.

`RecipeNutrientCalculator` mirrors `NutritionTargetCalculator`'s role — the single
authority for its numbers.

---

## 6. Tests

Per §17 (`recipe nutrient aggregation`, `recipe catalog schema validation`,
`recipe filtering/detail/serving change`):

- Nutrient aggregation from ingredients, including serving scaling, with a
  hand-verified vector (the EF-0 precedent).
- Catalog validation: every record parses, every `foodId` resolves, the §9.1
  composition floor is asserted **as a test** so the catalog cannot regress below
  24/8/8/4/4/8-veg/4-vegan.
- Allergen filtering correctness — a test that a declared allergen never appears
  in the default result set.
- Widget tests: library renders, search filters, detail scales servings, add-to-day
  writes a `FoodLogEntry`, premium gating hides Pro recipes for a free user.
- Accessibility: 44px minimum touch targets, semantic labels on icon buttons.

Note the `ListView` viewport gotcha from `HANDOFF.md` §2 — use
`scrollUntilVisible` in any test that taps below the fold, and prefer
`ListView.builder` for the recipe list.

---

## 7. Commit

Exactly, per §19 — not paraphrased:

```
feat(edge-fuel): add curated recipe system
```

If the sprint is split across commits, this is the final one.

---

## 8. Decisions — settled 2026-09-01

All three were put to the user with a recommendation; all three recommendations
were accepted.

1. **Allergen behaviour → Option B.** Recipes conflicting with a declared allergen
   are hidden by default, with a visible count ("3 recipes hidden by your allergen
   filters") and a deliberate opt-in to reveal them, each then carrying a warning
   banner. Satisfies Responsibility (never silently suggest a harmful ingredient)
   and Agency (never remove the user's ability to choose).
2. **No recipe photography in V1.** Image asset reference stays in the schema
   (§9.2 allows it to be optional) but ships null. Cards and detail headers use a
   typographic/colour treatment keyed to meal type. Placeholder stock imagery
   would read as unfinished — worse than an intentional typographic card.
3. **Food table transcribed from USDA FoodData Central**, which is public domain.
   Source recorded per food, attribution added to `SAFETY_AND_EVIDENCE.md`, whole
   table shipped as `status: draft` pending dietitian review.

### 8.1 Scope note added during 3a

`FoodCatalogRepository` in 3a covers the **bundled, read-only** catalog:
`loadAll`, `byId`, `search`. The user-scoped surface from §9.3 V1 — custom foods,
recents, favourites — lands in **3c**, where the UI that needs it exists.
Declaring those methods now and leaving them unimplemented would be worse than
adding them when they are wired up.

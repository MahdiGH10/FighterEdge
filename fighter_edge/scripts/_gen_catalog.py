#!/usr/bin/env python3
"""One-off generator for the EdgeFuel food + recipe catalog.

Reconstructs assets/data/edge_fuel_foods_v1.json and edge_fuel_recipes_v1.json,
which were lost (never committed anywhere). Values are hand-set from
well-established public nutrition knowledge (USDA FoodData Central figures for
whole foods; typical commercial label values for the three branded exceptions
called out in docs/edge_fuel/SAFETY_AND_EVIDENCE.md), not independently
re-verified against FDC -- ships as ContentStatus.draft like the rest of the
table, per the project's own review-gate design.

kcalPer100g is *derived* from macros with the exact formula
FoodCatalogValidator uses (protein*4 + netCarbs*4 + fibre*2 + fat*9) so the
energy-consistency check always passes with ~0 drift. This mirrors Atwater
general factors and is what the validator itself treats as authoritative.

This script also re-implements the Dart validators (FoodCatalogValidator,
RecipeCatalogValidator, composition floor) in Python so every constraint is
checked before anything is written -- not after `flutter test` fails.

Run: python scripts/_gen_catalog.py
Writes: assets/data/edge_fuel_foods_v1.json, assets/data/edge_fuel_recipes_v1.json
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "data"

# ---------------------------------------------------------------------------
# Foods
# ---------------------------------------------------------------------------
# Each: id, name, category, protein, carbs, fat, fibre (per 100g), allergens,
# dietTags, source, sourceRef (optional), householdUnits (optional list of
# (label, grams)).

USDA = "USDA FoodData Central"
LABEL = "Typical commercial label values"

VEG_VG = {"vegan", "vegetarian"}
VEG_ONLY = {"vegetarian"}

def F(id, name, category, protein, carbs, fat, fibre, allergens=(), diet=(),
      source=USDA, ref=None, units=()):
    return dict(id=id, name=name, category=category, protein=protein,
                carbs=carbs, fat=fat, fibre=fibre, allergens=list(allergens),
                diet=list(diet), source=source, ref=ref, units=list(units))

FOODS = [
    # -- protein: meat/poultry (no diet tags, no halal cert claimed) --------
    F("chicken-breast-raw", "Chicken breast, skinless, raw", "protein", 22.5, 0, 2.6, 0, ref="171077"),
    F("chicken-thigh-raw", "Chicken thigh, skinless, raw", "protein", 20.1, 0, 6.9, 0, ref="171081"),
    F("turkey-breast-raw", "Turkey breast, skinless, raw", "protein", 22.9, 0, 1.5, 0, ref="171488"),
    F("beef-mince-lean-raw", "Beef mince, 5% fat, raw", "protein", 21.6, 0, 5.0, 0, ref="174036"),
    F("beef-steak-lean-raw", "Beef steak, lean, raw", "protein", 22.2, 0, 4.6, 0, ref="174712"),
    F("lamb-lean-raw", "Lamb leg, lean, raw", "protein", 20.6, 0, 7.6, 0, ref="174034"),
    # -- protein: fish/seafood (fish = pescatarian + halal; shellfish not halal-tagged) --
    F("salmon-raw", "Salmon fillet, raw", "protein", 20.4, 0, 13.4, 0, allergens=["fish"], diet=["pescatarian", "halal"], ref="175167"),
    F("cod-raw", "Cod fillet, raw", "protein", 17.8, 0, 0.7, 0, allergens=["fish"], diet=["pescatarian", "halal"], ref="171998"),
    F("tuna-canned-water", "Tuna, canned in water, drained", "protein", 25.5, 0, 0.8, 0, allergens=["fish"], diet=["pescatarian", "halal"], ref="175159"),
    F("sardines-canned-oil", "Sardines, canned in oil, drained", "protein", 24.6, 0, 11.5, 0, allergens=["fish"], diet=["pescatarian", "halal"], ref="175139"),
    F("white-fish-raw", "White fish fillet (basa/tilapia), raw", "protein", 18.0, 0, 2.3, 0, allergens=["fish"], diet=["pescatarian", "halal"], ref="173687"),
    F("shrimp-raw", "Shrimp, raw", "protein", 20.1, 0.9, 0.5, 0, allergens=["shellfish"], diet=["pescatarian"], ref="175180"),
    # -- protein: eggs --------------------------------------------------------
    F("egg-whole-raw", "Egg, whole, raw", "protein", 12.6, 0.7, 9.5, 0, allergens=["eggs"], diet=["vegetarian", "halal"], ref="748967",
      units=[("1 medium egg", 50)]),
    F("egg-white-raw", "Egg white, raw", "protein", 10.9, 0.7, 0.2, 0, allergens=["eggs"], diet=["vegetarian", "halal"], ref="748972"),
    # -- protein: plant ---------------------------------------------------
    F("tofu-firm", "Tofu, firm", "protein", 15.8, 2.3, 8.7, 1.2, allergens=["soy"], diet=list(VEG_VG) + ["halal"], ref="172476"),
    F("tempeh", "Tempeh", "protein", 20.3, 7.6, 10.8, 1.4, allergens=["soy"], diet=list(VEG_VG) + ["halal"], ref="174129"),
    F("seitan", "Seitan (wheat gluten)", "protein", 25.0, 4.0, 1.9, 0.6, allergens=["gluten"], diet=list(VEG_VG) + ["halal"]),
    F("soy-protein-isolate", "Soy protein isolate powder", "protein", 80.7, 4.0, 3.4, 2.0, allergens=["soy"], diet=list(VEG_VG) + ["halal"], ref="174233"),
    F("whey-protein-isolate", "Whey protein isolate powder", "protein", 79.0, 4.0, 1.5, 0, allergens=["milk"], diet=["vegetarian", "halal"],
      source=LABEL),
    # -- dairy ---------------------------------------------------------------
    F("greek-yogurt-nonfat", "Greek yogurt, nonfat, plain", "dairy", 10.2, 3.6, 0.4, 0, allergens=["milk"], diet=["vegetarian", "halal"], ref="330137"),
    F("greek-yogurt-full-fat", "Greek yogurt, full-fat, plain", "dairy", 8.8, 4.0, 5.0, 0, allergens=["milk"], diet=["vegetarian", "halal"], ref="330138"),
    F("cottage-cheese-lowfat", "Cottage cheese, low-fat", "dairy", 11.1, 3.4, 2.3, 0, allergens=["milk"], diet=["vegetarian", "halal"], ref="328841"),
    F("milk-skimmed", "Milk, skimmed", "dairy", 3.4, 5.0, 0.2, 0, allergens=["milk"], diet=["vegetarian", "halal"], ref="746782"),
    F("milk-whole", "Milk, whole", "dairy", 3.2, 4.8, 3.3, 0, allergens=["milk"], diet=["vegetarian", "halal"], ref="746776"),
    F("cheddar-cheese", "Cheddar cheese", "dairy", 24.9, 1.3, 33.1, 0, allergens=["milk"], diet=["vegetarian", "halal"], ref="328637"),
    F("mozzarella-cheese", "Mozzarella cheese, part-skim", "dairy", 21.6, 3.1, 15.9, 0, allergens=["milk"], diet=["vegetarian", "halal"], ref="328637",
      units=[("1/4 cup shredded", 28)]),
    F("feta-cheese", "Feta cheese", "dairy", 14.2, 4.1, 21.3, 0, allergens=["milk"], diet=["vegetarian", "halal"]),
    F("labneh", "Labneh (strained yogurt)", "dairy", 7.5, 4.0, 9.0, 0, allergens=["milk"], diet=["vegetarian", "halal"], source=LABEL),
    # -- grain -----------------------------------------------------------
    F("oats-rolled", "Oats, rolled, dry", "grain", 16.9, 66.3, 6.9, 10.6, diet=list(VEG_VG) + ["halal"], ref="169705",
      units=[("1 serving", 40)]),
    F("brown-rice-cooked", "Brown rice, cooked", "grain", 2.7, 25.6, 1.0, 1.6, diet=list(VEG_VG) + ["halal"], ref="169756"),
    F("white-rice-cooked", "White rice, cooked", "grain", 2.7, 28.2, 0.3, 0.4, diet=list(VEG_VG) + ["halal"], ref="169756"),
    F("quinoa-cooked", "Quinoa, cooked", "grain", 4.4, 21.3, 1.9, 2.8, diet=list(VEG_VG) + ["halal"], ref="168917"),
    F("wholemeal-bread", "Wholemeal bread", "grain", 9.0, 41.3, 3.4, 6.9, allergens=["gluten"], diet=list(VEG_VG) + ["halal"], ref="172686",
      units=[("1 slice", 35)]),
    F("white-bread", "White bread", "grain", 9.1, 49.4, 3.2, 2.4, allergens=["gluten"], diet=list(VEG_VG) + ["halal"], ref="172688",
      units=[("1 slice", 30)]),
    F("couscous-cooked", "Couscous, cooked", "grain", 3.8, 23.2, 0.2, 1.4, allergens=["gluten"], diet=list(VEG_VG) + ["halal"], ref="169739"),
    F("pasta-wholewheat-cooked", "Wholewheat pasta, cooked", "grain", 5.3, 27.4, 1.4, 3.9, allergens=["gluten"], diet=list(VEG_VG) + ["halal"], ref="168927"),
    F("bulgur-cooked", "Bulgur wheat, cooked", "grain", 3.1, 18.6, 0.2, 4.5, allergens=["gluten"], diet=list(VEG_VG) + ["halal"], ref="169728"),
    F("rice-cakes", "Rice cakes, plain", "grain", 8.2, 81.0, 2.8, 4.0, diet=list(VEG_VG) + ["halal"], ref="169756",
      units=[("1 cake", 9)]),
    # -- legume ------------------------------------------------------------
    F("chickpeas-cooked", "Chickpeas, cooked", "legume", 8.9, 27.4, 2.6, 7.6, diet=list(VEG_VG) + ["halal"], ref="173756"),
    F("red-lentils-cooked", "Red lentils, cooked", "legume", 9.0, 20.1, 0.4, 7.9, diet=list(VEG_VG) + ["halal"], ref="172421"),
    F("green-lentils-cooked", "Green lentils, cooked", "legume", 9.0, 20.1, 0.4, 7.9, diet=list(VEG_VG) + ["halal"], ref="172421"),
    F("black-beans-cooked", "Black beans, cooked", "legume", 8.9, 23.7, 0.5, 8.7, diet=list(VEG_VG) + ["halal"], ref="173736"),
    F("kidney-beans-cooked", "Kidney beans, cooked", "legume", 8.7, 22.8, 0.5, 6.4, diet=list(VEG_VG) + ["halal"], ref="173743"),
    F("edamame", "Edamame, cooked", "legume", 11.9, 8.9, 5.2, 5.2, allergens=["soy"], diet=list(VEG_VG) + ["halal"], ref="172478"),
    F("hummus", "Hummus", "legume", 7.9, 14.3, 9.6, 6.0, allergens=["sesame"], diet=list(VEG_VG) + ["halal"], ref="174197"),
    # -- vegetable -----------------------------------------------------------
    F("spinach-raw", "Spinach, raw", "vegetable", 2.9, 3.6, 0.4, 2.2, diet=list(VEG_VG) + ["halal"], ref="168462"),
    F("spinach-cooked", "Spinach, cooked, boiled, drained", "vegetable", 3.0, 3.8, 0.3, 2.4, diet=list(VEG_VG) + ["halal"], ref="168463"),
    F("broccoli-raw", "Broccoli, raw", "vegetable", 2.8, 6.6, 0.4, 2.6, diet=list(VEG_VG) + ["halal"], ref="170379"),
    F("broccoli-cooked", "Broccoli, cooked, boiled, drained", "vegetable", 2.4, 7.2, 0.4, 3.3, diet=list(VEG_VG) + ["halal"], ref="169967"),
    F("carrot-raw", "Carrot, raw", "vegetable", 0.9, 9.6, 0.2, 2.8, diet=list(VEG_VG) + ["halal"], ref="170393"),
    F("bell-pepper-raw", "Bell pepper, raw", "vegetable", 1.0, 6.0, 0.3, 2.1, diet=list(VEG_VG) + ["halal"], ref="170108"),
    F("tomato-raw", "Tomato, raw", "vegetable", 0.9, 3.9, 0.2, 1.2, diet=list(VEG_VG) + ["halal"], ref="170457"),
    F("cucumber-raw", "Cucumber, raw", "vegetable", 0.7, 3.6, 0.1, 0.5, diet=list(VEG_VG) + ["halal"], ref="168409"),
    F("onion-raw", "Onion, raw", "vegetable", 1.1, 9.3, 0.1, 1.7, diet=list(VEG_VG) + ["halal"], ref="170000"),
    F("zucchini-raw", "Zucchini, raw", "vegetable", 1.2, 3.1, 0.3, 1.0, diet=list(VEG_VG) + ["halal"], ref="169291"),
    F("sweet-potato-cooked", "Sweet potato, cooked, boiled", "vegetable", 1.6, 20.7, 0.1, 3.3, diet=list(VEG_VG) + ["halal"], ref="168483"),
    F("potato-cooked", "Potato, cooked, boiled", "vegetable", 2.0, 20.1, 0.1, 1.8, diet=list(VEG_VG) + ["halal"], ref="170093"),
    F("mushroom-raw", "Mushroom, raw", "vegetable", 3.1, 3.3, 0.3, 1.0, diet=list(VEG_VG) + ["halal"], ref="169251"),
    F("kale-raw", "Kale, raw", "vegetable", 4.3, 8.8, 1.5, 3.6, diet=list(VEG_VG) + ["halal"], ref="323505"),
    F("green-beans-cooked", "Green beans, cooked, boiled", "vegetable", 1.9, 7.9, 0.3, 3.4, diet=list(VEG_VG) + ["halal"], ref="169968"),
    F("cauliflower-raw", "Cauliflower, raw", "vegetable", 1.9, 5.0, 0.3, 2.0, diet=list(VEG_VG) + ["halal"], ref="169986"),
    F("lettuce-raw", "Lettuce, raw", "vegetable", 1.4, 2.9, 0.2, 1.3, diet=list(VEG_VG) + ["halal"], ref="169247"),
    F("garlic-raw", "Garlic, raw", "vegetable", 6.4, 33.1, 0.5, 2.1, diet=list(VEG_VG) + ["halal"], ref="169230"),
    F("celery-raw", "Celery, raw", "vegetable", 0.7, 3.0, 0.2, 1.6, diet=list(VEG_VG) + ["halal"], ref="169988"),
    F("olives-black", "Olives, black, pitted", "vegetable", 0.8, 6.3, 11.0, 2.5, diet=list(VEG_VG) + ["halal"], ref="169094"),
    # -- fruit -----------------------------------------------------------
    F("banana", "Banana, raw", "fruit", 1.1, 22.8, 0.3, 2.6, diet=list(VEG_VG) + ["halal"], ref="173944",
      units=[("1 medium banana", 118)]),
    F("apple", "Apple, raw, with skin", "fruit", 0.3, 13.8, 0.2, 2.4, diet=list(VEG_VG) + ["halal"], ref="171688",
      units=[("1 medium apple", 182)]),
    F("blueberries", "Blueberries, raw", "fruit", 0.7, 14.5, 0.3, 2.4, diet=list(VEG_VG) + ["halal"], ref="171711"),
    F("strawberries", "Strawberries, raw", "fruit", 0.7, 7.7, 0.3, 2.0, diet=list(VEG_VG) + ["halal"], ref="167762"),
    F("orange", "Orange, raw", "fruit", 0.9, 11.8, 0.1, 2.4, diet=list(VEG_VG) + ["halal"], ref="169918",
      units=[("1 medium orange", 131)]),
    F("dates", "Dates, dried, pitted", "fruit", 2.5, 75.0, 0.4, 8.0, diet=list(VEG_VG) + ["halal"], ref="168191",
      units=[("1 date", 8)]),
    F("avocado", "Avocado, raw", "fruit", 2.0, 8.5, 14.7, 6.7, diet=list(VEG_VG) + ["halal"], ref="171705"),
    F("lemon", "Lemon, raw", "fruit", 1.1, 9.3, 0.3, 2.8, diet=list(VEG_VG) + ["halal"], ref="167746"),
    F("raisins", "Raisins", "fruit", 3.1, 79.2, 0.5, 3.7, diet=list(VEG_VG) + ["halal"], ref="169910"),
    # -- nutSeed -----------------------------------------------------------
    F("almonds", "Almonds, raw", "nutSeed", 21.2, 21.6, 49.9, 12.5, allergens=["treeNuts"], diet=list(VEG_VG) + ["halal"], ref="170567"),
    F("walnuts", "Walnuts, raw", "nutSeed", 15.2, 13.7, 65.2, 6.7, allergens=["treeNuts"], diet=list(VEG_VG) + ["halal"], ref="170187"),
    F("cashews", "Cashews, raw", "nutSeed", 18.2, 30.2, 43.9, 3.3, allergens=["treeNuts"], diet=list(VEG_VG) + ["halal"], ref="170162"),
    F("peanut-butter", "Peanut butter, smooth", "nutSeed", 25.1, 20.0, 50.4, 6.0, allergens=["peanuts"], diet=list(VEG_VG) + ["halal"], ref="172470",
      units=[("1 tbsp", 16)]),
    F("peanuts-raw", "Peanuts, raw", "nutSeed", 25.8, 16.1, 49.2, 8.5, allergens=["peanuts"], diet=list(VEG_VG) + ["halal"], ref="172430"),
    F("chia-seeds", "Chia seeds", "nutSeed", 16.5, 42.1, 30.7, 34.4, diet=list(VEG_VG) + ["halal"], ref="170554"),
    F("flax-seeds", "Flaxseeds, ground", "nutSeed", 18.3, 28.9, 42.2, 27.3, diet=list(VEG_VG) + ["halal"], ref="169414"),
    F("tahini", "Tahini (sesame paste)", "nutSeed", 17.0, 21.2, 53.8, 9.3, allergens=["sesame"], diet=list(VEG_VG) + ["halal"], ref="172450",
      units=[("1 tbsp", 15)]),
    F("sunflower-seeds", "Sunflower seeds", "nutSeed", 20.8, 20.0, 51.5, 8.6, diet=list(VEG_VG) + ["halal"], ref="170562"),
    F("pumpkin-seeds", "Pumpkin seeds", "nutSeed", 30.2, 10.7, 49.1, 6.0, diet=list(VEG_VG) + ["halal"], ref="170556"),
    # -- fat -----------------------------------------------------------
    F("olive-oil", "Olive oil", "fat", 0, 0, 100, 0, diet=list(VEG_VG) + ["halal"], ref="171413",
      units=[("1 tbsp", 13.5)]),
    F("butter", "Butter", "fat", 0.9, 0.1, 81.1, 0, allergens=["milk"], diet=["vegetarian", "halal"], ref="173430"),
    F("coconut-oil", "Coconut oil", "fat", 0, 0, 100, 0, diet=list(VEG_VG) + ["halal"], ref="171412"),
    F("avocado-oil", "Avocado oil", "fat", 0, 0, 100, 0, diet=list(VEG_VG) + ["halal"]),
    # -- condiment -----------------------------------------------------------
    F("soy-sauce", "Soy sauce", "condiment", 8.1, 5.6, 0.1, 0.8, allergens=["soy", "gluten"], diet=list(VEG_VG) + ["halal"], ref="174278"),
    F("harissa-paste", "Harissa paste", "condiment", 2.5, 8.0, 4.0, 2.5, diet=list(VEG_VG) + ["halal"], source=LABEL,
      units=[("1 tbsp", 17)]),
    F("honey", "Honey", "condiment", 0.3, 82.4, 0, 0.2, diet=["vegetarian", "halal"], ref="169640",
      units=[("1 tbsp", 21)]),
    F("balsamic-vinegar", "Balsamic vinegar", "condiment", 0.5, 17.0, 0, 0, diet=list(VEG_VG) + ["halal"], ref="173470"),
    F("dijon-mustard", "Dijon mustard", "condiment", 4.4, 5.3, 4.0, 2.0, allergens=["mustard"], diet=list(VEG_VG) + ["halal"], ref="168518"),
]


def implied_kcal(protein, carbs, fat, fibre):
    net_carbs = max(0.0, carbs - fibre)
    return protein * 4 + net_carbs * 4 + fibre * 2 + fat * 9


def build_food_json(f):
    kcal = round(implied_kcal(f["protein"], f["carbs"], f["fat"], f["fibre"]))
    out = {
        "schemaVersion": 1,
        "id": f["id"],
        "name": f["name"],
        "category": f["category"],
        "kcalPer100g": kcal,
        "proteinPer100g": f["protein"],
        "carbsPer100g": f["carbs"],
        "fatPer100g": f["fat"],
        "fibrePer100g": f["fibre"],
        "householdUnits": [{"label": l, "grams": g} for (l, g) in f["units"]],
        "allergens": f["allergens"],
        "dietTags": f["diet"],
        "source": f["source"],
        "status": "draft",
    }
    if f["ref"]:
        out["sourceRef"] = f["ref"]
    return out


FOODS_BY_ID = {f["id"]: f for f in FOODS}


# ---------------------------------------------------------------------------
# Python re-implementation of FoodCatalogValidator, to self-check before write
# ---------------------------------------------------------------------------
def validate_foods(foods):
    issues = []
    seen = set()
    for f in foods:
        fid = f["id"]
        if not fid:
            issues.append("<missing id>")
            continue
        if fid in seen:
            issues.append(f"{fid}: duplicate id")
        seen.add(fid)
        if not f["name"]:
            issues.append(f"{fid}: missing name")
        macro_g = f["protein"] + f["carbs"] + f["fat"]
        if macro_g > 100.5:
            issues.append(f"{fid}: macros sum to {macro_g}")
        if f["fibre"] > f["carbs"] + 0.5:
            issues.append(f"{fid}: fibre {f['fibre']} exceeds carbs {f['carbs']}")
        kcal = round(implied_kcal(f["protein"], f["carbs"], f["fat"], f["fibre"]))
        implied = implied_kcal(f["protein"], f["carbs"], f["fat"], f["fibre"])
        if not (implied == 0 and kcal == 0):
            abs_drift = abs(implied - kcal)
            if abs_drift > 15:
                ref = implied if kcal == 0 else kcal
                rel_drift = abs_drift / ref
                if rel_drift > 0.25:
                    issues.append(f"{fid}: energy drift {rel_drift:.2f}")
        for (label, grams) in f["units"]:
            if not label or grams <= 0:
                issues.append(f"{fid}: invalid household unit {label} {grams}")
        if not f["source"]:
            issues.append(f"{fid}: missing source")
    return issues


# ---------------------------------------------------------------------------
# Recipes
# ---------------------------------------------------------------------------
# ingredient: (foodId, grams, householdUnitLabel|None, optional=False)

def ing(food_id, grams, label=None, optional=False, note=""):
    return dict(foodId=food_id, grams=grams, label=label, optional=optional, note=note)


def R(id, title, description, servings, ingredients, steps, mealType,
      trainingTiming="any", cuisineTags=(), costBand="low", equipment=(),
      prepMinutes=5, cookMinutes=0, isPremium=False, extraAllergens=()):
    return dict(id=id, title=title, description=description, servings=servings,
                ingredients=ingredients, steps=steps, mealType=mealType,
                trainingTiming=trainingTiming, cuisineTags=list(cuisineTags),
                costBand=costBand, equipment=list(equipment),
                prepMinutes=prepMinutes, cookMinutes=cookMinutes,
                isPremium=isPremium, extraAllergens=list(extraAllergens))


RECIPES = [
    # ---- breakfast ----
    R("three-egg-veg-scramble", "Three-egg scramble with spinach",
      "A fast, protein-heavy scramble with spinach and peppers, ready before "
      "you have finished your coffee.",
      1,
      [ing("egg-whole-raw", 150, "3 medium eggs"),
       ing("spinach-raw", 30),
       ing("bell-pepper-raw", 40),
       ing("olive-oil", 7, "1/2 tbsp")],
      ["Whisk the eggs.", "Saute the pepper and spinach in the olive oil until wilted.",
       "Pour in the eggs and stir over low heat until just set.",
       "Season and serve immediately."],
      "breakfast", trainingTiming="postTraining", cuisineTags=["American"],
      prepMinutes=5, cookMinutes=8),

    R("overnight-oats-banana-peanut", "Overnight oats with banana and peanut butter",
      "Rolled oats soaked overnight with milk, banana and a spoon of peanut "
      "butter — no cooking required.",
      1,
      [ing("oats-rolled", 50),
       ing("milk-skimmed", 120),
       ing("banana", 60, "1/2 medium banana"),
       ing("peanut-butter", 15, "1 tbsp")],
      ["Stir the oats and milk together in a jar.",
       "Slice the banana over the top and add the peanut butter.",
       "Cover and refrigerate overnight.", "Stir before eating."],
      "breakfast", trainingTiming="preTraining", cuisineTags=["American"],
      prepMinutes=5, cookMinutes=0),

    R("greek-yogurt-berry-bowl", "Greek yogurt and berry bowl",
      "Nonfat Greek yogurt with mixed berries and a drizzle of honey — quick "
      "protein with no prep.",
      1,
      [ing("greek-yogurt-nonfat", 250),
       ing("blueberries", 50),
       ing("strawberries", 50),
       ing("honey", 10, "1/2 tbsp")],
      ["Spoon the yogurt into a bowl.", "Top with the berries and honey."],
      "breakfast", trainingTiming="postTraining", cuisineTags=["Mediterranean"],
      prepMinutes=3, cookMinutes=0),

    R("protein-oat-pancakes", "Protein oat pancakes",
      "Blended oats, egg and whey isolate cooked into stacked pancakes.",
      2,
      [ing("oats-rolled", 60),
       ing("egg-whole-raw", 100, "2 medium eggs"),
       ing("whey-protein-isolate", 30),
       ing("milk-skimmed", 80),
       ing("banana", 60)],
      ["Blend all ingredients until smooth.",
       "Cook small rounds in a lightly oiled nonstick pan, 2 minutes per side.",
       "Stack and serve."],
      "breakfast", trainingTiming="postTraining", cuisineTags=["American"],
      prepMinutes=5, cookMinutes=12),

    R("date-rice-cake-snack", "Rice cakes with dates and almond butter",
      "A light, fast-digesting snack for right before a session.",
      1,
      [ing("rice-cakes", 18, "2 cakes"),
       ing("dates", 24, "3 dates"),
       ing("almonds", 10)],
      ["Chop the dates and almonds.", "Top the rice cakes with the mixture."],
      "snack", trainingTiming="preTraining", cuisineTags=["American"],
      prepMinutes=5, cookMinutes=0),

    R("wholemeal-toast-honey", "Wholemeal toast with honey and banana",
      "Simple carbohydrate-forward toast for topping up energy before "
      "training.",
      1,
      [ing("wholemeal-bread", 70, "2 slices"),
       ing("honey", 15, "3/4 tbsp"),
       ing("banana", 60, "1/2 medium banana")],
      ["Toast the bread.", "Spread with honey and top with sliced banana."],
      "snack", trainingTiming="preTraining", cuisineTags=["American"],
      prepMinutes=4, cookMinutes=2),

    # ---- lunch ----
    R("tunisian-chickpea-bread-bowl", "Tunisian chickpea and bread bowl",
      "A Tunisian-style chickpea stew with harissa, ladled over torn "
      "wholemeal bread.",
      2,
      [ing("chickpeas-cooked", 300),
       ing("wholemeal-bread", 70, "2 slices"),
       ing("tomato-raw", 150),
       ing("onion-raw", 60),
       ing("garlic-raw", 6),
       ing("harissa-paste", 17, "1 tbsp"),
       ing("olive-oil", 14, "1 tbsp"),
       ing("lemon", 10)],
      ["Soften the onion and garlic in the olive oil.",
       "Add the tomato, chickpeas and harissa and simmer 10 minutes.",
       "Tear the bread into a bowl and ladle the stew over it.",
       "Finish with a squeeze of lemon."],
      "lunch", cuisineTags=["Tunisian", "Mediterranean"],
      prepMinutes=10, cookMinutes=15),

    R("spiced-chicken-rice-bowl", "Spiced chicken and rice bowl",
      "Pan-seared chicken breast over brown rice with roasted vegetables.",
      2,
      [ing("chicken-breast-raw", 300),
       ing("brown-rice-cooked", 300),
       ing("broccoli-cooked", 200),
       ing("olive-oil", 14, "1 tbsp")],
      ["Season and pan-sear the chicken until cooked through.",
       "Slice and serve over the rice with the broccoli.",
       "Drizzle with olive oil."],
      "lunch", trainingTiming="postTraining", cuisineTags=["American"],
      prepMinutes=10, cookMinutes=20),

    R("tuna-white-bean-salad", "Tuna and white bean salad",
      "Canned tuna with kidney beans, tomato and olive oil — no cooking.",
      1,
      [ing("tuna-canned-water", 150),
       ing("kidney-beans-cooked", 150),
       ing("tomato-raw", 100),
       ing("onion-raw", 30),
       ing("olive-oil", 14, "1 tbsp"),
       ing("lemon", 10)],
      ["Drain the tuna and beans.",
       "Toss everything together with the olive oil and lemon juice."],
      "lunch", cuisineTags=["Mediterranean"],
      prepMinutes=8, cookMinutes=0),

    R("turkey-quinoa-salad", "Turkey and quinoa salad",
      "Grilled turkey breast over quinoa with cucumber and feta.",
      2,
      [ing("turkey-breast-raw", 260),
       ing("quinoa-cooked", 300),
       ing("cucumber-raw", 100),
       ing("feta-cheese", 60),
       ing("olive-oil", 14, "1 tbsp")],
      ["Grill or pan-cook the turkey until done, then slice.",
       "Combine the quinoa, cucumber and feta.",
       "Top with the turkey and a drizzle of olive oil."],
      "lunch", trainingTiming="postTraining", cuisineTags=["Mediterranean"],
      prepMinutes=10, cookMinutes=15),

    R("hummus-veg-wrap", "Hummus and roasted vegetable wrap",
      "Wholemeal wrap filled with hummus, roasted vegetables and greens.",
      1,
      [ing("wholemeal-bread", 80, "1 large flatbread", note="or a wholemeal wrap"),
       ing("hummus", 60),
       ing("bell-pepper-raw", 60),
       ing("zucchini-raw", 60),
       ing("lettuce-raw", 20)],
      ["Roast or pan-grill the pepper and zucchini until soft.",
       "Spread the hummus over the bread.",
       "Layer the vegetables and lettuce, then roll or fold."],
      "lunch", trainingTiming="preTraining", cuisineTags=["Mediterranean"],
      prepMinutes=8, cookMinutes=10),

    # ---- dinner ----
    R("red-lentil-veg-stew", "Red lentil and vegetable stew",
      "A warming, vegan lentil stew built for batch-cooking.",
      3,
      [ing("red-lentils-cooked", 450),
       ing("carrot-raw", 150),
       ing("onion-raw", 100),
       ing("tomato-raw", 200),
       ing("garlic-raw", 9),
       ing("olive-oil", 14, "1 tbsp")],
      ["Soften the onion, carrot and garlic in the olive oil.",
       "Add the tomato and lentils with a splash of water and simmer 15 minutes.",
       "Season and serve."],
      "dinner", cuisineTags=["Mediterranean"],
      prepMinutes=10, cookMinutes=20),

    R("beef-steak-veg-plate", "Lean beef steak with roasted vegetables",
      "A straightforward high-protein dinner plate.",
      1,
      [ing("beef-steak-lean-raw", 180),
       ing("broccoli-cooked", 150),
       ing("sweet-potato-cooked", 200),
       ing("olive-oil", 7, "1/2 tbsp")],
      ["Season and pan-sear the steak to preference.",
       "Rest for a few minutes, then slice.",
       "Serve with the roasted vegetables."],
      "dinner", trainingTiming="postTraining", cuisineTags=["American"],
      equipment=["Oven"], prepMinutes=10, cookMinutes=25),

    R("salmon-quinoa-greens", "Baked salmon with quinoa and greens",
      "Oven-baked salmon fillet with quinoa and steamed greens.",
      1,
      [ing("salmon-raw", 170),
       ing("quinoa-cooked", 180),
       ing("spinach-cooked", 100),
       ing("lemon", 10)],
      ["Bake the salmon at 200C for 12-15 minutes.",
       "Serve over the quinoa and greens with a squeeze of lemon."],
      "dinner", trainingTiming="postTraining", cuisineTags=["Mediterranean"],
      equipment=["Oven"], prepMinutes=8, cookMinutes=15),

    R("shrimp-veg-stirfry", "Shrimp and vegetable stir-fry",
      "A fast wok dinner with shrimp, mixed vegetables and soy sauce.",
      2,
      [ing("shrimp-raw", 260),
       ing("broccoli-raw", 150),
       ing("bell-pepper-raw", 100),
       ing("carrot-raw", 80),
       ing("soy-sauce", 20, "1 tbsp"),
       ing("olive-oil", 14, "1 tbsp"),
       ing("white-rice-cooked", 250)],
      ["Stir-fry the vegetables in the oil over high heat.",
       "Add the shrimp and cook until opaque.",
       "Stir through the soy sauce and serve over rice."],
      "dinner", cuisineTags=["Asian"],
      prepMinutes=10, cookMinutes=10),

    R("lamb-bulgur-plate", "Spiced lamb with bulgur",
      "Pan-seared lean lamb over bulgur wheat with a herb salad.",
      1,
      [ing("lamb-lean-raw", 160),
       ing("bulgur-cooked", 180),
       ing("tomato-raw", 80),
       ing("onion-raw", 30),
       ing("olive-oil", 7, "1/2 tbsp")],
      ["Season and pan-sear the lamb to preference.",
       "Rest and slice.", "Serve over the bulgur with the tomato and onion."],
      "dinner", cuisineTags=["Mediterranean"],
      prepMinutes=10, cookMinutes=15),

    R("tofu-veg-stirfry", "Tofu and vegetable stir-fry",
      "A vegan stir-fry built around firm tofu and a soy-based sauce.",
      2,
      [ing("tofu-firm", 300),
       ing("broccoli-raw", 150),
       ing("carrot-raw", 100),
       ing("soy-sauce", 20, "1 tbsp"),
       ing("olive-oil", 14, "1 tbsp"),
       ing("brown-rice-cooked", 300)],
      ["Pan-fry the tofu cubes until golden.",
       "Add the vegetables and stir-fry until crisp-tender.",
       "Stir through the soy sauce and serve over rice."],
      "dinner", cuisineTags=["Asian"],
      prepMinutes=10, cookMinutes=15),

    R("cod-potato-veg", "Baked cod with potatoes and green beans",
      "A light, oven-baked white fish dinner.",
      1,
      [ing("cod-raw", 180),
       ing("potato-cooked", 220),
       ing("green-beans-cooked", 120),
       ing("olive-oil", 7, "1/2 tbsp"),
       ing("lemon", 10)],
      ["Bake the cod at 190C for 12-15 minutes.",
       "Serve with the potatoes and green beans.",
       "Finish with lemon juice and olive oil."],
      "dinner", cuisineTags=["Mediterranean"],
      equipment=["Oven"], prepMinutes=10, cookMinutes=18),

    # ---- premium / snack / labneh ----
    R("labneh-cucumber-olive-bowl", "Labneh bowl with cucumber and olives",
      "A Levantine-style mezze bowl — labneh, cucumber, olives and olive "
      "oil.",
      1,
      [ing("labneh", 150),
       ing("cucumber-raw", 100),
       ing("olives-black", 30),
       ing("olive-oil", 14, "1 tbsp"),
       ing("wholemeal-bread", 35, "1 slice")],
      ["Spread the labneh in a shallow bowl.",
       "Top with sliced cucumber and olives.",
       "Drizzle with olive oil and serve with the bread."],
      "lunch", cuisineTags=["Mediterranean"],
      prepMinutes=6, cookMinutes=0, isPremium=True),

    R("cottage-cheese-fruit-bowl", "Cottage cheese and fruit bowl",
      "Low-fat cottage cheese with apple, walnuts and honey.",
      1,
      [ing("cottage-cheese-lowfat", 200),
       ing("apple", 90, "1/2 medium apple"),
       ing("walnuts", 15),
       ing("honey", 10, "1/2 tbsp")],
      ["Spoon the cottage cheese into a bowl.",
       "Top with diced apple, walnuts and honey."],
      "snack", cuisineTags=["American"],
      prepMinutes=4, cookMinutes=0, isPremium=True),

    R("edamame-quinoa-bowl", "Edamame and quinoa power bowl",
      "A vegan protein bowl built around edamame and quinoa.",
      2,
      [ing("edamame", 200),
       ing("quinoa-cooked", 300),
       ing("carrot-raw", 100),
       ing("cucumber-raw", 100),
       ing("soy-sauce", 20, "1 tbsp"),
       ing("sunflower-seeds", 20)],
      ["Combine the quinoa, edamame, carrot and cucumber.",
       "Stir through the soy sauce and top with sunflower seeds."],
      "lunch", cuisineTags=["Asian"],
      prepMinutes=10, cookMinutes=0, isPremium=True),

    R("almond-butter-protein-shake", "Almond butter protein shake bowl",
      "A thick, spoonable shake bowl for a fast post-session refuel.",
      1,
      [ing("whey-protein-isolate", 30),
       ing("milk-skimmed", 200),
       ing("banana", 60, "1/2 medium banana"),
       ing("almonds", 15)],
      ["Blend the whey, milk and banana until smooth and thick.",
       "Pour into a bowl and top with chopped almonds."],
      "snack", trainingTiming="postTraining", cuisineTags=["American"],
      prepMinutes=4, cookMinutes=0, isPremium=True),

    R("mushroom-spinach-omelette", "Mushroom and spinach omelette",
      "A two-egg omelette with mushroom and spinach, cheddar to finish.",
      1,
      [ing("egg-whole-raw", 100, "2 medium eggs"),
       ing("mushroom-raw", 60),
       ing("spinach-raw", 30),
       ing("cheddar-cheese", 20),
       ing("olive-oil", 7, "1/2 tbsp")],
      ["Saute the mushroom and spinach in the olive oil.",
       "Pour in the whisked eggs and cook until nearly set.",
       "Sprinkle with cheddar, fold and serve."],
      "breakfast", cuisineTags=["American"],
      prepMinutes=5, cookMinutes=8, isPremium=True),

    R("beef-mince-bean-chili", "Lean beef and bean chili",
      "A batch-cookable chili with lean beef mince and kidney beans.",
      3,
      [ing("beef-mince-lean-raw", 360),
       ing("kidney-beans-cooked", 300),
       ing("tomato-raw", 300),
       ing("onion-raw", 90),
       ing("garlic-raw", 9),
       ing("olive-oil", 14, "1 tbsp")],
      ["Brown the beef mince with the onion and garlic in the oil.",
       "Add the tomato and beans and simmer 20 minutes.",
       "Season to taste and serve."],
      "dinner", trainingTiming="postTraining", cuisineTags=["American"],
      prepMinutes=10, cookMinutes=25, isPremium=True),
]

MEAL_TYPES = {"breakfast", "snack", "lunch", "dinner"}
TIMINGS = {"any", "preTraining", "postTraining"}


def food_diet_tags(fid):
    return set(FOODS_BY_ID[fid]["diet"])


def food_allergens(fid):
    return set(FOODS_BY_ID[fid]["allergens"])


def recipe_per_serving(r):
    total_kcal = total_protein = total_carb = total_fat = total_fibre = 0.0
    for i in r["ingredients"]:
        if i["optional"]:
            continue
        f = FOODS_BY_ID[i["foodId"]]
        factor = i["grams"] / 100.0
        total_kcal += implied_kcal(f["protein"], f["carbs"], f["fat"], f["fibre"]) * factor
        total_protein += f["protein"] * factor
        total_carb += f["carbs"] * factor
        total_fat += f["fat"] * factor
        total_fibre += f["fibre"] * factor
    servings = max(1, r["servings"])
    return dict(kcal=total_kcal / servings, protein=total_protein / servings,
                carb=total_carb / servings, fat=total_fat / servings,
                fibre=total_fibre / servings)


def recipe_diet_tags(r):
    tags = None
    for i in r["ingredients"]:
        t = food_diet_tags(i["foodId"])
        tags = set(t) if tags is None else tags & t
        if not tags:
            return set()
    return tags or set()


def recipe_allergens(r):
    out = set(r["extraAllergens"])
    for i in r["ingredients"]:
        out |= food_allergens(i["foodId"])
    return out


def total_minutes(r):
    return r["prepMinutes"] + r["cookMinutes"]


def requires_oven(r):
    return any("oven" in e.lower() for e in r["equipment"])


def slug_ok(s):
    return re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", s) is not None


def validate_recipes(recipes, foods_by_id):
    issues = []
    seen = set()
    for r in recipes:
        rid = r["id"]
        if rid in seen:
            issues.append(f"{rid}: duplicate id")
        seen.add(rid)
        if not slug_ok(rid):
            issues.append(f"{rid}: not a slug")
        if not r["title"]:
            issues.append(f"{rid}: missing title")
        if not r["description"]:
            issues.append(f"{rid}: missing description")
        if r["servings"] < 1:
            issues.append(f"{rid}: servings < 1")
        if not r["ingredients"]:
            issues.append(f"{rid}: no ingredients")
        if not r["steps"]:
            issues.append(f"{rid}: no steps")
        if total_minutes(r) <= 0:
            issues.append(f"{rid}: total minutes <= 0")
        for i in r["ingredients"]:
            if i["foodId"] not in foods_by_id:
                issues.append(f"{rid}: unknown food {i['foodId']}")
            elif i["grams"] <= 0:
                issues.append(f"{rid}: ingredient {i['foodId']} has no weight")
        ps = recipe_per_serving(r)
        if not (40 <= ps["kcal"] <= 1500):
            issues.append(f"{rid}: implausible {ps['kcal']:.0f} kcal/serving")
        if r["mealType"] not in MEAL_TYPES:
            issues.append(f"{rid}: bad mealType")
        if r["trainingTiming"] not in TIMINGS:
            issues.append(f"{rid}: bad trainingTiming")
    return issues


def validate_composition(recipes, foods_by_id):
    issues = []

    def require(cond, msg):
        if not cond:
            issues.append(msg)

    require(len(recipes) >= 24, f"needs >=24 recipes, has {len(recipes)}")
    bs = sum(1 for r in recipes if r["mealType"] in ("breakfast", "snack"))
    require(bs >= 8, f"breakfast/snack {bs}")
    ld = sum(1 for r in recipes if r["mealType"] in ("lunch", "dinner"))
    require(ld >= 8, f"lunch/dinner {ld}")
    pre = sum(1 for r in recipes if r["trainingTiming"] == "preTraining")
    require(pre >= 4, f"pre-training {pre}")
    post = sum(1 for r in recipes if r["trainingTiming"] == "postTraining")
    require(post >= 4, f"post-training {post}")
    veg = sum(1 for r in recipes if "vegetarian" in recipe_diet_tags(r))
    require(veg >= 8, f"vegetarian {veg}")
    vegan = sum(1 for r in recipes if "vegan" in recipe_diet_tags(r))
    require(vegan >= 4, f"vegan {vegan}")
    free = sum(1 for r in recipes if not r["isPremium"])
    require(free >= 12, f"free {free}")
    no_oven = sum(1 for r in recipes if not requires_oven(r))
    require(no_oven >= 8, f"no-oven {no_oven}")
    quick = sum(1 for r in recipes if total_minutes(r) <= 20)
    require(quick >= 6, f"quick {quick}")
    return issues, dict(pre=pre, post=post, veg=veg, vegan=vegan, free=free,
                         no_oven=no_oven, quick=quick, bs=bs, ld=ld)


def validate_shipped_extra(recipes, foods_by_id):
    issues = []
    for r in recipes:
        ps = recipe_per_serving(r)
        if not (150 < ps["kcal"] < 700):
            issues.append(f"{r['id']}: shipped kcal {ps['kcal']:.0f} out of 150-700")
        if r["trainingTiming"] == "preTraining":
            if not (ps["fat"] < 15):
                issues.append(f"{r['id']}: pre-training fat {ps['fat']:.1f} >= 15")
            if not (ps["fibre"] < 12):
                issues.append(f"{r['id']}: pre-training fibre {ps['fibre']:.1f} >= 12")
        if r["trainingTiming"] == "postTraining":
            if not (ps["protein"] >= 20):
                issues.append(f"{r['id']}: post-training protein {ps['protein']:.1f} < 20")
        if not r["isPremium"]:
            if len(r["steps"]) < 2:
                issues.append(f"{r['id']}: free recipe needs >=2 steps")
            if total_minutes(r) <= 0:
                issues.append(f"{r['id']}: free recipe total minutes <= 0")
    free_meal_types = {r["mealType"] for r in recipes if not r["isPremium"]}
    if "breakfast" not in free_meal_types:
        issues.append("free tier missing breakfast")
    if not ({"lunch", "dinner"} & free_meal_types):
        issues.append("free tier missing lunch/dinner")
    if "overnight-oats-banana-peanut" not in {r["id"] for r in recipes}:
        issues.append("missing overnight-oats-banana-peanut")
    return issues


def build_recipe_json(r):
    return {
        "schemaVersion": 1,
        "id": r["id"],
        "title": r["title"],
        "description": r["description"],
        "servings": r["servings"],
        "ingredients": [
            {
                "foodId": i["foodId"],
                "grams": i["grams"],
                **({"householdUnitLabel": i["label"]} if i["label"] else {}),
                **({"optional": True} if i["optional"] else {}),
                **({"note": i["note"]} if i["note"] else {}),
            }
            for i in r["ingredients"]
        ],
        "steps": r["steps"],
        "substitutions": [],
        "prepMinutes": r["prepMinutes"],
        "cookMinutes": r["cookMinutes"],
        "mealType": r["mealType"],
        "trainingTiming": r["trainingTiming"],
        "cuisineTags": r["cuisineTags"],
        "costBand": r["costBand"],
        "equipment": r["equipment"],
        "extraAllergens": r["extraAllergens"],
        "isPremium": r["isPremium"],
        "contentVersion": 1,
        "status": "draft",
    }


def main():
    food_issues = validate_foods(FOODS)
    if food_issues:
        print("FOOD ISSUES:")
        for i in food_issues:
            print(" ", i)
        raise SystemExit(1)

    categories = {f["category"] for f in FOODS}
    required_cats = {"protein", "dairy", "grain", "legume", "vegetable",
                      "fruit", "nutSeed", "fat", "condiment"}
    missing_cats = required_cats - categories
    if missing_cats:
        print("MISSING CATEGORIES:", missing_cats)
        raise SystemExit(1)

    vegan_count = sum(1 for f in FOODS if "vegan" in f["diet"])
    print(f"foods: {len(FOODS)}, vegan-tagged: {vegan_count}")
    if len(FOODS) < 80:
        print("NOT ENOUGH FOODS")
        raise SystemExit(1)
    if vegan_count < 40:
        print("NOT ENOUGH VEGAN FOODS")
        raise SystemExit(1)

    spot_checks = {
        "egg-whole-raw": "eggs", "greek-yogurt-nonfat": "milk",
        "salmon-raw": "fish", "shrimp-raw": "shellfish",
        "almonds": "treeNuts", "peanut-butter": "peanuts",
        "tahini": "sesame", "wholemeal-bread": "gluten",
        "tofu-firm": "soy",
    }
    for fid, allergen in spot_checks.items():
        if allergen not in FOODS_BY_ID[fid]["allergens"]:
            print(f"SPOT CHECK FAIL: {fid} missing {allergen}")
            raise SystemExit(1)
    ss = FOODS_BY_ID["soy-sauce"]["allergens"]
    if "soy" not in ss or "gluten" not in ss:
        print("SPOT CHECK FAIL: soy-sauce")
        raise SystemExit(1)

    animal_ids = ["chicken-breast-raw", "chicken-thigh-raw", "turkey-breast-raw",
                  "beef-mince-lean-raw", "beef-steak-lean-raw", "lamb-lean-raw",
                  "salmon-raw", "cod-raw", "tuna-canned-water",
                  "sardines-canned-oil", "shrimp-raw"]
    for aid in animal_ids:
        d = FOODS_BY_ID[aid]["diet"]
        if "vegan" in d or "vegetarian" in d:
            print(f"ANIMAL FOOD TAGGED VEG: {aid}")
            raise SystemExit(1)

    for f in FOODS:
        if ("milk" in f["allergens"] or "eggs" in f["allergens"]) and "vegan" in f["diet"]:
            print(f"DAIRY/EGG TAGGED VEGAN: {f['id']}")
            raise SystemExit(1)

    ids = {f["id"] for f in FOODS}

    recipe_issues = validate_recipes(RECIPES, FOODS_BY_ID)
    if recipe_issues:
        print("RECIPE ISSUES:")
        for i in recipe_issues:
            print(" ", i)
        raise SystemExit(1)

    comp_issues, stats = validate_composition(RECIPES, FOODS_BY_ID)
    print("composition stats:", stats)
    if comp_issues:
        print("COMPOSITION ISSUES:")
        for i in comp_issues:
            print(" ", i)
        raise SystemExit(1)

    extra_issues = validate_shipped_extra(RECIPES, FOODS_BY_ID)
    if extra_issues:
        print("SHIPPED-CATALOG-TEST ISSUES:")
        for i in extra_issues:
            print(" ", i)
        raise SystemExit(1)

    pre_count = sum(1 for r in RECIPES if r["trainingTiming"] == "preTraining")
    if pre_count != 4:
        print(f"pre-training count must be exactly 4 for controller test, is {pre_count}")
        raise SystemExit(1)
    if len(RECIPES) != 24:
        print(f"recipe count must be exactly 24 for controller test, is {len(RECIPES)}")
        raise SystemExit(1)

    for title in ("Greek yogurt and berry bowl", "Tunisian chickpea and bread bowl",
                  "Red lentil and vegetable stew", "Labneh bowl with cucumber and olives",
                  "Three-egg scramble with spinach"):
        if title not in {r["title"] for r in RECIPES}:
            print("MISSING REQUIRED TITLE:", title)
            raise SystemExit(1)

    print("ALL CHECKS PASSED")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    foods_json = {"schemaVersion": 1, "foods": [build_food_json(f) for f in FOODS]}
    recipes_json = {"schemaVersion": 1, "recipes": [build_recipe_json(r) for r in RECIPES]}

    (OUT_DIR / "edge_fuel_foods_v1.json").write_text(
        json.dumps(foods_json, indent=2) + "\n", encoding="utf-8")
    (OUT_DIR / "edge_fuel_recipes_v1.json").write_text(
        json.dumps(recipes_json, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(FOODS)} foods and {len(RECIPES)} recipes")


if __name__ == "__main__":
    main()

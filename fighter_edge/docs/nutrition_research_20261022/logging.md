# Food logging and tracking: how successful nutrition apps do it

Date: 2026-10-22. Scope: Fighter Edge Fuel redesign, topic = logging and tracking.

Notes on method and honesty:
- NUTRITION_COMPETITOR_RESEARCH.md was NOT found in the repo (searched fighter_edge/docs), so I could not dedupe against it. I did read repo hints: the app bundles a 94-food USDA-derived table, USDA proxy and barcode/photo are "V1.5/LATER", and docs/UX_RETENTION_RESEARCH_20260923.md already cites MacroFactor "adherence neutral". I avoid repeating those and go deeper.
- Many "comparison" pages online are written by competing apps (Nutrola, NutriScan, Fitia, etc.). I flag those as vendor claims. Reddit could not be fetched directly (blocked); Reddit themes below are second-hand via blogs and are marked as such.
- Everything marked UNVERIFIED could not be confirmed from a primary source.

---

## 1. Fastest paths to log

### What each app actually offers (verified from first-party pages unless noted)

**MacroFactor** (best-documented, most relevant to a serious tracker)
- Input methods: barcode scanner, nutrition-label scanner (auto fallback when a barcode fails), search, "AI Describe" (voice or text), AI photo logging, Quick Add (calories/protein/fat/carbs, no food needed), custom foods, recipes. Source: https://macrofactor.com/new-food-logger/ and https://macrofactor.com/macrofactor/
- Multi-Add: from search results, tap a food and its default serving goes straight onto the "Plate" without leaving the sheet. The app remembers the most recently used serving, so staples need no re-adjusting. Source: https://macrofactor.com/new-food-logger/
- Time-aware defaults: the app learns which foods you eat at which hour and surfaces them ("hourly go-tos"). A 24-hour timeline replaces fixed meal buckets; items default to the current hour; press-and-hold an hour (or the calendar icon) to pre-log or back-log. Source: same page.
- Custom serving keyboard for fast serving selection; "create and add the food in one tap". Same page.
- Copy/paste: single food, multi-select, or a whole day, pasted to any date/time. Source (secondary, MacroFactor blog snippet and a podcast host): https://www.witsandweights.com/podcast-episodes/my-7-favorite-food-logging-hacks-with-macrofactor ("copy yesterday's 7 a.m. entry, paste to today in two taps" is one podcast host's description, not a measured figure).
- Usage: the team says users open the logger "4-6 times a day" and benchmarked 20 food loggers; it promised a separate article quantifying speed. No measured seconds or tap counts are published in the page I read. Other "MacroFactor is faster" tap tables are third-party and methodology-free (UNVERIFIED).

**Cronometer** (forum answers, so labels may have changed)
- Copy a day or a selection: web gear icon, or mobile multi-select then Copy then Paste on the target day. Whole meal group can be copied. Source: https://forums.cronometer.com/discussion/comment/501 and related threads.
- Users have long asked for saved "meals" in one step; workaround is "Create Recipe From Selected Items", after which it appears as a custom food. Source: https://forums.cronometer.com/discussion/231/saving-a-group-of-foods-together-like-myfitnesspal-meals
- Gold-tier barcode details: not verified.

**MyFitnessPal**
- 2026 tiers per a company press release (syndicated): Free, Premium $79.99/yr, Premium+ $99.99/yr. Premium unlocks Meal Scan, Barcode Scan, Voice Log; Premium+ adds Meal Planner. Source: https://lite.aol.com/sports/other/story/0022/20260224/9659625.htm. Whether a limited free barcode scanner remains is disputed between third-party sources (UNVERIFIED).
- Home screen: calories remaining shown in the middle with goal, food, exercise, net (third-party descriptions only).

**Lose It!**
- Snap It (photo), voice, barcode. Company press release (Apr 2025) claims "3.5x faster meal logging", "6% more weight loss", "twice as many foods logged" with no sample size or method in the release. Treat as marketing. Source: https://www.newswire.com/news/lose-it-finds-ai-powered-logging-boosts-weight-loss-success-and-22557702
- Competing-vendor speed tests give Snap It 5-11 s per recognition and 68.7% food ID rate; methods undisclosed, UNVERIFIED. https://ai-food-tracker.com/reviews/lose-it/

**Yazio**: free vs Pro split unclear in sources (one says barcode is Pro; another disagrees); offline use reportedly limited; Quick Add / copy not confirmed. UNVERIFIED. https://nutriscan.app/blog/posts/yazio-pricing-2026-free-vs-pro-what-pro-unlocks-33b26f8fc7

**Lifesum**: store listing says photo, voice, text or barcode, plus "quick tracking". Post-redesign complaint: meal categories replaced and meals auto-filed under breakfast/dinner by time entered; developer told users to turn off "Multimodal Tracking" in settings. Source: https://apps.apple.com/app/286906691 (reviews) . Meal-category re-filing by clock time is a good "what to avoid" example.

**Carbon Diet Coach**: logging is in service of a weekly check-in; at check-in you declare "tracked everything / tracked some meals / didn't track but met targets / tracked in another app" (and can type weekly totals or daily averages). Partial tracking = targets held, not penalised. Source: https://help.joincarbon.com/en/articles/16105189-which-tracking-option-should-i-choose-at-check-in (search summary). Lesson: a "weekly totals" path is a legitimate low-effort mode.

**Noom**: ingredient-level logging described as tedious by a 90-day reviewer (anecdotal); colour coding (green/yellow/orange, originally red) by calorie density. https://www.garagegymreviews.com/noom-review

**FatSecret**: free Basic API (5,000 calls/day) requires attribution; relevant only if you ever go online. https://platform.fatsecret.com/api-editions

### Measured time-to-log (what is public)
- No independent head-to-head timing study of barcode vs search vs photo vs voice was found.
- Vendor numbers (Nutrola, a competitor; own platform data): photo ~8 s, barcode ~12 s, manual search ~47 s per meal. Generic vendor ranges elsewhere: manual 30-120 s per item, barcode 3-5 s. All UNVERIFIED. https://nutrola.app/en/blog/nutrition-tracking-methods-compared-manual-barcode-photo-voice-ai
- Peer-reviewed, small: 28-day pilot, 18 people, voice vs text logging: 1.7x more distinct logging events in voice arm, more dropouts in text arm. Engagement not per-entry time. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10230351/
- Time actually spent: Harvey 2019 (n=142, internet weight-loss programme) found 23.2 min/day month 1 falling to 14.6 min/day month 6; time spent did NOT differ between people who did and did not lose weight, but login frequency did (those losing >=5% logged ~2.4 times/day vs 1.6). Source: https://onlinelibrary.wiley.com/doi/10.1002/oby.22382 (figures via search summary; abstract values should be re-checked before quoting).
- SnappyMeal (arXiv, 21 days, >500 logged items): users liked multiple input modes, many preferred images, none chose audio; missed logs mostly because logging felt time-consuming or they forgot. https://arxiv.org/abs/2511.03907

Takeaway: the pattern across apps is "repeat what you already ate" (recents, time-of-day suggestions, remembered serving, copy day/meal) plus a zero-database escape hatch (Quick Add). Capture methods (photo/voice) add reach but are less accurate (section 6).

---

## 2. Food database approach

| App | Approach | Notes |
|---|---|---|
| MyFitnessPal | Large, largely user-submitted | Duplicates and conflicting values are the standard complaint. Size claims range ~14M-20.5M (UNVERIFIED). |
| Cronometer | Curated: USDA, NCCDB etc., staff review submissions | Own blog: staff review every submission. Peer-reviewed support below. https://cronometer.com/blog/small-is-better/ |
| MacroFactor | "Verified" ~1.36M items; vetted research databases plus human-verified submissions; unknown barcodes/outdated labels go to Open Food Facts; label scanner and "copy to custom" for gaps; no user-submitted Common Foods or recipes | https://help.macrofactorapp.com/en/articles/25-how-robust-is-the-database-coverage-in-my-region . A 2.7.0 release note says OFF-sourced entries are machine-validated, not guaranteed human-verified, and "the majority" of branded foods are human-verified, so "verified" is not absolute. https://macrofactor.com/version-2-7-0/ |
| Lose It! | Claims 63M items (press release) | Marketing figure. |
| FatSecret | Own database plus API | Attribution required. |

Evidence on accuracy:
- Morello et al. 2025 (n=43 Canadian endurance athletes, same food records entered in both apps): Cronometer showed good reliability/validity for nearly all nutrients (exceptions: fibre, vitamins A and D); MyFitnessPal showed poor validity for energy, carbs, protein, cholesterol, sugar, fibre. Via search summary of https://biolayne.com/reps/issue-45/comparing-myfitnesspal-to-cronometer-for-fitness-assessment-among-athletes/ . Directly relevant: athletes.
- No study found that directly measures duplicate rates in MFP or Cronometer. Claims like "30/30 vs 11/30 within 5% of USDA" are from a coaching site with no method: UNVERIFIED.
- Regional gap (MacroFactor's own admission): strong barcode coverage in US, CA, UK, AU, IE, NZ, JP, FR, ES; weak elsewhere; restaurant items weak everywhere; staples fine everywhere because values do not vary much by locality. This matters for a global fighter audience.

Serving-size UX patterns: remember last-used serving; allow grams as first-class; custom keyboard for fast serving entry; "copy to custom" to fix an entry without waiting for moderators; Cronometer users report edits being overwritten by database updates (forum complaint, avoid by versioning user overrides). https://forums.cronometer.com/discussion/comment/20196

### Free / open data an indie app can legally use

| Source | Licence | What it gives | Catches |
|---|---|---|---|
| USDA FoodData Central (Foundation, SR Legacy, FNDDS, Branded) | CC0 1.0 public domain; USDA asks (does not require) credit to FoodData Central. API default 1,000 requests/hour/IP, key required. https://fdc.nal.usda.gov/api-guide | Bulk JSON/CSV downloads: Foundation (Apr 2026), SR Legacy (final, Apr 2018), FNDDS (2021-2023, Oct 2024), Branded (Apr 2026). https://fdc.nal.usda.gov/download-datasets/ (the download page itself shows no licence text; licence is on the API guide) | US-centric. Branded dataset is US labels. FNDDS gives portion descriptions useful for serving UX. |
| Open Food Facts | Database: ODbL. Contents: DbCL. Images: CC BY-SA. Must credit OFF with link; share-alike applies to derivative databases; no guarantee of accuracy and "not for medical purposes"; use a custom User-Agent for API calls. https://world.openfoodfacts.org/terms-of-use , https://support.openfoodfacts.org/help/en-gb/12-api-data-reuse/94-are-there-conditions-to-use-the-api | Barcode lookups worldwide. Daily dumps: JSONL.gz, CSV.gz (~0.9 GB compressed, ~9 GB uncompressed per the data page), Parquet on Hugging Face. | Share-alike: if you merge OFF into your own database, that combined database must be open under ODbL. Keep OFF as a separate, attributed layer and consider publishing it; the terms do not say apps must be open source (I am not a lawyer; email reuse@openfoodfacts.org to confirm). Do not bundle the images. Current product counts and nutrition-completeness not verified. |
| Canadian Nutrient File | Open Government Licence - Canada (per portal) https://open.canada.ca/data/en/dataset/1b6139bd-ed7e-4043-bc28-ff00e10f3109 | Generic foods | Verify terms before shipping. |
| UK CoFID (McCance & Widdowson) | Crown copyright, reportedly OGL v3 (secondary source; verify at gov.uk) | Generic foods | UNVERIFIED primary. |
| ANSES Ciqual (France) | reportedly Licence Ouverte/Etalab (secondary source) | Generic foods | UNVERIFIED primary. |
| FatSecret Platform API | Free Basic tier 5,000 calls/day with mandatory attribution; Premier Free for startups under US$1M revenue | Online API | Online-only, terms on caching not verified; conflicts with offline-first. https://platform.fatsecret.com/terms |
| Fineli, NEVO, others | Not verified | | UNVERIFIED |

Practical reading for an offline-first indie app: bundle a curated, hand-checked generic-food table (USDA Foundation/SR Legacy are CC0 and safe to bundle), add regional dishes you write yourself with a `source` field (the repo already does this), and do barcode as an optional online lookup against OFF with a local cache of items the user has scanned (cache stays on device, so share-alike exposure is small, still confirm). Offer label-scan / manual label entry as the fallback, mirroring MacroFactor.

---

## 3. The daily screen

MacroFactor (first-party help: https://help.macrofactorapp.com/en/articles/22-get-to-know-your-dashboard , /225-understanding-the-widgets-at-the-top-of-the-dashboard):
- Three swipeable widgets at the top, one per time scale: week ("Nutrition & Targets" stacked bars per day for kcal/protein/fat/carbs with today boxed), month ("Energy Balance"), today ("Daily Nutrition").
- Today: calories remaining, consumed and target in the top row; macros below; a "Remaining" toggle flips macros between consumed and remaining; per nutrient you can show % / consumed / remaining. The company says some users want consumed-vs-target and "meal planners" want remaining budget, so it is a one-tap, remembered preference.
- Vitamins/minerals are collapsed behind an expand. Dashboard order is user-customisable.
- Whether rings are used: unverified for MacroFactor.

Carbon (release 76): daily rings for macro progress and weigh-ins on the Coach tab, tappable; tracking visuals show which days are complete or missing data; tap into a day to add missing meals/weight before check-in; in-week nudges when calories run high or protein runs short. A day counts as compliant when minimum protein and total calories are met; carbs and fat can vary. Source: https://www.joincarbon.com/blog/release-76 and https://help.joincarbon.com/en/articles/6004813-why-compliance-is-the-foundation-of-your-progress-in-carbon. This is a nicely small definition of "on target".

MyFitnessPal: remaining calories centred, goal/food/exercise/net around it (third-party description; exercise adds to budget).

Lifesum: green plus button at bottom right and per-meal sections; food, meal and day ratings (users ask to make ratings optional). https://www.active.com/nutrition/articles/lifesum-review

Pattern: lead with "remaining" (calories, then protein), macros second, micros hidden by default, meal-by-meal list below, with a one-tap "log" action always visible.

---

## 4. Streaks vs adherence, and what research says

Design approaches:
- MacroFactor "adherence neutral": no red numbers, no frowny/smiley faces on foods, no warning pop-ups for overshoot; argument is that shame makes people "stop logging for the day when they exceed target", corrupting data; coaching works from weight trend and intake regardless of adherence. https://macrofactor.com/adherence-neutral/ . Its Habits section shows logging consistency over time (design philosophy on streaks not documented). https://help.macrofactorapp.com/dashboard/consistency
- Carbon: adherence is explicit but purpose-framed (clean data gives better target changes); partial week means "hold", not "fail".
- No controlled evidence found that streaks raise food-logging adherence. A trial (NCT07555262) is testing streak-feedback reminders vs loss-framed vs neutral; no results yet. Claims in vendor blogs about streak mechanics and a "JAMA Psychiatry" gamification dropout finding: UNVERIFIED.

Research on logging consistency and outcomes (all observational, so association not cause):
- Retrofit 6-month programme (n=2,113 completers, JMIR 2017): mean weight loss by food-log days per week: <1 day 3.67%; 1-2 days 4.32%; 3-4 days 5.15%; >=5 days 8.20%. Entry count per week mattered less than days logged. Source: https://pmc.ncbi.nlm.nih.gov/articles/PMC5446667
- MyNetDiary cohort (n=5,132, JMIR 2026; authors work for the company): tracking 6-7 days/week 11.33% loss; 2-3 days/week 7.35%; <2 days/week 6.84%; longest streak >90 days 11.55% vs <=7 days 4.21%. Authors caution motivated users self-select. https://www.eurekalert.org/news-releases/1141289 . Note the 2-3 days/week group still lost a lot: partial logging is worth supporting.
- Minimum thresholds (n=74, 12 months): >=3 days/week linked to less regain; largest benefit >=5 days/week. Not randomised. https://pmc.ncbi.nlm.nih.gov/articles/PMC10972539/
- Sources I could not verify: dose-response figures quoted by blogs (Ingels 2017; Harvey 24-month adherence; a "2008 Kaiser trial").
- Why people stop: a CHI 2015 survey (141 current and lapsed journalers; 94 of 141 had lapsed per one source, attribution between the two papers unverified) cites effort, uncertainty about eating out, embarrassment logging in front of others, and "negative nudges" (people choose foods because they are easy to log). https://www.researchgate.net/publication/282348764_Barriers_and_Negative_Nudges_Exploring_Challenges_in_Food_Journaling
- Risk: Levinson 2017 (n=105 with eating disorders; ~75% used MFP; 73% of those felt it contributed to their disorder) and Simpson and Mazzeo 2017 (n=493 students) link tracking apps to disordered-eating symptoms; associational, self-report; motive matters more than tracking per se. Secondary sources only. https://examine.com/conditions/disordered-eating/faq/does-macronutrient-tracking-cause-disordered-eating . A 2024 paper looks at dietary restraint and emotional eating among elite combat-sport athletes (abstract not read): https://doi.org/10.1080/1612197X.2024.2308884 . Rapid weight loss is common in combat sports (one survey: 95.7% of athletes; ISSN position stand). https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11894756/

Implication: reward "days with a meaningful log" and weekly coverage (e.g. "5 of 7 days"), not an unbroken chain; make partial days count; never shame overshoot.

---

## 5. Complaints and mistakes to avoid

(Source quality: third-party blogs, several by competitors; app-store text not directly retrieved; Reddit unreachable. Themes recur across independent reviews.)
1. Paywalling basics that used to be free, especially barcode scanning. One analysis of 202 negative reviews found 59 mention Premium/paywall, 27 the barcode scanner (vendor blog, UNVERIFIED). https://unstar.app/blog/is-myfitnesspal-premium-worth-it-paywall-app-reviews-2026
2. Crowd-sourced duplicates and wrong values (chicken breast 165 vs 280 kcal; protein bar 180 vs 230 on the label). Vendor examples; theme is credible.
3. Ads interrupting a daily 30-second task.
4. Redesigns that move or rename core flows (Lifesum meal categories re-filed by clock time; users asked how to turn the new mode off).
5. Barcode returning wrong products (Noom reviewers).
6. Subscription billing and cancellation friction (Trustpilot 1.6/5 for MFP is a single secondary source).
7. Ingredient-by-ingredient recipe logging being tedious; adding whole meals as one number is skewed (Noom reviewer).
8. Judging foods: colour or rating systems that label foods "bad" (Noom changed red to orange after criticism; Lifesum users want ratings optional).
9. Entries edited by users getting overwritten by database updates (Cronometer forum).
10. Georgia Tech finding that databases have missing common foods or multiple listings, and mixed/party food is hardest to log (via search summary; page blocked).

---

## 6. Accuracy: portion error and what is honest to show

Facts:
- Photo AI: NIH/NIDDK controlled-feeding abstract (NUTRITION 2026, conference abstract, not peer-reviewed): MyFitnessPal, Lose It!, Cal AI and Appediet all under-estimated calories by ~250-345 kcal per meal and fat by ~30 g; 102 standardized meals (+200 preliminary); worse on ketogenic meals; carbs estimated more consistently than fat. https://www.eurekalert.org/news-releases/1136415 . The "345 kcal for Cal AI" and "mean 918 kcal meal" details come from one secondary source.
- Cal AI claims "about 80%" accurate (FAQ) or 90% (older post) with no method. No independent peer-reviewed Cal AI validation found. A competitor test (Nutrola, 60 meals) reports 14.2% MAPE for Cal AI (vendor, UNVERIFIED).
- A 2025 general vision-model study: MAPE 30.5% from photo alone, 13.9% when an ingredient list with amounts was added (via search summary; primary not opened). Portion size is the weakest link. Hidden oils, sauces, sugar in drinks are not visible.
- Systematic review of 52 AI food-image studies: average relative calorie error 0.10% to 38.3% (via summary).
- Self-report generally: doubly-labelled-water studies show underreporting from near 0 to -20% in lean non-athletic groups and -35 to -50% in obese groups; 7-day diet records under-report ~9% and FFQ ~18% vs DLW in one Japanese older-adult study; mobile food record ~10-12% under-reporting in one small study. (Search summaries of https://www.nature.com/articles/s43016-024-01089-5 and related; population is general public, not fighters.)
- No study found testing whether showing ranges/confidence changes user trust; a design argument (opinion) and a patent exist. Treat range display as a reasoned design choice, not an evidence-backed one.

What is honest to show:
- Weighed or label-based entries: show exact number.
- Estimated entries (photo, "a bowl of", volume): show an estimate flag and a plausible range (for photo/estimated items a rough +/-20-30% is supported by the numbers above but is my inference, not a published standard), skew the high side for fat-rich foods since apps systematically under-estimate fat.
- Label every entry with its source (bundled table, own entry, scanned label, estimate) and keep it editable.
- Show weekly averages and trend rather than single-day precision; MacroFactor's whole approach is that energy balance is inferred from trend weight, which absorbs logging error.
- Do not present calorie totals to the digit when half the entries are estimated.

---

## 10 ranked recommendations (offline-first, free data, privacy-first, fighters)

1. **Recents + "usual at this time" + remembered serving; one-tap add** (Effort S-M). Biggest time saver in every top app (MacroFactor Multi-Add/hourly go-tos). All local, no data needed. Needs only a local usage table.
2. **Quick Add calories/protein (and optional macros) as a first-class, always-visible action, plus "I ate about X" meal-size presets** (S). Zero-database path for restaurants, camp meals, eating-out uncertainty; Carbon and MacroFactor both treat approximate logging as valid.
3. **Copy yesterday / copy meal / copy a day, and "save meal as template"** (S-M). Fighters repeat meals during camp; Cronometer users still ask for template meals, so doing it well is a differentiator.
4. **Bundled curated food table (USDA CC0 plus self-sourced regional/Mediterranean items with a visible `source`)** with grams-first serving entry and household measure conversions (M). Quality beats size; Cronometer-style curation shows better validity than crowd data (Morello 2025). Avoids duplicates entirely because you control the table. Add regional foods your audience actually eats.
5. **Daily screen: "Remaining" kcal and protein first, macros second, micros hidden; consumed/remaining toggle remembered** (S). Mirrors MacroFactor and Carbon. Defines "on target" as protein minimum + calorie window rather than every macro.
6. **Adherence-neutral feedback: no red numbers, no food scoring, partial days count, weekly "days logged x/7" coverage instead of an unbroken streak** (S). Research ties days-per-week logged (>=5) to outcomes, and 2-3 days still helps, so reward coverage; avoid streak-loss shame. Combat sports have weight-cut and restraint risks, so avoid moralising.
7. **Weekly mode for tired or hectic weeks: enter weekly or daily totals, or "didn't log, on plan"** (S-M). Carbon's check-in shows this is accepted; protects the data without punishing gaps. Mark such days as "approximate".
8. **Estimate honesty layer: per-entry source tag (weighed/label/estimate) and range for estimates, fat-leaning high for photo/volume guesses** (M). This is where you can be more truthful than Cal AI-style single numbers; evidence supports under-estimation of fat. No-evidence caveat: range display effects on trust are untested.
9. **Optional barcode via Open Food Facts with on-device cache, label-entry fallback, attribution and ODbL review** (M-L). Useful for packaged food (supplements, bars) but weak coverage by region and share-alike obligations; make it opt-in and degrade gracefully offline. Do this after 1-8.
10. **Voice/text "describe" logging that only maps to your own bundled foods and presets (on-device parsing first), no photo logging at launch** (L). Voice has the best small-trial engagement result but heavy implementation; photo is demonstrably under-reading fat and carries privacy cost. Defer until the data layer is strong. Fits the repo rule that deterministic calculations are authoritative and any AI only assists.

---

## Source list (primary or first-party first)
- https://macrofactor.com/new-food-logger/
- https://macrofactor.com/adherence-neutral/
- https://help.macrofactorapp.com/en/articles/25-how-robust-is-the-database-coverage-in-my-region
- https://help.macrofactorapp.com/en/articles/22-get-to-know-your-dashboard
- https://help.macrofactorapp.com/en/articles/225-understanding-the-widgets-at-the-top-of-the-dashboard
- https://macrofactor.com/version-2-7-0/
- https://www.joincarbon.com/blog/release-76
- https://help.joincarbon.com/en/articles/6004813-why-compliance-is-the-foundation-of-your-progress-in-carbon
- https://help.joincarbon.com/en/articles/16105189-which-tracking-option-should-i-choose-at-check-in
- https://forums.cronometer.com/discussion/comment/501
- https://cronometer.com/blog/small-is-better/
- https://fdc.nal.usda.gov/api-guide
- http://fdc.nal.usda.gov/download-datasets/
- https://world.openfoodfacts.org/terms-of-use
- https://support.openfoodfacts.org/help/en-gb/12-api-data-reuse/94-are-there-conditions-to-use-the-api
- https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/license-be-on-the-legal-side/
- https://open.canada.ca/data/en/dataset/1b6139bd-ed7e-4043-bc28-ff00e10f3109
- https://platform.fatsecret.com/api-editions
- https://pmc.ncbi.nlm.nih.gov/articles/PMC5446667 (Retrofit, JMIR 2017)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC10972539/ (minimum thresholds)
- https://www.eurekalert.org/news-releases/1141289 (MyNetDiary cohort; JMIR doi 10.2196/98144)
- https://onlinelibrary.wiley.com/doi/10.1002/oby.22382 (Harvey 2019)
- https://www.eurekalert.org/news-releases/1136415 (NIH photo-app study)
- https://arxiv.org/abs/2511.03907 (SnappyMeal)
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10230351/ (voice vs text pilot)
- https://biolayne.com/reps/issue-45/comparing-myfitnesspal-to-cronometer-for-fitness-assessment-among-athletes/
- https://www.researchgate.net/publication/282348764_Barriers_and_Negative_Nudges_Exploring_Challenges_in_Food_Journaling
- https://www.newswire.com/news/lose-it-finds-ai-powered-logging-boosts-weight-loss-success-and-22557702
- https://lite.aol.com/sports/other/story/0022/20260224/9659625.htm
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11894756/ (ISSN combat-sport weight-cut stand)
- Vendor/secondary (weak): nutrola.app, nutriscan.app, unstar.app, garagegymreviews.com, examine.com, ai-food-tracker.com

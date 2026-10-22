# Fighter Edge Fuel redesign: retention, decision support, tone, privacy, pricing

Researched 2026-10-22. Tags: [V] = read on a primary or official page this session; [S] = secondary/third-party source; [U] = unverified or my own inference. Nothing here is an invented statistic. Where a number is vendor- or competitor-blog-sourced it is marked [S].

## 0. Scope notes and repo findings

- `fighter_edge/docs/NUTRITION_COMPETITOR_RESEARCH.md` does not exist in the repo (checked docs/ and a glob for *NUTRITION*). I did not repeat it. I did read `docs/UX_RETENTION_RESEARCH_20260923.md` (§4.2-4.5, §6) and `docs/PRODUCT_MONETIZATION_STRATEGY.md` and avoided repeating them except where I found a correction (see 0.2).
- Current Fuel code already has a deterministic engine: `lib/features/edge_fuel/domain/calculators/fuel_match_calculator.dart` ranks recipes at 0.5-2.5 servings against remaining kcal/macros, filters allergens/diet/budget/time/dislikes, returns max 3 options. Scoring weights are kcal 0.48, protein 0.30, carbs 0.16, fat 0.06, with an overshoot penalty above 112% of remaining kcal. There is no "protein-only gap" mode.
- Data: `assets/data/edge_fuel_recipes_v1.json` has 24 recipes, ALL `status: "draft"` (0 reviewed), 6 premium. `edge_fuel_foods_v1.json` has 93 foods. Mix: breakfasts 5, lunches 7, dinners 8, snacks ~4. Too small to avoid repetition inside a 4-week camp. I did not verify whether the UI hides draft content.
- Deps already present: `flutter_local_notifications`, `shared_preferences`, `firebase_analytics`, `firebase_crashlytics`, `purchases_flutter`. `firestore_edge_fuel_repository.dart` writes the nutrition setup draft to Firestore. I did not check exactly which fields (weight, height, allergens) are synced. That is the first thing to audit for the privacy checklist (§5).

### 0.2 Corrections to the existing in-repo research doc
- "Duolingo streak freeze cut churn by 21%" [U]: I could not find this. What I found on Duolingo's own blog is that allowing up to two freezes raised daily active learners by a relative +0.38% (company-reported). Treat the 21% as unverified.
- Health & Fitness trial-to-paid: the repo doc says 39.9% median / 68.3% top decile (2025 edition via secondary summary). The RevenueCat State of Subscription Apps 2026 page [V] gives 37.7% median, top quartile above 51.4%, download-to-paid 2.9% median.
- "73% said the app contributed to their disorder" (Levinson 2017) [S]: this was among MyFitnessPal users inside a clinically diagnosed eating-disorder sample, not all calorie-tracker users. Correlational, self-reported.

## 1. Onboarding to first log, time-to-value, retention drivers

What is actually known:
- No public source I could find gives measured time-to-first-log for MacroFactor, Cronometer, Yazio, Lose It or MyFitnessPal [U: gap]. Do not cite any number for this.
- Noom: RevenueCat teardown [V] says up to 113 screens, 10-15 minutes to click through, email gate about one third in, a 10-question behavioural quiz, "building your plan" loaders, then a "pay what you want" 14-day trial offer. Paywall arrives after about 100 screens. No Noom conversion numbers are public. The lesson is that each question visibly feeds a personalised plan. It is not "make it long".
- Yazio [S]: goal, then age/height/activity, then a personalised dashboard preview (progressive disclosure). MyFitnessPal [S]: video teardown shows paywall overlays ~38 s in; barcode scanning moved behind premium in 2024 triggered backlash.
- Benchmarks (cross-industry, [S] compilations of Adjust/AppsFlyer, primary reports not read): D1 ~25-26%, D7 ~11-13%, D30 ~5-7%. Health & Fitness D30 about 3-4% (Phiture compilation) and 3.4-3.9% (Braze). Definitions differ, so use only as a rough floor.
- RevenueCat 2026 H&F [V]: 82.1% of trial starts happen on Day 0; 54% of H&F trials are 5-9 days; median month-1 realised LTV $24.23.
- Why people drop food logging: Cordeiro et al., CHI 2015 [S via summaries]: survey of 141 current/lapsed journalers + 5,526 forum posts. Barriers were effort, partial portions/loose recipes, missing or duplicate database entries, and social features backfiring. A figure that only 3% of 190,000 downloads of one food-journal app led to more than a week of use is from a Big Think article [U: check original].
- Self-monitoring evidence for what to design around:
  - Harvey et al. 2019, Obesity [V via PubMed abstract summary]: 142 adults, 24 weeks. Time spent logging fell from 23.2 min/day in month 1 to 14.6 min/day in month 6. Time did not separate weight-loss groups; login frequency did (2.7 vs 1.7 per day for those losing at least 10%). Lesson: what matters is that people keep logging often, not how detailed each log is.
  - Burke-group 2019 (J Acad Nutr Diet) [S]: across two app trials (91 completers), days with at least 2 eating occasions logged was the best adherence marker for 6-month weight loss (~27% of variance). Lesson: "2 meals a day" is a sufficient logging target, and a fighter does not need 6.
  - Payne et al. 2022, Obesity Science and Practice [S]: 90 adults; weeks of consistent logging associated with percent weight loss. Original page was blocked (403), so details are from a search summary.
  - Patel et al. 2019 JMIR GoalTracker RCT [S]: 105 adults; self-monitoring declined over the trial; median days/week of diet tracking 1.9-5.3 by arm.
  All are weight-loss populations, not athletes. Transfer to fighters is [U].
- Caveat: the 2026 repo doc quotes RevenueCat's 55% Day-0 cancellations for 3-day trials. I did not re-verify that figure.

Design implication: the first log should happen inside the plan-reveal session, pre-filled, and ongoing logging should be as cheap as repeating a meal.

## 2. Notifications and gamification

Evidence:
- Drink Less micro-randomised trial, JMIR mHealth 2023 [V, PMC10337295]: 349 new users analysed (target 1,200, so underpowered). A notification raised the probability of opening the app in the next hour 3.5-fold (RR, 95% CI 2.91-4.25); observed open rate 8-9 pm was 12-13% with a notification vs 3.6% without. No significant decline over 30 days (daily change 0.993, CI 0.975-1.012), and habituation tests were non-significant but with wide CIs. New and standard message wording worked similarly (3.39x vs 3.66x). Takeaway: a well-timed notification reliably gets a short-window open; it does not prove it improves outcomes or retention.
- Opt-in rates [S, OneSignal 2024 data]: Health & fitness ~43.2% Android, ~33.5% iOS. Airship 2026 [S]: opted-in devices had a 2.9x higher Day-30 activation for one airline case (not health). Android 13+ runtime permission effect not measured in what I found.
- Apple: Time Sensitive level only for events happening now or within the hour; provisional authorization (iOS 12+) delivers quietly to Notification Center with Keep/Turn Off, no prompt [S: Apple HIG pages via search, not fully read].
- Streaks: Duolingo says freezes add slack and raise daily actives +0.38% [S, company]. The Decision Lab summarises a Journal of Consumer Research study (secondhand) that users can value the streak above the activity and are more likely to quit after breaking it [U: original not read]. For eating-disorder-risk users, streaks and logging reminders drive obsessive logging (BJPsych Open qualitative study, 24 women, 8 harm themes [V]).
- I found no study comparing weekly vs daily streaks in nutrition apps [U: gap]. The repo's weekly-consistency design is reasoned, not proven.

Design rules (reasoned from the above, [U] as to effect size):
1. Notification channels the user turns on separately: (a) session reminder, (b) pre-session fuel window, (c) weekly recap, (d) fight-week/weigh-in checklist. Default off until after the first completed session, with an in-app primer. Use iOS provisional authorization for (c).
2. All local (`flutter_local_notifications`) and schedule-driven (training plan), no server-side behavioural targeting. This is both privacy-cheaper and exactly the "event-based, not broadcast" pattern.
3. Hard cap one a day. Quiet hours default 21:00-07:00 and respect the sleep window of an athlete with early sessions. Auto-snooze a channel after 3 consecutive dismissals and ask once whether to keep it.
4. Content states what is next and why ("Session 18:00. A carb-rich snack around 15:30 helps."). Never mention what was missed, never a number the user is "behind" on.
5. No notification keyed to food logging at all by default (ED-risk, see §4). Offer an opt-in "log nudge" only.
6. Gamification: weekly session consistency ring ("3 of 4 sessions"), a "weeks hitting plan" counter with freezes, personal bests in drills. A miss is shown neutrally: "Rest week. Next session Thursday." Nothing red, no loss language. Food logging gets no streak and no completion bar.

## 3. Deterministic, explainable "what should I eat" (offline, no AI)

What competitors do:
- Cronometer "Suggest Food" [V via search/summary]: curated list of common foods/meals ranked against remaining daily targets; filters for diet type, categories and exclusions; each suggestion shows what it adds against targets. Gold only. A forum user complained protein-focused requests returned low-protein foods, so the ranker was not protein-first [S]. (Later versions are described as AI-driven [S].)
- MyFitnessPal Winter 2026 [S, press release]: Premium+ Meal Planner with Recipes tab and a "Blue Check" dietitian-reviewed collection of 8 recipes. Barcode/Meal Scan/Voice Log are Premium.
- Eat This Much [S]: user sets calories/macros/diet/time/budget; app generates a daily or weekly plan plus grocery list; pantry is premium. Algorithm not described [U].
- Mealime/other planners [S]: pick recipes, ingredients merge into a grocery list; planners like PlantStrong offer a "leftovers" button that doubles a recipe and updates the list. Mealime batch-cook support unconfirmed.
- MacroFactor: I found no official training-day/rest-day target feature or food-suggestion feature [U: gap]. Only a third-party directory claims "different targets for different days". Everfit (coaching platform) has a rest-day macro goal [S].

Sports-nutrition numbers you can hard-code (all from papers I fetched [V], but get a dietitian to sign off before shipping):
- ISSN nutrient timing 2017 [V]: protein 20-40 g (0.25-0.40 g/kg) per dose every 3-4 h; post-exercise protein from immediately to 2 h after; pre-exercise carbohydrate 1-4 g/kg several hours before higher-intensity or >90 min sessions; casein 30-40 g before sleep; recovery carbs 1.2 g/kg/h if under 4 h to next session; 0.6-1.0 g/kg within 30 min standard.
- ISSN combat sports/weight cut 2025 [V]: during camp minimum about 3.0-4.0 g/kg carbs, 1.2-2.0 g/kg protein (1.6-2.2 g/kg during weight descent per body text), 0.5-1.0 g/kg fat; meal 2-3 h before the first session; stay 12-15% above the division limit off-camp; acceptable pre-weigh-in loss 6.7%/5.7%/4.4% at 72/48/24 h; rehydration with oral solutions first, then carbs up to ~60 g/h, aim to regain at least 10% body mass; fibre limits around weigh-in.
- Train-low / carbohydrate periodisation (Impey et al. 2018) [S]: "fuel for the work required" is the right framing for rest vs hard day, but "train low" is an advanced, contested tactic. Do not ship it to amateurs.
- I could not retrieve the 2016 ACSM/AND/DC position-stand numbers [U]. Use ISSN above.

Proposed offline algorithms (my design, [U] as to user effect):
A. Gap picker ("Protein left today: 34 g"). Pool: about 40 curated add-ons with household portions (e.g. 200 g Greek yogurt, 3 eggs, 1 tuna can, 1 whey scoop, 150 g cottage cheese, 100 g edamame) plus the recipe set. Constraints: allergens/diet/dislikes (existing filters), calorie cap = remaining kcal x 1.1 (existing overshoot logic), and portion rounded to the household unit. Rank by protein delivered per kcal with a fat/carb tiebreak chosen from the day type. Show 3 options from 3 different food groups, each with a one-line reason: "Adds 31 g protein for 190 kcal. Leaves 3 g to go." If the gap exceeds 0.4 g/kg for one eating occasion, propose two smaller add-ons over two meals instead of one huge one (ISSN dose logic). Add a mode switch in `FuelMatchCalculator` (macro-first weights) instead of the current calorie-first 0.48/0.30/0.16/0.06.
B. Day-type templates keyed to scheduled sessions: rest, easy, hard (sparring/conditioning), double day, fight week. Protein is flat per kg; carbs scale with session load; the app picks meal slots (pre, post, main, snack) per day type. Pure function of the plan, so offline and testable.
C. Pre/post-session card: time-aware ("session 18:00, eat 2-3 h before: 1-2 g/kg carbs, low fat/fibre; within 2 h after: 0.25-0.4 g/kg protein plus carbs"). Content by lookup table. Recipe tag `trainingTiming` (preTraining/postTraining/any) already exists in the data model.
D. Meal prep and grocery list: choose N recipes, scale servings (existing portion calculator), merge by `foodId` and sum grams, show household labels, checkbox list stored locally, "cook x4 for 4 days" multiplier, share as plain text. No account needed.
E. Explainability: every suggestion shows its inputs (remaining numbers, day type, filters applied). Keep AI out of the numbers (matches CLAUDE.md rule).

## 4. Tone and safety for athletes

Evidence:
- Simpson and Mazzeo 2017 [S]: 493 college students; diet/fitness-app use associated with higher eating-disorder symptoms; correlational.
- Levinson et al. 2017 [S]: among MyFitnessPal users in an eating-disorder sample, 73% said the app contributed to their disorder; correlational.
- BJPsych Open qualitative study [V]: 24 women, mostly MyFitnessPal. Harm themes: fixation on numbers, rigid diet, obsession, dependency, achievement from under-eating, extreme negative emotion, motivation by "negative" messages, excess competition. Red indicators caused guilt irrespective of how far over; green indicators rewarded restriction; streaks and logging reminders drove compulsive logging; warnings sometimes motivated more restriction. Authors recommend fewer reminders/streaks, break modes without quantified data, non-calorie goals, nuanced non-punishing colour, and lived-experience input.
- Combat sports: a 2025 wrestling systematic review (8 studies) found wrestlers more susceptible to eating disorders than other athletes [S]; weight-cut prevalence in combat sport 66-100% in one cited review [S]; 88% of 187 Norwegian combat athletes regulated weight in the prior 12 months [S]; MMA athletes dieted more extremely than BJJ in a Swedish sample of 111 [S]. These are small, self-report studies. The "weight-cut culture" is the main risk for a fighter app.
- MacroFactor "adherence-neutral": company-stated design with no red numbers, no shaming, coaching independent of adherence [S: App Store listing and company pages]. The company's own page does not define the term in detail. No independent evaluation found. Treat as a good heuristic, not evidence of safety.
- NEDA's coach toolkit [S] advises removing weight/size/dieting messages from sport and referring to registered dietitians/therapists. I found NO NEDA or ACSM design guidance for nutrition apps specifically [U: gap]. Do not claim the app is "NEDA-compliant". The AIS/NEDC joint statement on disordered eating in high-performance sport and IOC RED-S resources exist [S, not read in full] and are citable for coach-facing copy.

Practical tone rules:
- Performance framing: fuel for sessions, energy availability, recovery, sleep, skill output. Targets are "fuel for Thursday's hard session", not "budget".
- No good/bad food labels, no "cheat"/"earn"/"burn off", no red/green over/under colouring, no praise for being under target, no calorie-deficit leaderboards.
- Numbers neutral: single neutral accent, "left today" language, no overshoot warnings.
- Weight: show trends not daily weigh-in judgement; keep the existing ISSN-limit refusal in the weight-path planner and surface "why".
- Risk signals handled deterministically and on-device: requesting a target below the minimum, repeated very low logged days (e.g. under a floor several days in a row), repeated weight-path requests beyond ISSN limits, fast-loss goals far from the division, or users under 18. Response: calm check-in card, link to a professional-help resource, offer "Hide numbers" mode, and do not coach further down. The existing `NutritionSafetyPolicy` (underage/underweight/invalid target -> unsupported or needsProfessionalReview) is the right place to extend. Do not diagnose or label the user.
- Consider an explicit "Pause nutrition" mode (hide all fuel numbers and reminders; training continues).

## 5. Privacy and regulation checklist (practical; not legal advice, check with counsel [U])

GDPR (EU/UK users):
- [ ] Treat weight, body measurements, meal logs tied to weight goals and any ED-risk signals as data concerning health (special category) under Art. 9(1). Processing is prohibited unless an Art. 9(2) condition applies; explicit consent for specified purposes is the usual one (Art. 9(2)(a)) [V: gdpr-info.eu]. Whether plain meal logs count as health data is [U], so design as if yes.
- [ ] Explicit, granular, withdrawable consent screens (not bundled with Terms). Record consent version.
- [ ] Data minimisation: do not collect what you do not use. Provide in-app export and delete.
- [ ] A DPIA is advisable for large-scale health-like processing [U: not verified here].

Washington My Health My Data Act (RCW 19.373) [V: leg.wa.gov, full text partly read]:
- [ ] Applies to non-HIPAA "consumer health data" linked or reasonably linkable to a consumer, covering past/present/future health status. Biometric data and "bodily functions, vital signs, symptoms, or measurements" are named. Dietary information is not listed but the list is non-exhaustive.
- [ ] Separate, prominently linked Consumer Health Data Privacy Policy on the homepage/app (RCW 19.373.020).
- [ ] Consent before collection for a specified purpose, or collect only as necessary to provide the requested service; sharing needs separate and distinct consent; acceptance of general terms of use is not consent (19.373.010(6)(b), .030).
- [ ] Deletion/access requests answered within 45 days (one 45-day extension); delete across systems and notify processors; backups may lag but not beyond 6 months (.040).
- [ ] Violations are treated as unfair/deceptive acts under the Consumer Protection Act; secondary sources say it carries a private right of action [S].
- Effective since 2024-03-31 (small businesses 2024-06-30).

US federal:
- [ ] FTC Health Breach Notification Rule amended 2024 (effective 2024-07-29) to cover non-HIPAA health apps [S]: notify users, the FTC and sometimes media after a breach of unsecured identifiable health data, including unauthorised disclosure such as sharing with ad platforms.
- [ ] No third-party advertising/analytics SDKs that receive health-linked events. The Frasco v. Flo/Meta jury verdict (Aug 2025, California CIPA) [S] shows SDK-sharing risk even outside HIPAA; post-trial status unverified. FTC GoodRx/BetterHelp/Flo actions are from my memory only [U].

Apple App Store [V: Review Guidelines]:
- [ ] 5.1.3(i): health/fitness data may not be used for advertising, marketing or data mining; disclose the specific health data collected.
- [ ] 5.1.3(ii): "may not store personal health information in iCloud". So do not use CloudKit/iCloud sync for meal logs or measurements; verify whether iCloud device backup of app files counts [U]. A Firebase backend is not iCloud, but keep the disclosure accurate.
- [ ] 5.1.1(iii) data minimisation; 5.1.1(v) in-app account deletion; 1.4.1 for health measurement claims plus a "check with a doctor" reminder.
- [ ] 3.1.2(c) clearly describe what the user gets for the price, with trial and renewal terms.

Google Play [S: policy pages via search, dates unverified]:
- [ ] Complete the Health apps declaration in Play Console and publish a non-PDF privacy policy URL, also in-app.
- [ ] If Health Connect is used, request only the data types that back specific user-facing features; justify each; repeat declaration when adding types. Data from Health Connect is sensitive user data.
- [ ] Do not make misleading medical claims.

On-device vs sync (recommendation, [U] as to your exact architecture):
- On device by default: meal logs, quantities, body weight/measurements, ED-risk flags, allergen/dislike lists, weight-path inputs, notification schedule, drill/session history that reveals schedule.
- Server only with an explicit separate toggle ("Back up my data"), encrypted at rest, deletable, with no analytics join to identity.
- Server-owned, never client-owned: entitlements (RevenueCat webhook; per CLAUDE.md).
- Analytics: event names and params must not include weights, food names, meal text, goal type or risk signals; Crashlytics must not log them either; no Firebase UID in logs (CLAUDE.md).
- Audit first: what does `firestore_edge_fuel_repository.dart` write today? If it syncs setup measurements, MHMDA/GDPR consent and a disclosure are needed before launch.

## 6. Pricing and paywall evidence

Competitor prices (check live before using externally):
| App | Prices | Trial | Gating | Source quality |
|---|---|---|---|---|
| MacroFactor | $11.99/mo, $47.99/6 mo, $71.99/yr; bundle with Workouts $89.99/yr from 2026-01-01 | 7-day mentioned by third parties, not on official page | No free tier mentioned | official help page [V]; trial [S] |
| Cronometer Gold | $10.99/mo, $59.99/yr | not stated | Free tier: logging, barcode, 84 nutrients, 7-day reports. Gold: Photo/Voice Log, Recipe Importer, Macro Scheduler, Food Suggestions, Crono Coach, custom charts, ad-free | cronometer.com/gold [V] |
| MyFitnessPal | Premium $79.99/yr, $19.99/mo; Premium+ $99.99/yr, $24.99/mo | 1-month Premium+ promo mentioned | Barcode, custom macros, Meal Scan, Voice Log gated; Premium+ adds Meal Planner and Blue Check recipes | [S] |
| Yazio Pro | roughly $24-48/yr US depending on promo; EUR 6.99/mo | "sometimes 7 days" | Meal plans, detailed macros, barcode, AI photo log, 2,900+ recipes in Pro | [S], inconsistent |
| Lose It Premium | $39.99/yr | not found | Ad-supported free tier | [S] |
| Noom | $59-70/mo, ~$209-299/yr | 7 or 14 days, often via an up-front-payment funnel | No free tier | [S] |

Category benchmarks:
- RevenueCat SoSA 2026 H&F [V]: trial-to-paid 37.7% median (top quartile >51.4%); download-to-paid 2.9% median; download-to-trial 6.9% median; yearly prices cluster ~$39.94, monthly $9.99, weekly $4.99; 82.1% of trial starts on Day 0; 54% of trials 5-9 days; lowest no-trial share (18.3%). Annual plan share figure is internally inconsistent on that page (59% vs 68%), so cite cautiously.
- Adapty [S]: H&F annual plans ~61% of revenue in 2025; weekly+trial funnel 9.5% install-to-trial, 42.2% trial-to-paid, 67.7% first renewal (third-party reproduction); H&F has a wide annual price spread.
- RevenueCat blog [S]: 17-32 day trials convert 42.5% vs 25.5% for under 4 days (a secondary statement; 2026 H&F data shows 5-9 days is the mode).

Read for Fighter Edge: planned $7.99/mo and $59.99/yr sits at Cronometer Gold annual parity and below MacroFactor, above the category median annual (~$39.94) and above Lose It/Yazio. That is defensible only because Fuel is bundled with training and camp planning. Competitors mostly gate convenience (barcode, voice/photo, ads, planners); core logging stays free. With a hard paywall everything is gated, so the paywall must show a concrete preview of today's fuel plan, not a feature list.

## 7. Ten ranked recommendations

Size: S = under a week, M = 1-3 weeks, L = a month or more. Rank is by expected retention/decision value per effort and by risk reduction.

1. [M] Gap picker ("Protein left: 34 g -> 3 options"). Macro-first mode in `FuelMatchCalculator`, a curated ~40-item add-on pool with household portions, 3 options from 3 food groups, one-line reason, split suggestion if above 0.4 g/kg per occasion. Why: it is the decision moment that Cronometer gates and that people complain is weak; it works offline and is explainable. Depends on #9 for content.
2. [S] Day-type fuel templates (rest, easy, hard, double, fight week) as a pure function of the training plan, protein flat per kg, carbs scaled by load, with ISSN floors (carbs not below ~3-4 g/kg in camp). Surfaces "Today: Hard day, more carbs" on Home. Why: fighter-specific differentiator that competitors do not clearly ship (MacroFactor day-specific targets unverified).
3. [M] First-log path under 60 seconds: after plan reveal, pre-fill the next meal from the gap picker, one tap to log it; then Recents, favourites, "repeat yesterday", saved meals. Design for "2 eating occasions a day" as the success bar (Burke 2019 [S]). Why: logging frequency, not detail, predicts results; effort and bad databases are the top reasons to quit. Measure time-to-first-log yourself since no public benchmark exists.
4. [S] Weekly consistency model for training (existing plan), no streak or completion bar for food, neutral "rest week" miss copy, freezes for training weeks only. Why: loss-aversion streaks work but are the named harm vector for ED-prone users; weekly fits a fighter's rest days.
5. [S] Granular local notifications: four opt-in channels, asked after the first completed session with a primer, iOS provisional authorization, one a day, quiet hours, auto-snooze after 3 dismissals, content = what is next and why, nothing about misses. Why: Drink Less RCT shows timed notifications raise short-window opens 3.5x; opt-in rates are only ~33-43% so earn them.
6. [M] ED-risk and tone layer: extend `NutritionSafetyPolicy` with log-pattern and goal-pattern signals, "Hide numbers" and "Pause nutrition" modes, calm check-in with professional-help link, copy lint (no "good/bad", "cheat", "earn", "burn"), no red/green. Get a registered dietitian or clinician to review copy. Why: weight-class sport is a higher-risk population and the apps studied cause harm through exactly these features.
7. [M] Privacy-first architecture: local-first storage for meals and measurements, optional encrypted backup behind a separate consent, analytics scrubbed of health content, MHMDA consumer-health-data policy and consent flow, GDPR Art. 9 explicit consent, in-app export/delete, no iCloud for health data. Begin with an audit of what Firestore receives today. Why: Apple 5.1.3 and MHMDA are concrete and enforceable; the Flo/Meta verdict shows SDK risk.
8. [M] Meal-prep and grocery list: pick 3-5 recipes, scale servings, merge by food id, "cook x4" multiplier, offline checklist, share as text. Gate as Pro polish. Why: planner apps use it as a reason to pay and it sustains weekly habit around camp.
9. [L] Content: dietitian-review and publish the 24 draft recipes, expand to about 60 recipes plus the ~40 add-ons, tagged by day type, pre/post timing, prep time, budget, diet, allergens, with Tunisian/MENA coverage given the existing recipes. Validate through the existing catalog validator. Why: variety is the precondition for #1, #2, #8; 24 drafts will repeat within a week.
10. [S] Paywall as proof: after plan reveal show today's fuel numbers, one suggested meal and a gap-picker example, then the 7-day trial with a clear price/renewal line, a trial-end reminder notification (opt-in) around day 5, annual default but monthly visible, Restore link, no toggle. Test 14 days later when traffic allows. Why: 82% of H&F trial starts are Day 0 and 54% of trials are 5-9 days, so 7 days is in-category; value must land before the paywall.

## 8. Anti-patterns to avoid

- Daily streaks or completion rings on food logging; streak-loss notifications; "Don't break your streak".
- Red/green over/under colouring, "you're over by X", praise for being under, "deficit achieved" confetti.
- "Good/bad", "clean/junk", "cheat meal", "earn your food", "burn it off" copy; calorie-equivalent exercise framing.
- Default calorie-deficit goals or custom targets below clinical minimums; rapid weight-cut goals beyond ISSN 6.7/5.7/4.4% limits; fasting, sauna or fluid-restriction advice.
- Pushing the notification permission prompt on first launch; more than one push a day; guilt or loss-aversion copy; notifications that reveal measurements on the lock screen.
- Paywalling the safety information, the weight-cut limits or basic targets; trial toggles; hidden renewal terms; hard-to-find cancel.
- Sending weights, food names, goals or risk flags to analytics/ad SDKs; Firebase UID in logs; syncing health data to iCloud; treating "accepted Terms" as health-data consent.
- Using AI to compute or change nutrient numbers; any AI output without schema/safety validation (CLAUDE.md).
- Social leaderboards on food or weight; comparisons with "successful" friends (Cordeiro found this makes people quit).
- Publishing draft or unreviewed recipes as "dietitian approved", or claiming NEDA/ACSM compliance that does not exist.
- Showing a long quiz that does not change the plan (Noom length only pays when every answer is visibly used).

## 9. Gaps I could not close

- Measured time-to-first-log for any named competitor.
- Primary Adjust/AppsFlyer H&F retention tables (only secondary compilations read).
- Weekly vs daily streak experimental evidence in nutrition apps.
- NEDA/ACSM app-design guidance (none found); ACSM/AND/DC 2016 numbers (not retrieved).
- MacroFactor trial length and day-specific targets (official pages silent).
- Current Yazio, Lose It, Noom, MyFitnessPal prices from official pages (only third parties).
- Whether Apple's iCloud rule extends to device backups; whether meal logs alone are GDPR special-category data in every jurisdiction.

## 10. Sources

Retention / self-monitoring
- Harvey et al. 2019, Log Often, Lose More: https://pubmed.ncbi.nlm.nih.gov/30801989/
- Payne et al. 2022: https://onlinelibrary.wiley.com/doi/10.1002/osp4.566 (blocked, read via search summary)
- Burke-group adherence definition (2019): https://www.sciencedirect.com/science/article/abs/pii/S2212267219302655
- Patel et al. 2019 GoalTracker RCT: https://mhealth.jmir.org/2019/2/e12209/
- Cordeiro et al. CHI 2015: https://homes.cs.washington.edu/~jfogarty/publications/chi2015-decaf.pdf
- Big Think summary of food logging abandonment: https://bigthink.com/ideafeed/why-so-many-people-quit-food-logging-apps-in-the-first-week
- RevenueCat State of Subscription Apps 2026: https://www.revenuecat.com/state-of-subscription-apps
- RevenueCat Noom funnel teardown: https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel
- Adapty H&F benchmarks: https://adapty.io/blog/health-fitness-app-subscription-benchmarks/ and https://adapty.io/state-of-in-app-subscriptions-report/
- Retention compilations: https://phiture.com/mobilegrowthstack/managing-retention-rate-benchmarks-and-expectations/ and https://www.braze.com/resources/articles/mobile-app-retention.md
- Yazio onboarding (secondary): https://screensdesign.com/apps/yazio-calorie-counter-diet/

Notifications / gamification
- Drink Less MRT (JMIR 2023): https://pmc.ncbi.nlm.nih.gov/articles/PMC10337295 and https://mhealth.jmir.org/2023/1/e38342
- OneSignal 2024 benchmarks: https://onesignal.com/mobile-app-benchmarks-2024
- Airship 2026 benchmarks: https://www.airship.com/mobile-app-push-notification-benchmarks-for-2026/
- Apple notifications HIG: https://developer.apple.com/design/human-interface-guidelines/managing-notifications.md
- Provisional authorization: https://useyourloaf.com/blog/provisional-authorization-of-user-notificatons/
- Duolingo streaks: https://blog.duolingo.com/how-duolingo-streak-builds-habit
- Streak creep (secondary): https://thedecisionlab.com/insights/consumer-insights/streak-creep-the-perils-of-too-much-gamification

Meal suggestions and sports nutrition
- Cronometer Suggest Food help: https://support.cronometer.com/hc/en-us/articles/29272790841236-Mobile-Suggest-Food (403 on fetch, read via search) and https://cronometer.com/blog/suggest-food/
- Cronometer Gold: https://cronometer.com/gold/
- MyFitnessPal Winter 2026 release: https://lite.aol.com/sports/other/story/0022/20260224/9659625.htm
- Eat This Much: https://www.eatthismuch.com/how-it-works
- ISSN nutrient timing 2017: https://pmc.ncbi.nlm.nih.gov/articles/PMC5596471/
- ISSN combat sports and weight cut 2025: https://pmc.ncbi.nlm.nih.gov/articles/PMC11894756/
- Impey et al. 2018 Fuel for the Work Required: https://researchonline.ljmu.ac.uk/id/eprint/8142/
- Thomas et al. 2016 position stand: https://pubmed.ncbi.nlm.nih.gov/26917108/

Tone / eating disorders
- BJPsych Open, diet and fitness apps and ED behaviours: https://www.cambridge.org/core/journals/bjpsych-open/article/effects-of-diet-and-fitness-apps-on-eating-disorder-behaviours-qualitative-study/2D1EE739D97AB3EFC6573835E4C527BD
- Levinson et al. 2017: https://pmc.ncbi.nlm.nih.gov/articles/PMC5700836/
- Duke psychiatry summary: https://psychiatry.duke.edu/blog/trouble-tracking
- MacroFactor adherence-neutral: https://macrofactor.com/mm-october-2023/ and https://apps.apple.com/app/id1553503471
- NEDA coaches and trainers: https://www.nationaleatingdisorders.org/coaches-trainers/
- AIS disordered eating in high performance sport: https://support.sportsintel.ausport.gov.au/hc/en-us/articles/4989576295823-Disordered-Eating-in-High-Performance-Sport
- Wrestling ED systematic review (2025): https://papers.sze.hu/research-portal/publications/10.1186/s40795-025-01169-0
- Combat sport weight-cut study: https://www.frontiersin.org/articles/10.3389/fnut.2025.1726260/full

Privacy / regulation
- Washington RCW 19.373 full text: https://app.leg.wa.gov/rcw/default.aspx?cite=19.373&full=true
- GDPR Art. 9: https://gdpr-info.eu/art-9-gdpr/
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Google Play health apps: https://developer.android.com/health-and-fitness/health-connect/declare-access and https://support.google.com/googleplay/android-developer/answer/16679511
- FTC Health Breach Notification Rule 2024: https://www.ftc.gov/node/78112
- Flo/Meta verdict: https://www.burr.com/newsroom/articles/jury-found-meta-liable-in-flo-privacy-case-what-to-do-if-your-website-or-app-collects-user-health-data

Pricing
- MacroFactor subscriptions: https://help.macrofactorapp.com/en/articles/393-how-macrofactor-subscriptions-and-bundles-work
- Noom pricing (secondary): https://bettercare.com/costs/noom-cost
- Lose It / Noom comparison (secondary): https://nutrola.app/en/blog/weight-loss-app-pricing-guide-2026
- Yazio pricing (secondary): https://nutriscan.app/blog/posts/yazio-pricing-2026-free-vs-pro-what-pro-unlocks-33b26f8fc7
- MyFitnessPal pricing (secondary): https://www.fitbudd.com/post/myfitnesspal-app-cost

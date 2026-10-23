# How nutrition apps set targets, adapt them, and make suggestions: translated for Fighter Edge

Date: 2026-10-22. Research only, no code or git changes.

Evidence tags used below:
- [V] = read on the cited page this session.
- [S] = secondary source (review site, blog, press) or search snippet only.
- [U] = unverified: from memory or my own arithmetic; check before relying on it.

Note on repo state: `docs/NUTRITION_COMPETITOR_RESEARCH.md` is NOT in the checked-out branch (`feat/ai-eval-and-camp-domain`). It exists on `chrome-laneF`, `feat/training-aware-nutrition` and `docs/phase1-proposals` (read with `git show`). All "repo" statements below are from `chrome-laneF` (which contains PR #58's v2 policy plus later work). Nothing was run; this is a code read.

---

## 1. What the repo already has (so this report does not repeat it)

Files read: `nutrition_policy_v2.dart`, `weight_rate_policy.dart`, `nutrition_target_calculator_v2.dart`, `session_energy_table.dart`, `weekly_check_in.dart`, `weight_trend.dart`, `weight_cut_policy.dart`, `nutrition_safety_policy.dart`.

| Area | What exists |
|---|---|
| Resting energy | Mifflin-St Jeor, sex path or neutral midpoint (range widened x1.5, confidence low) |
| Maintenance | RMR x non-training factor (1.20 to 1.55) + planned session kcal / 7, where session kcal = (gross MET - 1) x kg x effective hours (90 min full cost, 0.8 taper after, 240 min cap). Dietitian sign-off flag still `true` |
| Rate | % body weight per week. Loss options 0.25/0.5/0.75/1.0 (default 0.5), gain 0.1/0.25/0.5 (default 0.25). Cap: loss 1% AND 1 kg/week (tighter wins), gain 0.5%. Daily gap = pct/100 x kg x 7,700 / 7 |
| Floors | Never below RMR. Protein 2.0 g/kg target weight (losing) or 1.8 g/kg (other), floor 1.2 g/kg. Fat 27.5% of kcal, floor 0.5 g/kg. Carbs floor 3.0 g/kg enforced while losing (lifts the average, or stays at maintenance and warns); warn-only for maintain/gain |
| Day split | 50% of each day's session-energy deviation from the weekly mean moves into intake; zero-sum over the week; protein and fat fixed, carbs carry the difference; no day below `minimumDailyKcal` |
| Safety gate | Adults only (18+), BMI < 18.5 blocks fat loss, invalid vitals/targets, self-declared flags (pregnant/breastfeeding, eating-disorder history or symptoms, diabetes on medication, kidney, serious liver, other clinician-managed diet) give `needsProfessionalReview` |
| Weight trend | Mean of weigh-ins in last 7 days minus mean of the 7 days before (null if either window empty) |
| Weekly check-in | Decision table, pure Dart, recommend-only. Gates: >=5 days logged, >=3 weigh-ins, intake within +/-10% of target, no change accepted in last 7 days, not fight week, |weekly change| <= 2% body weight. On-pace band: max(25% of planned rate, 0.15% body weight). Faster than planned only acts beyond 150% of plan. Step 100 kcal, or 150 if miss > 2x tolerance. Bounded by `minimumKcal` and optional ceiling. Reasons are stable enum codes |
| Fight camp | ISSN-2025-based `WeightCutPolicy`: 0.5 to 1 kg/week camp loss, acute limits 6.7/5.7/4.4% at 72/48/24 h, food-only, sweat allowance by competition category |

Search of `chrome-laneF` found no caller of `WeeklyCheckIn` outside its own file, i.e. the decision table appears to be unwired from UI/controllers [U: grep only, not a build check].

---

## 2. How the successful apps actually work

### 2.1 MacroFactor (best documented)

Expenditure ("Expenditure" screen)
- Energy-balance rearrangement: calories in - change in stored energy = calories out. Inputs are logged intake and the rate of change of trend weight. Stored-energy change is estimated from weight change "adjusting for the different energy content of fat and lean tissue" [V] https://help.macrofactorapp.com/en/articles/20-expenditure
- Energy densities discussed in V3 write-up: fat about 39.5 MJ/kg (about 4,282 kcal/lb), lean tissue about 7.6 MJ/kg (about 824 kcal/lb). The "3,500 rule" implies roughly 78% fat / 22% lean. V3 treats gain and loss symmetrically (V1/V2 did not; effect 0 to 130 kcal/day) [V] https://macrofactor.com/expenditure-v3/
- It is error-correcting: expenditure is nudged by the gap between predicted and observed weight change (example: predicted 1 lb/week loss, observed 1.2, expenditure nudged up). Exact filter, window and tuning constants are NOT disclosed; the author says he will not share more [V]. "Kalman filter" is not stated anywhere I could read; do not claim it.
- Learning window: "about three weeks of data" [V] https://help.macrofactorapp.com/en/articles/109-how-frequently-do-i-need-to-log-my-weight-for-the-expenditure-algorithm-and-weekly-coaching-updates
- Missing data: V2 paused updates when a 7-day period had 2+ missing days (needed >=6 logged). V3 pauses only when >3 days are missing in 7 days; in a 50%-random-deletion test V3 stayed close to the full-data result [V]. Missing intake on unlogged days is predicted, with typical error about 13% (90% of errors < 30%) [V].
- Biggest named weakness: partial logging (breakfast and lunch but not dinner) cannot be detected, so expenditure and recommendations drift down [V] (expenditure article). Their own accuracy post says partial logging above 5 to 10% of days noticeably reduces accuracy [V] https://macrofactor.com/algorithm-accuracy/
- Starting value: a formula estimate; about a quarter of 100-day cumulative error comes from the starting estimate before convergence [V] (accuracy post). How the formula blends into observed data is not published.
- Their accuracy claims (company-authored, internal, challenge participants, partial-logging users excluded): median daily expenditure error after 3 to 4 weeks 135 kcal vs 335 for a formula TDEE; 94.1% of users had smaller error than the formula. Wearable comparison is cross-study. Treat as marketing-grade, not peer-reviewed [V].
- Wearable data is deliberately excluded from expenditure (error "substantial, nonrandom, and hard to predict") [S via search snippet].

Trend weight
- Missing days filled by linear interpolation ("Scale Weight"). Trend is "a moving average ... that places greater emphasis on more recent weigh-ins". No window, constant or weights disclosed. Water, glycogen, GI content are named as the noise source; V3 additionally damps short-term fluid shifts (glycogen, sodium/carbs, creatine, menstrual cycle) by an undisclosed method [V] https://help.macrofactorapp.com/en/articles/21-weight-trend
- Weigh-in cadence: at least weekly, daily preferred; "a missing weight pauses updates (status 'holding')" in the help text; example where deleting six days changed the target by < 15 kcal/day [V].

Rate and targets
- Handbook: most people should aim for 0.25 to 1% of body weight per week loss; faster raises muscle-loss and diet-fatigue risk [S: search snippet of the handbook PDF, PDF itself could not be decoded]. https://macrofactor.com/wp-content/uploads/2025/11/MacroFactor-Fat-Loss-Handbook.pdf
- No published calorie floor found [V: goal-features page and help pages do not state one].
- Protein: coached programs offer low/moderate/high; range for manual/collaborative 1.2 to 2.2 g/kg body mass, nearer the top when losing or very active, bottom when less active or gaining [V] https://help.macrofactorapp.com/en/articles/142-protein
- Dynamic maintenance: user sets a target trend weight; tolerance band +/-1.5 lb (about 0.7 kg); outside the band the program nudges with a deficit/surplus sized to move weight about 0.15% body weight per week (worked example: 75 kg, 2,500 kcal expenditure, about -125 kcal/day) [V] https://help.macrofactorapp.com/en/articles/125-how-does-dynamic-maintenance-work-in-macrofactor
- Targets are "adherence-neutral": recommendations come from expenditure, actual intake and weight trend, "not on how closely you followed the previous targets" [V] (expenditure article). This is the key philosophical difference from Carbon and from the repo's check-in.

Weekly check-in and coaching modules
- Weekly, user picks the day. Recommendations apply only if the user accepts; declining is allowed. Modules (Partial Logging, Weigh-In, Fasting, Logging Break, Program Update) each explain why they appear, may ask a question, and end with a change made "with your approval". "Fast Check-In" skips modules [V] https://help.macrofactorapp.com/en/articles/247-introduction-to-check-ins-and-coaching-modules
- No numeric limits on a weekly target change are published [V].

Plateau, diet breaks, refeeds
- No plateau feature; the pitch is that expenditure re-estimation means you "never plateau" (marketing) [S].
- Stance: no dedicated modes because the evidence does not justify them. Diet break = eat near maintenance 1 to 2 weeks (or switch goal to maintenance); refeeds = 1 to 3 higher-carb days per week, no settings change needed because the app is adherence-neutral; carb cycling handled by calorie shifting or manual targets [V] https://help.macrofactorapp.com/en/articles/30-does-macrofactor-support-refeeds-diet-breaks-or-carb-cycling
- Their own evidence review concludes refeeds/diet breaks do not meaningfully attenuate metabolic adaptation or improve fat loss for most dieters; may help hunger, adherence, training. Author has ties to cited research and the company sells the app [V] https://macrofactor.com/refeeds-diet-breaks/

### 2.2 Carbon Diet Coach

- Initial targets: "modified Müller equation" using weight and estimated body fat (lean mass) plus activity; protein based on lean body mass; carbs/fat split by diet preference. No numeric protein, fat or calorie floor published [V] https://help.joincarbon.com/en/articles/14005628-how-carbon-sets-and-adjusts-your-macros
- Weekly check-in asks one adherence question: tracked everything (adjust from metabolic response), tracked only some meals (targets HOLD, partial logs cannot support adjustment), did not track but met targets (judge on weight change), tracked elsewhere (enter averages). Weight required, body fat optional. Report shows intake, compliance, changes [V] https://help.joincarbon.com/en/articles/6004812-weekly-check-in-in-carbon-how-it-works-and-what-to-expect
- Direction rules: slower than goal rate -> calories down; faster -> calories up; maintain -> small drift correction. Only adjusts when needed to keep you on pace. If you ate under target and lost faster than goal, no adjustment. After a non-compliant check-in targets hold a week. Scale outliers "typically self-correct within one to two weeks of consistent data" [V] https://help.joincarbon.com/en/articles/15826058-why-are-my-carbon-calorie-targets-so-high-or-so-low
- Goal creation gives a coach-suggested rate range but figures are not on the page; notes that choosing within the range avoids excessive metabolic adaptation and muscle loss [V] https://help.joincarbon.com/en/articles/6040890-how-to-create-your-initial-goal

### 2.3 Renaissance Periodization Diet Coach

- Public page: weekly diet-and-macros review recommends changes from progress and eating habits; weekly targets, "eat more on hard training days, less on rest days"; goals cut/build/maintain. No adjustment rules, floors, diet-break or refeed detail on the page [V] https://rpstrength.com/pages/diet-coach-app
- Everything about its internal algorithm is therefore unknown [U].

### 2.4 Cronometer, MyFitnessPal, Noom, Lose It

- Cronometer: static targets from Mifflin-St Jeor plus activity, every assumption editable; Gold adds "Nutrition Scores", reports, charts, and a Macro Scheduler (different targets per weekday). No protein streak or adaptive expenditure found [S] https://cronometer.com/blog/nutrition-scores/ (see also existing doc).
- MyFitnessPal: formula goal minus food plus exercise. Official page returned HTTP 403. The "1,200 women / 1,500 men" floors are widely repeated but I could not confirm in official docs [S/U].
- Noom: weight-loss zone uses Harris-Benedict; lower end of zone pairs with faster pace (about 1 to 2 lb/week), upper end about 0.5 lb/week [S] https://www.noom.com/support/faqs/question-topics/weight-logging/2016/08/how-often-should-i-be-weighing-in-2/ . A review reports floors of 1,320 (female) / 1,400 (male) [S; the existing doc says 1,320/1,540: the two disagree, treat both as unverified].
- Lose It!: older review notes a 2 lb/week maximum and a 1,011 kcal budget at that setting in 2009, so floor behaviour has changed or is inconsistent [S/U].
- Pattern: mass-market apps use fixed-deficit formula goals plus sex-only calorie floors; adaptive apps (MacroFactor, Carbon, RP) use trend + intake. The weak spots are floors that ignore body size and sport.

### 2.5 Endurance-athlete and wearable tools

- Fuelin: targets from goal, weight, sex, experience, daily activity, planned and completed workouts, RMR; auto-updates when training changes; "Smart Adjustments" re-plan remaining meals; no weekly algorithm published [V] https://www.fuelin.com/ . Day colour is by total daily carbs per kg: red <= 1.8, yellow 1.8 to 4.0, green > 4.0 g/kg (previously 3.2 / 5.2) [V] https://fuelin.com/articles/psychology-of-carb-colours . Deliberate language: red is "low" not "bad"; they changed thresholds because athletes felt always on low-carb. An independent athlete review claims the app under-prescribed calories by 8 to 21% over a week: single anecdote [S] https://hoppersportsperformance.substack.com/p/my-experience-with-fuelin-program
- TrainingPeaks Fueling Insights (July 2025, power-based cycling): classifies a ride into one of four metabolic profiles from RER lab testing (stated >250 tests), estimates carbs and fat burned per ride; coach guidance to replace about 40 to 60% of carbs burned during the ride. Company/developer claims, not independent evidence [S] https://www.trainingpeaks.com/fueling-insights/ and https://athletechnews.com/trainingpeaks-debuts-fueling-insights/
- Whoop/Oura: no verified kcal prescription. Oura Meals gives photo logging, "nutritional breakdown, personalized feedback, and meal timing"; tone encouraging, non-judgemental; no goal-setting rules published [V] https://ouraring.com/blog/oura-meal-logging-data/ . Whoop nutrition is via third-party imports [S]. Recovery-score-driven eating advice: I found no evidence; treat as marketing [U].

---

## 3. Evidence versus marketing

| Claim / mechanic | Evidence status |
|---|---|
| Mifflin-St Jeor is the best of the four common equations for non-obese and obese adults, but individual errors are noteworthy | Frankenfield 2005 systematic review, J Am Diet Assoc [S via abstract snippet] https://pure.psu.edu/en/publications/comparison-of-predictive-equations-for-resting-metabolic-rate-in-/ . The "82% within 10%" figure often quoted is [U], I did not retrieve it |
| In athletes no single equation is reliably best; Ten-Haaf (age, weight, height) was most precise in a 29-study, 1,430-athlete meta-analysis (80.2% within +/-10% vs 40.7 to 63.7% for others); Cunningham and Harris-Benedict were not different from measured on average | O'Neill et al. 2023, Sports Med [S, search summary] https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10687135/ . Pooled Mifflin figure not retrieved [U]. Implication: Mifflin RMR carries meaningful individual error for fighters, so a first target must be labelled an estimate |
| 3,500 kcal/lb (7,700 kcal/kg) linear rule | Wishnofsky 1952; dynamic models (Hall 2011 Lancet 378:826) show expenditure falls as weight falls, so a fixed deficit gives less loss over time; ASN-aligned commentary says abandon it for long-range prediction [S] https://pmc.ncbi.nlm.nih.gov/articles/PMC4442575 . A correction loop (check-in) offsets this. For an 8 to 12 week camp the rule is a reasonable first-order tool if re-corrected weekly |
| Loss rate for athletes | Garthe 2011: 24 elite athletes, 0.7%/week vs 1.4%/week with resistance training; slower rate recommended for lean-mass gain and strength; 12-month follow-up found no group differences [S via abstract] https://lida.sport-iat.de/ta/Record/4020931 . Helms 2014: 0.5 to 1%/week for contest prep, slower for leaner, much extrapolated [V] https://pmc.ncbi.nlm.nih.gov/articles/PMC4033492/ . ISSN diets/body-composition stand: slower rates better preserve lean mass in leaner subjects [S] https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5470183/ . ISSN 2025 combat-sport stand: camp "0.5 to 1 kg" per week is the figure used in repo [existing doc] |
| Protein | Morton 2018 BJSM (49 studies, 1,863 people): benefit of supplementation plateaus at total intake about 1.62 g/kg/day [S] https://pubmed.ncbi.nlm.nih.gov/28698222/ . The "upper CI 2.2 g/kg" often quoted was NOT confirmed [U]. ISSN 2025 stand: 1.2 to 2.0 g/kg minimum during descent, protein prioritised [V] https://pmc.ncbi.nlm.nih.gov/articles/PMC11894756/ . Helms: 2.3 to 3.1 g/kg lean mass for lean athletes in deficit (expert extrapolation) [V] |
| Carbs and fat floors | ISSN 2025: carbs "3.0 to 4.0 g/kg" and fat "0.5 to 1.0 g/kg/day" as floors during descent [V as returned by the fetch tool; the repo's 3.0 and 0.5 are the low ends] |
| Metabolic adaptation exceeds prediction in athletes; use slow rates, consider breaks | Trexler, Smith-Ryan, Norton 2014 JISSN 11:7: adaptation = hormones, mitochondrial efficiency, expenditure drop; recommendations not retrieved [S] https://pmc.ncbi.nlm.nih.gov/articles/PMC3943438/ |
| Diet breaks / refeeds | Mixed. MacroFactor's own review: Byrne 2018 (51 men, 2-week on/off) favoured breaks; Peos 2021 and Siedler 2023 (3:1 and 2:1) showed no advantage in weight, fat loss or RMR but some hunger/disinhibition benefit; Campbell 2020 refeeds similar fat loss [V, company-authored] https://macrofactor.com/refeeds-diet-breaks/ . Helms does not recommend them [V]. Position: use for adherence/training quality, never promise a metabolic reset |
| Low energy availability | IOC 2023 REDs: LEA is a spectrum (adaptable to problematic); the old 30 kcal/kg FFM cutoff came from short lab studies in sedentary women and is now questioned; low carbohydrate availability added [S] https://pubmed.ncbi.nlm.nih.gov/37752011/ . Use as a risk flag, never as a target |
| Calorie-tracking apps and eating-disorder risk | Levinson 2017 (n=105 with ED diagnosis): about 75% used MyFitnessPal, 73% of those felt it contributed [S] https://pubmed.ncbi.nlm.nih.gov/28843591/ . 2021 study (n=1,357): weight/shape motives linked to preoccupation and all-or-none thinking, health motives to fewer effects [S] https://aes.as.uky.edu/bibcite/reference/27230 . Associational, cross-sectional |
| Day-to-day weight noise | Popular sources: about 0.5 to 1 kg day to day is common; water and glycogen (glycogen carries roughly 3 g water per g) dominate. I found no primary study with SDs [S/U] |
| Scholastic wrestling safeguards (a minors precedent) | NFHS rule via a state association: weight-management programme with urine specific gravity <= 1.025, minimum body fat 7% (male) / 12% (female), planned loss <= 1.5% body weight per week [S, secondhand] https://www.uiltexas.org/wrestling/page/wrestling-minimum-weight-certification-program-information |
| Vendor accuracy claims (MacroFactor expenditure, TrainingPeaks fuelling, Fuelin) | Marketing-grade until independently validated |

---

## 4. Translation: a deterministic, explainable system for fighters

Principles: every number traceable to a formula and a constant with a source; no hidden state; every proposal explainable in one sentence using a stable reason code; recommend-only; safety limits always beat goals.

### 4.1 Data-sufficiency tiers

| Tier | Gate | What the app may do |
|---|---|---|
| 0 Starting estimate | Fewer than 14 days since the target started, or fewer than 6 weigh-ins | Show formula target with maintenance range and a "starting estimate" label. No proposals |
| 1 Trend check-in | Target age >= 14 days; >= 5 of 7 days logged in each of the last 2 weeks; >= 3 weigh-ins/week in each of the last 2 weeks (or >= 8 in 14 days) | Compute observed slope and propose within-limits corrections (section 4.3) |
| 2 Adaptive expenditure | >= 21 days of data; >= 6 of 7 days logged in >= 2 of last 3 weeks; >= 12 weigh-ins in 21 days; user has not marked days as partial | Show "observed expenditure" next to formula; allow proposal to move maintenance toward observed (section 4.4) |

Rationale: MacroFactor needs about 3 weeks [V]; V3 tolerates up to 3 missing days per 7 [V]; the repo research doc already sets 3 weeks and 6 of 7 for adaptive [existing doc 10.5]. Carbon's "partial tracking -> hold" is the strictest and most athlete-safe [V].

### 4.2 Trend weight and noise (replace "mean of this week minus mean of last week")

Illustrative noise calculation [U: my arithmetic, assumes independent daily noise SD about 0.6 kg for a fighter, which is NOT sourced; real noise is autocorrelated and training/sweat adds more]:
- Difference of two weekly means with 3 weigh-ins each: SE about sqrt(2) x 0.6 / sqrt(3) = 0.49 kg, about 0.7% of 70 kg. A planned 0.5%/week change is 0.35 kg. Signal below noise.
- OLS slope over 21 days of daily weigh-ins: SE about 0.6 / sqrt(n(n^2-1)/12) = 0.6 / 27.7 = 0.022 kg/day, about 0.15 kg/week. This is why about 3 weeks is the practical window.
- The repo's min band 0.15% body weight (about 0.1 kg at 70 kg) is inside that noise at weekly resolution, so a Tier-1 check-in on a 7-vs-7 difference will give false proposals.

Proposed method:
1. Use only valid weigh-ins: finite, 20 to 250 kg. Keep a "condition" tag: standard (morning, after toilet, before food/fluid) vs non-standard. Exclude non-standard (post-training or sweat-loss weigh-ins) and anything in fight week.
2. Outlier rule: drop a weigh-in more than max(1.5 kg, 2% body weight) from the median of the surrounding 7 days; keep it visible on the chart, grey.
3. Display trend: exponentially smoothed weight, trend_t = trend_(t-1) + a x (w_t - trend_(t-1)), a = 0.1 per weigh-in day (the "Hacker's Diet" constant [U: from memory]). Fill gaps by linear interpolation as MacroFactor does [V]. Display only.
4. Decision slope: OLS slope of valid weigh-ins over the last 21 days (>= 12 points, >= 14 days spanned); fall back to 14 days only for Tier 1 minimum. Compute residual SD s and Sxx; noise band = 1.96 x s / sqrt(Sxx) kg/day x 7. Dead band for the decision = max(0.25 x |planned rate|, noise band, 0.1 kg/week).
5. Water events (sodium, creatine start, cycle, carb-load) are not modelled; the long window and band are the defence. Say so in copy.

### 4.3 Weekly decision formula (recommend-only)

Definitions (kg/week, signed; loss negative):
- planned = signed pct x body weight / 100 (from `WeightRatePolicy`)
- observed = OLS slope x 7
- error e = observed - planned (positive means heavier than the plan)
- implied correction in kcal/day = -e x 7,700 / 7 = -1,100 x e

Examples: planned -0.35 kg/week, observed -0.05 kg/week -> e = +0.30 -> correction about -330 kcal/day.

Proposal = damped, clamped:
- step = clamp(round10(0.5 x |1,100 x e|), 100, 200) kcal/day. Half correction because the trend lags by days and the 7,700 rule overstates the effect of a sustained deficit [V Hall critique, S]. The repo's fixed 100/150 is close to this for most real misses; the formula version explains the size in one line ("you are about 0.3 kg/week above plan, about 330 kcal/day; we suggest closing half of it now").
- Direction by sign of e (goal-aware as the repo does).
- Bounds, any of which converts to a Hold with a reason code: new target >= `minimumKcal` (section 4.5); loss: new target <= estimated maintenance; one accepted change per 7 days; never in fight week; max cumulative change from the first target in any 4-week period of 15% (prevents drift) [U: my suggestion, no source].

### 4.4 Adaptive expenditure (Tier 2, proposal only)

observed_expenditure = mean logged intake (14 to 21 days) - (OLS slope kg/day x 7,700).
Blend: maintenance_new = (1 - w) x formula + w x observed, with w = min(0.7, 0.25 + 0.15 x completed_weeks_beyond_2) and capped at +/-10% of the formula in any one proposal [U: weights are my design, not sourced]. Show both numbers and the range. Never auto-apply. Do not use wearable calories (MacroFactor excludes them [S]). Partial days must be markable (MacroFactor Partial Logging module [V]) or the estimate drifts low.

### 4.5 Safety limits (deterministic)

| Limit | Value | Source / status |
|---|---|---|
| Adults only for automated deficits | 18+ (existing) | repo; ISSN gives no minors guidance (not found in retrieved text) |
| Minimum daily kcal | max( RMR, fixed-macro kcal + carb floor 3 g/kg, RMR + 0.5 x average planned session kcal/day ) (the 0.5 is my placeholder, needs dietitian review) | The first two exist. The third is my proposal, see gap G3 |
| Max weekly loss | 1% body weight and 1 kg (existing); for non-camp use default 0.5%, offer up to 0.75%; 1.0% only inside a fight-camp path | Helms 0.5 to 1% [V]; Garthe slower better [S]; ISSN camp 0.5 to 1 kg [existing doc] |
| Max observed loss | If trend loss > 1% for two consecutive check-ins, propose +150 kcal and show safety copy | Repo "faster than planned" acts at 150% of plan only; no absolute trigger |
| Protein | 1.6 to 2.2 g/kg (2.0 g/kg target weight when losing), floor 1.2 g/kg | ISSN 2025 [V], Morton [S] |
| Carbs | >= 3.0 g/kg during descent | ISSN 2025 [V] |
| Fat | >= 0.5 g/kg and 25 to 30% energy | ISSN 2025 [V]; Helms 15 to 30% [V] |
| Logged intake safety | If average logged intake (>= 5 days) < RMR for 2 weeks: stop proposing cuts, hide deficit language, show supportive "talk to a professional" card | My proposal [U] |
| Exclusions | pregnancy/breastfeeding, eating-disorder history or symptoms, medicated diabetes, kidney, serious liver, other clinician-managed diet -> `needsProfessionalReview` (existing) | Add periodic re-screen (section 4.7) |
| Fight week | Food-only, ISSN 24/48/72 h limits, no fluid/sweat/diuretic guidance (existing) | ISSN 2025 [V] |
| Never | single weigh-in or single day driving a change; streaks; red/green day judgement; eat-back of exercise calories | existing research doc |

### 4.6 Recommend-only weekly check-in spec

Cadence: user-picked weekday (default Sunday), available once the previous 7 days have closed. At most one target proposal per 7 days. Declining is a normal outcome and is remembered (no nagging).

Screen order (matches Carbon "adherence first" [V] and MacroFactor "explains why" [V]):
1. "What we saw" (facts only, no verdicts): days logged x/7; average intake vs target; trend change over the last 2 to 3 weeks in kg and % body weight per week vs plan; sessions done vs planned; days protein >= 90% of target.
2. One optional question: "How complete was your logging?" (All / Most / Some / None). Maps to hold rules: Some/None -> hold; Most -> allowed only if >= 5/7 logged and no day flagged partial.
3. Result card, exactly one of:
   - HOLD (reason code + one sentence).
   - PROPOSAL: "Suggested: 2,240 -> 2,140 kcal/day (-100). Why: your 3-week trend is about 0.3 kg/week above plan while you ate close to your target." Buttons: Apply / Keep current / Not now.
   - SAFETY: no number change; supportive copy (section 4.7).
4. History: the old target, new target, policy version and the reason code are stored; nothing is changed until Apply.

Reason codes (reuse `CheckInReason`): insufficientLogging, insufficientWeighIns, intakeOffTarget, implausibleWeightChange, onPace, atCalorieFloor, atCalorieCeiling, recentChange, fightWeek, slowerThanPlanned, fasterThanPlanned, maintenanceDriftUp/Down. Add: partialLoggingFlagged, lowIntakeSafety, lossAboveCap, programTooNew.

Adherence-neutral option (from MacroFactor [V]): when intake is off target but logging is complete, instead of holding with "intake off target", offer "Re-base on what you actually ate" (Tier 2 only) so the plan matches reality. Keep the hold as the default for Tier 1 (Carbon-style).

Language rules (copy, not code): describe the plan not the person ("the plan has not been tested yet", not "you did not follow"); no "cheat", "bad", "good", "failed", "over/under budget" in red; numbers neutral; offer "Keep current" as an equal-weight button; Fuelin explicitly reframed red as "low" not "bad" [V].

### 4.7 Rules-based insights (no AI needed)

All computed over a trailing 7 days, shown only when the data gate passes, in neutral colour, never as streaks.

| Insight | Rule |
|---|---|
| Protein days hit | Count of days where protein >= 90% of target (or >= 1.6 g/kg). Show "5 of 7 days". Suggest the meal slot with the lowest average protein share (rule: argmin of mean protein by slot over days logged) |
| Weekly average vs target | mean logged kcal / target; band +/-5% "close", 5 to 10% "a little off", > 10% "off plan, trend not judged" |
| Training vs rest carbs | mean carbs on hard days minus rest days vs planned difference; flag if hard-day carbs < 3 g/kg on 2+ days |
| Fuel around hard sessions | on days with a hard session, whether >= 30 g carbs logged in the 3 h before/after (only if timestamps exist) |
| Logging coverage | days logged x/7; if < 5: "this week is too thin to adjust from" |
| Weigh-in coverage | weigh-ins x/week; "3 or more makes the trend reliable" |
| Floor proximity | target within 100 kcal of `minimumKcal`: "your target is near its safe minimum; the next change would be slower pace or a maintenance week, not a lower number" |
| Deficit duration | weeks since last maintenance week; after 10 continuous deficit weeks, suggest an optional maintenance week for training quality and hunger (not as a metabolic reset: evidence mixed [V]) |

Optional safety layer for the eating-disorder risk (Levinson 2017 [S]): a "hide calories, show protein and fuel-for-training only" display mode; no weight-loss celebration animations; re-ask the safety flags every 8 weeks and whenever a loss goal starts; add a short validated screen at setup (SCOFF 5 questions [U: from memory]; for women also the LEAF-Q [U]) with a "needs professional review" result rather than a diagnosis.

---

## 5. Comparison with policy v2 (PR #58 and what followed): gaps and risks

| # | Gap or risk | Evidence | Severity |
|---|---|---|---|
| G1 | `WeeklyCheckIn` is not wired to UI, controller or storage; no history/version of accepted targets | grep on `chrome-laneF` found no caller [U] | High (feature absent) |
| G2 | Weekly 7-vs-7 mean difference is below weigh-in noise at 3 weigh-ins/week, and the on-pace band min (0.15% body weight, about 0.1 kg) is smaller than that noise. Expect false proposals | Section 4.2 arithmetic [U: noise SD assumed] ; MacroFactor uses about 3 weeks [V] | High |
| G3 | Floor = RMR protects little for a training athlete. Worked example [U: my arithmetic, 25% body fat assumed]: woman 60 kg, 165 cm, 25 y: RMR 1,345; five 60-min "moderate" sessions (MET 7.0 -> net 6.0) = 360 kcal each = about 257 kcal/day average. Energy availability at target = RMR is about (1,345 - 257) / 45 kg FFM = 24 kcal/kg FFM. With carb floor and macro floors the minimum day is about 1,430, EA about 26. Both are under the 30 kcal/kg FFM risk marker, which IOC 2023 treats as a flag not a threshold [S] | Code read + REDs [S] | High for women and lean athletes |
| G4 | Check-in treats "intake not within 10% of target" as a plain hold. A user eating far below target while losing quickly gets "intakeOffTarget" with no safety message; no check that logged intake is below RMR | `weekly_check_in.dart` | High |
| G5 | Loss options offer 1.0%/week outside fight camp; evidence for athletes favours 0.5 to 0.75% (Garthe 0.7% vs 1.4%; Helms 0.5 to 1%) and slower for leaner athletes. Body fat is not in the model so leanness cannot lower the cap | `weight_rate_policy.dart` | Medium |
| G6 | No partial-logging signal. Days logged counts any entry. One snack counts as a logged day, which silently lowers measured intake. MacroFactor and Carbon both treat this as the dominant failure mode [V] | `WeeklyCheckInInput.daysLogged` | High |
| G7 | No weigh-in conditions (time of day, post-training, sweat loss). For fighters, sparring and sauna-adjacent sweat can swing 1 to 2 kg [U: general knowledge] | `WeightTrend` takes raw `kg` only | Medium |
| G8 | No plateau/duration logic beyond "at floor" hold. No guidance on maintenance blocks, no max-deficit-duration | `weekly_check_in.dart` | Medium |
| G9 | Step size is fixed 100/150 regardless of the miss; not explainable as a formula and slow to converge when the miss is large (0.3 kg/week miss is about 330 kcal/day) | `weekly_check_in.dart` | Low (conservative, but unexplained) |
| G10 | Adults-only is safe but excludes teen amateurs, a large share of amateur combat sport. No fallback experience for 14 to 17 | safety policy; NFHS wrestling programme shows a minors safeguard model (<= 1.5%/week, SG <= 1.025) [S] | Medium (product), High if bypassed by false birthdate |
| G11 | Safety flags are one-time self-declarations; no screen instrument, no re-ask, no behavioural triggers (e.g. repeated weight-cut history) | safety policy | Medium |
| G12 | Session energy table MET values are an unreviewed default; Mifflin has individual error in athletes (O'Neill 2023 [S]); activity-factor answers are noisy. Labels say "starting estimate"? Not confirmed in UI | `session_energy_table.dart` flag | Medium |
| G13 | Carb floor (3 g/kg) is only warn-only for maintain/gain; fine, but the `minimumDailyKcal` still includes it for losing only; a heavy-training maintainer on a low target is not flagged by EA proxy (see G3) | `nutrition_target_calculator_v2.dart` | Low |
| G14 | Adherence-neutral path (MacroFactor) does not exist; users who log accurately but eat off-plan can never get a recalibrated plan under the Carbon-style hold | design | Low/Medium |
| G15 | 7,700 kcal/kg treats all weight as fat; MacroFactor uses a fat/lean mix in V3 (about 4,282 vs 824 kcal/lb) [V]. For short camps this slightly misstates expected loss; check-in corrects | `weight_rate_policy.dart` | Low |

What the repo does at least as well as the best apps: versioned deterministic engine, reason-coded decisions, recommend-only design, hold-on-bad-data, one change per week, fight-week handover to camp policy, food-only line, protein/carb/fat floors tied to ISSN 2025.

---

## 6. Ten ranked recommendations

Rank by (safety and correctness impact) over effort.

1. **Use a 21-day OLS slope with a measured noise band, plus the Tier 0/1/2 data gates, in place of 7-vs-7 means.** Fixes the largest correctness risk (G2) and makes decisions explainable as "slope vs plan". Effort S (pure Dart, one file plus tests).
2. **Add an energy-availability proxy floor.** `minimumDailyKcal = max(RMR, fixed + carb floor, RMR + 0.5 x average planned session kcal/day)`, and a warning when estimated EA (needs optional body-fat or assumed 20 to 25%) < 30 kcal/kg FFM, worded as a risk indicator. Needs dietitian review. Effort S to M (G3).
3. **Safety escalation inside the check-in.** New reason codes: lowIntakeSafety (average logged intake < RMR for 2 weeks), lossAboveCap (trend loss > 1% body weight for 2 weeks), repeated declines at floor. Result is a SAFETY card, not a number. Effort M (G4, G11).
4. **Wire `WeeklyCheckIn` + trend into a recommend-only Apply / Keep / Not now flow with target history (policy version + reason code stored).** Without this nothing above ships. Effort M to L (G1).
5. **Logging-quality model: mark days "complete" or "partial", and count a day only if complete or >= 50% of target kcal.** Biggest data-quality lever in every adaptive app. Effort M (G6).
6. **Cap non-camp loss options at 0.75% (keep 1.0% only inside fight-camp path), and make 0.5% the default with copy about lean-mass retention; lower cap if body fat is supplied and < 12% men / 20% women [U thresholds].** Effort S (G5).
7. **Add weigh-in condition tags (standard / post-training / fight week) and exclude non-standard weigh-ins from the decision slope.** Effort S to M (G7).
8. **Plateau and duration rules: "at floor" next step is slower pace or a maintenance week; after 10 continuous deficit weeks offer an optional maintenance week framed for training quality and hunger, never a metabolic reset.** Effort M (G8).
9. **Insights and language pack: the rules in section 4.7 with a copy guide (neutral colours, no streaks, no judgement words), a "hide calories" mode, and a re-ask of safety flags every 8 weeks.** Effort M (G11, eating-disorder risk).
10. **Tier 2 adaptive expenditure proposal (observed = intake - slope x 7,700) with partial-log marking, and a junior mode for 14 to 17 (maintenance/gain only, no deficit numbers, coach/doctor referral).** Effort L (G9, G10, G14; requires dietitian sign-off and owner decision on minors).

---

## 7. Sources

Competitor documentation
- MacroFactor expenditure: https://help.macrofactorapp.com/en/articles/20-expenditure
- MacroFactor weight trend: https://help.macrofactorapp.com/en/articles/21-weight-trend
- MacroFactor logging frequency: https://help.macrofactorapp.com/en/articles/109-how-frequently-do-i-need-to-log-my-weight-for-the-expenditure-algorithm-and-weekly-coaching-updates
- MacroFactor check-ins and modules: https://help.macrofactorapp.com/en/articles/247-introduction-to-check-ins-and-coaching-modules
- MacroFactor V3 expenditure: https://macrofactor.com/expenditure-v3/
- MacroFactor accuracy: https://macrofactor.com/algorithm-accuracy/
- MacroFactor goal features: https://macrofactor.com/goal-features/
- MacroFactor dynamic maintenance: https://help.macrofactorapp.com/en/articles/125-how-does-dynamic-maintenance-work-in-macrofactor
- MacroFactor protein: https://help.macrofactorapp.com/en/articles/142-protein
- MacroFactor refeeds / diet breaks (help): https://help.macrofactorapp.com/en/articles/30-does-macrofactor-support-refeeds-diet-breaks-or-carb-cycling
- MacroFactor refeeds / diet breaks (evidence article): https://macrofactor.com/refeeds-diet-breaks/
- MacroFactor fat loss handbook (PDF, not decodable; figures via search snippet): https://macrofactor.com/wp-content/uploads/2025/11/MacroFactor-Fat-Loss-Handbook.pdf
- Carbon weekly check-in: https://help.joincarbon.com/en/articles/6004812-weekly-check-in-in-carbon-how-it-works-and-what-to-expect
- Carbon macros: https://help.joincarbon.com/en/articles/14005628-how-carbon-sets-and-adjusts-your-macros
- Carbon targets high/low: https://help.joincarbon.com/en/articles/15826058-why-are-my-carbon-calorie-targets-so-high-or-so-low
- Carbon initial goal: https://help.joincarbon.com/en/articles/6040890-how-to-create-your-initial-goal
- RP Diet Coach: https://rpstrength.com/pages/diet-coach-app
- Cronometer scores: https://cronometer.com/blog/nutrition-scores/
- Noom weight zone: https://www.noom.com/support/faqs/question-topics/weight-logging/2016/08/how-often-should-i-be-weighing-in-2/
- Fuelin: https://www.fuelin.com/ and https://fuelin.com/articles/psychology-of-carb-colours
- Fuelin independent review: https://hoppersportsperformance.substack.com/p/my-experience-with-fuelin-program
- TrainingPeaks Fueling Insights: https://www.trainingpeaks.com/fueling-insights/ ; https://athletechnews.com/trainingpeaks-debuts-fueling-insights/
- Oura meals: https://ouraring.com/blog/oura-meal-logging-data/

Science
- ISSN 2025 combat-sport weight cut stand: https://pmc.ncbi.nlm.nih.gov/articles/PMC11894756/
- Helms, Aragon, Fitschen 2014: https://pmc.ncbi.nlm.nih.gov/articles/PMC4033492/
- Aragon et al. 2017 ISSN diets and body composition: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5470183/
- Trexler, Smith-Ryan, Norton 2014: https://pmc.ncbi.nlm.nih.gov/articles/PMC3943438/
- Garthe et al. 2011 (record): https://lida.sport-iat.de/ta/Record/4020931
- Morton et al. 2018 BJSM: https://pubmed.ncbi.nlm.nih.gov/28698222/
- Hall et al. 2011 Lancet (via critique of 3,500 rule): https://pmc.ncbi.nlm.nih.gov/articles/PMC4442575 ; NIDDK Body Weight Planner: https://www.niddk.nih.gov/research-funding/at-niddk/labs-branches/laboratory-biological-modeling/integrative-physiology-section/research/body-weight-planner
- Frankenfield 2005: https://pure.psu.edu/en/publications/comparison-of-predictive-equations-for-resting-metabolic-rate-in-/
- O'Neill et al. 2023, RMR equations in athletes: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10687135/
- IOC 2023 REDs: https://pubmed.ncbi.nlm.nih.gov/37752011/
- Levinson 2017: https://pubmed.ncbi.nlm.nih.gov/28843591/
- Calorie-tracking and ED symptoms (2021): https://aes.as.uky.edu/bibcite/reference/27230
- NFHS wrestling weight management (via UIL): https://www.uiltexas.org/wrestling/page/wrestling-minimum-weight-certification-program-information

Could not retrieve (PubMed and one PMC page blocked the fetch tool): ACSM/AND/DC 2016 text, Trexler recommendations section, Hall 2011 abstract, Garthe full text, MyFitnessPal help page (403). Do not cite specifics from them without re-checking.

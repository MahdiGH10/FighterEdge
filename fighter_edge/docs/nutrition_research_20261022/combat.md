# Combat-sport nutrition and weight management: evidence and safe-by-design rules for Fighter Edge

Date: 2026-10-22. Research only; no code or git changes.

## 0. Scope notes and verification status

- **Missing input docs.** `docs/NUTRITION_COMPETITOR_RESEARCH.md` and `docs/TRAINING_PLAN_PROPOSAL.md` do not exist in the working tree or git. I used `docs/FIGHT_CAMP_PATTERN_BRIEF.md` (competitor patterns, which already studied CutCoach, Runna, MacroFactor) and the code instead. I did NOT read `docs/edge_fuel/SAFETY_AND_EVIDENCE.md`; read it before acting on this report.
- **What I could actually read in full text:** the ISSN 2025 position stand (PMC11894756, about 300k characters, first ~300k read via a summariser, so numbers below are as extracted and should be spot-checked against the PDF) and the ACSM 2021 weight-category consensus (Burke et al., author's accepted PDF, extracted with pdftotext; verified directly).
- **Not verifiable here (marked UNVERIFIED below):** ACSM/AND/DC 2016 joint position exact tiers (only secondary summaries), Burke 2018 "fuel for the work required" figures, ISSN 2018 sports-nutrition numbers, ISSN creatine dose text, IOC REDs 2023 full text, IBJJF/ADCC/USA Boxing weigh-in rules, IMMAF hydration policy, any current UFC/USADA weigh-in policy beyond news summaries. PubMed, Taylor & Francis, Springer and Human Kinetics returned 403/cookie walls.
- No statistic below is invented. Where a number comes from a secondary source I say so.

## 1. What the repo already does (so recommendations are incremental)

- `lib/features/fight_camp/domain/weight_cut_policy.dart`: already built on the ISSN 2025 position stand. Camp loss 0.5-1.0 kg/week; fight week = last 7 days; food-only fight-week loss capped at 2% (glycogen 1-2% plus fibre 1-2%, low end); suitable total acute loss 6.7% at 72 h, 5.7% at 48 h, 4.4% at 24 h; sweat allowance by competition category (grappling 3%, amateur striking 4%, Olympic 5%, pro 6%); under-18 not supported.
- `weight_path.dart`: statuses `onTrack`, `needsSupervision`, `notSafe`, `atWeight`, `needsMoreData`, `notSupported`. Water cut is flagged, never written out. Good design; keep.
- `fight_camp.dart`: phases offCamp, camp (default 8 weeks, 4-16), fightWeek (7 d), refuel, postFight (7 d). Weigh-in lead max 2 days.
- `NutritionPolicy` / `NutritionTargetCalculator`: Mifflin-St Jeor RMR times activity coefficient (1.20-1.90); fat-loss deficit 10-20%; protein 1.8 g/kg (1.6 maintain); fat 27.5% of kcal; carb floor 3.0 g/kg for high/very-high load; target never below RMR; clinical flags (ED history, pregnancy, diabetes on meds, kidney, liver) send to professional review.
- Gaps vs evidence (details in section 9): no carbohydrate periodisation by session type, no fat g/kg floor, no off-camp "12-15% above class" check, no energy-availability (EA) guard, no refuel targets or daily fight-week steps in domain (the pattern brief says these "need domain work first"), no hydration tracking, no youth pathway other than refusal.
- Note the pattern brief says fight-week "food-only steps (lower fibre, carbohydrate reduction)". Even those are not risk-free (see 3.5); they need dietitian sign-off.

## 2. Energy, protein, carbohydrate, fat by training load

### 2.1 Primary consensus numbers

| Item | Value | Source / status |
|---|---|---|
| Carb, off-camp, light activity | 3-5 g/kg/day | ISSN 2025 body text (extracted) |
| Carb, off-camp, intense training | 8-12 g/kg/day | ISSN 2025 body text (extracted) |
| Carb, moderate load | 5-7 g/kg/day | ACSM 2021 Table 3 (verified in PDF) |
| Carb, heavy load to glycogen supercompensation | 6-10 g/kg/day | ACSM 2021 Table 3 (verified) |
| Carb general athlete range | 3-10 g/kg/day, up to 12 for extreme/prolonged | AND/DC/ACSM 2016, via secondary summary only (UNVERIFIED tiers) |
| Carb during energy-restricted descent | not below 3.0-4.0 g/kg/day | ISSN 2025 point 6 |
| Protein during descent | point 6 says 1.2-2.0 g/kg minimum band; practical-application text gives 1.6-2.2 g/kg/day. The paper is internally inconsistent; use 1.6-2.2 | ISSN 2025 |
| Protein, general athletes | 1.2-2.0 g/kg/day | AND/DC/ACSM 2016 (secondary summary) |
| Protein, injury | 1.3-2.5 g/kg/day | ISSN 2025 |
| Protein, physique contest prep (lean mass basis) | 2.3-3.1 g/kg lean mass, fat 15-30% kcal, loss 0.5-1% BM/week | Helms, Aragon, Fitschen 2014 (bodybuilding, not combat; extrapolation) |
| Fat during descent | point 6 minimum 0.5-1.0 g/kg/day; body text 0.7-1.3 g/kg/day | ISSN 2025 |
| Fat, general | 20-35% of energy | AND/DC/ACSM 2016 (secondary) |
| Camp weight loss | 0.5-1 kg/week | ISSN 2025 |
| Gradual-loss rule in regulated wrestling | at most 1.5% BM/week (NCAA/Wisconsin, adolescent NFHS too) | ACSM 2021 (verified); this is a rule, not a nutrition target |
| Off-camp "walk-around" mass | 12-15% above class limit during general preparation | ISSN 2025 point 3 |
| Cutting more than 12-15% in under 8 weeks | "may raise risk of low energy availability" | ISSN 2025 (extracted via summariser; check wording) |
| LEA threshold | 30 kcal/kg FFM/day, widely used, derived from lab studies in women; exact male cutpoints "not definitively established"; ISSN-cited paper proposes 20-25 kcal/kg FFM for male BM loss | IOC REDs 2023 via secondary summary; PMC12513969 scoping review |
| Weight-loss energy approach | Mifflin-St Jeor or Cunningham, or indirect calorimetry | ISSN 2025 point 5 |
| Training volume in camp | up to three sessions per day | ISSN 2025 |

Hall: the dynamic body-weight model (Lancet 2011) shows the "3500 kcal = 1 lb" rule is structurally wrong because energy balance changes as weight changes. Implication for the app: never project a straight-line loss from a fixed deficit; use trend weight and re-fit (the app already uses trend weight in `weight_trend.dart`). I did not read the paper itself (model parameters UNVERIFIED).

Helms et al. is bodybuilding contest-prep, so only use it as supporting evidence for protein-high and slow-loss principles, not combat-specific numbers.

### 2.2 Suggested carbohydrate periodisation by session type (information tier, needs dietitian sign-off)

Derived from ACSM Table 3 and ISSN 2025; there is no single combat-sport table in what I could read, so the mapping is my synthesis.

| Day type | Carb target (g/kg/day) | Basis |
|---|---|---|
| Rest or technique-only, light | 3-5 | ISSN light-activity range |
| Moderate load (one moderate session) | 5-7 | ACSM moderate |
| Heavy (two sessions, hard sparring/conditioning) | 6-10 | ACSM heavy |
| Camp descent floor on any training day | not below 3-4 | ISSN point 6 |
| Peak intensity block, no deficit | up to 8-12 | ISSN intense |

Rules of thumb that the sources support: more carbohydrate on hard days, less on rest days; protein spread across meals (~20-25 g high-quality protein after sessions, ACSM table); ~1 g/kg/h carbohydrate in the first hours after hard sessions when a second session is within about 8 hours (ACSM table, "~1 g/kg BM/h", up to 4 h).

The existing 3.0 g/kg floor in `NutritionPolicy` is at the bottom of ISSN's 3.0-4.0 band. Consider raising the floor to 3.5-4.0 on two-session days (dietitian decision).

## 3. Fight-camp phases: what nutrition changes

Sources: ISSN 2025 (phases), ACSM 2021, Burke/Slater/Reale reviews. The phase names below match `CampPhase` plus camp sub-phases that the code does not have.

| Phase | Goal | Nutrition change | Notes |
|---|---|---|---|
| Off-camp / general prep | stay 12-15% above class (ISSN pt 3); build muscle/skills | maintenance or small surplus; carbs 3-5 light to 8-12 intense by load; protein 1.6-2.2 | Avoid year-round dieting; chronic low EA is the RED-S route |
| Build (weeks ~8-4) | slow fat loss if needed 0.5-1 kg/week; highest training volume | deficit moderate; protect carbs at 3-4+ g/kg floor, higher on heavy days; protein 1.6-2.2; fat 0.7-1.3 g/kg | Up to three sessions/day; fatigue and injury risk rise when carbs cut |
| Peak (weeks ~4-1 before fight week) | sharpen, hit fight-week entry weight | continue descent; pre-plan food tolerances; test foods | Camp pace already modelled by `WeightPathCalculator` |
| Taper | reduce volume | energy need falls: reduce calories with training, keep carbs adequate | Not defined in code; keep information-only |
| Fight week (7 d to weigh-in) | last 1-2% from diet only for app; rest needs supervision | reduce glycogen-bound water (carb restriction 1-2% BM, ISSN pt 9) and gut content (<10 g fibre/day for 4 days, 1-2% BM, ISSN pt 9); sodium: establish baseline, <2.3 g/day may be used but not below the 2300 mg/day RDA | Info-only; see 5.3 |
| Weigh-in | make weight | n/a | |
| Rehydrate / refuel | restore fluid, glycogen, gut comfort | 1-2 h: oral rehydration solution 1-1.5 L/h, carbs up to 60 g/h; 3-6 h: electrolyte fluids, simple starch; 6+ h: high carb, low/moderate protein, little fat, small frequent meals; 8-12 g/kg carb if depleted, 4-7 g/kg if modest restriction; limit fibre; regain at least 10% of BM (pt 15) | ISSN pt 12-15 as extracted; ACSM gives fluid at ~150% of deficit, 50-60 mmol sodium, large bolus ~10 mL/kg after weigh-in |
| Fight day | perform | 1-4 g/kg carb in the window (6 h window: 210-280 g for a 70 kg athlete; 12 h: 420-560 g), 20-30 g protein per meal, no fat for about 3 h pre-competition | ISSN 2025 example |
| Post-fight (week after) | recover | return to maintenance energy, protein at the high end, carbs per load; no deficit | Medical review after knockouts or injury is outside nutrition scope |

Rehydration detail that matters for app copy (ISSN, extracted): replacing 125-150% of sweat loss is practical for 24-36 h windows, often impractical for same-day weigh-ins; if hypohydration is above 3% BM start about 300-500 mL right after weigh-in then about 240-350 mL every 30 min; ORS with 50-90 mmol sodium above 3%, under 3% sports drinks with under 30 mmol sodium. NOTE: the position stand prints "mmol/dL" in point 12, which is almost certainly a typo for mmol/L (ACSM says ~50-60 mmol sodium). UNVERIFIED which unit the authors meant; do not hard-code this in the app without dietitian review.

## 4. Weight classes and cutting

### 4.1 Gradual vs rapid vs water manipulation

- Gradual loss (fat mass over weeks) is the only method all consensus statements endorse without conditions: 0.5-1 kg/week (ISSN), 0.5-1% BM/week (Helms, bodybuilding), at most 1.5% BM/week in regulated wrestling programmes (ACSM, NCAA).
- Rapid weight loss (RWL) via fluid/food restriction, passive heat, exercise in heat, diuretics, laxatives is very common: Reale/Slater/Burke MMA survey (n = 314): most athletes cut (men 97.2%, women 100%), pre-weigh-in loss greater in professionals than amateurs, coaches the main influence (men 29.3%, women 48.1%). An Irish amateur MMA study (n = 30, other authors): 97% cut, mean 7.9% +/- 3.1% of habitual BM. Prevalence of RWL across combat sports is 42-90% depending on study (scoping review). Source: search summaries of abstracts; I did not open the full papers.
- Youth: a Lithuanian combat-sport survey (other authors) reported 88% had lost weight to compete, weight cycling from as early as age 9 (mean 12.8 +/- 2.1 years). Secondary summary; UNVERIFIED.
- Water loading: ISSN reports one protocol (Reid et al.: 100 mL/kg/day for 3 days, restricted to 15 mL/kg on day 4) with day-5 loss of 3.2% vs 2.4% in controls; other studies had confounds. Sodium restriction: not below the 2300 mg/day RDA. Diuretic use in a 637-athlete survey: 12% overall; diuretics are on the WADA prohibited list.

### 4.2 Safe-rate and distance limits (what the evidence supports)

- ISSN suitable total acute loss: 6.7% (72 h), 5.7% (48 h), 4.4% (24 h) before weigh-in, and these are for supervised athletes, not self-directed beginners. The app's policy already takes the min of this and a diet-plus-sweat allowance.
- Sweat loss target depends on time between weigh-in and bout (ISSN): under 4 h: 0-3% sweat plus 1-2% glycogen; 4-12 h: 2-4% plus 1-2%; 12-24 h: 3-5%; 24-36 h: 4-6%.
- "How far from fight-week weight is safe for amateurs?" No source gives an amateur-specific number. The app's logic (diet-only 2% in fight week for anyone, more only if supervised) is more conservative than ISSN, which is appropriate. ISSN's 12-15% off-camp ceiling is for camps of 8+ weeks; below 8 weeks with a large cut, LEA risk rises. This should become a camp-length check, not only a weekly-rate check.
- ACSM 2021 safe-practice recommendations (verified, Table 6): select a suitable weight class that the athlete can reach "without undue physical, nutritional or psychological stress"; day-to-day body mass should be within reach of the class; "minimal weight may not be the optimal performance weight"; discourage any weight making among minors and the youngest participants; sporting organisations should shorten weigh-in to competition time, classify by preseason body composition, and ban unhealthy methods.

### 4.3 Same-day vs day-before weigh-ins

- ACSM (verified): shorter weigh-in-to-competition gaps reduce harmful practices (NCAA moved weigh-ins to 1-2 h pre-competition; result: smaller seasonal weight swings, rapid regain reduced to 1.2 +/- 0.9 kg). It may not be possible to refuel sufficiently with a 1-2 h gap.
- ISSN: same-day weigh-ins are common in wrestling, taekwondo and most jiu-jitsu bodies (the paper says so; I could not confirm IBJJF/ADCC specifics).
- Boxing: examples found (Ontario amateur rules, Irish amateur rules, British Army Boxing) weigh the boxer on the day they box, and Delaware allows up to 24 h. USA Boxing specifics UNVERIFIED.
- IMMAF youth rules (January 2025 document, via search): weigh-ins on the day of competition, 1 lb allowance; amateur rules say weight-cutting techniques are "to be discouraged". IMMAF hydration testing UNVERIFIED (not found).
- UFC (news summaries, dated): weigh-in the day before, 9-11 a.m. local; IV rehydration banned since October 2015 (policy: IV above 100 mL per 12 h only if medically justified); UFC fight-week weight tracking from 2016 with check-in within 8% of target. Dated and secondary; UNVERIFIED for 2026.
- California athletic commission (via search): dehydration checks at physicals, specific-gravity tests, heavier-division requirement on failure.
- ONE Championship: after the December 2015 death of a 21-year-old flyweight (reports spell his name differently), adopted walking-weight rules with hydration testing and daily weight logging. Wikipedia and sport media; ACSM cites it as a response "similar to the NCAA Program" (verified in ACSM).
- Hydration testing is imperfect: ACSM notes urine specific gravity cut-offs can misclassify euhydrated athletes (false positives common). Treat USG as a regulatory tool, not a hydration test the app should interpret.

### 4.4 Deaths and injuries

- ACSM 2021 (verified): "The most serious consequence of making weight is death", reported in taekwondo, college wrestling, MMA, judo, Muay Thai and lightweight rowing, typically from cardiovascular complications and/or heat stroke secondary to fluid restriction, passive heat or strenuous sweat exercise. Acute kidney injury also associated with extreme fluid loss.
- 1997: three US collegiate wrestlers died in about 35 days (CDC: dehydration and hyperthermia from rapid weight loss). NCAA rule changes January 1998: weigh-ins 1-2 h before, +7 lb per class, ban on heat/sweat devices and artificial rehydration, certification with body composition and USG 1.020-1.025, max 1.5% BM/week. Source: NCAA news pages and ACSM.
- Hyperthermia is defined in ISSN as core temperature above 40 C, the monitoring threshold for heat-based loss.
- RED-S: chronic low EA affects metabolic, endocrine, reproductive systems, growth in child and adolescent athletes; reductions in testosterone and IGF-1 across wrestling seasons; fat-free mass loss in a boxing camp (ACSM, verified). ISSN reports testosterone falls with 13-15% losses over 8 weeks.
- Eating-disorder scores are higher in weight-category athletes than in matched controls (ACSM line ~265, verified statement; exact comparison group per paper). 

### 4.5 Minors

- AAP 2005 policy (via press coverage): no weight-loss plan for athletic purposes before ninth grade; ban on rubber suits, saunas, diet pills, diuretics; flags weekly change of more than 1-2 lb as dangerous. AAP 2017 clinical report warns about rapid changes in youth. UNVERIFIED beyond summaries.
- ACSM 2021: strategies should discourage any weight making among minors.
- NFHS: minimum body fat 7% (boys) and 12% (girls) for high-school wrestlers; 1.5%/week limit (ACSM, AAP site).
- The app's existing under-18 "not supported" behaviour is correct. Extend it: no deficit calorie target for minors at all, a growth-focused "eat enough" screen, and a note to talk to a coach/parent/doctor.

### 4.6 Should an app give water/sodium protocols?

No. Reasons: (a) the margin between the 4-6% figures and harm is small and individual; (b) ISSN and ACSM frame water manipulation as supervised and as the practice linked to deaths; (c) the app cannot monitor temperature, symptoms, heart rate, urine, or mental status; (d) post-weigh-in recovery windows vary from 1 hour to 36 hours and the app cannot verify them; (e) diuretics and some masking practices are anti-doping violations (WADA strict liability); (f) legal and store-policy exposure (not researched; UNVERIFIED). This matches the current `WeightCutPolicy` doc comment.

## 5. Safe-by-design rule list

### 5.1 Hard limits (code-enforced, domain layer)

1. Age under 18 or unknown age: no weight-cut plan, no deficit target, no cut timeline. Ask age; unknown fails closed.
2. Never output a fluid restriction, water loading, sodium manipulation, sauna, hot bath, sweat suit, diuretic, laxative, enema, vomiting or fasting instruction, in UI, notifications, or AI text. Add a denylist in the Functions validator.
3. Camp loss rate: never plan above 1.0 kg/week (existing). Add a percentage cap of 1.5% BM/week as a second limit (NCAA/ACSM regulated reference).
4. Fight-week app-planned loss: food-only, capped at 2% (existing).
5. Energy never below RMR (existing); add an EA guard: if estimated EA falls below 30 kcal/kg FFM/day for more than a few days, stop the deficit and show a professional-review card. Needs body fat input; if no body composition, use a conservative RMR floor only. Cutpoint for men is not definitively established (IOC 2023, secondary), so label "estimate".
6. Carbohydrate: never plan below 3.0 g/kg/day (existing); sign-off may raise to 3.5-4.0 on two-session days.
7. Protein minimum 1.6 g/kg in any deficit; fat floor 0.5 g/kg (ISSN descent minimum). Currently only protein is enforced.
8. Minimum-weight guard: refuse a class limit that implies body fat below a configurable floor (NCAA uses 5% for men; NFHS 7%/12% for adolescents). Needs a dietitian to set values and a body-fat estimate caveat; skinfold or smart-scale estimates are unreliable.
9. BMI under 18.5 + deficit goal: refuse (existing for `loseFat`; extend to camp weight path).
10. Weigh-in leads and times: the app does not tell the user how to behave in the final 24 hours before a same-day weigh-in beyond "stop cutting, rehydrate when allowed".

### 5.2 Refuse and show "talk to a professional"

Show a non-dismissable referral card (no plan) when:
- under 18; or age unknown.
- required loss in fight week exceeds what food alone covers (`needsSupervision`) or exceeds ISSN limits (`notSafe`). Offer "lightest safe class" and "later fight date" (already in `lightestSafeLimitKg`).
- any clinical flag (existing list), plus: recent fainting, dizziness, chest pain, palpitations, dark urine for days, vomiting, amenorrhea or loss of periods, stress fracture, history of heat illness, current use of diuretics or laxatives or prescribed stimulants.
- prior cuts of more than the app's allowed pace in the last 8 weeks (weight cycling), or repeated cuts of more than 5% within a few weeks (threshold my suggestion; no source).
- user self-reports binge/purge, restriction fear, or body-image distress (screen at setup and at each camp start).
- mid-camp loss faster than planned by more than a margin, or weight below the planned path for two weigh-ins, or energy/mood/sleep scores falling together.
- Weigh-in within a day or two and user is more than 2% above the limit.

### 5.3 Never automate

- Any prescription during fight-week that depends on exact hours, fluid volumes or sodium grams for the cut itself.
- Personalised IV, medication, diuretic, supplement-stacking or pharmaceutical advice.
- Medical diagnosis (RED-S, eating disorder, kidney). Show "signs to watch for" only.
- AI free-text "how to cut water weight" answers: AI must refuse and return the same professional card; the AI only explains trusted calculator facts (consistent with CLAUDE.md).
- Server-side or client-side "unlock" of supervised cuts via Pro entitlement. Safety rules must not be a paywall lever.
- Auto-adjusting targets downward in response to missed weight without user review; propose, never apply.

### 5.4 Safe-by-design UX rules

- Show "walk-around weight", "class limit" and "to go" in kg and % body mass, with the percentage visible so the user feels the cost.
- Explain why the app does not plan water loss (selling point, already in the pattern brief).
- Hydration tracking: let users log water, colour of urine and body weight; show only "log" and "on target" for ordinary hydration (e.g. drink to thirst, pale urine), not cut-targets. Do not show a daily fluid deficit target in fight week.
- Always show the date-stamped policy version and "not medical advice".
- Never log or commit meal text, measurements, clinical flags beyond what the repo rules allow.

## 6. Supplements, caffeine, creatine, anti-doping caution

- ISSN 2025 point 4 supports creatine, beta-alanine, HMB and caffeine as potentially useful across preparation, competition and recovery (no doses in the portion I could read; the summariser also reported caffeine 3-6 mg/kg and creatine 5-10 g/day in body text vs Table 3 3-5 g/day, which conflict; UNVERIFIED).
- Caffeine in combat sports (Delleli 2022 meta-analysis, 26 studies): small effects (handgrip ES 0.28); no consensus on ergogenic benefit. Earlier review (Lopez-Gonzalez 2019): 3-6 mg/kg raised glycolytic contribution; 3 of 9 studies found no effect.
- Creatine: ISSN 2017 says up to 30 g/day for 5 years safe in healthy people; acceptable in adolescents with supervision (secondary summary). Dose and body-water effect on weigh-in: creatine can add scale weight (commonly cited ~1-2 kg; UNVERIFIED here), which matters for class limits; this is a design point, not a stat from the sources.
- Anti-doping: WADA strict liability; diuretics and masking agents are prohibited in and out of competition and are the weight-class athlete's biggest unintended-violation risk; contaminated supplements are a documented route (secondary sources; Informed Sport/Batch-tested schemes exist but I did not verify protocols).

What the app should say:
- "Supplements are optional. Food first. If you compete in a tested event, check every product on the official anti-doping site before using it."
- Link out to WADA/USADA/UKAD "Global DRO"-style check tools (names not verified; use generic "your national anti-doping agency's lookup").
- Show caffeine and creatine as educational cards (what the research says, "small effect, individual response"), no doses beyond "common research doses are given in position stands; ask a sports dietitian". If the product shows a dose at all, restrict to the ISSN published doses after sign-off.
- Never recommend fat burners, thermogenics, diuretic herbs, "water pills", or any product marketed for fast weight loss; ISSN explicitly does not endorse diet pills, enemas, laxatives and bulimia.
- Never track or suggest prohibited substances; if the user logs one by name, show a warning card.

## 7. Beginner vs intermediate vs advanced

Evidence note: no source tests levels against app UX; the matrix is my design synthesis from the physiology above and the pattern brief. Beginner definition: no regulated bouts yet, or fewer than about 2 amateur bouts; intermediate: regular amateur competition; advanced: tested or professional-tier, has a coach/dietitian.

| Feature | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Daily targets | One calorie + protein target; plate-based guide; no macro splits unless asked | kcal, protein, carb, fat; heavy/light day variation | Full macros by session type, fibre, sodium baseline, per-meal timing |
| Carb periodisation | "Eat more on hard days" (two states) | Rest / moderate / heavy tiers (section 2.2) | Per-session fuelling and recovery windows |
| Weight goal | Hide cut tools by default; offer "find a comfortable class"; recommend competing at walk-around +/- small margin | Camp path with weekly checkpoints, trend weight, diet-only fight week | Weight-class planning with walk-around vs class gap %, camp length check (12-15% / 8 weeks), multi-class what-if |
| Fight-week | Info card: "what happens, eat normally, rest" | Day-by-day information-only template (section 8) | Same template with the user's own notes, plus a "supervised cut required" handoff note for coach/dietitian |
| Hydration | Simple log, thirst/colour guide | Log + trend + sweat-rate estimate (sweat rate from session weight change) | Same; show weight-regain tracking after weigh-in |
| Refuel | Short list of easy foods | Timeline cards (1-2 h, 3-6 h, 6+ h) without volumes | Timeline with athlete-entered preferences; volumes only if signed off |
| Safety screening | At setup: age, health flags, disordered-eating screen | Same + prior cut history | Same + "who supervises you?" field; prompt to share with coach |
| Supplements | Education card only | Education + anti-doping checklist | Same; no dose automation |
| AI | Explains targets | Explains path | Explains path and fight-week facts; never cut instructions |

## 8. Information-only fight-week template skeleton

Applies only when `WeightPathStatus` is `onTrack` or `atWeight`, age 18+, screening passed. This is a display skeleton, not a prescription; every numeric cell needs sports-dietitian sign-off before it ships. Replace "day" labels with D-7 ... D0 (weigh-in), then refuel.

| Day | Training | Food focus (information) | Hydration | Check-ins |
|---|---|---|---|---|
| D-7 | normal last hard session | Eat as camp; practise foods you will eat after weigh-in | Drink to thirst, normal | Trend weight vs entry weight; confirm limit, weigh-in time and rules |
| D-6 | one hard session, then taper | Keep carbs per load; protein steady | Normal | Sleep; note any dizziness or low mood |
| D-5 | moderate | Begin gradually lowering fibre only if signed off (ISSN: under 10 g/day for ~4 days is a published practice with 1-2% BM effect) | Normal | Review "on path" status |
| D-4 | light + sharp technique | Lower fibre continues; carbs per signed-off fight-week range | Normal | Confirm weigh-in venue, scale rules, allowance (e.g. 1 lb IMMAF youth; not for adults) |
| D-3 | light | Same; small frequent meals; keep protein | Normal | If still more than ISSN diet-only 2% above limit, STOP and show "talk to a professional" |
| D-2 | very light | Same; avoid new foods | Normal | Re-check status; packing list (ORS, familiar foods) |
| D-1 | rest or short shakeout | Low-fibre, familiar foods; do not skip meals | Normal; no restriction advice from the app | Check weight; if over, show options (supervised cut, move class, withdraw), not tips |
| D0 weigh-in | none | After the scale: follow refuel timeline | After weigh-in: see refuel cards | Log weigh-in weight |
| Refuel 0-2 h | none | Oral rehydration solution; fast carbs; limit fibre/fat; avoid coffee, citrus, tomatoes, carbonated drinks, chocolate, peppermint, garlic, onion, fatty/spicy/fried (ISSN 0-2 h list) | Sip on a schedule; volumes only if signed off | Log weight regain |
| Refuel 3-6 h | none | Electrolyte fluids, simple starches | Continue | Urine colour |
| Refuel 6 h+ | warm-up per coach | Carb-rich, low/moderate protein, little fat; small frequent meals | Continue | Gut comfort; do not try new food |
| Fight day | per event | 1-4 g/kg carb window; 20-30 g protein per meal; no fat ~3 h pre | Normal | Log; report any symptoms to medical staff |
| Post-fight (7 d) | rest | Return to maintenance; protein high; no deficit | Normal | Medical check if injured |

Important caveats to display on the card: this is general information for healthy adults; it is not a plan to lose weight in fight week; if you are over your limit, talk to your coach or a sports dietitian.

## 9. Findings from the repo vs evidence (small gaps worth fixing)

1. **Camp length vs total cut**: `FightCamp` accepts 4-16 weeks and the path only checks weekly rate. ISSN warns cuts of 12-15% in under 8 weeks raise LEA risk. Add a status or warning when required loss as % of walk-around exceeds ~12-15% or camp is shorter than 8 weeks (dietitian to confirm wording).
2. **Carb floor and training load** are a two-level rule. Add the three tiers from section 2.2.
3. **No fat floor** in `NutritionTargetCalculator`. 27.5% of calories meets 0.5-1.0 g/kg for most, but a 90 kg athlete at 1,800 kcal is 55 g = 0.6 g/kg; verify with tests.
4. **No refuel/fight-week domain** yet (pattern brief step 4).
5. **Camp-pace policy is hard-coded in kg**: 1.0 kg/week is 1.4% for a 70 kg athlete but 0.8% for a 125 kg athlete. Consider a combined kg and % cap (the 1.5%/week NCAA reference, ACSM).
6. **Policy version** still `NutritionPolicy.version = 1` and "pending qualified dietitian review" per its own comment; the ISSN-derived `WeightCutPolicy` has no version field.

## 10. Existing fighter-oriented tools and what users complain about

Evidence is thin; I could not access forums or Reddit through the tools.

- **CutCoach** (competitor): App Store 4.8/5 from 1.6K ratings (US store, search snapshot), Google Play 4.4 from 97 reviews, a third-party tracker lower (3.6/5 from 21 reviews, mostly one-star). Praise: energy kept during a cut, water tracking, one user "lost 8 lb in 5 days". Complaints: launch/login crashes and black screen (fix claimed December 2025, a later report in April 2026), forced subscription before use, forced rating prompt. Their own website testimonials are marketing. Source: store listings and developer site via search. The pattern brief (2026-09-26) also says CutCoach shows water loading and fluid and sodium targets for the cut; our policy deliberately does not.
- **MyFightPrep guides**: educational content; not evaluated.
- **Coaches' spreadsheets, weight-cut calculators on forums**: UNVERIFIED; I found none in the search results. Typical pain points are my hypotheses, not evidence: manual entry, no trend smoothing, no link between training load and food, no safety limits.
- **Pattern-brief competitors** (Runna, MacroFactor, Libra, Lose It!, FightCamp): structural lessons already documented there. Added lesson from this research: a hydration and weight log is what users value; ours should keep that but remove cut targets.
- **Regulator-led tools**: ONE Championship's portal (daily walking weight, hydration tests) is the closest "product" with a safety rationale; the Wisconsin/NCAA programmes are the only evidence-based interventions and have documented harm reduction (ACSM).

## 11. Which items need sign-off from a sports dietitian (before public release)

1. All numbers in `WeightCutPolicy` and the 7-day template, especially <10 g fibre for 4 days and carbohydrate restriction for glycogen water in fight week (ISSN points 9, 7): not for beginners, possible GI and performance impact, individual tolerance.
2. Carb tiers and floor by training load (section 2.2) and protein/fat floors.
3. Whether the app should show any refuel volumes (1-1.5 L/h, 50-90 mmol sodium) and the ISSN unit ambiguity.
4. The 12-15% off-camp and 8-week camp warning and minimum-weight/body-fat guard.
5. LEA/EA guard and what to do without body-composition data.
6. Safety screening questions, referral triggers and wording (ED screen, weight cycling).
7. The status copy for `needsSupervision` and `notSafe` and the supplement/anti-doping text.
8. Minors: legal/ethical wording and whether to show any nutrition content at all.
9. AI system prompt and validator denylist.
10. Whether AI may mention any fight-week number.
The existing handoff (`CAMP_SAFETY_IMPLEMENTATION_20260928.md`) already says to keep prescriptive fight-week guidance out of public release until a clinician or sports dietitian signs off; this report agrees.

## 12. Ten ranked recommendations (S small, M medium, L large)

Ranking by safety value first, then user value.

1. **(S) Add safety screening and referral card to every cut/fight-week entry.** Questions: age, current health flags (including ED/ED symptoms, weight cycling, supervised?). Fail closed. Use the `needsProfessionalReview` path already present. Dietitian sign-off on wording.
2. **(S) Keep water/sodium manipulation out and publish that as a product principle**, with an AI validator denylist for the terms in 5.1 #2. Add tests that every AI/UI string avoids them.
3. **(M) Camp-length and total-loss check**: warn when required loss exceeds ~12-15% of walk-around or camp under 8 weeks (ISSN pt 3 and LEA statement), and offer "heavier class" or "later fight". Pure Dart in `weight_path.dart`. Needs sign-off on thresholds.
4. **(M) Training-load carb tiers** in `NutritionTargetCalculator` using ACSM/ISSN ranges (3-5 / 5-7 / 6-10 / up to 8-12 g/kg), with the descent floor 3.0-4.0, protein 1.6-2.2, fat 0.5-1.0 g/kg floor. Replaces the two-level `carbFloorApplies`. Needs sign-off.
5. **(M) Refuel domain**: pure-Dart timeline (0-2 h, 3-6 h, 6+ h, fight day) from ISSN points 12-15, with copy marked information-only; start with food/foods list and timing only, volumes behind a feature flag until sign-off.
6. **(M) Fight-week info template (section 8)** gated to `onTrack`/`atWeight` adults; no new numbers beyond those in `WeightCutPolicy`; day strip UI already specified in the pattern brief.
7. **(S) Hydration and weight logging without cut targets**: water log, urine-colour check, session weigh-in/out to estimate sweat rate, post-weigh-in regain tracker (supports ISSN rehydration monitoring). No fluid-restriction targets in fight week.
8. **(M) Level-aware UI** per the matrix: beginner sees no cut tools by default and a "choose a sustainable class" explainer; advanced sees weight-class planner with walk-around gap and class what-if. Reuses existing fighter profile/level.
9. **(S) Supplements and anti-doping education card** (caffeine, creatine, "check every product with your anti-doping agency", never diuretics). Content only; no dose automation. Dietitian sign-off.
10. **(L) Energy-availability guard and minimum-weight guard**: estimate EA from intake, exercise and FFM when body composition is available, plus a configurable minimum body-fat/minimum-class rule (NCAA/NFHS precedent). Larger because it needs a body-composition input, an exercise-energy estimate and careful UX; schedule after dietitian review.

## 13. Sources

Primary (read):
- ISSN position stand, Ricci et al. 2025, doi:10.1080/15502783.2025.2467909: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11894756/ (also https://www.tandfonline.com/doi/full/10.1080/15502783.2025.2467909, 403 for fetch)
- ACSM Expert Consensus Statement on Weight Loss in Weight-Category Sports, Burke, Slater, Matthews, Langan-Evans, Horswill, Curr Sports Med Rep 2021;20(4):199-217, doi:10.1249/JSR.0000000000000831: https://researchonline.ljmu.ac.uk/id/eprint/17789/ (accepted PDF: https://researchonline.ljmu.ac.uk/id/eprint/17789/1/ACSM%20Consensus%20Statement%20Weight%20Making.pdf); summary: https://acsm.org/safe-practices-weight-category-sports/
- Scoping review of consensus statements for body-mass manipulation: https://pmc.ncbi.nlm.nih.gov/articles/PMC12513969/ (first 100k characters read)

Secondary or search-summary only:
- Reale, Slater, Burke, Acute weight loss strategies for combat sports and applications to Olympic success, IJSPP 2017;12(2):142-151: https://acuresearchbank.acu.edu.au/item/88q7v/acute-weight-loss-strategies-for-combat-sports-and-applications-to-olympic-success
- Reale et al., Individualised dietary strategies for Olympic combat sports (EJSS 2017): https://acuresearchbank.acu.edu.au/item/88w9w/individualised-dietary-strategies-for-olympic-combat-sports-acute-weight-loss-recovery-and-competition-nutrition
- Reale et al., High prevalence and magnitude of RWL in MMA athletes, IJSNEM 2019;29(5):512: https://journals.humankinetics.com/view/journals/ijsnem/29/5/article-p512.xml (403; figures from search summary)
- Irish amateur MMA RWL: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6783947/
- RWL across combat sports: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11964705/
- RWL <24 h vs >=24 h weigh-ins: https://www.sciencedirect.com/science/article/pii/S2211266925000787
- IOC REDs 2023 consensus (Mountjoy et al., BJSM 57:1073): https://pubmed.ncbi.nlm.nih.gov/37752011/ (cookie wall; details from search summaries)
- AND/DC/ACSM Nutrition and Athletic Performance 2016, doi:10.1016/j.jand.2015.12.006 (tiers UNVERIFIED)
- Helms, Aragon, Fitschen 2014: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4033492/
- Burke, Hawley, Wong, Jeukendrup 2011, Carbohydrates for training and competition: https://doi.org/10.1080/02640414.2011.585473 (not read)
- Hall et al. 2011, Lancet 378:826-837 (not read); Hall and Chow critique of the 3500 kcal rule: https://doi.org/10.1038/ijo.2013.51 (search summary)
- Caffeine and combat sports meta-analysis (Delleli 2022): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9315598/ ; systematic review (Lopez-Gonzalez 2019): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6310931/
- ISSN creatine position stand 2017: https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0173-z (secondary summary)
- NCAA wrestling response after 1997: https://www.ncaa.org/champion/wrestling-away-troubled-past ; https://content.usawmembership.com/articles/3154
- AAP 2017 caution on rapid weight changes in youth: https://www.aap.org/en/news-room/news-releases/aap/2017/caution-about-rapid-weight-changes-in-youth-athletes/ ; https://www.healthychildren.org/English/healthy-living/sports/Pages/Cutting-Weight-A-Major-Problem-in-Wrestling.aspx
- ONE Championship hydration policy: https://www.f4wonline.com/news/mma/one-championships-new-anti-dehydration-weight-cutting-policies-and-analysis-204296 ; https://immaf.org/2015/12/24/one-championship-bans-weight-cutting-by-dehydration-2/
- California athletic commission and IMMAF news: https://immaf.org/2016/02/03/california-tightens-weight-cutting-restrictions-2/
- IMMAF youth rules 2025: https://mma-sa.co.za/wp-content/uploads/2025/06/DOC-20250602-WA0073.1.pdf ; amateur rules Oct 2022: https://immaf.org/wp-content/uploads/2022/10/IMMAF-Rules-Document-as-of-Oct-2022.pdf
- Boxing weigh-in examples: https://www.ontario.ca/document/amateur-combative-sport-rules-boxing/part-iii-pre-competition-requirements ; https://iatba.ie/2024/03/08/information-regarding-weigh-ins
- UFC weigh-in and IV news: https://myfightprep.com/guides/ufc-weight-cut/ ; https://mixedmartialarts.com/news/ufc-instituting-new-weight-cutting-guidelines/
- WADA diuretics and masking: https://www.dshs-koeln.de/en/universitaet/organisation/institute-einrichtungen/department-of-biochemistry/doping-substances/prohibited-classes-of-substances-and-methods/s5-diuretics-and-other-masking-agents ; https://www.globalsportsadvocates.com/blog/weight-management-practices-and-anti-doping-exposure-risks.cfm
- CutCoach listings: https://apps.apple.com/us/app/cutcoach/id6751152119 ; https://play.google.com/store/apps/details?id=com.ethancajigas.cutcoach.android ; https://www.cutcoach.app/
- Repo files: `fighter_edge/lib/features/fight_camp/domain/{weight_cut_policy,weight_path,fight_camp}.dart`, `fighter_edge/lib/features/edge_fuel/domain/{policies/nutrition_policy,policies/nutrition_safety_policy,calculators/nutrition_target_calculator}.dart`, `fighter_edge/docs/FIGHT_CAMP_PATTERN_BRIEF.md`, `fighter_edge/docs/CAMP_SAFETY_IMPLEMENTATION_20260928.md`.

## 14. Unverified list (summary)

- AND/DC/ACSM 2016 carb tiers; Burke 2018 per-session carb tiers; ISSN 2018 sports nutrition numbers.
- ISSN 2025: which unit "mmol/dL" means; caffeine/creatine doses (3-6 mg/kg; 5-10 vs 3-5 g/day); the exact wording of the 12-15%/<8-weeks LEA statement; whether the 16 points were quoted exactly (summariser extracts).
- IOC REDs 2023 thresholds beyond secondary summaries; male-specific EA cutpoint.
- UFC, IMMAF, IBJJF, ADCC, USA Boxing weigh-in and hydration rules; California 10-point plan details.
- Lithuanian youth statistics; AAP 2005 details (press coverage).
- Creatine scale-weight effect size; any app-store or legal exposure for weight-cut features.
- Users' complaints beyond CutCoach store reviews; coaches' spreadsheet practices.

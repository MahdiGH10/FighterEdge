# Palette and image provenance

Measured from AppColors at origin/main 578c636; read 2026-10-01. The two role fixes retain every color value. Script uses sRGB relative luminance, the 0.04045 transfer threshold, foreground-alpha composition on opaque background and (lighter+0.05)/(darker+0.05). Compare full precision against thresholds; tables round for reading. Run `python measure_palette.py <fighter_edge-path>` from this folder to reproduce JSON and ratios. Counts are direct Dart references, including the debug gallery; aliases and runtime states mean a count is not a count of rendered pixels.

Rules: [Contrast minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), read 2026-10-01; [Non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html), read 2026-10-01. Normal text needs 4.5:1; large text needs 3:1. Bold 14px is normal text (14pt is about 18.67 CSS px). Essential control information needs 3:1; decorative borders do not all need it. A passing token pair does not prove a photo/gradient or every composed screen compliant.

## Tokens and roles

ARGB includes opacity: FF is opaque, 22 is about 13.3%, 38 about 22.0%, C7 about 78.0%. Ramps are part of the design system, not dozens of competing foreground accents.

| Token | ARGB | Role | Direct references | Example source |
|---|---|---|---|---|
| background | #FF09090D | Surface depth | 21 | lib/main.dart:405 |
| backgroundRaised | #FF0E0E14 | Surface depth | 9 | lib/theme/app_theme.dart:213 |
| surface | #FF14141B | Surface depth | 22 | lib/screens/change_password_sheet.dart:25 |
| surfaceAlt | #FF191922 | Surface depth | 10 | lib/theme/app_theme.dart:215 |
| surfaceElevated | #FF21212B | Surface depth | 24 | lib/debug/component_gallery_screen.dart:306 |
| scrim | #C7050508 | Mask, scrim or foreground utility | 3 | lib/theme/app_theme.dart:295 |
| border | #FF292933 | Boundary/remaining track | 22 | lib/debug/component_gallery_screen.dart:308 |
| borderStrong | #FF3A3A46 | Boundary/remaining track | 7 | lib/theme/app_accessibility.dart:38 |
| primary | #FFE63328 | Action/accent; text uses readable accentText | 71 | lib/billing/subscription.dart:18 |
| primaryBright | #FFFF4C42 | Action/accent; text uses readable accentText | 7 | lib/debug/component_gallery_screen.dart:224 |
| accentText | #FFFF4C42 | Action/accent; text uses readable accentText | 28 | lib/debug/component_gallery_screen.dart:103 |
| primaryDark | #FFC22A20 | Action/accent; text uses readable accentText | 2 | lib/screens/round_timer_screen.dart:400 |
| primaryFill | #FFD22519 | Action/accent; text uses readable accentText | 3 | lib/screens/training_camp_screen.dart:302 |
| primarySoft | #22E63328 | Action/accent; text uses readable accentText | 12 | lib/screens/drill_library_screen.dart:498 |
| primaryGlow | #38E63328 | Action/accent; text uses readable accentText | 0 | No direct usage; alias/theme ramp |
| premium | #FFF2C879 | Pro only | 31 | lib/debug/component_gallery_screen.dart:206 |
| onPrimary | #FFFFFFFF | Mask, scrim or foreground utility | 4 | lib/screens/nutrition_screen.dart:1184 |
| maskOpaque | #FFFFFFFF | Mask, scrim or foreground utility | 4 | lib/widgets/filter_chips.dart:204 |
| transparent | #00000000 | Mask, scrim or foreground utility | 7 | lib/main.dart:62 |
| googleSurface | #FFFFFFFF | Provider branding | 1 | lib/screens/auth/auth_widgets.dart:81 |
| googleText | #FF1F1F1F | Provider branding | 1 | lib/theme/app_typography.dart:29 |
| googleBorder | #FF747775 | Provider branding | 1 | lib/screens/auth/auth_widgets.dart:92 |
| textPrimary | #FFFFFFFF | Reading hierarchy | 34 | lib/screens/nutrition_screen.dart:579 |
| textSecondary | #FFAAAAB5 | Reading hierarchy | 85 | lib/billing/subscription.dart:17 |
| textMuted | #FF8A8A96 | Reading hierarchy | 61 | lib/debug/component_gallery_screen.dart:135 |
| positive | #FF3FD07E | Status meaning | 27 | lib/screens/drill_library_screen.dart:813 |
| warning | #FFF5A623 | Status meaning | 39 | lib/screens/dashboard_screen.dart:364 |
| negative | #FFFF3B5C | Status meaning | 21 | lib/privacy/health_consent_screen.dart:129 |
| track | #FF2A2A2E | Boundary/remaining track | 14 | lib/screens/drill_library_screen.dart:823 |
| carbs | #FF4A9EF0 | Named macro category | 6 | lib/screens/nutrition_screen.dart:511 |
| fats | #FFF5A623 | Named macro category | 6 | lib/screens/nutrition_screen.dart:514 |
| protein | #FF3FD07E | Named macro category | 7 | lib/screens/nutrition_screen.dart:508 |
| crimson50 | #FFFCEAE8 | Brand ramp | 0 | No direct usage; alias/theme ramp |
| crimson100 | #FFF9CBC8 | Brand ramp | 0 | No direct usage; alias/theme ramp |
| crimson200 | #FFF3A19B | Brand ramp | 0 | No direct usage; alias/theme ramp |
| crimson300 | #FFEE766D | Brand ramp | 0 | No direct usage; alias/theme ramp |
| crimson400 | #FFEB5C52 | Brand ramp | 0 | No direct usage; alias/theme ramp |
| crimson500 | #FFE63328 | Brand ramp | 0 | No direct usage; alias/theme ramp |
| crimson600 | #FFD22519 | Brand ramp | 0 | No direct usage; alias/theme ramp |
| crimson700 | #FFAD1F14 | Brand ramp | 0 | No direct usage; alias/theme ramp |
| crimson800 | #FF891810 | Brand ramp | 0 | No direct usage; alias/theme ramp |
| crimson900 | #FF64120C | Brand ramp | 0 | No direct usage; alias/theme ramp |
| neutral0 | #FFFFFFFF | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral50 | #FFD6D6DD | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral100 | #FFAAAAB5 | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral200 | #FF8A8A96 | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral300 | #FF6E6E79 | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral400 | #FF55555F | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral500 | #FF3A3A46 | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral600 | #FF292933 | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral700 | #FF21212B | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral800 | #FF191922 | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral850 | #FF14141B | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral900 | #FF0E0E14 | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| neutral950 | #FF09090D | Neutral ramp | 0 | No direct usage; alias/theme ramp |
| positiveSoft | #223FD07E | Status meaning / tinted background | 3 | lib/screens/drill_library_screen.dart:1044 |
| positiveStrong | #FF3FD07E | Status meaning | 1 | lib/screens/auth/verify_email_screen.dart:314 |
| warningSoft | #22F5A623 | Status meaning / tinted background | 0 | No direct usage; alias/theme ramp |
| warningStrong | #FFF5A623 | Status meaning | 0 | No direct usage; alias/theme ramp |
| negativeSoft | #22FF3B5C | Status meaning / tinted background | 0 | No direct usage; alias/theme ramp |
| negativeStrong | #FFFF3B5C | Status meaning | 0 | No direct usage; alias/theme ramp |
| info | #FF4A9EF0 | Status meaning | 0 | No direct usage; alias/theme ramp |
| infoSoft | #224A9EF0 | Status meaning / tinted background | 0 | No direct usage; alias/theme ramp |
| infoStrong | #FF4A9EF0 | Status meaning | 0 | No direct usage; alias/theme ramp |
| premiumSoft | #22F2C879 | Pro only | 2 | lib/screens/paywall_screen.dart:421 |
| premiumStrong | #FFF2C879 | Pro only | 0 | No direct usage; alias/theme ramp |
| premiumDeep | #FFB8893A | Pro only | 0 | No direct usage; alias/theme ramp |
| series1 | #FF3FD07E | Chart series; also use names/legend | 0 | No direct usage; alias/theme ramp |
| series2 | #FF4A9EF0 | Chart series; also use names/legend | 0 | No direct usage; alias/theme ramp |
| series3 | #FFF5A623 | Chart series; also use names/legend | 0 | No direct usage; alias/theme ramp |
| series4 | #FFB98CF0 | Chart series; also use names/legend | 0 | No direct usage; alias/theme ramp |
| series5 | #FF4ACFC4 | Chart series; also use names/legend | 0 | No direct usage; alias/theme ramp |
| series6 | #FFF07EA8 | Chart series; also use names/legend | 0 | No direct usage; alias/theme ramp |

## Computed text/background pairs

All reading/status tokens used by the screen families are measured on all five opaque surfaces. The individual screen rows refer to these families. Text over imagery is unverified unless covered by an opaque surface.

| Foreground | Background | Ratio | 4.5 normal text | 3 large/essential graphic |
|---|---|---|---|---|
| textPrimary | background | 19.877:1 | pass | pass |
| textPrimary | backgroundRaised | 19.238:1 | pass | pass |
| textPrimary | surface | 18.330:1 | pass | pass |
| textPrimary | surfaceAlt | 17.449:1 | pass | pass |
| textPrimary | surfaceElevated | 15.944:1 | pass | pass |
| textSecondary | background | 8.638:1 | pass | pass |
| textSecondary | backgroundRaised | 8.361:1 | pass | pass |
| textSecondary | surface | 7.966:1 | pass | pass |
| textSecondary | surfaceAlt | 7.583:1 | pass | pass |
| textSecondary | surfaceElevated | 6.929:1 | pass | pass |
| textMuted | background | 5.827:1 | pass | pass |
| textMuted | backgroundRaised | 5.640:1 | pass | pass |
| textMuted | surface | 5.374:1 | pass | pass |
| textMuted | surfaceAlt | 5.116:1 | pass | pass |
| textMuted | surfaceElevated | 4.674:1 | pass | pass |
| primary | background | 4.608:1 | pass | pass |
| primary | backgroundRaised | 4.460:1 | FAIL (only if used as normal text) | pass |
| primary | surface | 4.250:1 | FAIL (only if used as normal text) | pass |
| primary | surfaceAlt | 4.046:1 | FAIL (only if used as normal text) | pass |
| primary | surfaceElevated | 3.697:1 | FAIL (only if used as normal text) | pass |
| accentText | background | 6.024:1 | pass | pass |
| accentText | backgroundRaised | 5.830:1 | pass | pass |
| accentText | surface | 5.555:1 | pass | pass |
| accentText | surfaceAlt | 5.288:1 | pass | pass |
| accentText | surfaceElevated | 4.832:1 | pass | pass |
| positive | background | 9.972:1 | pass | pass |
| positive | backgroundRaised | 9.651:1 | pass | pass |
| positive | surface | 9.196:1 | pass | pass |
| positive | surfaceAlt | 8.754:1 | pass | pass |
| positive | surfaceElevated | 7.999:1 | pass | pass |
| warning | background | 9.807:1 | pass | pass |
| warning | backgroundRaised | 9.492:1 | pass | pass |
| warning | surface | 9.044:1 | pass | pass |
| warning | surfaceAlt | 8.609:1 | pass | pass |
| warning | surfaceElevated | 7.867:1 | pass | pass |
| negative | background | 5.710:1 | pass | pass |
| negative | backgroundRaised | 5.526:1 | pass | pass |
| negative | surface | 5.265:1 | pass | pass |
| negative | surfaceAlt | 5.012:1 | pass | pass |
| negative | surfaceElevated | 4.580:1 | pass | pass |
| premium | background | 12.601:1 | pass | pass |
| premium | backgroundRaised | 12.196:1 | pass | pass |
| premium | surface | 11.621:1 | pass | pass |
| premium | surfaceAlt | 11.062:1 | pass | pass |
| premium | surfaceElevated | 10.108:1 | pass | pass |
| carbs | background | 7.042:1 | pass | pass |
| carbs | backgroundRaised | 6.816:1 | pass | pass |
| carbs | surface | 6.494:1 | pass | pass |
| carbs | surfaceAlt | 6.182:1 | pass | pass |
| carbs | surfaceElevated | 5.649:1 | pass | pass |
| crimson400 | background | 5.854:1 | pass | pass |
| crimson400 | backgroundRaised | 5.666:1 | pass | pass |
| crimson400 | surface | 5.399:1 | pass | pass |
| crimson400 | surfaceAlt | 5.139:1 | pass | pass |
| crimson400 | surfaceElevated | 4.696:1 | pass | pass |
| series4 | background | 7.641:1 | pass | pass |
| series4 | backgroundRaised | 7.395:1 | pass | pass |
| series4 | surface | 7.046:1 | pass | pass |
| series4 | surfaceAlt | 6.707:1 | pass | pass |
| series4 | surfaceElevated | 6.129:1 | pass | pass |
| series5 | background | 10.424:1 | pass | pass |
| series5 | backgroundRaised | 10.089:1 | pass | pass |
| series5 | surface | 9.613:1 | pass | pass |
| series5 | surfaceAlt | 9.151:1 | pass | pass |
| series5 | surfaceElevated | 8.362:1 | pass | pass |
| series6 | background | 7.813:1 | pass | pass |
| series6 | backgroundRaised | 7.562:1 | pass | pass |
| series6 | surface | 7.205:1 | pass | pass |
| series6 | surfaceAlt | 6.859:1 | pass | pass |
| series6 | surfaceElevated | 6.267:1 | pass | pass |
| onPrimary | primary | 4.313:1 | FAIL (only if used as normal text) | pass |
| onPrimary | primaryFill | 5.225:1 | pass | pass |
| onPrimary | primaryDark | 5.760:1 | pass | pass |
| googleText | googleSurface | 16.483:1 | pass | pass |
| googleBorder | googleSurface | 4.528:1 | pass | pass |
| border | surface | 1.274:1 | FAIL (only if used as normal text) | FAIL if essential |
| borderStrong | surface | 1.635:1 | FAIL (only if used as normal text) | FAIL if essential |

## Smallest change

| Use | Before | After | Action |
|---|---|---|---|
| Floating field labels on surface | primary 4.250:1 | accentText 5.555:1 | Existing AppAccessibility.accentText; errors remain negative |
| Timer Start/Restart with white text | primary 4.313:1 | primaryFill 5.225:1 | Remove the brighter role override; pause/resume darker fill remains 5.760:1 |
| Palette values | Unchanged | Unchanged | No change to app_colors.dart |

textMuted is 5.374:1 on surface, 4.674:1 on elevated: this measured token passes, despite looking grey. primary fails normal text on all content surfaces, but can still serve large headings, graphics and suitable backgrounds. White/primaryFill and white/primaryDark pass. Status text on opaque surfaces passes; tinted status surfaces need separate composition below. Gold denotes Pro features/teasers. Amber warning is visually related to gold but carries a different label/icon/meaning; do not recolor warnings for branding.

Exact aliases: primaryBright=accentText; primary=crimson500; primaryFill=crimson600; white utility tokens=neutral0; textSecondary=neutral100; textMuted=neutral200; surface depth/borders map to neutral ramp. protein=positive=series1; fats=warning=series3; carbs=info=series2. Strong semantic variants alias their default. These aliases name different roles intentionally; collapsing them would reduce clarity. Near colors crimson400/accentText/primary are role/ramp choices, not evidence of random palette growth. primaryDark is a pressed fill close to crimson600/700; retain it while measured. No unsolicited palette expansion is proposed.

Border/surface is 1.274:1 and borderStrong/surface is 1.635:1. These are fine as decoration but inadequate if a border alone conveys a required state. Existing input labels/glyphs also identify the control, and focus crimson is above 3:1 on the surface. Audit required state indicators case by case. Empty ring tracks are background scaffolding; the active segment and labels carry information.

### Semantic text on tinted surfaces

| Text / soft background composited over surface | Ratio | Normal text |
|---|---|---|
| positive / positiveSoft | 7.263:1 | pass |
| warning / warningSoft | 7.151:1 | pass |
| negative / negativeSoft | 4.611:1 | pass |
| info / infoSoft | 5.370:1 | pass |
| premium / premiumSoft | 8.736:1 | pass |

## Remaining primary usage to classify

Direct references include non-text rings, icons, gradients and fills, so this is a review list rather than a blanket failure list. Confirm size, background and state before changing each.

- `lib/billing/subscription.dart:18`
- `lib/debug/component_gallery_screen.dart:194`
- `lib/debug/component_gallery_screen.dart:215`
- `lib/notifications/local_reminder_gateway.dart:117`
- `lib/screens/dashboard_screen.dart:200`
- `lib/screens/drill_library_screen.dart:439`
- `lib/screens/drill_library_screen.dart:497`
- `lib/screens/drill_library_screen.dart:634`
- `lib/screens/drill_library_screen.dart:649`
- `lib/screens/drill_library_screen.dart:719`
- `lib/screens/drill_library_screen.dart:977`
- `lib/screens/nutrition_screen.dart:427`
- `lib/screens/nutrition_screen.dart:433`
- `lib/screens/nutrition_screen.dart:770`
- `lib/screens/nutrition_screen.dart:793`
- `lib/screens/nutrition_screen.dart:907`
- `lib/screens/nutrition_screen.dart:962`
- `lib/screens/nutrition_screen.dart:1071`
- `lib/screens/paywall_screen.dart:629`
- `lib/screens/reaction_drill_screen.dart:211`
- `lib/screens/round_timer_screen.dart:273`
- `lib/screens/round_timer_screen.dart:400`
- `lib/screens/training_camp_screen.dart:187`
- `lib/screens/training_camp_screen.dart:195`
- `lib/screens/training_camp_screen.dart:199`
- `lib/screens/training_camp_screen.dart:369`
- `lib/screens/weight_tracker_screen.dart:192`
- `lib/screens/weight_tracker_screen.dart:199`
- `lib/screens/weight_tracker_screen.dart:292`
- `lib/screens/weight_tracker_screen.dart:303`
- `lib/screens/weight_tracker_screen.dart:450`
- `lib/screens/weight_tracker_screen.dart:456`
- `lib/theme/app_theme.dart:204`
- `lib/widgets/app_text_field.dart:66`
- `lib/widgets/app_text_field.dart:76`
- `lib/widgets/app_text_field.dart:91`
- `lib/widgets/bottom_nav.dart:137`
- `lib/widgets/brand_logo.dart:27`
- `lib/widgets/coach_marks.dart:193`
- `lib/widgets/premium_effects.dart:112`
- `lib/widgets/progress_ring.dart:22`
- `lib/widgets/pro_lock.dart:51`
- `lib/widgets/weekly_overview.dart:47`
- `lib/screens/auth/auth_widgets.dart:27`
- `lib/screens/auth/forgot_password_screen.dart:54`
- `lib/screens/auth/magic_link_screen.dart:67`
- `lib/screens/auth/signup_screen.dart:223`
- `lib/screens/first_run/first_week_checklist.dart:193`
- `lib/screens/onboarding/onboarding_widgets.dart:35`
- `lib/screens/onboarding/onboarding_widgets.dart:96`
- `lib/screens/onboarding/welcome_pages.dart:263`
- `lib/features/fight_camp/presentation/widgets/weight_path_chart.dart:183`
- `lib/features/fight_camp/presentation/widgets/weight_path_chart.dart:283`
- `lib/features/edge_fuel/presentation/screens/edge_fuel_coach_screen.dart:705`
- `lib/features/edge_fuel/presentation/screens/edge_fuel_coach_screen.dart:890`
- `lib/features/edge_fuel/presentation/screens/edge_fuel_coach_screen.dart:913`
- `lib/features/edge_fuel/presentation/screens/edge_fuel_coach_screen.dart:932`
- `lib/features/edge_fuel/presentation/screens/edge_fuel_setup_screen.dart:216`
- `lib/features/edge_fuel/presentation/screens/recipe_detail_screen.dart:465`
- `lib/features/edge_fuel/presentation/screens/recipe_library_screen.dart:410`
- `lib/features/edge_fuel/presentation/widgets/add_food_sheet.dart:137`
- `lib/features/edge_fuel/presentation/widgets/add_food_sheet.dart:162`
- `lib/features/edge_fuel/presentation/widgets/add_food_sheet.dart:475`
- `lib/features/edge_fuel/presentation/widgets/add_food_sheet.dart:484`
- `lib/features/edge_fuel/presentation/widgets/add_food_sheet.dart:611`
- `lib/features/edge_fuel/presentation/widgets/choice_card.dart:33`
- `lib/features/edge_fuel/presentation/widgets/choice_card.dart:54`
- `lib/features/edge_fuel/presentation/widgets/fuel_what_is_left.dart:86`
- `lib/features/edge_fuel/presentation/widgets/recipe_card.dart:37`
- `lib/features/edge_fuel/presentation/screens/setup_steps/body_step.dart:228`
- `lib/features/edge_fuel/presentation/screens/setup_steps/food_step.dart:176`

## Existing images and source trail

No image was created or acquired. The 24 recipe WebPs all have code-manifest credits and source URLs; the asset names match. The app renders credits through RecipePhotoImage/recipe detail. Four attempted source pages failed, so source-page license claims are manifest evidence, not an independently completed license audit. Preserve credits and have the owner verify originals.

| Asset | Manifest author | Manifest license | Source URL | Asset present |
|---|---|---|---|---|
| assets/images/recipes/three-egg-veg-scramble.webp | Stacy Spensley | CC BY 2.0 | [three-egg-veg-scramble](https://www.flickr.com/photos/21001756@N06/3464755994) | yes |
| assets/images/recipes/overnight-oats-banana-peanut.webp | ella.o | CC BY 2.0 | [overnight-oats-banana-peanut](https://www.flickr.com/photos/155807330@N05/30863438117) | yes |
| assets/images/recipes/greek-yogurt-berry-bowl.webp | Average Jane | CC BY 2.0 | [greek-yogurt-berry-bowl](https://www.flickr.com/photos/64401168@N00/3604928038) | yes |
| assets/images/recipes/protein-oat-pancakes.webp | Stacy Spensley | CC BY 2.0 | [protein-oat-pancakes](https://www.flickr.com/photos/21001756@N06/4334573247) | yes |
| assets/images/recipes/date-rice-cake-snack.webp | Double Bean | CC BY 2.0 | [date-rice-cake-snack](https://www.flickr.com/photos/8102985@N05/7428491122) | yes |
| assets/images/recipes/wholemeal-toast-honey.webp | Think YUM! | CC BY 2.0 | [wholemeal-toast-honey](https://www.flickr.com/photos/30320107@N06/6613098381) | yes |
| assets/images/recipes/tunisian-chickpea-bread-bowl.webp | Phil and Pam | CC BY 2.0 | [tunisian-chickpea-bread-bowl](https://www.flickr.com/photos/33987777@N00/2397457458) | yes |
| assets/images/recipes/spiced-chicken-rice-bowl.webp | kawanet | CC BY 2.0 | [spiced-chicken-rice-bowl](https://www.flickr.com/photos/50902562@N00/2597505789) | yes |
| assets/images/recipes/tuna-white-bean-salad.webp | jules:stonesoup | CC BY 2.0 | [tuna-white-bean-salad](https://www.flickr.com/photos/58367355@N00/10585910504) | yes |
| assets/images/recipes/turkey-quinoa-salad.webp | comicpie | CC BY 2.0 | [turkey-quinoa-salad](https://www.flickr.com/photos/90678392@N00/4158566695) | yes |
| assets/images/recipes/hummus-veg-wrap.webp | moriza | CC BY 2.0 | [hummus-veg-wrap](https://www.flickr.com/photos/44373968@N00/174312158) | yes |
| assets/images/recipes/red-lentil-veg-stew.webp | whitneyinchicago | CC BY 2.0 | [red-lentil-veg-stew](https://www.flickr.com/photos/29298849@N05/5215904693) | yes |
| assets/images/recipes/beef-steak-veg-plate.webp | jeffreyw | CC BY 2.0 | [beef-steak-veg-plate](https://www.flickr.com/photos/7927684@N03/7331360786) | yes |
| assets/images/recipes/salmon-quinoa-greens.webp | Annie Mole | CC BY 2.0 | [salmon-quinoa-greens](https://www.flickr.com/photos/21309047@N00/6041522909) | yes |
| assets/images/recipes/shrimp-veg-stirfry.webp | Rusty Clark | CC BY 2.0 | [shrimp-veg-stirfry](https://www.flickr.com/photos/23206546@N04/22231165550) | yes |
| assets/images/recipes/lamb-bulgur-plate.webp | WordRidden | CC BY 2.0 | [lamb-bulgur-plate](https://www.flickr.com/photos/97844767@N00/483132061) | yes |
| assets/images/recipes/tofu-veg-stirfry.webp | Augapfel | CC BY 2.0 | [tofu-veg-stirfry](https://www.flickr.com/photos/47038415@N00/216875127) | yes |
| assets/images/recipes/cod-potato-veg.webp | Prayitno | CC BY 2.0 | [cod-potato-veg](https://www.flickr.com/photos/34128007@N04/15988408872) | yes |
| assets/images/recipes/labneh-cucumber-olive-bowl.webp | T.Tseng | CC BY 2.0 | [labneh-cucumber-olive-bowl](https://www.flickr.com/photos/68147320@N02/14597127398) | yes |
| assets/images/recipes/cottage-cheese-fruit-bowl.webp | USDAgov | Public domain | [cottage-cheese-fruit-bowl](https://www.flickr.com/photos/41284017@N08/52644863050) | yes |
| assets/images/recipes/edamame-quinoa-bowl.webp | Vegan Feast Catering | CC BY 2.0 | [edamame-quinoa-bowl](https://www.flickr.com/photos/25128194@N02/4326526767) | yes |
| assets/images/recipes/almond-butter-protein-shake.webp | Berries.com | CC BY 2.0 | [almond-butter-protein-shake](https://www.flickr.com/photos/126560659@N06/33343287432) | yes |
| assets/images/recipes/mushroom-spinach-omelette.webp | Andy Hay | CC BY 2.0 | [mushroom-spinach-omelette](https://www.flickr.com/photos/29172291@N00/12015275683) | yes |
| assets/images/recipes/beef-mince-bean-chili.webp | lejoe | CC BY 2.0 | [beef-mince-bean-chili](https://www.flickr.com/photos/21458229@N00/5090013026) | yes |

`assets/images/google_g.png`: local README identifies the unmodified approved Google asset and retrieval date; branding page was read. Google Sans modification has a bundled OFL. Barlow has OFL and Phosphor fonts have MIT; Oswald source/license packaging needs owner confirmation if the bundled font provenance is not documented elsewhere. These are type/icon assets, not stock photos.

`assets/images/login_background.webp`: no clear provenance found (IMAGE-01). It must be resolved by the owner; it was not replaced. The FE brand mark is drawn in BrandLogo. Android/iOS launcher and splash assets exist but their installed appearance and source artwork were not reviewed on a device. Apple provider glyph comes from Phosphor; official Apple-button compliance remains unverified. Emoji/unicode-as-icon issues were not introduced. The single Phosphor family plus provider marks is coherent.

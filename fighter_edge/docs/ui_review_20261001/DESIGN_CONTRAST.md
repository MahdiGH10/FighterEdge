# Design specifications — 2026-10-01

Written before production edits. Baseline: origin/main 578c636. Preserve the dark athletic instrument, Oswald headings, Barlow reading text, crimson actions and gold Pro meaning. The supplied reference says Inter; shipped Barlow is authoritative. No new assets, calculations, eligibility logic, warning text or entitlement code.

## CONTRAST-01 — use the existing readable crimson roles

Problem: AppTextField floating labels use primary on surface (4.250:1); round timer Start/Restart overrides the readable button fill, giving white 4.313:1 at 14px. Evidence: 01-login-and-signup/08, 04-train/19 and /35; `app_text_field.dart`, `round_timer_screen.dart`. Rule: WCAG 1.4.3 https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html (read 2026-10-01).

Change: floating labels use AppAccessibility.accentText(context), 5.555:1 on surface. Error labels retain negative. Timer uses PrimaryButton's primaryFill, white 5.225:1; paused/running darker fill remains readable. Keep AppType.subhead, Insets, Radii, ring color and all timing unchanged. Before: low contrast red label / brighter button; after: readable light crimson label / deeper crimson button. No AppColors value change or new token. Effort S, risk low. Test actual rendered roles against 4.5:1, including high contrast and 200% text.


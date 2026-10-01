# Design specifications ? 2026-10-01

Written before production edits. Baseline: origin/main 578c636. Preserve the dark athletic instrument, Oswald headings, Barlow reading text, crimson actions and gold Pro meaning. The supplied reference says Inter; shipped Barlow is authoritative. No new assets, calculations, eligibility logic, warning text or entitlement code.

## A11Y-01 ? independent control names

Problem: Fuel's Add food is absorbed into its heading; the Settings Health data action absorbs the adjacent switches. Evidence: Chrome semantics and `app_scaffold.dart` / `grouped_list.dart`; frames 05-fuel/01 and 08-profile-and-settings/04. Rule: WCAG 4.1.2 https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html (read 2026-10-01).

Change: give tappable GroupedRow and HeaderIcon their own semantics containers. Keep PrimaryButton/GhostButton boundaries independent inside labeled cards. Existing AppType.callout/subhead, Insets.lg, Radii.button/card, AppAccessibility.minTouchTarget and MotionTokens.press remain. No visual redesign, new component or token is needed. Before: `heading NUTRITION Add food`; after: `heading NUTRITION` then `button Add food`. Before: `Health data + three switches`; after: Health data action, AI sharing switch, analytics switch, crash switch. Validate semantic activation invokes the intended action and leaves neighbors untouched. Also preserve disabled roles and button labels. Effort S, risk low; reader behavior still needs TalkBack/VoiceOver on a phone.

## CONTRAST-01 ? use the existing readable crimson roles

Problem: AppTextField floating labels use primary on surface (4.250:1); round timer Start/Restart overrides the readable button fill, giving white 4.313:1 at 14px. Evidence: 01-login-and-signup/08, 04-train/19 and /35; `app_text_field.dart`, `round_timer_screen.dart`. Rule: WCAG 1.4.3 https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html (read 2026-10-01).

Change: floating labels use AppAccessibility.accentText(context), 5.555:1 on surface. Error labels retain negative. Timer uses PrimaryButton's primaryFill, white 5.225:1; paused/running darker fill remains readable. Keep AppType.subhead, Insets, Radii, ring color and all timing unchanged. Before: low contrast red label / brighter button; after: readable light crimson label / deeper crimson button. No AppColors value change or new token. Effort S, risk low. Test actual rendered roles against 4.5:1, including high contrast and 200% text.

## AUTH-01 ? explain missing or malformed sign-in fields

Problem: empty login submits to the repository and gives a general SnackBar instead of identifying the fields. Evidence: 01-login-and-signup/02; `_signIn` has no validation. Rule: WCAG 3.3.1 and 3.3.3 https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html and https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html (read 2026-10-01).

Change: reuse validateEmailAddress's existing loose shape check; require only a nonempty sign-in password, preserving older accounts. Errors appear after submit and clear while correcting. Localize messages in EN/DE ARBs; use AppTextField.errorText and existing negative role, focus the first invalid field, preserve autofill/paste and password visibility. Existing AppType.callout/subhead, Insets.md and Radii.button remain. Before: submit -> general bottom error; after: Email + correction, Password + required message -> same Sign in action. Server failures still use existing SnackBar. Effort S, risk low; production Firebase responses not tested offline.

## Report-only proposals

Safety mismatch: keep warning AppType.callout and warning token at current prominence. Owner/qualified reviewer must approve wording about withheld food steps and timing of clinician advice. Do not edit it in these slices.

Fuel setup: show required-field completion near Next using AppType.subhead(textSecondary), Insets.sm and existing inline input errors. Clearing a filled body field retains the previous draft value in current code; changing this touches screening data and requires a separate owner-reviewed correctness task.

Empty training: use AppType.title2 instead of display for No sessions planned; add a real recovery action using PrimaryButton/Insets.lg only after defining the existing camp reset flow. Fresh onboarding already seeds a week; the offline demo loses in-memory sessions on reload. Do not classify that as a production first-run blocker.

First-meal celebration: replace the interrupting sheet with an inline positive confirmation, preserving the existing Undo action. Keep meaning without blocking recovery. AppType.callout, positive, Insets.md; no new effect.

Home: keep the TODAY accent for a real scheduled session; remove it for an empty fallback (judgment). Keep one solid PrimaryButton for the next useful action; make Pro a quieter GhostButton. Do not add glass, glows or decorative graphs. Liquid Glass is navigation/control material, not a reason to blur these data cards. Material 3 Expressive supports purposeful hierarchy and containment; existing readable stateful controls meet that intent.

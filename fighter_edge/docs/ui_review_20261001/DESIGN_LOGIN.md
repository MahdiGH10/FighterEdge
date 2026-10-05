# Design specifications — 2026-10-01

Written before production edits. Baseline: origin/main 578c636. Preserve the dark athletic instrument, Oswald headings, Barlow reading text, crimson actions and gold Pro meaning. The supplied reference says Inter; shipped Barlow is authoritative. No new assets, calculations, eligibility logic, warning text or entitlement code.

## AUTH-01 — explain missing or malformed sign-in fields

Problem: empty login submits to the repository and gives a general SnackBar instead of identifying the fields. Evidence: 01-login-and-signup/02; `_signIn` has no validation. Rule: WCAG 3.3.1 and 3.3.3 https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html and https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html (read 2026-10-01).

Change: reuse validateEmailAddress's existing loose shape check; require only a nonempty sign-in password, preserving older accounts. Errors appear after submit and clear while correcting. Localize messages in EN/DE ARBs; use AppTextField.errorText and existing negative role, focus the first invalid field, preserve autofill/paste and password visibility. Existing AppType.callout/subhead, Insets.md and Radii.button remain. Before: submit -> general bottom error; after: Email + correction, Password + required message -> same Sign in action. Server failures still use existing SnackBar. Effort S, risk low; production Firebase responses not tested offline.


Pre-edit amendment: the 320px/200% test found single-line errors clipped. Login opts into multilineError on existing AppTextField. Its error Text inherits InputDecorator error style and wraps without a maximum line count; other callers keep their behavior. No new type, spacing, color or motion value.

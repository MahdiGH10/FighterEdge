# Sign-in validation slice

Finding AUTH-01. Baseline origin/main 578c636; 2026-10-01.

Empty or incomplete email and an empty password now show field errors after submit. Errors clear while correcting, and focus moves to the first invalid field. Existing email policy is reused. Sign-in accepts any nonempty password, preserving legacy six-character accounts; no new-account password policy changes. Server failures retain the existing SnackBar. Autofill, paste and password visibility remain intact.

Three messages were added to both EN/DE ARBs and generated localizations. Login opts into wrapping AppTextField errors so corrections remain visible at 320px/200% text/high contrast. Other input callers keep their current error behavior. The error Text inherits the standard InputDecorator error style; no raw design value or new component/token.

Rules: [WCAG 3.3.1](https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html), [3.3.3](https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html), and [1.4.4](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html), read 2026-10-01.

Format, generated-localization diff, analyze, 913 non-golden tests and three unchanged goldens pass. Coverage is 82.3% (12493/15178, generated localization excluded), above 80%. Five new widget cases check English/German field errors, focus, correction, prevented repository submission, keyboard submit with legacy credentials and unclipped EN/DE errors at 200% high contrast. Common audit backend checks pass (113 tests; backend unchanged). No golden regeneration.

Eight matched before/after Login fixture pairs cover English/German, standard, 200%, high contrast and combined 320px/200%/high contrast. Local images: FighterEdge-screens/before-after/login-inline-validation. Scratch harnesses/images are not committed. The original general-error frame is an offline stub; production Firebase responses, native keyboards, real email delivery, password-manager integration and spoken screen readers were not tested.

An early full run failed eight text expectations after my initial Windows file edit corrupted existing UTF-8 punctuation. Both ARBs were restored from origin/main before inserting only three keys and regenerating; final full checks pass. The final localization diff changes only those new keys/generated accessors. An initial large-text regression exposed one-line truncation and drove the wrapping fix. No unrelated safety/localization text is changed.

Supported --no-pub commands used resolved dependencies after Windows' existing symlink prerequisite stopped normal pub-get completion. No permission/device setting changed. This draft does not claim authentication or release readiness.

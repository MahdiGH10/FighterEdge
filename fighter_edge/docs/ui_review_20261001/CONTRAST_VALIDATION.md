# Contrast role slice

Finding CONTRAST-01. Baseline origin/main 578c636; 2026-10-01.

Floating AppTextField labels use AppAccessibility.accentText instead of primary. On surface, normal-text contrast rises from 4.250:1 to 5.555:1. Timer Start/Restart uses primaryFill instead of primary; white contrast rises from 4.313:1 to 5.225:1. Running Pause uses the existing primaryDark. No color value, warning, domain calculation or timer logic changes.

Rule: [WCAG 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), read 2026-10-01. Bold 14px button text uses the normal-text threshold. Test checks rendered default/error/high-contrast field roles and Start/Pause/Resume fills, including 200% text.

Format, generated-localization diff, analyze, 911 non-golden tests and three unchanged golden tests pass. Coverage is 82.2% (12457/15150; generated localization excluded), above 80%. Cloud Functions npm ci/npm test passed in the common audit baseline (113 tests); backend source is unchanged. No golden regeneration.

26 matched before/after fixture pairs cover Login, Signup, Forgot password, magic-email entry, change password, onboarding body, fight setup, Fuel body/food and Round timer; standard and combined 320px/200%/high contrast, plus four original key variants. They are in the external FighterEdge-screens/before-after/contrast-role-usage folder. Fuel Body/Food are bounded component hosts, not complete navigation flows. Scratch harnesses and images are not committed. Other conditional code/detail states share the input implementation and are not claimed as individually captured.

Supported --no-pub commands used resolved dependencies after the existing Windows symlink prerequisite prevented a normal pub-get completion. No permission/device setting changed. Native text rendering, keyboard, screen readers, haptics and real motion were not reviewed. Other small-primary-text call sites remain report-only in the common audit.

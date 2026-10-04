# Independent accessible controls

Finding A11Y-01. Baseline origin/main 578c636; 2026-10-01.

| Surface | Baseline Chrome tree / code | Changed widget-test tree and activation |
|---|---|---|
| Settings privacy group | Health data button name included neighboring AI/analytics/crash switches | Health data has its own button/name. SemanticsAction.tap opens Withdraw consent; Cancel preserves all switch values. Tested at 320px, 100% and 200% high contrast. |
| Fuel header | NUTRITION heading name included Add food | Heading is exactly NUTRITION; Add food is an independent button and semantic activation opens Add to Today. |
| Home Corner Brief | Heading name included the explanation and Unlock action | Heading is exactly Corner Brief; Unlock the full brief has its own button/name. |
| Disabled shared buttons | Custom button labels can merge into ancestor content | PrimaryButton/GhostButton keep their individual names/roles and expose no tap action while disabled. |

The implementation adds semantics containers to existing tappable GroupedRow, HeaderIcon, PrimaryButton, GhostButton and SocialButton, and the Corner Brief heading. It preserves layout, color, warning prominence, actions and entitlement logic. There is no new visual component/token.

Five new regression cases pass; final full run passes 913 non-golden tests, format, generated-localization diff, analyze, 82.2% coverage (12453/15149; 80% floor) and three unchanged goldens. No golden regeneration. The test MediaQuery includes the actual 320×844 viewport so the large-text case exercises the intended layout.

All 56 matched before/after accessibility pairs have identical PNG hashes. That is expected for a semantic change; it proves no captured visual shift, not that semantic behavior is unchanged. Independent-name/activation assertions prove the tested change. Images are external at FighterEdge-screens/before-after/interaction-accessibility; scratch harnesses are not committed. Coverage includes 200%/high contrast/320px key variants and affected host examples; every possible conditional sheet is not claimed as individually captured.

Rules: [WCAG 4.1.2](https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html) and [Flutter accessibility](https://docs.flutter.dev/ui/accessibility), read 2026-10-01. Physical TalkBack/VoiceOver, switch control and native reading order were not tested. PressScale keyboard focus/activation remains KBD-01; this slice does not claim complete accessibility conformance.

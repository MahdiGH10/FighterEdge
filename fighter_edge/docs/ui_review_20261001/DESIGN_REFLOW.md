# REFLOW-01 / REFLOW-02: labels and values at 320 px and 200% text

Slice branch: `ui-review/reflow-label-size`, based on `origin/main` 578c636. One theme: layout that keeps labels and values
whole on a 320 px phone and at 200% text. It changes layout only. No copy, colour, safety wording, screening rule,
calculation or entitlement changes, and no new image.

## Problem

The UI review (PR #31, `REPORT.md` rows REFLOW-01 and REFLOW-02) found, in matched 320 px / 200% fixtures:

| Where | What broke |
|---|---|
| Reaction picker, 320 px, normal text | "Wrestling" cut to "Wrestl..." in the three-chip row |
| Fuel plan and Fuel setup review | Protein, carbs and fats cards in one row: "Protei" / "n", "127" / "g" |
| Weight tracker | "Set in EdgeFuel" broke as "EdgeFue" / "l"; chart dates printed over one another ("9/27" on "9/28") and were clipped at the bottom |
| Tab headers (Fuel, Train, ...) | "NUTRITION" cut to "NUTRIT..." |
| Onboarding body step | "Height cm" cut to "He..." |

- Rule: WCAG 2.2 SC 1.4.4 Resize Text and SC 1.4.10 Reflow: content and function stay available at 200% text and 320 CSS px
  without loss. Read 2026-10-01 at https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html and
  https://www.w3.org/WAI/WCAG22/Understanding/reflow.html.
- Evidence: the matched captures listed in `REPORT.md`, reproduced before this change in
  `before-after/reflow-label-size/before`.
- Judgment: ellipsis and mid-word breaks drop information the user needs (a cut title names nothing). Wrapping, stacking or
  scaling keeps it.

## Change (all in existing roles; no new tokens)

- `FilterChips`: the single equal-width row wraps below `LayoutTokens.narrowScreen` (360), as it already did at large text.
  The grid (`columns:`) and scrolling layouts are unchanged.
- Fuel plan and review step: `_MacroRow` stacks the three cards one per row at large text (`AppAccessibility.isLargeText`,
  at least 140%). Side by side otherwise. The two screens each had a private copy of the chip; both now use the same pattern.
- Weight tracker: `_StatPair` stacks the 7-day average and Goal cards at large text. The chart's date label count now comes
  from the plot width and the text scale (`dateLabelCount`): at most four as before, fewer when four would touch. The strip
  under the plot also grows with the text scale; the fixed 24 px strip clipped the bottom of 200% dates.
- Tab headers (`_CollapsingTabHeader`): the title is a `FittedBox(scaleDown)` instead of an ellipsised `Text`. Titles that
  fit are laid out exactly as before; a title that does not fit shrinks until it does.
- Onboarding body step (`BodyInputs`): Age and Height take a row each at large text.

## Tests (`test/accessibility/narrow_large_text_reflow_test.dart`, 15 cases)

Loads the app's real fonts (the default test font gives every glyph a one-em width and would measure the wrong thing).
Nine "control" cases pin the normal layout (four chart dates on a normal phone, cards side by side, header at full size, ...).
Six cases cover the fixes. Run against unchanged `main`, exactly those six fail and the nine controls pass.

## Left out on purpose

- **Fuel setup body step (screening fields), `edge_fuel` setup steps.** It shares the Row layout with the onboarding body
  step, but it holds the screening inputs. The report asks the owner to review safety-field presentation, so it is not
  touched here.
- **Long field labels at 200%** ("Current weight kg", "Target milestone in kg"). Even full width, a floating label is one
  line and ends in "..." at 200%. Fixing it needs a different label pattern in `AppTextField` (label above the field at
  large text), which changes every form. A design decision, so reported, not done.
- **TYPE-01 (floating label is about 10.5 px).** The one-line change is `AppType.callout` in `AppTextField`'s
  `floatingLabelStyle`. It sits on the line next to PR #29's `accentText` change in the same widget, so applying it here would
  make the two PRs conflict. Apply it after #29 merges, and check field and error geometry.
- **Fight-camp weight path chart** has the same date-label pattern. It is on a safety screen and was not part of the matched
  evidence, so it is untouched.
- **German text is longer than English.** None of this was run in German.

## Not tested

Real devices, TalkBack/VoiceOver, landscape, tablets, and any language other than English. Captures are widget-test renders
with bundled fonts, not a phone.

## Before / after

`FighterEdge-screens/before-after/reflow-label-size/{before,after}` (local): the same fixtures and fonts at 320 px, 3x.

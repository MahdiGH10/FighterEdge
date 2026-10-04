# KBD-01: keyboard focus and Enter/Space for PressScale controls

Slice branch: `ui-review/keyboard-activation`, based on `origin/main` 578c636. One theme: keyboard access. It does not
change copy, colours, layout, safety rules, calculations or entitlements.

## Problem

`PressScale` is the app's tap surface: 26 call sites, including `PrimaryButton`, `GhostButton`, the sign-in provider
buttons, grouped list rows, the Create account link, filter chips, the bottom navigation and stat cards. It was a bare
`GestureDetector`: no focus node, no key handling. With a hardware keyboard, a switch-control device or a desktop/web
build, none of those controls could be reached with Tab or activated with Enter or Space.

- Rule: WCAG 2.2 SC 2.1.1 Keyboard (all functionality works from a keyboard) and SC 2.4.7 Focus Visible. Read 2026-10-01 at
  https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html and
  https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html.
- Evidence: `lib/widgets/press_scale.dart` on main (no `Focus`, `FocusableActionDetector` or `ActivateIntent`). Report row
  KBD-01 in PR #31's `REPORT.md`.
- Judgment: PR #31 gave each control its own semantic boundary, which fixes the screen-reader tree. It does not make the
  controls keyboard operable.

## Change

- `PressScale` now wraps its surface in `FocusableActionDetector`.
  - An enabled surface (has `onTap`) is a tab stop. A surface with no `onTap` is not focusable.
  - Enter, numpad Enter and Space send `ActivateIntent`, which runs the same `_handleTap` as a touch (same haptic, same
    callback).
  - A held key activates once. The default app shortcuts also fire on key repeat, so `PressScale` consumes repeat events of
    those three keys while it holds focus. The unit test "holding Enter activates once" failed without this and passes now.
- Focus indication: a 2 px ring in `AppAccessibility.accentText(context)` (so high contrast keeps working), drawn only when
  focus came from the keyboard (`onShowFocusHighlight`). A touch or mouse press hides it. The ring sits in a foreground
  `DecoratedBox` that is always in the tree, so focus changes never rebuild or reset the child.
- New named token `FocusTokens.ringWidth = 2` in `app_theme.dart` (no raw number at the call site).
- New optional `PressScale.focusBorderRadius` (default `Radii.button`). `FilterChips` passes `Radii.tile` to match its shape.
  Other surfaces keep the default. A surface whose own radius differs can pass it later.

Contrast of the ring: `accentText` (#FF4C42) against background, surface, surfaceAlt and surfaceElevated all measure at
least 3:1 (WCAG 1.4.11), asserted in the new test.

## Tests added (`test/accessibility/press_scale_keyboard_test.dart`, 11 cases)

Tab focus, Enter/Space/numpad Enter once each, held Enter once, disabled surface skipped, ring shown after keyboard focus
and hidden after a touch, child state kept across focus changes, ring contrast on every surface, high-contrast accent,
`PrimaryButton`/`GhostButton`/`FilterChips` activation from the keyboard, disabled `PrimaryButton` not focusable, and the
semantics tree still reports one button with a tap action.

## Not covered

- No physical keyboard, switch-control or TalkBack/VoiceOver test on a device or emulator.
- The ring is checked on three screens (sign-in, Settings, Home) in widget-test captures with bundled fonts, not on every
  screen. The Google button label draws as blocks in those captures because the test host has no Google Sans.
- Focus order is the framework's reading order. Whether it matches the best task order on every screen was not reviewed.
- Behaviour on iOS and macOS hardware keyboards was not run.

## Before / after

`FighterEdge-screens/before-after/keyboard-activation/{before,after}`: same fixture, window size (390 x 844 at 3x), fonts
and Tab count. After: focus ring on Sign in, the Settings back button and Home's Start session. Before: the same number of
Tab presses never lands on a custom button (on sign-in it stops in the Email field).

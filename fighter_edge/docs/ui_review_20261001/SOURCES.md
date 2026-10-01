# Sources read on 2026-10-01

Only the sources below supplied published rules. No remembered rule or search snippet is treated as evidence. The findings distinguish published rule, observed evidence and design judgment.

| ID | Opened page | Read | What it supports |
|---|---|---|---|
| W | [WCAG 2.2 Recommendation](https://www.w3.org/TR/WCAG22/) | 2026-10-01 | Normative criteria; an audit of selected states is not a conformance claim. |
| C | [Contrast minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) | 2026-10-01 | 4.5:1 normal text, 3:1 large text; compare unrounded values. Disabled controls are exempt. |
| N | [Non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) | 2026-10-01 | 3:1 for essential control/state information, not every decorative divider. |
| R | [Resize text](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html) | 2026-10-01 | 200% text without losing information or function. |
| F | [Reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html) | 2026-10-01 | 320 CSS px vertical reflow; charts can have necessary two-dimensional exceptions. |
| E | [Error identification](https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html) | 2026-10-01 | Identify the field and describe the detected error in text. |
| ES | [Error suggestion](https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html) | 2026-10-01 | Offer a known correction when appropriate. |
| TS | [Target size minimum](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) | 2026-10-01 | WCAG AA uses 24px with exceptions. This project uses the stricter Flutter 48px. |
| NR | [Name, role, value](https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html) | 2026-10-01 | Controls need independent usable names, roles and values. |
| K | [Keyboard](https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html) | 2026-10-01 | Pointer functions generally need keyboard operation. |
| SP | [Text spacing](https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html) | 2026-10-01 | User spacing overrides must preserve content in supporting markup. Flutter canvas cannot be tested by CSS overrides; text scaling is not this test. |
| RE | [Redundant entry](https://www.w3.org/WAI/WCAG22/Understanding/redundant-entry.html) | 2026-10-01 | Avoid requesting the same information again within a process unless an exception applies. |
| AU | [Accessible authentication minimum](https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html) | 2026-10-01 | Support mechanisms such as paste and password managers. Security exceptions matter. |
| AN | [Animation from interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html) | 2026-10-01 | AAA criterion for disabling nonessential interaction animation. |
| NN | [Ten usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) | 2026-10-01 | Use visibility, control, consistency, prevention, recognition and minimalist presentation as heuristics, not measured conformance. |
| FL | [Flutter accessibility](https://docs.flutter.dev/ui/accessibility) | 2026-10-01 | 48px targets, contrast, descriptive labels, large text and testing with real assistive technology. |
| AA | [Apple accessibility (official HIG data)](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/accessibility.json) | 2026-10-01 | Scale text, provide meaningful accessible information and test. Readable official data, unlike the JavaScript shell. |
| AT | [Apple typography (official HIG data)](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/typography.json) | 2026-10-01 | Use legible text roles and support text-size changes. Map to existing app fonts; do not copy system branding. |
| AM | [Apple materials (official HIG data)](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/materials.json) | 2026-10-01 | Liquid Glass belongs primarily to navigation and controls; keep content legible and use materials with purpose. |
| AO | [Apple motion (official HIG data)](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/motion.json) | 2026-10-01 | Purposeful, brief motion with user control and accessibility settings. |
| GM | [Google Material 3 Expressive research](https://design.google/library/expressive-material-design-google-research?pubDate=20250521) | 2026-10-01 | Shape, size, color, motion and containment can help users recognize important actions. This does not require decorative effects. |
| GB | [Google sign-in branding](https://developers.google.com/identity/branding-guidelines) | 2026-10-01 | Use approved G artwork, colors/aspect ratio and appropriate text/background. |
| FI | [Figma best practices](https://www.figma.com/best-practices/) | 2026-10-01 | Published practice index; the variants article below supplies the component rule. |
| FV | [Figma component variants](https://www.figma.com/best-practices/creating-and-organizing-variants/) | 2026-10-01 | Keep reusable component states and meaningful properties together; avoid needless state combinations. |
| IM | [Impeccable](https://impeccable.style/) | 2026-10-01 | Manual critique of hierarchy, intentional visual choices and generic decorative defaults. |
| IG | [Impeccable repository](https://github.com/pbakaus/impeccable) | 2026-10-01 | Published skill set. Installed local v4.1.1 used manually for Flutter; no installation or automatic canvas detection claimed. |

## Opened but unreadable

An opened URL with an error or JavaScript shell is not a verified rule.

| URL attempted | Date | Result |
|---|---|---|
| [https://developer.apple.com/design/human-interface-guidelines/accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) | 2026-10-01 | JavaScript shell; readable official JSON used instead. |
| [https://developer.apple.com/design/human-interface-guidelines/typography](https://developer.apple.com/design/human-interface-guidelines/typography) | 2026-10-01 | JavaScript shell; readable official JSON used instead. |
| [https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple) | 2026-10-01 | JavaScript shell; button-rule text not retrieved. |
| [https://developer.apple.com/tutorials/data/design/human-interface-guidelines/sign-in-with-apple.json](https://developer.apple.com/tutorials/data/design/human-interface-guidelines/sign-in-with-apple.json) | 2026-10-01 | Internal error; no rule taken. |
| [https://developer.apple.com/sign-in-with-apple/](https://developer.apple.com/sign-in-with-apple/) | 2026-10-01 | Redirect/JavaScript shell; no readable branding rule taken. |
| [https://m3.material.io/blog/building-with-m3-expressive](https://m3.material.io/blog/building-with-m3-expressive) | 2026-10-01 | JavaScript shell; use Google Design research article instead. |
| [https://m3.material.io/styles/motion/overview](https://m3.material.io/styles/motion/overview) | 2026-10-01 | Redirected to how-it-works JavaScript shell; no numeric motion rule taken. |
| [https://m3.material.io/foundations/accessible-design/accessibility-basics](https://m3.material.io/foundations/accessible-design/accessibility-basics) | 2026-10-01 | 404; no rule taken. |
| [https://support.google.com/accessibility/android/answer/7101858?hl=en-GB](https://support.google.com/accessibility/android/answer/7101858?hl=en-GB) | 2026-10-01 | Internal error; no rule taken. |
| [https://www.flickr.com/photos/21001756@N06/3464755994](https://www.flickr.com/photos/21001756@N06/3464755994) | 2026-10-01 | Internal error; manifest credit checked in code, source licence not independently confirmed. |
| [https://www.flickr.com/photos/41284017@N08/52644863050](https://www.flickr.com/photos/41284017@N08/52644863050) | 2026-10-01 | Internal error; manifest credit checked in code, source licence not independently confirmed. |
| [https://www.flickr.com/photos/8102985@N05/7428491122](https://www.flickr.com/photos/8102985@N05/7428491122) | 2026-10-01 | Internal error; manifest credit checked in code, source licence not independently confirmed. |
| [https://www.flickr.com/photos/33987777@N00/2397457458](https://www.flickr.com/photos/33987777@N00/2397457458) | 2026-10-01 | Internal error; manifest credit checked in code, source licence not independently confirmed. |

## Design-language judgment

Apple's materials guidance supports using Liquid Glass selectively for navigation and controls. Inference: adding blur to Fighter Edge nutrition or safety cards would cost legibility without clarifying their role. Keep the current opaque content surfaces. A native navigation-material study needs a phone and is not implemented here.

Google's Expressive research supports recognizable key actions through hierarchy and purposeful containment. Inference: preserve crimson for action, large Oswald numerals for timing, and quiet secondary controls. It does not justify new glows, oversized empty-state headlines or identical card stacks. The canonical M3 pages were unreadable, so no unsupported claim about M3 component specifications is made.

Impeccable was already available locally. Its audit/adapt/clarify references and craft floor were read and applied as a manual checklist. The context script reported no product context file. Flutter paints a canvas; no DOM detector result is claimed. A newer available version was not installed. The explicit dark athletic brief governs aesthetic decisions; a useful card, chart or photo is not slop merely because it matches a common pattern.

## Repository evidence

Read CLAUDE.md first, the supplied UI contract, current handoff, the September UI/polish/reaction audits, design-system handoff/plan and fight-camp pattern brief; inspected token files, shared widgets, component gallery, goldens and workflow checks. Some earlier audit reads were sectional; no claim of exhaustive review of every old audit paragraph. The shipped fonts are Oswald and Barlow, despite the supplied reference saying Inter. Previously fixed 48px targets and explicit dark-only direction are retained, not reported as new work. Competitor research was read from the existing brief; no new App Store comparison was performed.

The installed Impeccable file was C:/Users/Mahdi/.agents/skills/impeccable/SKILL.md (v4.1.1). Apple HIG and Flutter widget-test skills supplied workflow guidance; the external rules cited above supplied audit criteria. No paid service, generated image, new stock image or account signup was used.

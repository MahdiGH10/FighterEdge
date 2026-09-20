# Train Taxonomy Handoff

**Date:** 2026-09-20

**Owner:** Train / Drill Library
**Status:** Implemented and validated in the Train taxonomy commit.

## Purpose

The coaching team supplied the first official Fighter Edge technique map:
**Striking** and **Grappling**. This slice makes that map the way athletes
explore the existing Train > Drills library, without falsely claiming that
every mapped technique already has a written drill or a video.

The source diagrams were deliberately **not** added as static in-app images.
They are now structured data, which is searchable, accessible, localizable,
easy to extend, and usable by future plans, recommendations, and video
features.

## Athlete experience

1. Open **Train > Drills**.
2. Use the existing search field, or choose **Striking** / **Grappling** from
   the top filter.
3. On `All`, a short horizontal rail presents the two main systems. Selecting
   one replaces the rail with its technique paths.
4. Select a path such as **Punches**, **Takedowns**, or **Judo & throws**.
   The athlete sees its parent context, the exact coach-mapped techniques,
   and only the real written drills currently in that path.
5. A path that has not yet been authored (for example Judo & throws) says
   that its curriculum is mapped and written drills are being added. It does
   not show a fake card, placeholder video, or false completion state.
6. Existing bookmarks, self-reported progress, starter content, and the Pro
   lock behavior remain unchanged.

This is intentionally a two-step flow, rather than a long row of 22 chips:
it stays quick to scan with one hand, works well at larger text sizes, and is
ready for more systems later.

## Official taxonomy now in code

`lib/training/taxonomy/technique_taxonomy.dart` owns stable IDs, display
labels, short descriptions, and the coaching team's technique lists.

| System | Paths |
| --- | --- |
| Striking | Punches; Kicks; Knees; Elbows; Punch defense; Kick defense; Footwork; Head movement; Counters; Clinch striking; Advanced & unorthodox; Combinations |
| Grappling | Takedowns; Takedown defense; Ground grappling; Clinch grappling; Judo & throws; Sprawling; Submissions; Submission defense; MMA ground fighting; Fundamentals |

The couple of readability normalizations are deliberate, not changes to the
coach's map: abbreviated labels such as `RNC` are expanded to `Rear naked
choke`, `G&P` to `Ground-and-pound`, and the diagram's wrapped knee label is
recorded as `Curved body knee`. `Ouchi gari` is preserved as supplied.

## Current content truth

There are **17** authored written drills today:

| System | Written drills mapped | Examples |
| --- | ---: | --- |
| Striking | 9 | Jab, lead hook, teep, body round kick, low-kick check, pivot, slip counter, 1-2, plum knees |
| Grappling | 8 | Double leg, sprawl, shrimp, closed guard posture break, mount escape, technical stand-up, stance/level change, underhook pummeling |

Most of the 22 paths therefore correctly show *Curriculum mapped* rather
than content that does not exist yet. This is important product honesty: the
map is valuable immediately, while additional drill/video production has a
clear destination.

## Code changed in this slice

| File | Responsibility |
| --- | --- |
| `lib/training/taxonomy/technique_taxonomy.dart` | New pure-Dart, immutable taxonomy models and official data. System/category lookup tables are cached. |
| `lib/training/drills/drill.dart` | Adds required `categoryId` to each authored drill. `DrillDiscipline` is retained as the broad drill-card label. |
| `lib/training/drills/drill_catalog.dart` | Maps all existing drills to an official category and exposes immutable, indexed category/system queries. |
| `lib/screens/drill_library_screen.dart` | Replaces hard-coded discipline filters with system filters and the two-step path rail. Adds semantic labels, clear selection, an honest mapped-content state, and a responsive progress indicator for large text. |
| `test/unit/training/technique_taxonomy_test.dart` | New domain tests for taxonomy size, IDs, drill mapping, and no invented content. |
| `test/widget/drill_library_test.dart` | Verifies System -> Path -> correct drill-list navigation. |

### Important data contract

- `TechniqueSystem.id` and `TechniqueCategory.id` are stable content keys.
  **Never use translated display text as an ID.**
- Every `Drill` must have a valid `categoryId`.
- A category may legitimately have zero written drills; the UI handles that.
- The data layer is Flutter-free. It can later be shared with a backend,
  recommendation engine, CMS importer, or offline content bundle.
- Query results are immutable cached lists. The horizontal rail does not scan
  the full catalog once per visible card.

## How to add the next CEO category safely

When the coaching team sends a new system or branch:

1. Add a stable lowercase ID and user-facing copy to
   `TechniqueTaxonomy.systems` and/or `TechniqueTaxonomy.categories`.
   Examples: `strength`, `conditioning`, `grappling.leg_locks`.
2. Keep the visible title separate from the ID so it can be localized later.
3. Add real authored `Drill` records only when their coaching, mistakes, and
   prescription have passed coaching review; give each its new `categoryId`.
4. Add a domain test for the expected categories and a widget test if the new
   content changes navigation behavior.
5. Run the commands below. No new UI branch or filter code should be needed.

Do not add stock videos merely to fill an empty category. Before a video can
ship, it needs a coach-approved technique, athlete suitability notes, a safe
progression, transcript/captions, rights confirmation, and a loading/offline
strategy.

## Localization note for the active German work

This slice keeps its labels in English because the Drill Library already has
English inline copy and another working tree is actively touching the ARB
files. In a dedicated localization slice, move the taxonomy's visible title,
description, and technique strings into the normal ARB flow while preserving
the stable IDs. Do **not** bundle that migration into an unrelated feature or
rename IDs during translation.

## Recommended next Train slices

1. **Coach content pass:** author the highest-demand foundational drills in
   the currently empty paths: punch defense, head movement, takedown defense,
   submissions, and submission defense.
2. **Path progression:** let a coach define prerequisites and recommended
   next paths. It must show this as a recommendation, not claim to certify
   ability from self-reported progress.
3. **Plan builder:** build a session from selected real drills and record
   completion locally/offline first. Do not mix it with subscription gating.
4. **Video pipeline:** only after the content and rights checklist exists;
   use captions, thumbnails, retries, and a low-bandwidth state.
5. **Remote content versioning:** when editing content without an app release
   becomes necessary, serve a validated, versioned taxonomy JSON from a
   trusted backend with the bundled taxonomy as an offline fallback.

## Verification completed

From `fighter_edge/`:

```powershell
& 'C:\src\flutter\bin\flutter.bat' analyze `
  lib/screens/drill_library_screen.dart `
  lib/training/drills/drill.dart `
  lib/training/drills/drill_catalog.dart `
  lib/training/taxonomy/technique_taxonomy.dart `
  test/unit/training/technique_taxonomy_test.dart `
  test/widget/drill_library_test.dart

& 'C:\src\flutter\bin\flutter.bat' test `
  test/unit/training/technique_taxonomy_test.dart `
  test/widget/drill_library_test.dart
```

Result at handoff: **analysis clean; 13 focused tests passed.**

## Handoff boundaries

This work intentionally does not touch the active nutrition screen, ARB
files, generated localization files, analytics, subscription code, Firebase,
or external media. Keep those parallel changes out of this commit. Stage only
the files listed in **Code changed in this slice** when committing this work.

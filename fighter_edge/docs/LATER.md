# LATER

Everything an agent (or you) wanted to build that is **not** the current step.

Writing it down here is what makes it safe to say "not now". Nothing is lost;
it just is not today's work. Review this list only at Step 8 of
`docs/START_HERE.md` — not before.

---

## Already deferred, with the reason

| Item | Why not now |
|---|---|
| EF-4 — connect nutrition to training | Real value, but does not make the app sellable. After payments. |
| EF-5 — weekly fuel review | The main reason people *keep* paying. Build it once someone has paid once. |
| Meal plans + grocery lists | v1.1. Pro is already worth $6.99 without them. |
| iOS build via Codemagic | Not technically blocked — Codemagic (or a GitHub Actions `macos-latest` runner) builds and code-signs the iOS binary in the cloud from this Windows checkout, no Mac purchase needed. Still needs an Apple Developer Program membership ($99/yr) and its own review cycle. Deferred so the payment plumbing (Step 5) is built and proven once on Android before paying for a second store. When you get here: connect this repo to Codemagic, let it auto-manage signing certs/provisioning profiles, add the iOS in-app-purchase products in App Store Connect mirroring the Android ones, and re-run Step 5's payment verification against the iOS build. |
| Technique library videos | Filming or licensing is a separate project with its own budget. |
| Corner Coach v2 (real personalisation) | Currently static cue cards. Either build it properly later or drop the name. |
| Mobility routines | Placeholder. Hide it for v1. |
| Camp Plan | Placeholder. Hide it for v1. |
| Custom foods / recents / favourites | EF-3c scope note. Add when the food-search UI needs it. |
| USDA FoodData Central API proxy | V1.5. The bundled 94-food table is enough for 24 recipes. |
| Recipe photography | Typographic cards ship instead. Revisit only with real photos, never stock. |
| Golden / screenshot tests | Worth having. Not worth blocking launch. |
| Declarative routing (go_router) | The app works on `Navigator.push`. No concrete problem to solve yet. |
| Localization | Structure is ready-ish. Do it when there is a second market. |
| App Check | Real hardening. Do it after launch, before scale. |
| Staging Firebase project | One project today. Split it when a second person joins. |
| Doc consolidation (11 files under docs/) | Tidy, not urgent. |

---

## Add new entries here

When a session proposes something outside the current step, add one line:

```
| <thing> | <why it is not now> |
```

Then carry on with the step.

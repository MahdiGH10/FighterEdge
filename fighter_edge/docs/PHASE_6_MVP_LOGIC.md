# Phase 6 — MVP Product Logic

Phase 6 moves Fighter Edge from “premium UI prototype” toward a real MVP flow:

`sign up → fresh-start onboarding → personalized dashboard → EdgeFuel target → training week`

## Implemented in Phase 6A

- Rebuilt first-run onboarding into a 6-step mobile flow.
- Removed weight-class-style thinking from onboarding.
- New users now enter normal inputs:
  - main camp goal
  - nutrition goal
  - age
  - height
  - current weight
  - optional target milestone
  - daily activity level
  - experience level
  - weekly training days
- Onboarding now creates a confirmed EdgeFuel profile when enough data exists.
- Onboarding now calculates and saves the first personalized calorie/macro target.
- Fresh-start camp still resets the user into a clean training week and starting weigh-in.
- Users can still skip detailed nutrition if they want to enter the app quickly.

## Product intent

Every new account should feel like a fresh start, not a demo account with random data.

The first moment of value should be:

- “This is my weekly training rhythm.”
- “These are my calories and macros.”
- “This app understands my goal.”

## Next Phase 6 tasks

### Phase 6B — implemented

- Dashboard now shows a clear EdgeFuel target snapshot when a target exists.
- Dashboard now shows consumed calories, target calories, remaining calories, macro targets, and streak in one glance.
- Fuel now opens with a stronger “Today’s EdgeFuel target” card instead of a small plan teaser.
- Fuel now shows target calories, logged calories, remaining/over-target status, progress, and macro targets before the meal log.

## Next Phase 6 tasks

1. Test the new target cards on a real emulator/device:

   ```powershell
   flutter run
   ```

2. Re-run validation before every handoff:

   ```powershell
   flutter analyze
   flutter test
   ```

3. Add focused widget tests for the new onboarding/target surface:
   - validation blocks empty body details
   - “Start my plan” saves EdgeFuel target
   - “Skip detailed target” completes onboarding without target
   - Dashboard shows the EdgeFuel target after onboarding
   - Fuel shows today’s personalized target after onboarding

4. Add a premium paywall moment after the free personalized target:
   - free users get basic targets
   - premium users unlock AI meal plans, grocery lists, and advanced recipes

5. Connect real payments using RevenueCat or native in-app purchases.

6. Move OpenRouter calls behind a backend/API boundary before production.

## Emulator QA script

When the emulator is ready, test:

1. Create account.
2. Complete onboarding with “Lose fat.”
3. Leave target weight empty and let the app choose the first safe milestone.
4. Confirm the dashboard opens.
5. Open Fuel.
6. Confirm EdgeFuel shows a calorie target instead of “Set target.”
7. Sign out.
8. Create another account and confirm it starts clean.

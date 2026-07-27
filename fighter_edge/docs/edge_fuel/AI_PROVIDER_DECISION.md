# EdgeFuel AI provider decision

Provider: OpenRouter

Status: selected for the EF-6 secure AI sprint. Do not implement direct calls
from Flutter before EF-6.

## Security rule

Never store provider keys in Flutter, Firestore, Remote Config, docs, tests, or
git. The app must call a backend-owned EdgeFuel AI gateway, and that backend
must read the OpenRouter key from a secret environment variable.

Because a real key was shared in chat during planning, rotate it in OpenRouter
before using the integration.

## Backend boundary

The Flutter app sends only:

- Firebase auth token;
- current confirmed `NutritionTarget`;
- the selected `NutritionDay`;
- user food preferences from the confirmed EdgeFuel profile;
- requested AI task, such as explain target, suggest substitution, or draft a
  meal plan.

The backend must:

- verify Firebase Auth and App Check;
- check the user's paid entitlement for premium AI tasks;
- enforce per-user quotas;
- call OpenRouter with the server-side key;
- request structured JSON output when the selected model supports it;
- validate the returned JSON before sending it to Flutter;
- fall back to deterministic non-AI guidance if validation fails.

## Model role

The model may explain, summarize, recommend recipes from validated data, and
draft meal plans. It must never calculate or override calories, macros, safety
states, or goal pace. Those stay owned by `NutritionTargetCalculator`.

Sources checked: OpenRouter authentication and structured-output docs.

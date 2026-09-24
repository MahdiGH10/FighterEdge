import { defineBoolean } from "firebase-functions/params";

/**
 * Whether callables that spend money (the AI coach, the RevenueCat sync)
 * refuse requests without a valid App Check token (audit S-4). The app sends
 * tokens from this release on; the server enforces them only once this is
 * true, so switching it on is a config change after the app is registered in
 * Firebase App Check and its metrics show real traffic passing. Set it in
 * `.env.<project>` (see docs/OWNER_SETUP.md, section 4).
 */
export const ENFORCE_APP_CHECK = defineBoolean("ENFORCE_APP_CHECK", {
  default: false,
  description: "Refuse AI and billing-sync calls without a valid App Check token.",
});

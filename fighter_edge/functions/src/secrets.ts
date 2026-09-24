import { defineSecret } from "firebase-functions/params";

/**
 * RevenueCat secret API key (starts with `sk_`). Used to read entitlements
 * straight from RevenueCat for syncs, transfers and reconciliation, and to
 * delete the RevenueCat customer with the account. Until RevenueCat is set
 * up, create the secret with the value "unset": deploys work, and those
 * paths degrade safely.
 */
export const REVENUECAT_API_KEY = defineSecret("REVENUECAT_API_KEY");

/**
 * Explicit consents an account holds, stored by the app on
 * `users/{uid}.consents.<purpose> = { version, grantedAt }` (see
 * `lib/privacy/data_consent.dart`). The Firestore rules only accept
 * `grantedAt` equal to the server's own clock, so a record can't be
 * backdated.
 */
export type ConsentPurpose = "healthData" | "aiCoach";

/**
 * The disclosure version each purpose must have been agreed to. Keep in step
 * with `DataConsentPurpose.currentVersion` in the app: when the app's wording
 * changes materially, both go up and every account is asked again.
 */
export const CONSENT_VERSIONS: Readonly<Record<ConsentPurpose, number>> = {
  healthData: 1,
  aiCoach: 1,
};

/** Whether [profile] holds [purpose] at (at least) its current version. */
export function hasConsent(
  profile: Record<string, unknown> | undefined,
  purpose: ConsentPurpose,
): boolean {
  const consents = profile?.consents;
  if (!consents || typeof consents !== "object") return false;
  const record = (consents as Record<string, unknown>)[purpose];
  if (!record || typeof record !== "object") return false;
  const version = (record as Record<string, unknown>).version;
  return typeof version === "number" && version >= CONSENT_VERSIONS[purpose];
}

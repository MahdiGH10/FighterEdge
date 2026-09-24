import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { CONSENT_VERSIONS, hasConsent } from "./consents";

describe("hasConsent", () => {
  const granted = (version: unknown) => ({
    consents: { aiCoach: { version, grantedAt: "server time" } },
  });

  it("accepts the current version and newer", () => {
    assert.equal(hasConsent(granted(CONSENT_VERSIONS.aiCoach), "aiCoach"), true);
    assert.equal(
      hasConsent(granted(CONSENT_VERSIONS.aiCoach + 1), "aiCoach"),
      true,
    );
  });

  it("asks again after the wording changed", () => {
    assert.equal(
      hasConsent(granted(CONSENT_VERSIONS.aiCoach - 1), "aiCoach"),
      false,
    );
  });

  it("treats a missing or malformed record as no consent", () => {
    assert.equal(hasConsent(undefined, "aiCoach"), false);
    assert.equal(hasConsent({}, "aiCoach"), false);
    assert.equal(hasConsent({ consents: "yes" }, "aiCoach"), false);
    assert.equal(hasConsent({ consents: { aiCoach: true } }, "aiCoach"), false);
    assert.equal(hasConsent(granted("1"), "aiCoach"), false);
  });

  it("keeps purposes separate", () => {
    const healthOnly = {
      consents: { healthData: { version: CONSENT_VERSIONS.healthData } },
    };
    assert.equal(hasConsent(healthOnly, "healthData"), true);
    assert.equal(hasConsent(healthOnly, "aiCoach"), false);
  });
});

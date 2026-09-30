import { strict as assert } from "node:assert";
import { generateKeyPairSync, sign } from "node:crypto";
import { describe, it } from "node:test";

import { REWARD_CUSTOM_DATA, VerifierKey, verifyRewardCallback } from "./adRewards";

// A stand-in for Google's signing key: same curve and format as AdMob's.
const { privateKey, publicKey } = generateKeyPairSync("ec", {
  namedCurve: "prime256v1",
});
const KEY: VerifierKey = {
  keyId: 1234,
  base64: publicKey.export({ format: "der", type: "spki" }).toString("base64"),
};

function signed(query: string, keyId = KEY.keyId): string {
  const signature = sign("sha256", Buffer.from(query, "utf8"), privateKey)
    .toString("base64url");
  return `${query}&signature=${signature}&key_id=${keyId}`;
}

const QUERY =
  "ad_network=5450213213286189855&ad_unit=1234567890&" +
  `custom_data=${REWARD_CUSTOM_DATA}&reward_amount=1&reward_item=brief&` +
  "timestamp=1759190400000&transaction_id=abc123&user_id=uid42";

describe("verifyRewardCallback", () => {
  it("accepts a callback signed by a known key, and reads its fields", () => {
    const reward = verifyRewardCallback(signed(QUERY), [KEY]);
    assert.deepEqual(reward, {
      userId: "uid42",
      customData: REWARD_CUSTOM_DATA,
      transactionId: "abc123",
      adUnit: "1234567890",
    });
  });

  it("accepts the query with its leading question mark", () => {
    assert.notEqual(verifyRewardCallback(`?${signed(QUERY)}`, [KEY]), null);
  });

  it("rejects a callback whose fields were changed after signing", () => {
    const forged = signed(QUERY).replace("user_id=uid42", "user_id=someoneElse");
    assert.equal(verifyRewardCallback(forged, [KEY]), null);
  });

  it("rejects an unknown key, a missing signature, or garbage", () => {
    assert.equal(verifyRewardCallback(signed(QUERY, 9999), [KEY]), null);
    assert.equal(verifyRewardCallback(QUERY, [KEY]), null);
    assert.equal(verifyRewardCallback(`${QUERY}&signature=bm90LWE-c2ln&key_id=1234`, [KEY]), null);
    assert.equal(verifyRewardCallback("", [KEY]), null);
  });

  it("rejects a signature from a different private key", () => {
    const other = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
    const signature = sign("sha256", Buffer.from(QUERY), other.privateKey)
      .toString("base64url");
    assert.equal(
      verifyRewardCallback(`${QUERY}&signature=${signature}&key_id=1234`, [KEY]),
      null,
    );
  });
});

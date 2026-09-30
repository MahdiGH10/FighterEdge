/**
 * Rewarded videos for free accounts: watch one short ad, get that day's full
 * Corner Brief. Google AdMob tells our server that the video was watched
 * (server-side verification, SSV) with a signed callback; the app itself can
 * never grant the reward, in line with "the client never grants Pro access".
 *
 * The app never hands Google the account ID. It asks us for a one-time token
 * (`adRewardTokens/{token}`, server-only) and passes that to AdMob; the
 * callback turns it back into the account here.
 *
 * `users/{uid}/adRewards/{YYYY-MM-DD}` (UTC) holds `granted` and `used`
 * counts only. Clients may read it, never write it (firestore.rules).
 */
import { createPublicKey, randomBytes, verify } from "node:crypto";

import { Firestore } from "firebase-admin/firestore";

/** Rewarded briefs per account per UTC day. One keeps the ad a treat. */
export const MAX_REWARDED_BRIEFS_PER_DAY = 1;

/** What the app sends as `custom_data`, so other rewards can't be replayed. */
export const REWARD_CUSTOM_DATA = "corner_brief";

const VERIFIER_KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const KEY_CACHE_MS = 24 * 60 * 60 * 1000;

export interface VerifierKey {
  keyId: number;
  /** Base64 DER (SubjectPublicKeyInfo) of an ECDSA P-256 public key. */
  base64: string;
}

export interface RewardCallback {
  userId: string;
  customData: string;
  transactionId: string;
  adUnit: string;
}

function base64UrlToBuffer(value: string): Buffer {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  return Buffer.from(padded, "base64");
}

/**
 * Checks AdMob's signature over the raw query string. Google signs every
 * parameter before `&signature=`, in the order sent, so the string must be
 * the one received, not re-encoded. Returns the callback's fields when the
 * signature is valid, else null.
 */
export function verifyRewardCallback(
  rawQuery: string,
  keys: readonly VerifierKey[],
): RewardCallback | null {
  const query = rawQuery.startsWith("?") ? rawQuery.slice(1) : rawQuery;
  const cut = query.indexOf("&signature=");
  if (cut <= 0) return null;
  const message = query.slice(0, cut);
  const params = new URLSearchParams(query);
  const signature = params.get("signature");
  const keyId = Number(params.get("key_id"));
  if (!signature || !Number.isInteger(keyId)) return null;
  const key = keys.find((candidate) => candidate.keyId === keyId);
  if (!key) return null;

  let valid = false;
  try {
    const publicKey = createPublicKey({
      key: Buffer.from(key.base64, "base64"),
      format: "der",
      type: "spki",
    });
    valid = verify(
      "sha256",
      Buffer.from(message, "utf8"),
      publicKey,
      base64UrlToBuffer(signature),
    );
  } catch {
    return null;
  }
  if (!valid) return null;

  return {
    userId: params.get("user_id") ?? "",
    customData: params.get("custom_data") ?? "",
    transactionId: params.get("transaction_id") ?? "",
    adUnit: params.get("ad_unit") ?? "",
  };
}

let cachedKeys: { keys: VerifierKey[]; fetchedAt: number } | null = null;

/** Google's current verifier keys, cached for a day. */
export async function fetchVerifierKeys(
  now: number = Date.now(),
): Promise<VerifierKey[]> {
  if (cachedKeys && now - cachedKeys.fetchedAt < KEY_CACHE_MS) {
    return cachedKeys.keys;
  }
  const response = await fetch(VERIFIER_KEYS_URL);
  if (!response.ok) {
    throw new Error(`AdMob verifier keys responded ${response.status}`);
  }
  const body = (await response.json()) as {
    keys?: { keyId?: unknown; base64?: unknown }[];
  };
  const keys = (body.keys ?? [])
    .filter(
      (key) => typeof key.keyId === "number" && typeof key.base64 === "string",
    )
    .map((key) => ({ keyId: key.keyId as number, base64: key.base64 as string }));
  cachedKeys = { keys, fetchedAt: now };
  return keys;
}

function todayKey(now: Date): string {
  return now.toISOString().slice(0, 10);
}

function rewardRef(db: Firestore, uid: string, now: Date) {
  return db.collection("users").doc(uid).collection("adRewards").doc(todayKey(now));
}

interface RewardDoc {
  granted?: number;
  used?: number;
  transactions?: string[];
}

/** A token lives long enough to load and watch a video, no longer. */
export const REWARD_TOKEN_TTL_MS = 2 * 60 * 60 * 1000;

function tokenRef(db: Firestore, token: string) {
  return db.collection("adRewardTokens").doc(token);
}

export type RewardState =
  /** A reward is waiting: write the brief, no video needed. */
  | "unused"
  /** Today's reward was earned and used. */
  | "usedToday"
  /** A video can still earn today's reward. */
  | "available";

export async function rewardState(
  db: Firestore,
  uid: string,
  now: Date,
): Promise<RewardState> {
  const doc = ((await rewardRef(db, uid, now).get()).data() ?? {}) as RewardDoc;
  const granted = doc.granted ?? 0;
  if (granted > (doc.used ?? 0)) return "unused";
  return granted >= MAX_REWARDED_BRIEFS_PER_DAY ? "usedToday" : "available";
}

/**
 * A one-time token the app passes to AdMob in place of the account ID.
 * `expiresAt` lets a Firestore TTL policy delete unused ones.
 */
export async function createRewardToken(
  db: Firestore,
  uid: string,
  now: Date,
): Promise<string> {
  const token = randomBytes(18).toString("base64url");
  await tokenRef(db, token).set({
    uid,
    createdAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + REWARD_TOKEN_TTL_MS),
  });
  return token;
}

export type GrantResult = "granted" | "duplicate" | "dailyLimit" | "unknownToken";

/**
 * Records a verified reward for the account behind [token]. The token works
 * once and only while fresh; a transaction ID seen before is ignored (AdMob
 * may retry a callback); at most [MAX_REWARDED_BRIEFS_PER_DAY] a day.
 */
export async function grantReward(
  db: Firestore,
  token: string,
  transactionId: string,
  now: Date,
): Promise<GrantResult> {
  return db.runTransaction(async (tx) => {
    const tokenDoc = await tx.get(tokenRef(db, token));
    const tokenData = tokenDoc.data() as
      | { uid?: unknown; createdAt?: unknown }
      | undefined;
    const uid = typeof tokenData?.uid === "string" ? tokenData.uid : null;
    const createdAt = Date.parse(String(tokenData?.createdAt ?? ""));
    if (!uid || !(now.getTime() - createdAt <= REWARD_TOKEN_TTL_MS)) {
      if (tokenDoc.exists) tx.delete(tokenDoc.ref);
      return "unknownToken";
    }

    const ref = rewardRef(db, uid, now);
    const doc = ((await tx.get(ref)).data() ?? {}) as RewardDoc;
    const transactions = doc.transactions ?? [];
    if (transactions.includes(transactionId)) return "duplicate";
    tx.delete(tokenDoc.ref);
    const granted = doc.granted ?? 0;
    if (granted >= MAX_REWARDED_BRIEFS_PER_DAY) return "dailyLimit";
    tx.set(
      ref,
      {
        granted: granted + 1,
        used: doc.used ?? 0,
        transactions: [...transactions, transactionId],
        updatedAt: now.toISOString(),
      },
      { merge: true },
    );
    return "granted";
  });
}

/** Whether a reward is waiting to be used today. A read, not a reservation. */
export async function hasUnusedReward(
  db: Firestore,
  uid: string,
  now: Date,
): Promise<boolean> {
  const doc = ((await rewardRef(db, uid, now).get()).data() ?? {}) as RewardDoc;
  return (doc.granted ?? 0) > (doc.used ?? 0);
}

/** Atomically takes one unused reward; false when there is none. */
export async function useReward(
  db: Firestore,
  uid: string,
  now: Date,
): Promise<boolean> {
  const ref = rewardRef(db, uid, now);
  return db.runTransaction(async (tx) => {
    const doc = ((await tx.get(ref)).data() ?? {}) as RewardDoc;
    const used = doc.used ?? 0;
    if ((doc.granted ?? 0) <= used) return false;
    tx.set(ref, { used: used + 1, updatedAt: now.toISOString() }, { merge: true });
    return true;
  });
}

/**
 * Gives a reward back when no brief could be written, so a watched video is
 * never wasted on our outage. Clamped at zero.
 */
export async function refundReward(
  db: Firestore,
  uid: string,
  now: Date,
): Promise<void> {
  const ref = rewardRef(db, uid, now);
  await db.runTransaction(async (tx) => {
    const doc = ((await tx.get(ref)).data() ?? {}) as RewardDoc;
    const used = doc.used ?? 0;
    if (used === 0) return;
    tx.set(ref, { used: used - 1, updatedAt: now.toISOString() }, { merge: true });
  });
}

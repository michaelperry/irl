import { createDb, schema } from "../db/index.js";
import { eq } from "drizzle-orm";

/**
 * Push dispatch.
 *
 * Stub implementation for now — looks up tokens for the recipient and logs the intended
 * payload. To enable real delivery, set APNS_AUTH_KEY (the .p8 contents), APNS_KEY_ID,
 * APNS_TEAM_ID, and APNS_BUNDLE_ID, then replace `deliver()` with an actual HTTP/2 request
 * to api.push.apple.com (or use a library like `node-apn`).
 *
 * Pushes are best-effort: they should never block the originating mutation.
 */
export type PushKind =
  | { type: "comment"; postId: string; commentId: string; actorId: string }
  | { type: "reaction"; postId: string; actorId: string; kind: string };

export async function notifyUser(recipientId: string, payload: PushKind): Promise<void> {
  try {
    const db = createDb();
    const tokens = await db
      .select({ token: schema.apnsTokens.token, environment: schema.apnsTokens.environment })
      .from(schema.apnsTokens)
      .where(eq(schema.apnsTokens.userId, recipientId));

    if (tokens.length === 0) return;

    for (const t of tokens) {
      await deliver(t.token, t.environment, payload);
    }
  } catch (err) {
    console.error("[push] dispatch failed", err);
  }
}

async function deliver(token: string, environment: string, payload: PushKind): Promise<void> {
  const hasAuth =
    !!process.env.APNS_AUTH_KEY &&
    !!process.env.APNS_KEY_ID &&
    !!process.env.APNS_TEAM_ID &&
    !!process.env.APNS_BUNDLE_ID;

  if (!hasAuth) {
    // No APNs credentials — log and move on. Tests + dev work fine without this.
    console.log(`[push] (stub) → ${token.slice(0, 8)}… [${environment}]`, payload);
    return;
  }

  // TODO: real delivery. Build the JWT, hit api.push.apple.com (or api.sandbox.push.apple.com
  // when environment === "sandbox"), and handle 410 (token retired → delete from db).
  console.log(`[push] (would deliver to ${token.slice(0, 8)}…)`, payload);
}

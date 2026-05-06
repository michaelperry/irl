import { createDb, schema } from "../db/index.js";
import { eq } from "drizzle-orm";

/**
 * Notification dispatch.
 *
 * Writes an in-app activity row (so the bell + activity feed update) and best-effort
 * sends an APNs push for the same event. APNs delivery is currently a stub — set
 * APNS_AUTH_KEY (the .p8 contents) + APNS_KEY_ID + APNS_TEAM_ID + APNS_BUNDLE_ID to
 * activate, then finish `deliver()` with an HTTP/2 request to api.push.apple.com.
 *
 * Both legs are best-effort: failures are logged, never thrown to callers.
 */
export type PushKind =
  | { type: "comment"; postId: string; commentId: string; actorId: string }
  | { type: "reaction"; postId: string; actorId: string; kind: string }
  | { type: "follow"; actorId: string }
  | { type: "message"; conversationId: string; messageId: string; actorId: string };

export async function notifyUser(recipientId: string, payload: PushKind): Promise<void> {
  // 1. Write the in-app activity row (source of truth for the bell)
  try {
    const db = createDb();
    await db.insert(schema.activities).values({
      recipientId,
      actorId: payload.actorId,
      kind: payload.type,
      postId: payload.type === "comment" || payload.type === "reaction" ? payload.postId : null,
      commentId: payload.type === "comment" ? payload.commentId : null,
      reactionKind: payload.type === "reaction" ? payload.kind : null,
    });
  } catch (err) {
    console.error("[notify] activity write failed", err);
  }

  // 2. Best-effort APNs delivery
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

import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { eq, and, sql } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import type { AppVariables } from "../types.js";

// Real-life-sized friend group. Keep tight; product premise is intimacy, not reach.
// Each user can earn up to BONUS_SLOTS_MAX additional slots by inviting friends.
export const BASE_FRIEND_LIMIT = 50;
export const BONUS_SLOTS_MAX = 5;

export function friendLimitFor(bonusSlotsUnlocked: number): number {
  return BASE_FRIEND_LIMIT + Math.max(0, Math.min(BONUS_SLOTS_MAX, bonusSlotsUnlocked));
}

const profile = new Hono<{ Variables: AppVariables }>();

profile.use("*", authMiddleware, screenTimeMiddleware);

// Get your own profile
profile.get("/me", async (c) => {
  const user = c.get("user");
  const db = createDb();

  const [followerCount] = await db
    .select({ count: sql<number>`count(*)` })
    .from(schema.follows)
    .where(eq(schema.follows.followingId, user.id));

  const [followingCount] = await db
    .select({ count: sql<number>`count(*)` })
    .from(schema.follows)
    .where(eq(schema.follows.followerId, user.id));

  const limit = friendLimitFor(user.bonusSlotsUnlocked);
  return c.json({
    id: user.id,
    encryptedProfile: user.encryptedProfile,
    followers: followerCount.count,
    following: followingCount.count,
    friendLimit: limit,
    friendSlotsRemaining: Math.max(0, limit - Number(followingCount.count)),
    bonusSlotsUnlocked: user.bonusSlotsUnlocked,
    bonusSlotsMax: BONUS_SLOTS_MAX,
    screenLimitSeconds: user.dailyScreenLimitSeconds,
    createdAt: user.createdAt,
  });
});

// Update encrypted profile data
profile.put("/me", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json();
  const { encryptedProfile, dailyScreenLimitSeconds } = body;

  const db = createDb();
  const updates: Record<string, unknown> = { updatedAt: new Date() };
  if (encryptedProfile !== undefined) updates.encryptedProfile = encryptedProfile;
  if (dailyScreenLimitSeconds !== undefined) {
    updates.dailyScreenLimitSeconds = Math.max(300, dailyScreenLimitSeconds); // min 5 minutes
  }

  const [updated] = await db
    .update(schema.users)
    .set(updates)
    .where(eq(schema.users.id, userId))
    .returning();

  return c.json({ user: updated });
});

// Follow a user
profile.post("/follow/:targetId", async (c) => {
  const userId = c.get("userId");
  const targetId = c.req.param("targetId");
  const body = await c.req.json();
  const { encryptedSharedKey } = body;

  if (!encryptedSharedKey) {
    return c.json({ error: "encryptedSharedKey required to share content" }, 400);
  }

  if (userId === targetId) {
    return c.json({ error: "Cannot follow yourself" }, 400);
  }

  const db = createDb();

  // Enforce the friend cap before inserting. Idempotent re-follow is allowed (no count change).
  const [existing] = await db
    .select()
    .from(schema.follows)
    .where(
      and(eq(schema.follows.followerId, userId), eq(schema.follows.followingId, targetId))
    )
    .limit(1);

  if (!existing) {
    const me = c.get("user");
    const limit = friendLimitFor(me.bonusSlotsUnlocked);
    const [{ count }] = await db
      .select({ count: sql<number>`count(*)::int` })
      .from(schema.follows)
      .where(eq(schema.follows.followerId, userId));

    if (Number(count) >= limit) {
      return c.json(
        {
          error: "friend_limit_reached",
          message: `Your friend circle is full (${limit}). Invite friends to unlock bonus spots, or remove someone first.`,
          limit,
        },
        409
      );
    }
  }

  await db
    .insert(schema.follows)
    .values({ followerId: userId, followingId: targetId, encryptedSharedKey })
    .onConflictDoNothing();

  const meAfter = c.get("user");
  return c.json({ followed: true, friendLimit: friendLimitFor(meAfter.bonusSlotsUnlocked) });
});

// Register or refresh an APNs device token for the current user/device.
profile.post("/apns-tokens", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json();
  const { token, deviceId, environment } = body as {
    token?: string;
    deviceId?: string;
    environment?: string;
  };

  if (!token || !deviceId) {
    return c.json({ error: "token and deviceId required" }, 400);
  }

  const env = environment === "sandbox" ? "sandbox" : "production";
  const db = createDb();
  await db
    .insert(schema.apnsTokens)
    .values({ userId, deviceId, token, environment: env })
    .onConflictDoUpdate({
      target: [schema.apnsTokens.userId, schema.apnsTokens.deviceId],
      set: { token, environment: env, lastSeenAt: new Date() },
    });

  return c.json({ registered: true });
});

profile.delete("/apns-tokens/:deviceId", async (c) => {
  const userId = c.get("userId");
  const deviceId = c.req.param("deviceId");
  const db = createDb();
  await db
    .delete(schema.apnsTokens)
    .where(
      and(eq(schema.apnsTokens.userId, userId), eq(schema.apnsTokens.deviceId, deviceId))
    );
  return c.json({ removed: true });
});

// Unfollow a user
profile.delete("/follow/:targetId", async (c) => {
  const userId = c.get("userId");
  const targetId = c.req.param("targetId");

  const db = createDb();
  await db
    .delete(schema.follows)
    .where(
      and(
        eq(schema.follows.followerId, userId),
        eq(schema.follows.followingId, targetId)
      )
    );

  return c.json({ unfollowed: true });
});

export default profile;

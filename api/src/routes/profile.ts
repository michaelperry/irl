import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { eq, and, sql } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import type { AppVariables } from "../types.js";

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

  return c.json({
    id: user.id,
    encryptedProfile: user.encryptedProfile,
    followers: followerCount.count,
    following: followingCount.count,
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
  await db
    .insert(schema.follows)
    .values({ followerId: userId, followingId: targetId, encryptedSharedKey })
    .onConflictDoNothing();

  return c.json({ followed: true });
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

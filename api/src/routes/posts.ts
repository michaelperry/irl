import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { and, eq, desc, inArray, isNull, isNotNull } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import type { AppVariables } from "../types.js";

const posts = new Hono<{ Variables: AppVariables }>();

posts.use("*", authMiddleware, screenTimeMiddleware);

// Delete a post (author only). Cascades remove reactions, comments, envelopes
// via FK ON DELETE CASCADE.
posts.delete("/:postId", async (c) => {
  const userId = c.get("userId");
  const postId = c.req.param("postId");
  const db = createDb();

  const result = await db
    .delete(schema.posts)
    .where(and(eq(schema.posts.id, postId), eq(schema.posts.userId, userId)))
    .returning({ id: schema.posts.id });

  if (result.length === 0) return c.json({ error: "not found" }, 404);
  return c.json({ deleted: true });
});

// Audience for a post: author + author's followers, with their X25519 pubkeys.
// Used by clients to seal comment-key envelopes for everyone who can read the thread.
posts.get("/:postId/audience", async (c) => {
  const postId = c.req.param("postId");
  const db = createDb();

  const [post] = await db.select().from(schema.posts).where(eq(schema.posts.id, postId)).limit(1);
  if (!post) return c.json({ error: "post not found" }, 404);

  const followerRows = await db
    .select({ id: schema.follows.followerId })
    .from(schema.follows)
    .where(eq(schema.follows.followingId, post.userId));

  const audienceIds = Array.from(new Set([post.userId, ...followerRows.map((r) => r.id)]));

  const recipients = await db
    .select({ id: schema.users.id, encryptionPublicKey: schema.users.encryptionPublicKey })
    .from(schema.users)
    .where(and(inArray(schema.users.id, audienceIds), isNotNull(schema.users.encryptionPublicKey)));

  return c.json({ recipients });
});

// Create an encrypted post
posts.post("/", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json();
  const { encryptedContent, encryptedMediaUrl, encryptedMediaKey } = body;

  if (!encryptedContent && !encryptedMediaUrl) {
    return c.json({ error: "Post must have content or media" }, 400);
  }

  const db = createDb();
  const [post] = await db
    .insert(schema.posts)
    .values({
      userId,
      encryptedContent,
      encryptedMediaUrl,
      encryptedMediaKey,
    })
    .returning();

  return c.json({ post }, 201);
});

// Get feed — encrypted posts from people you follow
posts.get("/feed", async (c) => {
  const userId = c.get("userId");
  const limit = Math.min(parseInt(c.req.query("limit") ?? "20"), 50);
  const before = c.req.query("before"); // cursor-based pagination

  const db = createDb();

  // Get list of users this person follows
  const following = await db
    .select({ followingId: schema.follows.followingId })
    .from(schema.follows)
    .where(eq(schema.follows.followerId, userId));

  const followingIds = following.map((f) => f.followingId);

  if (followingIds.length === 0) {
    return c.json({ posts: [], hasMore: false });
  }

  // Hide content from anyone the viewer has blocked, anyone who has blocked the viewer, or anyone muted.
  const [blocked, blockedBy, muted] = await Promise.all([
    db.select({ id: schema.blocks.blockedId }).from(schema.blocks).where(eq(schema.blocks.blockerId, userId)),
    db.select({ id: schema.blocks.blockerId }).from(schema.blocks).where(eq(schema.blocks.blockedId, userId)),
    db.select({ id: schema.mutes.mutedId }).from(schema.mutes).where(eq(schema.mutes.muterId, userId)),
  ]);

  const hiddenIds = [
    ...blocked.map((r) => r.id),
    ...blockedBy.map((r) => r.id),
    ...muted.map((r) => r.id),
  ];

  const visibleIds = hiddenIds.length > 0
    ? followingIds.filter((id) => !hiddenIds.includes(id))
    : followingIds;

  if (visibleIds.length === 0) {
    return c.json({ posts: [], hasMore: false });
  }

  const feedPosts = await db
    .select({
      id: schema.posts.id,
      userId: schema.posts.userId,
      authorDisplayName: schema.users.displayNameHash,
      encryptedContent: schema.posts.encryptedContent,
      encryptedMediaUrl: schema.posts.encryptedMediaUrl,
      encryptedMediaKey: schema.posts.encryptedMediaKey,
      createdAt: schema.posts.createdAt,
    })
    .from(schema.posts)
    .innerJoin(schema.users, eq(schema.users.id, schema.posts.userId))
    .where(
      and(
        inArray(schema.posts.userId, visibleIds),
        isNull(schema.posts.hiddenAt)
      )
    )
    .orderBy(desc(schema.posts.createdAt))
    .limit(limit + 1);

  const hasMore = feedPosts.length > limit;
  const results = hasMore ? feedPosts.slice(0, limit) : feedPosts;

  return c.json({
    posts: results,
    hasMore,
    nextCursor: hasMore ? results[results.length - 1].createdAt.toISOString() : null,
  });
});

export default posts;

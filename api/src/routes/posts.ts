import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { eq, desc, inArray } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import type { AppVariables } from "../types.js";

const posts = new Hono<{ Variables: AppVariables }>();

posts.use("*", authMiddleware, screenTimeMiddleware);

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

  const feedPosts = await db
    .select()
    .from(schema.posts)
    .where(inArray(schema.posts.userId, followingIds))
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

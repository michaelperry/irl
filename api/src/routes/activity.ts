import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { and, desc, eq, isNull, lt, sql } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import type { AppVariables } from "../types.js";

const activity = new Hono<{ Variables: AppVariables }>();

activity.use("*", authMiddleware, screenTimeMiddleware);

// Paginated activity list. Cursor is the createdAt of the last item.
activity.get("/", async (c) => {
  const userId = c.get("userId");
  const limit = Math.min(Number(c.req.query("limit") ?? 30), 100);
  const beforeRaw = c.req.query("before");
  const before = beforeRaw ? new Date(beforeRaw) : null;

  const db = createDb();

  const conditions = before
    ? and(eq(schema.activities.recipientId, userId), lt(schema.activities.createdAt, before))
    : eq(schema.activities.recipientId, userId);

  const rows = await db
    .select({
      id: schema.activities.id,
      actorId: schema.activities.actorId,
      actorName: schema.users.displayNameHash,
      kind: schema.activities.kind,
      postId: schema.activities.postId,
      commentId: schema.activities.commentId,
      reactionKind: schema.activities.reactionKind,
      readAt: schema.activities.readAt,
      createdAt: schema.activities.createdAt,
    })
    .from(schema.activities)
    .innerJoin(schema.users, eq(schema.users.id, schema.activities.actorId))
    .where(conditions)
    .orderBy(desc(schema.activities.createdAt))
    .limit(limit + 1);

  const hasMore = rows.length > limit;
  const items = hasMore ? rows.slice(0, limit) : rows;

  return c.json({
    activities: items,
    hasMore,
    nextCursor: hasMore ? items[items.length - 1].createdAt.toISOString() : null,
  });
});

activity.get("/unread-count", async (c) => {
  const userId = c.get("userId");
  const db = createDb();
  const [{ count }] = await db
    .select({ count: sql<number>`count(*)::int` })
    .from(schema.activities)
    .where(and(eq(schema.activities.recipientId, userId), isNull(schema.activities.readAt)));
  return c.json({ unread: Number(count) });
});

activity.post("/mark-read", async (c) => {
  const userId = c.get("userId");
  const db = createDb();
  await db
    .update(schema.activities)
    .set({ readAt: new Date() })
    .where(and(eq(schema.activities.recipientId, userId), isNull(schema.activities.readAt)));
  return c.json({ marked: true });
});

export default activity;

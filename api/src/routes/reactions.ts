import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { and, eq, sql } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import { notifyUser } from "../services/push.js";
import type { AppVariables } from "../types.js";

const reactions = new Hono<{ Variables: AppVariables }>();

reactions.use("*", authMiddleware, screenTimeMiddleware);

// Path-inspired fixed set. Keep small and expressive.
const REACTION_KINDS = ["smile", "love", "wow", "sad", "laugh", "fire"] as const;
type ReactionKind = (typeof REACTION_KINDS)[number];

function isValidKind(k: unknown): k is ReactionKind {
  return typeof k === "string" && (REACTION_KINDS as readonly string[]).includes(k);
}

// Set or replace your reaction on a post
reactions.put("/:postId", async (c) => {
  const userId = c.get("userId");
  const postId = c.req.param("postId");
  const { kind } = await c.req.json();

  if (!isValidKind(kind)) {
    return c.json({ error: "invalid reaction kind", allowed: REACTION_KINDS }, 400);
  }

  const db = createDb();
  await db
    .insert(schema.reactions)
    .values({ postId, userId, kind })
    .onConflictDoUpdate({
      target: [schema.reactions.postId, schema.reactions.userId],
      set: { kind, createdAt: new Date() },
    });

  // Best-effort push to the post author (skip when reacting to your own).
  const [post] = await db
    .select({ userId: schema.posts.userId })
    .from(schema.posts)
    .where(eq(schema.posts.id, postId))
    .limit(1);
  if (post && post.userId !== userId) {
    void notifyUser(post.userId, { type: "reaction", postId, actorId: userId, kind });
  }

  return c.json({ kind });
});

// Remove your reaction
reactions.delete("/:postId", async (c) => {
  const userId = c.get("userId");
  const postId = c.req.param("postId");

  const db = createDb();
  await db
    .delete(schema.reactions)
    .where(
      and(eq(schema.reactions.postId, postId), eq(schema.reactions.userId, userId))
    );

  return c.json({ removed: true });
});

// ---------- Comment reactions ----------

reactions.put("/comment/:commentId", async (c) => {
  const userId = c.get("userId");
  const commentId = c.req.param("commentId");
  const { kind } = await c.req.json();

  if (!isValidKind(kind)) {
    return c.json({ error: "invalid reaction kind", allowed: REACTION_KINDS }, 400);
  }

  const db = createDb();
  await db
    .insert(schema.commentReactions)
    .values({ commentId, userId, kind })
    .onConflictDoUpdate({
      target: [schema.commentReactions.commentId, schema.commentReactions.userId],
      set: { kind, createdAt: new Date() },
    });

  return c.json({ kind });
});

reactions.delete("/comment/:commentId", async (c) => {
  const userId = c.get("userId");
  const commentId = c.req.param("commentId");
  const db = createDb();
  await db
    .delete(schema.commentReactions)
    .where(
      and(eq(schema.commentReactions.commentId, commentId), eq(schema.commentReactions.userId, userId))
    );
  return c.json({ removed: true });
});

// Get reaction summary for a post: counts by kind + your current reaction
reactions.get("/:postId", async (c) => {
  const userId = c.get("userId");
  const postId = c.req.param("postId");

  const db = createDb();

  const rows = await db
    .select({
      kind: schema.reactions.kind,
      count: sql<number>`count(*)::int`,
    })
    .from(schema.reactions)
    .where(eq(schema.reactions.postId, postId))
    .groupBy(schema.reactions.kind);

  const counts: Record<string, number> = Object.fromEntries(
    REACTION_KINDS.map((k) => [k, 0])
  );
  for (const r of rows) counts[r.kind] = r.count;

  const [mine] = await db
    .select({ kind: schema.reactions.kind })
    .from(schema.reactions)
    .where(
      and(eq(schema.reactions.postId, postId), eq(schema.reactions.userId, userId))
    )
    .limit(1);

  return c.json({ counts, mine: mine?.kind ?? null });
});

export default reactions;

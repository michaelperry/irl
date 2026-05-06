import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { and, asc, eq, isNull, notInArray, inArray } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import { notifyUser } from "../services/push.js";
import type { AppVariables } from "../types.js";

const comments = new Hono<{ Variables: AppVariables }>();

comments.use("*", authMiddleware, screenTimeMiddleware);

// Create a comment (or one-level reply). Optionally accepts per-recipient sealed keys for E2E.
comments.post("/posts/:postId", async (c) => {
  const userId = c.get("userId");
  const postId = c.req.param("postId");
  const body = await c.req.json();
  const { encryptedContent, parentCommentId, envelopes } = body as {
    encryptedContent?: string;
    parentCommentId?: string;
    envelopes?: Array<{ recipientId: string; sealedKey: string }>;
  };

  if (!encryptedContent || typeof encryptedContent !== "string") {
    return c.json({ error: "encryptedContent required" }, 400);
  }

  const db = createDb();

  // Enforce single-level threading: a reply's parent must itself be a top-level comment.
  if (parentCommentId) {
    const [parent] = await db
      .select({ id: schema.comments.id, parentCommentId: schema.comments.parentCommentId, postId: schema.comments.postId })
      .from(schema.comments)
      .where(eq(schema.comments.id, parentCommentId))
      .limit(1);

    if (!parent || parent.postId !== postId) {
      return c.json({ error: "parent comment not found on this post" }, 400);
    }
    if (parent.parentCommentId) {
      return c.json({ error: "replies cannot be nested" }, 400);
    }
  }

  const [comment] = await db
    .insert(schema.comments)
    .values({ postId, userId, encryptedContent, parentCommentId: parentCommentId ?? null })
    .returning();

  if (Array.isArray(envelopes) && envelopes.length > 0) {
    const valid = envelopes.filter(
      (e) => e && typeof e.recipientId === "string" && typeof e.sealedKey === "string"
    );
    if (valid.length > 0) {
      await db.insert(schema.commentEnvelopes).values(
        valid.map((e) => ({
          commentId: comment.id,
          recipientId: e.recipientId,
          sealedKey: e.sealedKey,
        }))
      ).onConflictDoNothing();
    }
  }

  // Best-effort push to the post author (skip if commenter is the author).
  const [post] = await db
    .select({ userId: schema.posts.userId })
    .from(schema.posts)
    .where(eq(schema.posts.id, postId))
    .limit(1);
  if (post && post.userId !== userId) {
    void notifyUser(post.userId, {
      type: "comment",
      postId,
      commentId: comment.id,
      actorId: userId,
    });
  }

  return c.json({ comment }, 201);
});

// List comments for a post (excludes deleted, hidden, and content from blocked/muted users)
comments.get("/posts/:postId", async (c) => {
  const userId = c.get("userId");
  const postId = c.req.param("postId");

  const db = createDb();

  const blocked = await db
    .select({ id: schema.blocks.blockedId })
    .from(schema.blocks)
    .where(eq(schema.blocks.blockerId, userId));

  const blockedBy = await db
    .select({ id: schema.blocks.blockerId })
    .from(schema.blocks)
    .where(eq(schema.blocks.blockedId, userId));

  const muted = await db
    .select({ id: schema.mutes.mutedId })
    .from(schema.mutes)
    .where(eq(schema.mutes.muterId, userId));

  const hiddenIds = [
    ...blocked.map((b) => b.id),
    ...blockedBy.map((b) => b.id),
    ...muted.map((m) => m.id),
  ];

  const baseConditions = [
    eq(schema.comments.postId, postId),
    isNull(schema.comments.deletedAt),
    isNull(schema.comments.hiddenAt),
  ];

  const rows = await db
    .select()
    .from(schema.comments)
    .where(
      hiddenIds.length > 0
        ? and(...baseConditions, notInArray(schema.comments.userId, hiddenIds))
        : and(...baseConditions)
    )
    .orderBy(asc(schema.comments.createdAt))
    .limit(500);

  // Attach this user's sealed key envelope (if any) so they can decrypt.
  const ids = rows.map((r) => r.id);
  let envelopesByComment: Record<string, string> = {};
  if (ids.length > 0) {
    const envelopes = await db
      .select({
        commentId: schema.commentEnvelopes.commentId,
        sealedKey: schema.commentEnvelopes.sealedKey,
      })
      .from(schema.commentEnvelopes)
      .where(
        and(
          inArray(schema.commentEnvelopes.commentId, ids),
          eq(schema.commentEnvelopes.recipientId, userId)
        )
      );
    envelopesByComment = Object.fromEntries(envelopes.map((e) => [e.commentId, e.sealedKey]));
  }

  const enriched = rows.map((r) => ({
    ...r,
    myEnvelope: envelopesByComment[r.id] ?? null,
  }));

  return c.json({ comments: enriched });
});

// Soft-delete your own comment
comments.delete("/:id", async (c) => {
  const userId = c.get("userId");
  const id = c.req.param("id");

  const db = createDb();
  const [updated] = await db
    .update(schema.comments)
    .set({ deletedAt: new Date() })
    .where(and(eq(schema.comments.id, id), eq(schema.comments.userId, userId)))
    .returning({ id: schema.comments.id });

  if (!updated) return c.json({ error: "not found" }, 404);
  return c.json({ deleted: true });
});

export default comments;

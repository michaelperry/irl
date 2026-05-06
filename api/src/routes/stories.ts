import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { and, asc, desc, eq, gt, inArray, isNotNull, sql } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import type { AppVariables } from "../types.js";

const stories = new Hono<{ Variables: AppVariables }>();

stories.use("*", authMiddleware, screenTimeMiddleware);

const STORY_TTL_MS = 24 * 60 * 60 * 1000;

// Audience for a story: author + author's followers, with their pubkeys.
// Mirrors the post audience endpoint so iOS can share its envelope-building code.
stories.get("/audience", async (c) => {
  const userId = c.get("userId");
  const db = createDb();

  const followerRows = await db
    .select({ id: schema.follows.followerId })
    .from(schema.follows)
    .where(eq(schema.follows.followingId, userId));

  const audienceIds = Array.from(new Set([userId, ...followerRows.map((r) => r.id)]));

  const recipients = await db
    .select({ id: schema.users.id, encryptionPublicKey: schema.users.encryptionPublicKey })
    .from(schema.users)
    .where(and(inArray(schema.users.id, audienceIds), isNotNull(schema.users.encryptionPublicKey)));

  return c.json({ recipients });
});

// Create a story. Body: { encryptedContent?, encryptedMediaUrl?, encryptedMediaKey?,
//                         trustLevel, envelopes: [{recipientId, sealedKey}] }
stories.post("/", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json();
  const {
    encryptedContent,
    encryptedMediaUrl,
    encryptedMediaKey,
    mediaType,
    trustLevel,
    envelopes,
  } = body as {
    encryptedContent?: string;
    encryptedMediaUrl?: string;
    encryptedMediaKey?: string;
    mediaType?: string;
    trustLevel?: string;
    envelopes?: Array<{ recipientId: string; sealedKey: string }>;
  };

  if (!encryptedContent && !encryptedMediaUrl) {
    return c.json({ error: "Story must have content or media" }, 400);
  }

  const safeMediaType = mediaType === "video" ? "video" : "photo";
  const expiresAt = new Date(Date.now() + STORY_TTL_MS);

  const db = createDb();
  const [story] = await db
    .insert(schema.stories)
    .values({
      userId,
      encryptedContent: encryptedContent ?? null,
      encryptedMediaUrl: encryptedMediaUrl ?? null,
      encryptedMediaKey: encryptedMediaKey ?? null,
      mediaType: safeMediaType,
      trustLevel: trustLevel ?? "verified",
      expiresAt,
    })
    .returning();

  if (Array.isArray(envelopes) && envelopes.length > 0) {
    const valid = envelopes.filter(
      (e) => e && typeof e.recipientId === "string" && typeof e.sealedKey === "string"
    );
    if (valid.length > 0) {
      await db
        .insert(schema.storyEnvelopes)
        .values(valid.map((e) => ({ storyId: story.id, recipientId: e.recipientId, sealedKey: e.sealedKey })))
        .onConflictDoNothing();
    }
  }

  return c.json({ story }, 201);
});

// List active stories visible to me, grouped by author. Includes my own.
stories.get("/", async (c) => {
  const userId = c.get("userId");
  const db = createDb();
  const now = new Date();

  // The set of users whose stories I can see: people I follow + me
  const following = await db
    .select({ id: schema.follows.followingId })
    .from(schema.follows)
    .where(eq(schema.follows.followerId, userId));

  const visibleUserIds = Array.from(new Set([userId, ...following.map((f) => f.id)]));
  if (visibleUserIds.length === 0) return c.json({ groups: [] });

  // Fetch all active stories from those users
  const storyRows = await db
    .select({
      id: schema.stories.id,
      userId: schema.stories.userId,
      authorName: schema.users.displayNameHash,
      encryptedContent: schema.stories.encryptedContent,
      encryptedMediaUrl: schema.stories.encryptedMediaUrl,
      encryptedMediaKey: schema.stories.encryptedMediaKey,
      mediaType: schema.stories.mediaType,
      trustLevel: schema.stories.trustLevel,
      createdAt: schema.stories.createdAt,
      expiresAt: schema.stories.expiresAt,
    })
    .from(schema.stories)
    .innerJoin(schema.users, eq(schema.users.id, schema.stories.userId))
    .where(
      and(
        inArray(schema.stories.userId, visibleUserIds),
        gt(schema.stories.expiresAt, now)
      )
    )
    .orderBy(asc(schema.stories.createdAt));

  if (storyRows.length === 0) return c.json({ groups: [] });

  // Attach my envelope per story + viewed flag
  const ids = storyRows.map((s) => s.id);
  const envelopes = await db
    .select({ storyId: schema.storyEnvelopes.storyId, sealedKey: schema.storyEnvelopes.sealedKey })
    .from(schema.storyEnvelopes)
    .where(
      and(
        inArray(schema.storyEnvelopes.storyId, ids),
        eq(schema.storyEnvelopes.recipientId, userId)
      )
    );
  const envByStory = new Map(envelopes.map((e) => [e.storyId, e.sealedKey]));

  const views = await db
    .select({ storyId: schema.storyViews.storyId })
    .from(schema.storyViews)
    .where(
      and(inArray(schema.storyViews.storyId, ids), eq(schema.storyViews.viewerId, userId))
    );
  const viewedSet = new Set(views.map((v) => v.storyId));

  const enriched = storyRows.map((s) => ({
    ...s,
    myEnvelope: envByStory.get(s.id) ?? null,
    viewed: viewedSet.has(s.id),
  }));

  // Group by author, then sort groups so the ones with unseen stories come first,
  // mine to the front of all of those.
  type Item = (typeof enriched)[number];
  const byAuthor = new Map<string, { authorId: string; authorName: string; stories: Item[] }>();
  for (const s of enriched) {
    const g = byAuthor.get(s.userId) ?? {
      authorId: s.userId,
      authorName: s.authorName,
      stories: [] as Item[],
    };
    g.stories.push(s);
    byAuthor.set(s.userId, g);
  }

  const groups = Array.from(byAuthor.values()).map((g) => ({
    ...g,
    hasUnseen: g.stories.some((s) => !s.viewed),
  }));

  groups.sort((a, b) => {
    if (a.authorId === userId) return -1;
    if (b.authorId === userId) return 1;
    if (a.hasUnseen && !b.hasUnseen) return -1;
    if (!a.hasUnseen && b.hasUnseen) return 1;
    const aLast = a.stories[a.stories.length - 1].createdAt.getTime();
    const bLast = b.stories[b.stories.length - 1].createdAt.getTime();
    return bLast - aLast;
  });

  return c.json({ groups });
});

stories.post("/:id/view", async (c) => {
  const userId = c.get("userId");
  const storyId = c.req.param("id");
  const db = createDb();
  await db
    .insert(schema.storyViews)
    .values({ storyId, viewerId: userId })
    .onConflictDoNothing();
  return c.json({ viewed: true });
});

stories.delete("/:id", async (c) => {
  const userId = c.get("userId");
  const storyId = c.req.param("id");
  const db = createDb();
  const deleted = await db
    .delete(schema.stories)
    .where(and(eq(schema.stories.id, storyId), eq(schema.stories.userId, userId)))
    .returning({ id: schema.stories.id });
  if (deleted.length === 0) return c.json({ error: "not found" }, 404);
  return c.json({ deleted: true });
});

export default stories;

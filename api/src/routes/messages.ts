import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { and, asc, desc, eq, isNull, lt, ne, or, sql } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import { notifyUser } from "../services/push.js";
import type { AppVariables } from "../types.js";

const messages = new Hono<{ Variables: AppVariables }>();

messages.use("*", authMiddleware, screenTimeMiddleware);

// Canonical participant ordering: smaller UUID is A. Lets us enforce a single
// conversation per pair via UNIQUE(participantA, participantB).
function orderPair(a: string, b: string): { a: string; b: string } {
  return a < b ? { a, b } : { a: b, b: a };
}

async function isMutualFriend(db: ReturnType<typeof createDb>, x: string, y: string): Promise<boolean> {
  const [forward] = await db
    .select()
    .from(schema.follows)
    .where(and(eq(schema.follows.followerId, x), eq(schema.follows.followingId, y)))
    .limit(1);
  if (!forward) return false;
  const [back] = await db
    .select()
    .from(schema.follows)
    .where(and(eq(schema.follows.followerId, y), eq(schema.follows.followingId, x)))
    .limit(1);
  return !!back;
}

// List my conversations, newest activity first.
messages.get("/", async (c) => {
  const userId = c.get("userId");
  const db = createDb();

  const rows = await db
    .select({
      id: schema.conversations.id,
      participantA: schema.conversations.participantA,
      participantB: schema.conversations.participantB,
      lastMessageAt: schema.conversations.lastMessageAt,
      createdAt: schema.conversations.createdAt,
    })
    .from(schema.conversations)
    .where(or(eq(schema.conversations.participantA, userId), eq(schema.conversations.participantB, userId)))
    .orderBy(desc(schema.conversations.lastMessageAt));

  if (rows.length === 0) return c.json({ conversations: [] });

  // Hydrate the "other party" for each, plus last message + unread count
  const otherIds = Array.from(new Set(rows.map((r) => (r.participantA === userId ? r.participantB : r.participantA))));
  const others = await db
    .select({ id: schema.users.id, displayName: schema.users.displayNameHash, encryptionPublicKey: schema.users.encryptionPublicKey })
    .from(schema.users)
    .where(or(...otherIds.map((id) => eq(schema.users.id, id))));
  const othersById = new Map(others.map((o) => [o.id, o]));

  const conversationIds = rows.map((r) => r.id);
  const lastMessages = await db
    .select({
      conversationId: schema.messages.conversationId,
      ciphertext: schema.messages.ciphertext,
      senderId: schema.messages.senderId,
      createdAt: schema.messages.createdAt,
    })
    .from(schema.messages)
    .where(
      sql`${schema.messages.id} IN (
        SELECT id FROM (
          SELECT id, conversation_id,
                 ROW_NUMBER() OVER (PARTITION BY conversation_id ORDER BY created_at DESC) AS rn
          FROM messages
          WHERE conversation_id IN (${sql.join(conversationIds.map((id) => sql`${id}`), sql`, `)})
        ) t WHERE t.rn = 1
      )`
    );
  const lastByConv = new Map(lastMessages.map((m) => [m.conversationId, m]));

  const unreadCounts = await db
    .select({
      conversationId: schema.messages.conversationId,
      count: sql<number>`count(*)::int`,
    })
    .from(schema.messages)
    .where(
      and(
        ne(schema.messages.senderId, userId),
        isNull(schema.messages.readAt),
        or(...conversationIds.map((id) => eq(schema.messages.conversationId, id)))
      )
    )
    .groupBy(schema.messages.conversationId);
  const unreadByConv = new Map(unreadCounts.map((r) => [r.conversationId, Number(r.count)]));

  const result = rows.map((r) => {
    const otherId = r.participantA === userId ? r.participantB : r.participantA;
    const other = othersById.get(otherId);
    return {
      id: r.id,
      otherId,
      otherDisplayName: other?.displayName ?? "",
      otherEncryptionPublicKey: other?.encryptionPublicKey ?? null,
      lastMessage: lastByConv.get(r.id) ?? null,
      unread: unreadByConv.get(r.id) ?? 0,
      lastMessageAt: r.lastMessageAt,
      createdAt: r.createdAt,
    };
  });

  return c.json({ conversations: result });
});

messages.get("/unread-count", async (c) => {
  const userId = c.get("userId");
  const db = createDb();
  // Count unread messages where I am NOT the sender, across all my conversations.
  const [{ count }] = await db
    .select({ count: sql<number>`count(*)::int` })
    .from(schema.messages)
    .innerJoin(schema.conversations, eq(schema.conversations.id, schema.messages.conversationId))
    .where(
      and(
        ne(schema.messages.senderId, userId),
        isNull(schema.messages.readAt),
        or(eq(schema.conversations.participantA, userId), eq(schema.conversations.participantB, userId))
      )
    );
  return c.json({ unread: Number(count) });
});

// Get (or lazily create) the 1-on-1 conversation with :userId, plus recent messages.
messages.get("/with/:userId", async (c) => {
  const me = c.get("userId");
  const other = c.req.param("userId");

  if (me === other) return c.json({ error: "cannot DM yourself" }, 400);

  const db = createDb();

  if (!(await isMutualFriend(db, me, other))) {
    return c.json({ error: "not_mutual_friends", message: "You can only DM mutual friends." }, 403);
  }

  const { a, b } = orderPair(me, other);

  let [conversation] = await db
    .select()
    .from(schema.conversations)
    .where(and(eq(schema.conversations.participantA, a), eq(schema.conversations.participantB, b)))
    .limit(1);

  if (!conversation) {
    [conversation] = await db
      .insert(schema.conversations)
      .values({ participantA: a, participantB: b })
      .returning();
  }

  const limit = Math.min(Number(c.req.query("limit") ?? 50), 200);
  const beforeRaw = c.req.query("before");
  const before = beforeRaw ? new Date(beforeRaw) : null;

  const baseConditions = [eq(schema.messages.conversationId, conversation.id)];
  const whereClause = before
    ? and(...baseConditions, lt(schema.messages.createdAt, before))
    : and(...baseConditions);

  const rows = await db
    .select({
      id: schema.messages.id,
      senderId: schema.messages.senderId,
      ciphertext: schema.messages.ciphertext,
      createdAt: schema.messages.createdAt,
      readAt: schema.messages.readAt,
    })
    .from(schema.messages)
    .where(whereClause)
    .orderBy(desc(schema.messages.createdAt))
    .limit(limit + 1);

  // Attach my envelope per message
  const ids = rows.map((r) => r.id);
  let envelopesByMessage: Record<string, string> = {};
  if (ids.length > 0) {
    const envs = await db
      .select({ messageId: schema.messageEnvelopes.messageId, sealedKey: schema.messageEnvelopes.sealedKey })
      .from(schema.messageEnvelopes)
      .where(
        and(
          eq(schema.messageEnvelopes.recipientId, me),
          or(...ids.map((id) => eq(schema.messageEnvelopes.messageId, id)))
        )
      );
    envelopesByMessage = Object.fromEntries(envs.map((e) => [e.messageId, e.sealedKey]));
  }

  const hasMore = rows.length > limit;
  const items = (hasMore ? rows.slice(0, limit) : rows).map((r) => ({
    ...r,
    myEnvelope: envelopesByMessage[r.id] ?? null,
  }));

  return c.json({
    conversation: {
      id: conversation.id,
      otherId: other,
    },
    messages: items.reverse(), // chronological order for client rendering
    hasMore,
    nextCursor: hasMore ? items[0].createdAt.toISOString() : null,
  });
});

// Send a message. Body: { ciphertext, envelopes: [{recipientId, sealedKey}] }
// (envelopes should include both sender + recipient).
messages.post("/with/:userId", async (c) => {
  const me = c.get("userId");
  const other = c.req.param("userId");

  if (me === other) return c.json({ error: "cannot DM yourself" }, 400);

  const body = await c.req.json();
  const { ciphertext, envelopes } = body as {
    ciphertext?: string;
    envelopes?: Array<{ recipientId: string; sealedKey: string }>;
  };

  if (!ciphertext || typeof ciphertext !== "string") {
    return c.json({ error: "ciphertext required" }, 400);
  }

  const db = createDb();

  if (!(await isMutualFriend(db, me, other))) {
    return c.json({ error: "not_mutual_friends", message: "You can only DM mutual friends." }, 403);
  }

  const { a, b } = orderPair(me, other);

  let [conversation] = await db
    .select()
    .from(schema.conversations)
    .where(and(eq(schema.conversations.participantA, a), eq(schema.conversations.participantB, b)))
    .limit(1);

  if (!conversation) {
    [conversation] = await db
      .insert(schema.conversations)
      .values({ participantA: a, participantB: b })
      .returning();
  }

  const now = new Date();

  const [message] = await db
    .insert(schema.messages)
    .values({ conversationId: conversation.id, senderId: me, ciphertext })
    .returning();

  if (Array.isArray(envelopes) && envelopes.length > 0) {
    const valid = envelopes.filter(
      (e) => e && typeof e.recipientId === "string" && typeof e.sealedKey === "string"
    );
    if (valid.length > 0) {
      await db
        .insert(schema.messageEnvelopes)
        .values(valid.map((e) => ({ messageId: message.id, recipientId: e.recipientId, sealedKey: e.sealedKey })))
        .onConflictDoNothing();
    }
  }

  await db
    .update(schema.conversations)
    .set({ lastMessageAt: now })
    .where(eq(schema.conversations.id, conversation.id));

  void notifyUser(other, { type: "message", actorId: me, conversationId: conversation.id, messageId: message.id });

  return c.json({ message: { ...message, myEnvelope: null } }, 201);
});

messages.post("/:conversationId/mark-read", async (c) => {
  const me = c.get("userId");
  const conversationId = c.req.param("conversationId");

  const db = createDb();
  const [convo] = await db
    .select()
    .from(schema.conversations)
    .where(eq(schema.conversations.id, conversationId))
    .limit(1);

  if (!convo) return c.json({ error: "not found" }, 404);
  if (convo.participantA !== me && convo.participantB !== me) {
    return c.json({ error: "forbidden" }, 403);
  }

  await db
    .update(schema.messages)
    .set({ readAt: new Date() })
    .where(
      and(
        eq(schema.messages.conversationId, conversationId),
        ne(schema.messages.senderId, me),
        isNull(schema.messages.readAt)
      )
    );

  return c.json({ marked: true });
});

export default messages;

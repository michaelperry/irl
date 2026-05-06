import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { and, eq } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import type { AppVariables } from "../types.js";

const safety = new Hono<{ Variables: AppVariables }>();

safety.use("*", authMiddleware, screenTimeMiddleware);

const REPORT_REASONS = [
  "harassment",
  "sexual",
  "violence",
  "self_harm",
  "spam",
  "impersonation",
  "other",
] as const;
type ReportReason = (typeof REPORT_REASONS)[number];

const TARGET_TYPES = ["post", "comment", "user"] as const;
type TargetType = (typeof TARGET_TYPES)[number];

// ---------- Blocks ----------

safety.post("/blocks/:userId", async (c) => {
  const blockerId = c.get("userId");
  const blockedId = c.req.param("userId");

  if (blockerId === blockedId) {
    return c.json({ error: "cannot block yourself" }, 400);
  }

  const db = createDb();

  // Block + sever any follow edges in either direction.
  await db
    .insert(schema.blocks)
    .values({ blockerId, blockedId })
    .onConflictDoNothing();

  await db
    .delete(schema.follows)
    .where(
      and(eq(schema.follows.followerId, blockerId), eq(schema.follows.followingId, blockedId))
    );
  await db
    .delete(schema.follows)
    .where(
      and(eq(schema.follows.followerId, blockedId), eq(schema.follows.followingId, blockerId))
    );

  return c.json({ blocked: true });
});

safety.delete("/blocks/:userId", async (c) => {
  const blockerId = c.get("userId");
  const blockedId = c.req.param("userId");

  const db = createDb();
  await db
    .delete(schema.blocks)
    .where(
      and(eq(schema.blocks.blockerId, blockerId), eq(schema.blocks.blockedId, blockedId))
    );

  return c.json({ unblocked: true });
});

safety.get("/blocks", async (c) => {
  const userId = c.get("userId");
  const db = createDb();
  const rows = await db
    .select({ blockedId: schema.blocks.blockedId, createdAt: schema.blocks.createdAt })
    .from(schema.blocks)
    .where(eq(schema.blocks.blockerId, userId));
  return c.json({ blocks: rows });
});

// ---------- Mutes ----------

safety.post("/mutes/:userId", async (c) => {
  const muterId = c.get("userId");
  const mutedId = c.req.param("userId");
  const body = await c.req.json().catch(() => ({}));
  const { durationSeconds } = body as { durationSeconds?: number };

  if (muterId === mutedId) {
    return c.json({ error: "cannot mute yourself" }, 400);
  }

  const expiresAt =
    typeof durationSeconds === "number" && durationSeconds > 0
      ? new Date(Date.now() + durationSeconds * 1000)
      : null;

  const db = createDb();
  await db
    .insert(schema.mutes)
    .values({ muterId, mutedId, expiresAt })
    .onConflictDoNothing();

  return c.json({ muted: true, expiresAt });
});

safety.delete("/mutes/:userId", async (c) => {
  const muterId = c.get("userId");
  const mutedId = c.req.param("userId");
  const db = createDb();
  await db
    .delete(schema.mutes)
    .where(and(eq(schema.mutes.muterId, muterId), eq(schema.mutes.mutedId, mutedId)));
  return c.json({ unmuted: true });
});

// ---------- Moderation public key ----------

// Returns the moderation X25519 pubkey (base64). Clients seal report evidence to it,
// so only the moderation team (holders of MOD_PRIVATE_KEY) can read the contents.
safety.get("/mod-pubkey", async (c) => {
  const key = process.env.MOD_PUBLIC_KEY;
  if (!key) return c.json({ error: "moderation key not configured" }, 503);
  return c.json({ publicKey: key });
});

// ---------- Reports ----------

safety.post("/reports", async (c) => {
  const reporterId = c.get("userId");
  const body = await c.req.json();
  const { targetType, targetId, reason, note, encryptedEvidence } = body as {
    targetType?: string;
    targetId?: string;
    reason?: string;
    note?: string;
    encryptedEvidence?: string;
  };

  if (!targetType || !(TARGET_TYPES as readonly string[]).includes(targetType)) {
    return c.json({ error: "invalid targetType", allowed: TARGET_TYPES }, 400);
  }
  if (!targetId || typeof targetId !== "string") {
    return c.json({ error: "targetId required" }, 400);
  }
  if (!reason || !(REPORT_REASONS as readonly string[]).includes(reason)) {
    return c.json({ error: "invalid reason", allowed: REPORT_REASONS }, 400);
  }

  const db = createDb();
  const [report] = await db
    .insert(schema.reports)
    .values({
      reporterId,
      targetType: targetType as TargetType,
      targetId,
      reason: reason as ReportReason,
      note: note ?? null,
      encryptedEvidence: encryptedEvidence ?? null,
    })
    .returning({ id: schema.reports.id, createdAt: schema.reports.createdAt });

  return c.json({ report }, 201);
});

export default safety;

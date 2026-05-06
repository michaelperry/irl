import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { and, eq, isNull, lt, or, sql } from "drizzle-orm";
import { notifyUser } from "../services/push.js";

const cron = new Hono();

// Vercel Cron Jobs send the request with `Authorization: Bearer <CRON_SECRET>`.
// We require that header in production. Locally / when CRON_SECRET is unset the
// route is open so manual testing isn't blocked.
cron.use("*", async (c, next) => {
  const expected = process.env.CRON_SECRET;
  if (!expected) {
    return next();
  }
  const auth = c.req.header("Authorization");
  if (auth !== `Bearer ${expected}`) {
    return c.json({ error: "unauthorized" }, 401);
  }
  await next();
});

const NUDGE_COOLDOWN_DAYS = 7;
const INACTIVITY_DAYS = 5;

/// Find users who haven't posted in INACTIVITY_DAYS days, AND haven't been nudged
/// in NUDGE_COOLDOWN_DAYS days. Send each a gentle "share what's going on" push.
cron.get("/inactivity-nudge", async (c) => {
  const db = createDb();
  const now = new Date();
  const inactivityCutoff = new Date(now.getTime() - INACTIVITY_DAYS * 86_400_000);
  const cooldownCutoff = new Date(now.getTime() - NUDGE_COOLDOWN_DAYS * 86_400_000);

  // Pull users whose latest post is older than the inactivity cutoff (or who
  // have no posts at all), and who are off cooldown for nudges.
  const candidates = await db
    .select({
      id: schema.users.id,
      lastNudgeSentAt: schema.users.lastNudgeSentAt,
      lastPostAt: sql<Date | null>`(
        SELECT MAX(${schema.posts.createdAt})
        FROM ${schema.posts}
        WHERE ${schema.posts.userId} = ${schema.users.id}
      )`.as("lastPostAt"),
    })
    .from(schema.users);

  let nudged = 0;
  for (const u of candidates) {
    const lastPost = u.lastPostAt ? new Date(u.lastPostAt) : null;
    const isInactive = lastPost === null || lastPost < inactivityCutoff;
    if (!isInactive) continue;

    const lastNudge = u.lastNudgeSentAt;
    const offCooldown = lastNudge === null || lastNudge < cooldownCutoff;
    if (!offCooldown) continue;

    // Best-effort push, no activity row.
    void notifyUser(u.id, { type: "nudge", actorId: u.id });

    await db
      .update(schema.users)
      .set({ lastNudgeSentAt: now })
      .where(eq(schema.users.id, u.id));

    nudged += 1;
  }

  return c.json({ nudged, scanned: candidates.length });
});

export default cron;

import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { and, eq, sql } from "drizzle-orm";
import { authMiddleware } from "../middleware/auth.js";
import type { AppVariables } from "../types.js";

const screentime = new Hono<{ Variables: AppVariables }>();

screentime.use("*", authMiddleware);

// Get today's screen time status
screentime.get("/", async (c) => {
  const userId = c.get("userId");
  const user = c.get("user");
  const db = createDb();
  const today = new Date().toISOString().split("T")[0];

  const [record] = await db
    .select()
    .from(schema.screenTime)
    .where(
      and(
        eq(schema.screenTime.userId, userId),
        eq(schema.screenTime.date, today)
      )
    )
    .limit(1);

  const limit = user.dailyScreenLimitSeconds;
  const used = record?.secondsUsed ?? 0;

  return c.json({
    date: today,
    usedSeconds: used,
    limitSeconds: limit,
    remainingSeconds: Math.max(0, limit - used),
    limitReached: used >= limit,
  });
});

// Report screen time (called by client periodically)
screentime.post("/ping", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json();
  const { seconds } = body;

  if (!seconds || seconds < 0 || seconds > 300) {
    return c.json({ error: "seconds must be between 0 and 300" }, 400);
  }

  const db = createDb();
  const today = new Date().toISOString().split("T")[0];

  await db
    .insert(schema.screenTime)
    .values({ userId, date: today, secondsUsed: seconds })
    .onConflictDoUpdate({
      target: [schema.screenTime.userId, schema.screenTime.date],
      set: {
        secondsUsed: sql`screen_time.seconds_used + ${seconds}`,
      },
    });

  return c.json({ recorded: true });
});

export default screentime;

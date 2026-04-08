import { createMiddleware } from "hono/factory";
import { createDb, schema } from "../db/index.js";
import { and, eq } from "drizzle-orm";
import type { AppVariables } from "../types.js";

export const screenTimeMiddleware = createMiddleware<{ Variables: AppVariables }>(async (c, next) => {
  const userId = c.get("userId");
  if (!userId) {
    await next();
    return;
  }

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

  const user = c.get("user");
  const limit = user?.dailyScreenLimitSeconds ?? 3600;
  const used = record?.secondsUsed ?? 0;

  if (used >= limit) {
    return c.json(
      {
        error: "Daily screen time limit reached",
        limitSeconds: limit,
        usedSeconds: used,
      },
      429
    );
  }

  c.set("screenTimeRemaining", limit - used);
  await next();
});

import { createMiddleware } from "hono/factory";
import { jwtVerify } from "jose";
import { createDb, schema } from "../db/index.js";
import { eq } from "drizzle-orm";
import type { AppVariables } from "../types.js";

export const authMiddleware = createMiddleware<{ Variables: AppVariables }>(async (c, next) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return c.json({ error: "Missing authorization" }, 401);
  }

  const token = authHeader.slice(7);

  try {
    const secret = new TextEncoder().encode(process.env.JWT_SECRET);
    const { payload } = await jwtVerify(token, secret, { algorithms: ["HS256"] });
    const userId = payload.sub;

    if (!userId) {
      return c.json({ error: "Invalid token" }, 401);
    }

    const db = createDb();
    const [user] = await db
      .select()
      .from(schema.users)
      .where(eq(schema.users.id, userId))
      .limit(1);

    if (!user) {
      return c.json({ error: "User not found" }, 401);
    }

    c.set("userId", userId);
    c.set("user", user);
    await next();
  } catch {
    return c.json({ error: "Invalid token" }, 401);
  }
});

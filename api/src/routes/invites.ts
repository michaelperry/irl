import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { and, eq, isNull, sql } from "drizzle-orm";
import { randomBytes } from "node:crypto";
import { authMiddleware } from "../middleware/auth.js";
import { screenTimeMiddleware } from "../middleware/screentime.js";
import type { AppVariables } from "../types.js";

const invites = new Hono<{ Variables: AppVariables }>();

invites.use("*", authMiddleware, screenTimeMiddleware);

const CODE_BYTES = 5; // ~8-char base32 string
const DEFAULT_EXPIRY_DAYS = 30;

function newCode(): string {
  // Crockford-ish base32 (no I, L, O, U) for human-readable, ambiguity-free codes.
  const alphabet = "ABCDEFGHJKMNPQRSTVWXYZ23456789";
  const bytes = randomBytes(CODE_BYTES);
  let out = "";
  for (const b of bytes) out += alphabet[b % alphabet.length];
  return out;
}

// Mint up to N codes for the current user. Re-uses outstanding unredeemed codes
// to avoid generating an unbounded pile if the endpoint is hit repeatedly.
invites.post("/", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json().catch(() => ({}));
  const requested = Math.max(1, Math.min(5, Number(body.count ?? 5)));

  const db = createDb();

  // Existing live (unredeemed, unexpired) codes
  const now = new Date();
  const live = await db
    .select()
    .from(schema.invites)
    .where(
      and(
        eq(schema.invites.inviterId, userId),
        isNull(schema.invites.redeemedAt),
        sql`${schema.invites.expiresAt} > ${now}`
      )
    );

  const need = Math.max(0, requested - live.length);
  if (need === 0) return c.json({ invites: live });

  const expiresAt = new Date(Date.now() + DEFAULT_EXPIRY_DAYS * 86_400_000);
  const fresh = Array.from({ length: need }, () => ({
    inviterId: userId,
    code: newCode(),
    expiresAt,
  }));

  const inserted = await db
    .insert(schema.invites)
    .values(fresh)
    .returning();

  return c.json({ invites: [...live, ...inserted] }, 201);
});

// List all of my invites with redemption state.
invites.get("/me", async (c) => {
  const userId = c.get("userId");
  const db = createDb();
  const rows = await db
    .select()
    .from(schema.invites)
    .where(eq(schema.invites.inviterId, userId))
    .orderBy(schema.invites.createdAt);
  return c.json({ invites: rows });
});

export default invites;

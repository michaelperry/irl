import { Hono } from "hono";
import { SignJWT } from "jose";
import { createDb, schema } from "../db/index.js";
import { and, eq, isNull, sql } from "drizzle-orm";
import { BONUS_SLOTS_MAX } from "./profile.js";

const auth = new Hono();

async function generateToken(userId: string): Promise<string> {
  const secret = new TextEncoder().encode(process.env.JWT_SECRET);
  return new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(secret);
}

// Look up an invite code's metadata (used by the invitee's onboarding screen
// to show "you're being invited by ...").
auth.get("/invite/:code", async (c) => {
  const code = c.req.param("code").toUpperCase();
  const db = createDb();
  const now = new Date();
  const [invite] = await db
    .select({
      id: schema.invites.id,
      inviterId: schema.invites.inviterId,
      expiresAt: schema.invites.expiresAt,
      redeemedAt: schema.invites.redeemedAt,
    })
    .from(schema.invites)
    .where(eq(schema.invites.code, code))
    .limit(1);

  if (!invite) return c.json({ error: "invalid_code" }, 404);
  if (invite.redeemedAt) return c.json({ error: "already_redeemed" }, 410);
  if (invite.expiresAt < now) return c.json({ error: "expired" }, 410);

  return c.json({ valid: true, inviterId: invite.inviterId });
});

// Register a new user with their public key and biometric attestation.
// If an inviteCode is provided and valid, redeem it: increments the inviter's
// bonusSlotsUnlocked (cap 5) and creates mutual follow rows (with null shared key
// — exchanged later by the clients).
auth.post("/register", async (c) => {
  const body = await c.req.json();
  const { publicKey, encryptionPublicKey, displayNameHash, biometricKeyId, inviteCode } = body;

  if (!publicKey || !displayNameHash || !biometricKeyId) {
    return c.json({ error: "Missing required fields: publicKey, displayNameHash, biometricKeyId" }, 400);
  }

  const db = createDb();

  // Check for duplicate identity
  const [existing] = await db
    .select()
    .from(schema.users)
    .where(eq(schema.users.biometricKeyId, biometricKeyId))
    .limit(1);

  if (existing) {
    return c.json({ error: "This identity is already registered. One person, one account." }, 409);
  }

  // Validate invite code up front (if provided) so we can fail before creating the user.
  let inviterId: string | null = null;
  if (inviteCode && typeof inviteCode === "string") {
    const code = inviteCode.toUpperCase();
    const now = new Date();
    const [inv] = await db
      .select()
      .from(schema.invites)
      .where(
        and(
          eq(schema.invites.code, code),
          isNull(schema.invites.redeemedAt),
          sql`${schema.invites.expiresAt} > ${now}`
        )
      )
      .limit(1);
    if (!inv) {
      return c.json({ error: "invalid_or_expired_invite" }, 400);
    }
    inviterId = inv.inviterId;
  }

  const [user] = await db
    .insert(schema.users)
    .values({
      publicKey,
      encryptionPublicKey: encryptionPublicKey ?? null,
      displayNameHash,
      biometricKeyId,
    })
    .returning({ id: schema.users.id, createdAt: schema.users.createdAt });

  // Redeem invite + reward inviter + create mutual follow.
  if (inviterId) {
    await db
      .update(schema.invites)
      .set({ redeemedAt: new Date(), redeemerId: user.id })
      .where(eq(schema.invites.code, (inviteCode as string).toUpperCase()));

    await db
      .update(schema.users)
      .set({
        bonusSlotsUnlocked: sql`LEAST(${BONUS_SLOTS_MAX}, ${schema.users.bonusSlotsUnlocked} + 1)`,
        updatedAt: new Date(),
      })
      .where(eq(schema.users.id, inviterId));

    // Mutual follow with null shared key — clients exchange keys lazily later.
    await db
      .insert(schema.follows)
      .values([
        { followerId: inviterId, followingId: user.id, encryptedSharedKey: null },
        { followerId: user.id, followingId: inviterId, encryptedSharedKey: null },
      ])
      .onConflictDoNothing();
  }

  const token = await generateToken(user.id);
  return c.json({ user, token, redeemedInviterId: inviterId }, 201);
});

// Update encryption public key (e.g. after rotation or app reinstall)
auth.post("/encryption-key", async (c) => {
  const auth = c.req.header("Authorization");
  if (!auth?.startsWith("Bearer ")) return c.json({ error: "Missing authorization" }, 401);

  // Inline auth — avoids dragging the middleware just for this endpoint.
  const { jwtVerify } = await import("jose");
  const secret = new TextEncoder().encode(process.env.JWT_SECRET);
  const token = auth.slice(7);
  let userId: string;
  try {
    const { payload } = await jwtVerify(token, secret, { algorithms: ["HS256"] });
    if (!payload.sub) return c.json({ error: "Invalid token" }, 401);
    userId = payload.sub;
  } catch {
    return c.json({ error: "Invalid token" }, 401);
  }

  const { encryptionPublicKey } = await c.req.json();
  if (!encryptionPublicKey || typeof encryptionPublicKey !== "string") {
    return c.json({ error: "encryptionPublicKey required" }, 400);
  }

  const db = createDb();
  await db
    .update(schema.users)
    .set({ encryptionPublicKey, updatedAt: new Date() })
    .where(eq(schema.users.id, userId));

  return c.json({ updated: true });
});

// Login — verify biometric challenge and return session
auth.post("/login", async (c) => {
  const body = await c.req.json();
  const { biometricKeyId, signedChallenge } = body;

  if (!biometricKeyId || !signedChallenge) {
    return c.json({ error: "Missing biometricKeyId or signedChallenge" }, 400);
  }

  const db = createDb();
  const [user] = await db
    .select()
    .from(schema.users)
    .where(eq(schema.users.biometricKeyId, biometricKeyId))
    .limit(1);

  if (!user) {
    return c.json({ error: "User not found" }, 404);
  }

  // TODO: Verify signedChallenge against user's publicKey
  // This ensures the device that registered is the one logging in

  const token = await generateToken(user.id);
  return c.json({
    userId: user.id,
    screenLimitSeconds: user.dailyScreenLimitSeconds,
    token,
  });
});

export default auth;

import { Hono } from "hono";
import { createDb, schema } from "../db/index.js";
import { eq } from "drizzle-orm";

const auth = new Hono();

// Register a new user with their public key and biometric attestation
auth.post("/register", async (c) => {
  const body = await c.req.json();
  const { publicKey, displayNameHash, biometricKeyId } = body;

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

  const [user] = await db
    .insert(schema.users)
    .values({
      publicKey,
      displayNameHash,
      biometricKeyId,
    })
    .returning({ id: schema.users.id, createdAt: schema.users.createdAt });

  return c.json({ user }, 201);
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

  return c.json({
    userId: user.id,
    screenLimitSeconds: user.dailyScreenLimitSeconds,
    // TODO: Return signed JWT
    token: "placeholder",
  });
});

export default auth;

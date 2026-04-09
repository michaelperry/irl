import { Hono } from "hono";
import { SignJWT } from "jose";
import { createDb, schema } from "../db/index.js";
import { eq } from "drizzle-orm";

const auth = new Hono();

async function generateToken(userId: string): Promise<string> {
  const secret = new TextEncoder().encode(process.env.JWT_SECRET);
  return new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(secret);
}

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

  const token = await generateToken(user.id);
  return c.json({ user, token }, 201);
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

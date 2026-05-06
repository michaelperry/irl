#!/usr/bin/env node
// One-shot: generate the moderation X25519 keypair and print the raw 32-byte values
// in base64. Use the public key as MOD_PUBLIC_KEY in Vercel; the private key goes
// into MOD_PRIVATE_KEY for whoever runs the moderation triage tool.
//
// The raw representation matches Apple CryptoKit's Curve25519.KeyAgreement.{Private,Public}Key.rawRepresentation,
// so iOS-generated envelopes can be unsealed by anyone holding MOD_PRIVATE_KEY.

import { generateKeyPairSync } from "node:crypto";

const { publicKey, privateKey } = generateKeyPairSync("x25519");

const pubDer = publicKey.export({ type: "spki", format: "der" });
const privDer = privateKey.export({ type: "pkcs8", format: "der" });

// Last 32 bytes of the SPKI / PKCS8 DER are the raw key bytes for X25519.
const pubRaw = pubDer.subarray(pubDer.length - 32);
const privRaw = privDer.subarray(privDer.length - 32);

console.log("# Add to your environment:");
console.log(`MOD_PUBLIC_KEY=${pubRaw.toString("base64")}`);
console.log(`MOD_PRIVATE_KEY=${privRaw.toString("base64")}`);
console.log("\n# Public key is safe to expose to clients (it's how reports get sealed).");
console.log("# Private key MUST be guarded — anyone with it can decrypt every report.");

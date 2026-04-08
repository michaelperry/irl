import { pgTable, uuid, text, timestamp, integer, uniqueIndex, primaryKey } from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: uuid("id").defaultRandom().primaryKey(),
  publicKey: text("public_key").notNull(),
  encryptedProfile: text("encrypted_profile"),
  displayNameHash: text("display_name_hash").notNull().unique(),
  biometricKeyId: text("biometric_key_id").notNull(),
  dailyScreenLimitSeconds: integer("daily_screen_limit_seconds").notNull().default(3600), // 1 hour
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const posts = pgTable("posts", {
  id: uuid("id").defaultRandom().primaryKey(),
  userId: uuid("user_id").notNull().references(() => users.id),
  encryptedContent: text("encrypted_content"),
  encryptedMediaUrl: text("encrypted_media_url"),
  encryptedMediaKey: text("encrypted_media_key"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const follows = pgTable(
  "follows",
  {
    followerId: uuid("follower_id").notNull().references(() => users.id),
    followingId: uuid("following_id").notNull().references(() => users.id),
    encryptedSharedKey: text("encrypted_shared_key").notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.followerId, table.followingId] }),
  ]
);

export const screenTime = pgTable(
  "screen_time",
  {
    userId: uuid("user_id").notNull().references(() => users.id),
    date: text("date").notNull(), // YYYY-MM-DD
    secondsUsed: integer("seconds_used").notNull().default(0),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    uniqueIndex("screen_time_user_date_idx").on(table.userId, table.date),
  ]
);

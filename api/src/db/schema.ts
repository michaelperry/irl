import {
  pgTable,
  uuid,
  text,
  timestamp,
  integer,
  uniqueIndex,
  index,
  primaryKey,
} from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: uuid("id").defaultRandom().primaryKey(),
  publicKey: text("public_key").notNull(),                  // legacy biometric attestation key
  encryptionPublicKey: text("encryption_public_key"),       // X25519 base64 — used for E2E envelopes
  encryptedProfile: text("encrypted_profile"),
  displayNameHash: text("display_name_hash").notNull().unique(),
  biometricKeyId: text("biometric_key_id").notNull(),
  dailyScreenLimitSeconds: integer("daily_screen_limit_seconds").notNull().default(3600), // 1 hour
  bonusSlotsUnlocked: integer("bonus_slots_unlocked").notNull().default(0), // 0..5; +1 per successful invite, max 5
  strikeCount: integer("strike_count").notNull().default(0),
  suspendedUntil: timestamp("suspended_until"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const posts = pgTable("posts", {
  id: uuid("id").defaultRandom().primaryKey(),
  userId: uuid("user_id").notNull().references(() => users.id),
  encryptedContent: text("encrypted_content"),
  encryptedMediaUrl: text("encrypted_media_url"),
  encryptedMediaKey: text("encrypted_media_key"),
  hiddenAt: timestamp("hidden_at"), // moderation soft-hide
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const follows = pgTable(
  "follows",
  {
    followerId: uuid("follower_id").notNull().references(() => users.id),
    followingId: uuid("following_id").notNull().references(() => users.id),
    // Nullable for invite-driven follows where the key exchange happens later;
    // posts/comments fall back to plaintext until both sides exchange keys.
    encryptedSharedKey: text("encrypted_shared_key"),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.followerId, table.followingId] }),
  ]
);

// Invite codes — minted by an existing user, redeemed by the new user at register.
// Successful redemption: increments inviter's bonus_slots_unlocked (capped at 5)
// and creates mutual follow rows (with null shared key — exchanged later).
export const invites = pgTable(
  "invites",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    inviterId: uuid("inviter_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    code: text("code").notNull().unique(),
    redeemerId: uuid("redeemer_id").references(() => users.id, { onDelete: "set null" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    redeemedAt: timestamp("redeemed_at"),
    expiresAt: timestamp("expires_at").notNull(),
  },
  (table) => [
    index("invites_inviter_idx").on(table.inviterId),
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

// Path-inspired fixed reaction set: smile | love | wow | sad | laugh | fire
// One reaction per user per post, replace-on-tap.
export const reactions = pgTable(
  "reactions",
  {
    postId: uuid("post_id").notNull().references(() => posts.id, { onDelete: "cascade" }),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    kind: text("kind").notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.postId, table.userId] }),
    index("reactions_post_idx").on(table.postId),
  ]
);

// Reactions on comments — mirrors `reactions` for posts. Single-replace per user
// per comment via composite PK.
export const commentReactions = pgTable(
  "comment_reactions",
  {
    commentId: uuid("comment_id").notNull().references(() => comments.id, { onDelete: "cascade" }),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    kind: text("kind").notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.commentId, table.userId] }),
    index("comment_reactions_comment_idx").on(table.commentId),
  ]
);

export const comments = pgTable(
  "comments",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    postId: uuid("post_id").notNull().references(() => posts.id, { onDelete: "cascade" }),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    parentCommentId: uuid("parent_comment_id"),
    encryptedContent: text("encrypted_content").notNull(),
    deletedAt: timestamp("deleted_at"),
    hiddenAt: timestamp("hidden_at"),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    index("comments_post_idx").on(table.postId, table.createdAt),
  ]
);

// Bidirectional invisibility. Application-level enforcement filters both directions.
export const blocks = pgTable(
  "blocks",
  {
    blockerId: uuid("blocker_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    blockedId: uuid("blocked_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.blockerId, table.blockedId] }),
    index("blocks_blocked_idx").on(table.blockedId),
  ]
);

// Lighter than block: hides muted user's content from muter; muted user is unaware.
export const mutes = pgTable(
  "mutes",
  {
    muterId: uuid("muter_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    mutedId: uuid("muted_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    expiresAt: timestamp("expires_at"),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.muterId, table.mutedId] }),
  ]
);

// Reports include encrypted_evidence sealed to a moderation public key,
// because content at rest is E2E-encrypted and the server can't read it otherwise.
export const reports = pgTable(
  "reports",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    reporterId: uuid("reporter_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    targetType: text("target_type").notNull(), // post|comment|user
    targetId: uuid("target_id").notNull(),
    reason: text("reason").notNull(),          // harassment|sexual|violence|self_harm|spam|impersonation|other
    note: text("note"),                         // optional plaintext context from reporter
    encryptedEvidence: text("encrypted_evidence"), // sealed to moderation pubkey
    status: text("status").notNull().default("open"), // open|triaged|actioned|dismissed
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    index("reports_status_idx").on(table.status, table.createdAt),
    index("reports_target_idx").on(table.targetType, table.targetId),
  ]
);

// Per-recipient sealed content key for a comment. Server stores ciphertext;
// each viewer fetches their envelope and unseals on-device.
export const commentEnvelopes = pgTable(
  "comment_envelopes",
  {
    commentId: uuid("comment_id").notNull().references(() => comments.id, { onDelete: "cascade" }),
    recipientId: uuid("recipient_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    sealedKey: text("sealed_key").notNull(), // base64 sealed-box of the content key
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.commentId, table.recipientId] }),
    index("comment_envelopes_recipient_idx").on(table.recipientId),
  ]
);

// APNs device tokens. A user can have many — one per device they sign in on.
export const apnsTokens = pgTable(
  "apns_tokens",
  {
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    token: text("token").notNull(),
    deviceId: text("device_id").notNull(),
    environment: text("environment").notNull().default("production"), // production|sandbox
    createdAt: timestamp("created_at").defaultNow().notNull(),
    lastSeenAt: timestamp("last_seen_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.userId, table.deviceId] }),
    index("apns_tokens_user_idx").on(table.userId),
  ]
);

// Ephemeral stories — visible to the author's followers for 24h.
// Same audience model as posts (author's followers); same E2E pattern as comments
// (per-recipient sealed key envelope). expiresAt is set client-side or in the
// route to createdAt + 24h.
export const stories = pgTable(
  "stories",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    encryptedContent: text("encrypted_content"),
    encryptedMediaUrl: text("encrypted_media_url"),
    encryptedMediaKey: text("encrypted_media_key"),
    mediaType: text("media_type").notNull().default("photo"), // photo|video — discriminator for the viewer
    trustLevel: text("trust_level").notNull().default("verified"),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    expiresAt: timestamp("expires_at").notNull(),
  },
  (table) => [
    index("stories_user_idx").on(table.userId, table.expiresAt),
    index("stories_active_idx").on(table.expiresAt),
  ]
);

export const storyEnvelopes = pgTable(
  "story_envelopes",
  {
    storyId: uuid("story_id").notNull().references(() => stories.id, { onDelete: "cascade" }),
    recipientId: uuid("recipient_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    sealedKey: text("sealed_key").notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.storyId, table.recipientId] }),
    index("story_envelopes_recipient_idx").on(table.recipientId),
  ]
);

export const storyViews = pgTable(
  "story_views",
  {
    storyId: uuid("story_id").notNull().references(() => stories.id, { onDelete: "cascade" }),
    viewerId: uuid("viewer_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    viewedAt: timestamp("viewed_at").defaultNow().notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.storyId, table.viewerId] }),
  ]
);

// 1-on-1 DM conversations. Participants stored in canonical order (smaller UUID
// as participantA) so we can enforce a single conversation per pair via UNIQUE.
// Mutual-friend gate is enforced at the route layer, not the schema.
export const conversations = pgTable(
  "conversations",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    participantA: uuid("participant_a").notNull().references(() => users.id, { onDelete: "cascade" }),
    participantB: uuid("participant_b").notNull().references(() => users.id, { onDelete: "cascade" }),
    lastMessageAt: timestamp("last_message_at"),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    uniqueIndex("conversations_pair_idx").on(table.participantA, table.participantB),
    index("conversations_a_idx").on(table.participantA, table.lastMessageAt),
    index("conversations_b_idx").on(table.participantB, table.lastMessageAt),
  ]
);

export const messages = pgTable(
  "messages",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    conversationId: uuid("conversation_id").notNull().references(() => conversations.id, { onDelete: "cascade" }),
    senderId: uuid("sender_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    ciphertext: text("ciphertext").notNull(),
    createdAt: timestamp("created_at").defaultNow().notNull(),
    readAt: timestamp("read_at"), // when the (1-on-1) recipient read it
  },
  (table) => [
    index("messages_convo_idx").on(table.conversationId, table.createdAt),
  ]
);

// Sealed content keys per message, one row per recipient who can decrypt
// (sender + receiver both get one). Same envelope pattern as comment_envelopes.
export const messageEnvelopes = pgTable(
  "message_envelopes",
  {
    messageId: uuid("message_id").notNull().references(() => messages.id, { onDelete: "cascade" }),
    recipientId: uuid("recipient_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    sealedKey: text("sealed_key").notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.messageId, table.recipientId] }),
    index("message_envelopes_recipient_idx").on(table.recipientId),
  ]
);

// Recipient-centric activity log: one row per "thing that happened to you".
// Written from reaction/comment/follow paths alongside push dispatch, so the
// in-app bell can hydrate from a single table with cheap pagination.
export const activities = pgTable(
  "activities",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    recipientId: uuid("recipient_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    actorId: uuid("actor_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    kind: text("kind").notNull(), // reaction|comment|follow
    postId: uuid("post_id"),
    commentId: uuid("comment_id"),
    reactionKind: text("reaction_kind"),
    readAt: timestamp("read_at"),
    createdAt: timestamp("created_at").defaultNow().notNull(),
  },
  (table) => [
    index("activities_recipient_idx").on(table.recipientId, table.createdAt),
    index("activities_recipient_unread_idx").on(table.recipientId, table.readAt),
  ]
);

export const moderationActions = pgTable("moderation_actions", {
  id: uuid("id").defaultRandom().primaryKey(),
  reportId: uuid("report_id").references(() => reports.id),
  targetType: text("target_type").notNull(), // post|comment|user
  targetId: uuid("target_id").notNull(),
  action: text("action").notNull(),          // hide|remove|warn|suspend|ban|dismiss
  moderatorId: uuid("moderator_id"),         // not FK to users — moderators may not be app users
  reason: text("reason"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

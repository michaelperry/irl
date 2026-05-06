CREATE TABLE "apns_tokens" (
	"user_id" uuid NOT NULL,
	"token" text NOT NULL,
	"device_id" text NOT NULL,
	"environment" text DEFAULT 'production' NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"last_seen_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "apns_tokens_user_id_device_id_pk" PRIMARY KEY("user_id","device_id")
);
--> statement-breakpoint
CREATE TABLE "comment_envelopes" (
	"comment_id" uuid NOT NULL,
	"recipient_id" uuid NOT NULL,
	"sealed_key" text NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "comment_envelopes_comment_id_recipient_id_pk" PRIMARY KEY("comment_id","recipient_id")
);
--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "encryption_public_key" text;--> statement-breakpoint
ALTER TABLE "apns_tokens" ADD CONSTRAINT "apns_tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "comment_envelopes" ADD CONSTRAINT "comment_envelopes_comment_id_comments_id_fk" FOREIGN KEY ("comment_id") REFERENCES "public"."comments"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "comment_envelopes" ADD CONSTRAINT "comment_envelopes_recipient_id_users_id_fk" FOREIGN KEY ("recipient_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "apns_tokens_user_idx" ON "apns_tokens" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "comment_envelopes_recipient_idx" ON "comment_envelopes" USING btree ("recipient_id");
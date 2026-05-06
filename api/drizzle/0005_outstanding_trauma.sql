CREATE TABLE "conversations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"participant_a" uuid NOT NULL,
	"participant_b" uuid NOT NULL,
	"last_message_at" timestamp,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "message_envelopes" (
	"message_id" uuid NOT NULL,
	"recipient_id" uuid NOT NULL,
	"sealed_key" text NOT NULL,
	CONSTRAINT "message_envelopes_message_id_recipient_id_pk" PRIMARY KEY("message_id","recipient_id")
);
--> statement-breakpoint
CREATE TABLE "messages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"conversation_id" uuid NOT NULL,
	"sender_id" uuid NOT NULL,
	"ciphertext" text NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"read_at" timestamp
);
--> statement-breakpoint
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_participant_a_users_id_fk" FOREIGN KEY ("participant_a") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "conversations" ADD CONSTRAINT "conversations_participant_b_users_id_fk" FOREIGN KEY ("participant_b") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "message_envelopes" ADD CONSTRAINT "message_envelopes_message_id_messages_id_fk" FOREIGN KEY ("message_id") REFERENCES "public"."messages"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "message_envelopes" ADD CONSTRAINT "message_envelopes_recipient_id_users_id_fk" FOREIGN KEY ("recipient_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "messages" ADD CONSTRAINT "messages_conversation_id_conversations_id_fk" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "messages" ADD CONSTRAINT "messages_sender_id_users_id_fk" FOREIGN KEY ("sender_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "conversations_pair_idx" ON "conversations" USING btree ("participant_a","participant_b");--> statement-breakpoint
CREATE INDEX "conversations_a_idx" ON "conversations" USING btree ("participant_a","last_message_at");--> statement-breakpoint
CREATE INDEX "conversations_b_idx" ON "conversations" USING btree ("participant_b","last_message_at");--> statement-breakpoint
CREATE INDEX "message_envelopes_recipient_idx" ON "message_envelopes" USING btree ("recipient_id");--> statement-breakpoint
CREATE INDEX "messages_convo_idx" ON "messages" USING btree ("conversation_id","created_at");
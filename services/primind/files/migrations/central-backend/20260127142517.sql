-- Create "user_period_settings" table
CREATE TABLE "public"."user_period_settings" (
  "user_id" uuid NOT NULL,
  "periods" jsonb NOT NULL DEFAULT '{}',
  "created_at" timestamptz NOT NULL,
  "updated_at" timestamptz NOT NULL,
  PRIMARY KEY ("user_id")
);

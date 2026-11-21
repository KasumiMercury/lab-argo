-- Create "devices" table
CREATE TABLE "public"."devices" (
  "id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "session_token" text NULL,
  "timezone" character varying(100) NOT NULL,
  "locale" character varying(20) NOT NULL,
  "platform" character varying(20) NOT NULL,
  "fcm_token" text NULL,
  "user_agent" text NOT NULL,
  "accept_language" character varying(500) NULL,
  "created_at" timestamptz NOT NULL,
  "updated_at" timestamptz NOT NULL,
  PRIMARY KEY ("id")
);
-- Create index "idx_devices_session_token" to table: "devices"
CREATE INDEX "idx_devices_session_token" ON "public"."devices" ("session_token");
-- Create index "idx_devices_user_id" to table: "devices"
CREATE INDEX "idx_devices_user_id" ON "public"."devices" ("user_id");

-- Create "reminds" table
CREATE TABLE "public"."reminds" (
  "id" uuid NOT NULL,
  "time" timestamptz NOT NULL,
  "user_id" uuid NOT NULL,
  "devices" jsonb NOT NULL,
  "task_id" uuid NOT NULL,
  "task_type" character varying(255) NOT NULL,
  "throttled" boolean NOT NULL DEFAULT false,
  "created_at" timestamptz NOT NULL,
  "updated_at" timestamptz NOT NULL,
  PRIMARY KEY ("id")
);
-- Create index "idx_reminds_task_id_time" to table: "reminds"
CREATE UNIQUE INDEX "idx_reminds_task_id_time" ON "public"."reminds" ("time", "task_id");
-- Create index "idx_reminds_throttled" to table: "reminds"
CREATE INDEX "idx_reminds_throttled" ON "public"."reminds" ("throttled");
-- Create index "idx_reminds_time" to table: "reminds"
CREATE INDEX "idx_reminds_time" ON "public"."reminds" ("time");
-- Create index "idx_reminds_user_id" to table: "reminds"
CREATE INDEX "idx_reminds_user_id" ON "public"."reminds" ("user_id");

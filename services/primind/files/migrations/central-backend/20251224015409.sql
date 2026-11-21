-- Create "completed_tasks" table
CREATE TABLE "public"."completed_tasks" (
  "id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "title" character varying(500) NOT NULL,
  "task_type" character varying(50) NOT NULL,
  "description" text NULL,
  "scheduled_at" timestamptz NULL,
  "created_at" timestamptz NOT NULL,
  "target_at" timestamptz NOT NULL,
  "color" character varying(7) NOT NULL,
  "completed_at" timestamptz NOT NULL,
  PRIMARY KEY ("id")
);
-- Create index "idx_completed_tasks_completed_at" to table: "completed_tasks"
CREATE INDEX "idx_completed_tasks_completed_at" ON "public"."completed_tasks" ("completed_at");
-- Create index "idx_completed_tasks_user_id" to table: "completed_tasks"
CREATE INDEX "idx_completed_tasks_user_id" ON "public"."completed_tasks" ("user_id");

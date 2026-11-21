-- Create "tasks" table
CREATE TABLE "public"."tasks" (
  "id" uuid NOT NULL,
  "user_id" uuid NOT NULL,
  "title" character varying(500) NOT NULL,
  "task_type" character varying(50) NOT NULL,
  "task_status" character varying(50) NOT NULL,
  "description" text NULL,
  "due_time" timestamptz NULL,
  "created_at" timestamptz NOT NULL,
  PRIMARY KEY ("id")
);
-- Create index "idx_tasks_task_status" to table: "tasks"
CREATE INDEX "idx_tasks_task_status" ON "public"."tasks" ("task_status");
-- Create index "idx_tasks_task_type" to table: "tasks"
CREATE INDEX "idx_tasks_task_type" ON "public"."tasks" ("task_type");
-- Create index "idx_tasks_user_id" to table: "tasks"
CREATE INDEX "idx_tasks_user_id" ON "public"."tasks" ("user_id");

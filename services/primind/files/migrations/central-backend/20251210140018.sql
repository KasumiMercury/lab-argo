-- Modify "tasks" table
ALTER TABLE "public"."tasks" ADD COLUMN "target_at" timestamptz NOT NULL;
-- Create index "idx_tasks_target_at" to table: "tasks"
CREATE INDEX "idx_tasks_target_at" ON "public"."tasks" ("target_at");

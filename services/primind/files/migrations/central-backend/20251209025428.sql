-- Rename a column from "due_time" to "scheduled_at"
ALTER TABLE "public"."tasks" RENAME COLUMN "due_time" TO "scheduled_at";

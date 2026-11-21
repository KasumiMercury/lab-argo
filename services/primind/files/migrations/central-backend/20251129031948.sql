-- Create "auth_users" table
CREATE TABLE "public"."auth_users" (
  "id" uuid NOT NULL,
  "color" character varying(7) NOT NULL,
  "created_at" timestamptz NOT NULL,
  PRIMARY KEY ("id")
);
-- Create "auth_oidc_identities" table
CREATE TABLE "public"."auth_oidc_identities" (
  "user_id" uuid NOT NULL,
  "provider" text NOT NULL,
  "subject" text NOT NULL,
  "created_at" timestamptz NOT NULL,
  PRIMARY KEY ("provider", "subject"),
  CONSTRAINT "fk_auth_oidc_identities_user" FOREIGN KEY ("user_id") REFERENCES "public"."auth_users" ("id") ON UPDATE CASCADE ON DELETE CASCADE
);
-- Create index "idx_auth_oidc_identities_user_id" to table: "auth_oidc_identities"
CREATE INDEX "idx_auth_oidc_identities_user_id" ON "public"."auth_oidc_identities" ("user_id");

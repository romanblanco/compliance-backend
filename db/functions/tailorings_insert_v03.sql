CREATE OR REPLACE FUNCTION tailorings_insert() RETURNS trigger LANGUAGE plpgsql AS
$func$
DECLARE result_id uuid;
BEGIN

INSERT INTO "profiles" (
  "name",
  "ref_id",
  "policy_id",
  "account_id",
  "parent_profile_id",
  "benchmark_id",
  "os_minor_version",
  "value_overrides",
  "created_at",
  "updated_at"
) SELECT
  "canonical_profiles"."title",
  "canonical_profiles"."ref_id",
  NEW."policy_id",
  "policies"."account_id",
  NEW."profile_id",
  "canonical_profiles"."security_guide_id",
  NEW."os_minor_version",
  NEW."value_overrides",
  NEW."created_at",
  NEW."updated_at"
FROM "policies"
INNER JOIN "canonical_profiles" ON "canonical_profiles"."id" = "policies"."profile_id"
WHERE "policies"."id" = NEW."policy_id" RETURNING "id" INTO "result_id";

NEW."id" := "result_id";
RETURN NEW;

END
$func$;

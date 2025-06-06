--
-- Intializes a Cyndi-like inventory schema and creates a view copied from a
-- local inventory DB
--

CREATE SCHEMA IF NOT EXISTS inventory;

CREATE EXTENSION IF NOT EXISTS dblink;

-- This view should be queried instead
CREATE OR REPLACE VIEW inventory.hosts AS
SELECT
    id,
    account,
    org_id,
    display_name,
    created_on as created,
    modified_on as updated,
    stale_timestamp,
    stale_timestamp + INTERVAL '1' DAY * 7 AS stale_warning_timestamp,
    stale_timestamp + INTERVAL '1' DAY * 14 AS culled_timestamp,
    stale_timestamp + INTERVAL '1' DAY * 8 AS last_check_in,
    tags,
    system_profile_facts as system_profile,
    groups,
    canonical_facts->'insights_id' as insights_id
FROM dblink('dbname=insights user=insights', 'select id, account, org_id, display_name, created_on, modified_on, stale_timestamp, tags, system_profile_facts, groups, canonical_facts from hbi.hosts') as hosts(
    id uuid,
    account character varying(10),
    org_id character varying(10),
    display_name character varying(200),
    created_on timestamp with time zone,
    modified_on timestamp with time zone,
    stale_timestamp timestamp with time zone,
    tags jsonb,
    system_profile_facts jsonb,
    groups jsonb,
    canonical_facts jsonb
);

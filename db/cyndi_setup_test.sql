--
-- Intializes a Cyndi-like inventory schema and seeds it with sample data.
-- This script is intended to be used an extended for local development of applications against inventory schema.
-- Copied from https://github.com/RedHatInsights/inventory-syndication/blob/master/utils/seed-local.sql
--

CREATE SCHEMA IF NOT EXISTS inventory;

-- This table should never be queried direcly
DROP TABLE IF EXISTS inventory.hosts_v1_1 CASCADE;

CREATE TABLE inventory.hosts_v1_1 (
    id uuid PRIMARY KEY,
    account character varying(10),
    org_id character varying(10) NOT NULL,
    display_name character varying(200) NOT NULL,
    tags jsonb NOT NULL,
    updated timestamp with time zone NOT NULL,
    created timestamp with time zone NOT NULL,
    stale_timestamp timestamp with time zone NOT NULL,
    system_profile jsonb NOT NULL,
    groups jsonb,
    insights_id uuid
);

-- This view should be queried instead
CREATE OR REPLACE VIEW inventory.hosts AS
SELECT
    id,
    account,
    org_id,
    display_name,
    created,
    updated,
    stale_timestamp,
    stale_timestamp + INTERVAL '1' DAY * 7 AS stale_warning_timestamp,
    stale_timestamp + INTERVAL '1' DAY * 14 AS culled_timestamp,
    stale_timestamp + INTERVAL '1' DAY * 8 AS last_check_in,
    tags,
    system_profile,
    groups,
    insights_id
FROM inventory.hosts_v1_1;

-- INSTEAD OF INSERT trigger so the view is writable from tests
CREATE OR REPLACE FUNCTION inventory.hosts_insert_fn()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO inventory.hosts_v1_1
    (id, account, org_id, display_name, tags, updated, created, stale_timestamp, system_profile, groups, insights_id)
  VALUES
    (NEW.id, NEW.account, NEW.org_id, NEW.display_name, NEW.tags, NEW.updated, NEW.created, NEW.stale_timestamp, NEW.system_profile, NEW.groups, NEW.insights_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS hosts_insert_trigger ON inventory.hosts;
CREATE TRIGGER hosts_insert_trigger
  INSTEAD OF INSERT ON inventory.hosts
  FOR EACH ROW EXECUTE FUNCTION inventory.hosts_insert_fn();

--
-- Clear any existing host seeds
--
TRUNCATE inventory.hosts_v1_1;

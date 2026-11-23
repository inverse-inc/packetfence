-- Tables of the Upstream Fingerbank database used by the tests
-- (schema taken from fingerbank_Upstream.db)
CREATE TABLE IF NOT EXISTS "device" (
  "id" int NOT NULL ,
  "name" varchar(255) DEFAULT NULL,
  "mobile" tinyint(1) DEFAULT NULL,
  "tablet" tinyint(1) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  "parent_id" int DEFAULT NULL,
  "inherit" tinyint(1) DEFAULT NULL,
  "submitter_id" int DEFAULT NULL,
  "approved" tinyint(1) DEFAULT '1',
  "devices_count" int DEFAULT '0',
  "details" varchar(1000) DEFAULT NULL,
  "updated_by_id" int DEFAULT NULL,
  "virtual_parent_id" int DEFAULT NULL,
  "virtual_devices_count" int DEFAULT '0',
  "simplified_name" varchar(255) DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE TABLE IF NOT EXISTS "dhcp_fingerprint" (
  "id" int NOT NULL ,
  "value" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  "ignored" tinyint(1) DEFAULT '0',
  PRIMARY KEY ("id")
);
CREATE INDEX "dhcp_fingerprints_index_dhcp_fingerprints_on_value" ON "dhcp_fingerprint" ("value");
CREATE TABLE IF NOT EXISTS "dhcp_vendor" (
  "id" int NOT NULL ,
  "value" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "dhcp_vendors_index_dhcp_vendors_on_value" ON "dhcp_vendor" ("value");
CREATE TABLE IF NOT EXISTS "dhcp6_fingerprint" (
  "id" int NOT NULL ,
  "value" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "dhcp6_fingerprints_index_dhcp6_fingerprints_on_value" ON "dhcp6_fingerprint" ("value");
CREATE TABLE IF NOT EXISTS "dhcp6_enterprise" (
  "id" int NOT NULL ,
  "value" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  "organization" varchar(255) DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "dhcp6_enterprises_index_dhcp6_enterprises_on_value" ON "dhcp6_enterprise" ("value");
CREATE TABLE IF NOT EXISTS "mac_vendor" (
  "id" int NOT NULL ,
  "name" varchar(255) DEFAULT NULL,
  "mac" varchar(255) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  "device_id" int DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "mac_vendors_index_mac_vendors_on_mac" ON "mac_vendor" ("mac");
CREATE TABLE IF NOT EXISTS "user_agent" (
  "id" int NOT NULL ,
  "value" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "user_agents_index_user_agents_on_value" ON "user_agent" ("value");

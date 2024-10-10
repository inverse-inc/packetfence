CREATE TABLE "dhcp6_fingerprint" (
  "id" varchar(11) NOT NULL,
  "value" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE "dhcp6_enterprise" (
  "id" varchar(11) NOT NULL,
  "value" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  PRIMARY KEY ("id")
);

ALTER TABLE "combination" RENAME TO "combination_temp";
CREATE TABLE "combination" (
  "id" varchar(11) NOT NULL,
  "dhcp_fingerprint_id" varchar(11) DEFAULT '',
  "user_agent_id" varchar(11) DEFAULT '',
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  "device_id" varchar(11) DEFAULT NULL,
  "version" varchar(255) DEFAULT NULL,
  "dhcp_vendor_id" varchar(11) DEFAULT '',
  "score" int(11) DEFAULT '0',
  "mac_vendor_id" varchar(11) DEFAULT '',
  "submitter_id" int(11) DEFAULT NULL,
  PRIMARY KEY ("id")
);
INSERT INTO "combination" SELECT * FROM "combination_temp";
DROP TABLE "combination_temp";
UPDATE "combination" SET "dhcp_fingerprint_id" = '' WHERE "dhcp_fingerprint_id" IS NULL;
UPDATE "combination" SET "user_agent_id" = '' WHERE "user_agent_id" IS NULL;
UPDATE "combination" SET "dhcp_vendor_id" = '' WHERE "dhcp_vendor_id" IS NULL;
UPDATE "combination" SET "mac_vendor_id" = '' WHERE "mac_vendor_id" IS NULL;

ALTER TABLE "combination" ADD COLUMN "dhcp6_fingerprint_id" varchar(11) DEFAULT '';
ALTER TABLE "combination" ADD COLUMN "dhcp6_enterprise_id" varchar(11) DEFAULT '';

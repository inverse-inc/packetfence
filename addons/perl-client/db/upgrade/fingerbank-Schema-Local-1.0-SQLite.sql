CREATE TABLE "combination" (
  "id" varchar(11) NOT NULL,
  "dhcp_fingerprint_id" varchar(11) DEFAULT NULL,
  "user_agent_id" varchar(11) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  "device_id" varchar(11) DEFAULT NULL,
  "version" varchar(255) DEFAULT NULL,
  "dhcp_vendor_id" varchar(11) DEFAULT NULL,
  "score" int(11) DEFAULT '0',
  "mac_vendor_id" varchar(11) DEFAULT NULL,
  "submitter_id" int(11) DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE TABLE "device" (
  "id" varchar(11) NOT NULL,
  "name" varchar(255) DEFAULT NULL,
  "mobile" tinyint(1) DEFAULT NULL,
  "tablet" tinyint(1) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  "parent_id" varchar(11) DEFAULT NULL,
  "inherit" tinyint(1) DEFAULT NULL,
  "submitter_id" int(11) DEFAULT NULL,
  "approved" tinyint(1) DEFAULT '1',
  PRIMARY KEY ("id")
);
CREATE TABLE "dhcp_fingerprint" (
  "id" varchar(11) NOT NULL,
  "value" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE TABLE "dhcp_vendor" (
  "id" varchar(11) NOT NULL,
  "value" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE TABLE "mac_vendor" (
  "id" varchar(11) NOT NULL,
  "name" varchar(255) DEFAULT NULL,
  "mac" varchar(255) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE TABLE "tables_ids" (
  "combination" int(11) NOT NULL,
  "device" int(11) NOT NULL,
  "dhcp_fingerprint" int(11) NOT NULL,
  "dhcp_vendor" int(11) NOT NULL,
  "mac_vendor" int(11) NOT NULL,
  "user_agent" int(11) NOT NULL
);
CREATE TABLE "unmatched" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "type" varchar(255) NOT NULL,
  "value" varchar(1000) DEFAULT NULL,
  "occurence" int(11) DEFAULT 1,
  "submitted" tinyint(1) DEFAULT 0,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL
);
CREATE TABLE "user_agent" (
  "id" varchar(11) NOT NULL,
  "value" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  PRIMARY KEY ("id")
);
CREATE TABLE "users" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "username" varchar(255) NOT NULL,
  "password" varchar(255) NOT NULL,
  "encryption" varchar(255) NOT NULL DEFAULT "plain",
  "firstname" varchar(255) DEFAULT NULL,
  "lastname" varchar(255) DEFAULT NULL,
  "email" varchar(255) DEFAULT NULL,
  "notes" varchar(1000) DEFAULT NULL,
  "created_at" datetime DEFAULT NULL,
  "updated_at" datetime DEFAULT NULL,
  "created_by" varchar(255) DEFAULT NULL
);
CREATE INDEX "mac_vendors_index_mac_vendors_on_mac" ON "mac_vendor" ("mac");

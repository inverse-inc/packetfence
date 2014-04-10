---
--- Add a column to store the time balance of a node
---

ALTER TABLE node ADD `time_balance` int unsigned AFTER `lastskip`;

---
--- Add a column to store the bandwidth balance of a node
---

ALTER TABLE node ADD `bandwidth_balance` int unsigned AFTER `time_balance`;

--
-- Added a new column to keep the audit-session-id from the radius request to use with the CoA
--

ALTER TABLE `node` ADD `sessionid` varchar(30) default NULL AFTER autoreg;

--
-- Added a new columns to store in person field
--

ALTER TABLE person 
  ADD `anniversary` varchar(255) NULL DEFAULT NULL,
  ADD `birthday` varchar(255) NULL DEFAULT NULL,
  ADD `gender` char(1) NULL DEFAULT NULL,
  ADD `lang` varchar(255) NULL DEFAULT NULL,
  ADD `nickname` varchar(255) NULL DEFAULT NULL,
  ADD `cell_phone` varchar(255) NULL DEFAULT NULL,
  ADD `work_phone` varchar(255) NULL DEFAULT NULL,
  ADD `title` varchar(255) NULL DEFAULT NULL,
  ADD `building_number` varchar(255) NULL DEFAULT NULL,
  ADD `apartment_number` varchar(255) NULL DEFAULT NULL,
  ADD `room_number` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_1` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_2` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_3` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_4` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_5` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_6` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_7` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_8` varchar(255) NULL DEFAULT NULL,
  ADD `custom_field_9` varchar(255) NULL DEFAULT NULL
;

--
-- Added a new table inline_accounting
--

CREATE TABLE inline_accounting (
   outbytes bigint unsigned NOT NULL DEFAULT '0' COMMENT 'orig_raw_pktlen',
   inbytes bigint unsigned NOT NULL DEFAULT '0' COMMENT 'reply_raw_pktlen',
   ip varchar(16) NOT NULL,
   firstseen DATETIME NOT NULL,
   lastmodified DATETIME NOT NULL,
   status int unsigned NOT NULL default 0,
   PRIMARY KEY (ip, firstseen),
   INDEX (ip)
 ) ENGINE=InnoDB;

--
-- Added a new column config_timestamp
---

ALTER TABLE radius_nas 
  ADD config_timestamp BIGINT AFTER description,
  DROP PRIMARY KEY,
  DROP COLUMN id,
  ADD PRIMARY KEY (nasname)
;

--
-- Alter for dynamic controller
--

ALTER TABLE locationlog 
    ADD `switch_ip` varchar(17) DEFAULT NULL,
    ADD `switch_mac` varchar(17) DEFAULT NULL;

UPDATE locationlog SET switch_ip = switch;


--
-- Add a column to store the time balance of a node
--

ALTER TABLE node ADD `time_balance` int unsigned AFTER `lastskip`;

--
-- Add a column to store the bandwidth balance of a node
--

ALTER TABLE node ADD `bandwidth_balance` int unsigned AFTER `time_balance`;

--
-- Add a new column to keep the audit-session-id from the RADIUS request to use with the CoA
--

ALTER TABLE node ADD `sessionid` varchar(30) default NULL AFTER `autoreg`;

--
-- Add new columns to store various information related to a person
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
-- Add a new table for inline accounting
--

CREATE TABLE inline_accounting (
    `outbytes` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'orig_raw_pktlen',
    `inbytes` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'reply_raw_pktlen',
    `ip` varchar(16) NOT NULL,
    `firstseen` DATETIME NOT NULL,
    `lastmodified` DATETIME NOT NULL,
    `status` int unsigned NOT NULL default 0,
    PRIMARY KEY (ip, firstseen),
    INDEX (ip)
) ENGINE=InnoDB;

--
-- Added a new column config_timestamp for RADIUS NAS
--

ALTER TABLE radius_nas 
    ADD config_timestamp BIGINT AFTER description,
    DROP PRIMARY KEY,
    DROP COLUMN id,
    ADD PRIMARY KEY (nasname)
;

--
-- Table structure for wrix
--

CREATE TABLE wrix (
  id varchar(255) NOT NULL,
  `Provider_Identifier` varchar(255) NULL DEFAULT NULL,
  `Location_Identifier` varchar(255) NULL DEFAULT NULL,
  `Service_Provider_Brand` varchar(255) NULL DEFAULT NULL,
  `Location_Type` varchar(255) NULL DEFAULT NULL,
  `Sub_Location_Type` varchar(255) NULL DEFAULT NULL,
  `English_Location_Name` varchar(255) NULL DEFAULT NULL,
  `Location_Address1` varchar(255) NULL DEFAULT NULL,
  `Location_Address2` varchar(255) NULL DEFAULT NULL,
  `English_Location_City` varchar(255) NULL DEFAULT NULL,
  `Location_Zip_Postal_Code` varchar(255) NULL DEFAULT NULL,
  `Location_State_Province_Name` varchar(255) NULL DEFAULT NULL,
  `Location_Country_Name` varchar(255) NULL DEFAULT NULL,
  `Location_Phone_Number` varchar(255) NULL DEFAULT NULL,
  `SSID_Open_Auth` varchar(255) NULL DEFAULT NULL,
  `SSID_Broadcasted` varchar(255) NULL DEFAULT NULL,
  `WEP_Key` varchar(255) NULL DEFAULT NULL,
  `WEP_Key_Entry_Method` varchar(255) NULL DEFAULT NULL,
  `WEP_Key_Size` varchar(255) NULL DEFAULT NULL,
  `SSID_1X` varchar(255) NULL DEFAULT NULL,
  `SSID_1X_Broadcasted` varchar(255) NULL DEFAULT NULL,
  `Security_Protocol_1X` varchar(255) NULL DEFAULT NULL,
  `Client_Support` varchar(255) NULL DEFAULT NULL,
  `Restricted_Access` varchar(255) NULL DEFAULT NULL,
  `Location_URL` varchar(255) NULL DEFAULT NULL,
  `Coverage_Area` varchar(255) NULL DEFAULT NULL,
  `Open_Monday` varchar(255) NULL DEFAULT NULL,
  `Open_Tuesday` varchar(255) NULL DEFAULT NULL,
  `Open_Wednesday` varchar(255) NULL DEFAULT NULL,
  `Open_Thursday` varchar(255) NULL DEFAULT NULL,
  `Open_Friday` varchar(255) NULL DEFAULT NULL,
  `Open_Saturday` varchar(255) NULL DEFAULT NULL,
  `Open_Sunday` varchar(255) NULL DEFAULT NULL,
  `Longitude` varchar(255) NULL DEFAULT NULL,
  `Latitude` varchar(255) NULL DEFAULT NULL,
  `UTC_Timezone` varchar(255) NULL DEFAULT NULL,
  `MAC_Address` varchar(255) NULL DEFAULT NULL,
   PRIMARY KEY (id)
) ENGINE=InnoDB;

--
-- Alter for dynamic controller
--

ALTER TABLE locationlog
    ADD `switch_ip` varchar(17) DEFAULT NULL,
    ADD `switch_mac` varchar(17) DEFAULT NULL;

UPDATE locationlog SET switch_ip = switch;

--
-- Add column to locationlog_history table
--
ALTER TABLE locationlog_history ADD `switch_ip` varchar(17) default NULL;
ALTER TABLE locationlog_history ADD `switch_mac` varchar(17) default NULL;

UPDATE locationlog_history SET switch_ip = switch;

--
-- PacketFence SQL schema upgrade from 6.5.0 to 7.0.0
--

--
-- Add a primary key to the radacct_log
--

ALTER TABLE `radacct_log` ADD COLUMN `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the iplog_history
--

ALTER TABLE `iplog_history` ADD COLUMN `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the iplog_archive
--

ALTER TABLE `iplog_archive` ADD COLUMN `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the locationlog
--

ALTER TABLE `locationlog` ADD COLUMN `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the locationlog_archive
--

ALTER TABLE `locationlog_archive` ADD COLUMN `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Table structure for table `ip4log`
--

RENAME TABLE iplog TO ip4log;

ALTER TABLE ip4log
    DROP INDEX iplog_mac_end_time, ADD INDEX ip4log_mac_end_time (mac,end_time),
    DROP INDEX iplog_end_time, ADD INDEX ip4log_end_time (end_time);

--
-- Trigger to insert old record from 'ip4log' in 'ip4log_history' before updating the current one
--

DROP TRIGGER IF EXISTS iplog_insert_in_iplog_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER ip4log_insert_in_ip4log_history_before_update_trigger BEFORE UPDATE ON ip4log
FOR EACH ROW
BEGIN
  INSERT INTO ip4log_history SET ip = OLD.ip, mac = OLD.mac, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

--
-- Table structure for table `ip4log_history`
--

RENAME TABLE iplog_history TO ip4log_history;

ALTER TABLE ip4log_history
    DROP INDEX iplog_history_mac_end_time, ADD INDEX ip4log_history_mac_end_time (mac,end_time);

--
-- Table structure for table `ip4log_archive`
--

RENAME TABLE iplog_archive TO ip4log_archive;

--
-- Table structure for table `ip6log`
--

CREATE TABLE ip6log (
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  type varchar(32) DEFAULT NULL,
  start_time datetime NOT NULL,
  end_time datetime default "0000-00-00 00:00:00",
  PRIMARY KEY (ip),
  KEY ip6log_mac_end_time (mac,end_time),
  KEY ip6log_end_time (end_time)
) ENGINE=InnoDB;

--
-- Trigger to insert old record from 'ip6log' in 'ip6log_history' before updating the current one
--

DROP TRIGGER IF EXISTS ip6log_insert_in_ip6log_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER ip6log_insert_in_ip6log_history_before_update_trigger BEFORE UPDATE ON ip6log
FOR EACH ROW
BEGIN
  INSERT INTO ip6log_history SET ip = OLD.ip, mac = OLD.mac, type = OLD.type, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

--
-- Table structure for table `ip6log_history`
--

CREATE TABLE ip6log_history (
  id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  type varchar(32) DEFAULT NULL,
  start_time datetime NOT NULL,
  end_time datetime NOT NULL,
  KEY ip6log_history_mac_end_time (mac,end_time),
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB;

--
-- Table structure for table `ip6log_archive`
--

CREATE TABLE ip6log_archive (
  id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  type varchar(32) DEFAULT NULL,
  start_time datetime NOT NULL,
  end_time datetime NOT NULL,
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB;

--
-- Creating chi_cache table
--

CREATE TABLE `chi_cache` (
  `key` VARCHAR(767),
  `value` LONGBLOB,
  `expires_at` REAL,
  PRIMARY KEY (`key`),
  KEY chi_cache_expires_at (expires_at)
);

--
-- Add last_seen column to node table
--

ALTER TABLE node ADD last_seen DATETIME NOT NULL DEFAULT "0000-00-00 00:00:00";

ALTER TABLE node ADD INDEX node_last_seen (last_seen);

--
-- Add ifDesc to locationlog and locationlog_archive
--

ALTER table locationlog ADD column ifDesc VARCHAR(255) DEFAULT NULL;

ALTER table locationlog_archive ADD column ifDesc VARCHAR(255) DEFAULT NULL;

--
-- Add unicity index to node_category.name
--
ALTER TABLE node_category ADD UNIQUE INDEX node_category_name (name);

--
-- Change acct_update procedure
--

DROP PROCEDURE IF EXISTS acct_update;
DELIMITER /
CREATE PROCEDURE acct_update(
  IN p_timestamp datetime,
  IN p_framedipaddress varchar(15),
  IN p_acctsessiontime int(12),
  IN p_acctinputoctets bigint(20),
  IN p_acctoutputoctets bigint(20),
  IN p_acctuniqueid varchar(32),
  IN p_acctsessionid varchar(64),
  IN p_username varchar(64),
  IN p_realm varchar(64),
  IN p_nasipaddress varchar(15),
  IN p_nasportid varchar(32),
  IN p_nasporttype varchar(32),
  IN p_acctauthentic varchar(32),
  IN p_connectinfo_start varchar(50),
  IN p_calledstationid varchar(50),
  IN p_callingstationid varchar(50),
  IN p_servicetype varchar(32),
  IN p_framedprotocol varchar(32),
  IN p_acctstatustype varchar(25)
)
BEGIN
  DECLARE Previous_Input_Octets bigint(20);
  DECLARE Previous_Output_Octets bigint(20);
  DECLARE Previous_Session_Time int(12);
  DECLARE Previous_AcctUpdate_Time datetime;

  DECLARE Opened_Sessions int(12);
  DECLARE Latest_acctstarttime datetime;
  DECLARE cnt int(12);
  DECLARE countmac int(12);
  SELECT count(acctuniqueid), max(acctstarttime)
  INTO Opened_Sessions, Latest_acctstarttime
  FROM radacct
  WHERE acctuniqueid = p_acctuniqueid
  AND (acctstoptime IS NULL OR acctstoptime = 0);

  IF (Opened_Sessions > 1) THEN
      UPDATE radacct SET
        acctstoptime = NOW(),
        acctterminatecause = 'UNKNOWN'
        WHERE acctuniqueid = p_acctuniqueid
        AND acctstarttime < Latest_acctstarttime
        AND (acctstoptime IS NULL OR acctstoptime = 0);
  END IF;


  # Detect if we receive in the same time a stop before the interim update
  SELECT COUNT(*)
  INTO cnt
  FROM radacct
  WHERE acctuniqueid = p_acctuniqueid
  AND (acctstoptime = p_timestamp);

  # If there is an old closed entry then update it
  IF (cnt = 1) THEN
    UPDATE radacct SET
        framedipaddress = p_framedipaddress,
        acctsessiontime = p_acctsessiontime,
        acctinputoctets = p_acctinputoctets,
        acctoutputoctets = p_acctoutputoctets,
        acctupdatetime = p_timestamp
    WHERE acctuniqueid = p_acctuniqueid
    AND (acctstoptime = p_timestamp);
  END IF;

  #Detect if there is an radacct entry open
  SELECT count(callingstationid), acctinputoctets, acctoutputoctets, acctsessiontime, acctupdatetime
    INTO countmac, Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time, Previous_AcctUpdate_Time
    FROM radacct
    WHERE (acctuniqueid = p_acctuniqueid) 
    AND (acctstoptime IS NULL OR acctstoptime = 0) LIMIT 1;

  IF (countmac = 1) THEN
    # Update record with new traffic
    UPDATE radacct SET
        framedipaddress = p_framedipaddress,
        acctsessiontime = p_acctsessiontime,
        acctinputoctets = p_acctinputoctets,
        acctoutputoctets = p_acctoutputoctets,
        acctupdatetime = p_timestamp,
        acctinterval = timestampdiff( second, Previous_AcctUpdate_Time,  p_timestamp  )
    WHERE acctuniqueid = p_acctuniqueid 
    AND (acctstoptime IS NULL OR acctstoptime = 0);
  ELSE
    IF (cnt = 0) THEN
      # If there is no open session for this, open one.
      # Set values to 0 when no previous records
      SET Previous_Session_Time = 0;
      SET Previous_Input_Octets = 0;
      SET Previous_Output_Octets = 0;
      SET Previous_AcctUpdate_Time = p_timestamp;
      INSERT INTO radacct
             (
              acctsessionid,acctuniqueid,username,
              realm,nasipaddress,nasportid,
              nasporttype,acctstarttime,
              acctupdatetime,acctsessiontime,acctauthentic,
              connectinfo_start,acctinputoctets,
              acctoutputoctets,calledstationid,callingstationid,
              servicetype,framedprotocol,
              framedipaddress
             )
      VALUES
          (
              p_acctsessionid,p_acctuniqueid,p_username,
              p_realm,p_nasipaddress,p_nasportid,
              p_nasporttype,date_sub(p_timestamp, INTERVAL p_acctsessiontime SECOND ),
              p_timestamp,p_acctsessiontime,p_acctauthentic,
              p_connectinfo_start,p_acctinputoctets,
              p_acctoutputoctets,p_calledstationid,p_callingstationid,
              p_servicetype,p_framedprotocol,
              p_framedipaddress
          );
     END IF;
   END IF;

 
  # Create new record in the log table
  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime, acctuniqueid)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time), p_acctuniqueid);
END /
DELIMITER ;

DROP TABLE IF EXISTS traplog;
DROP TABLE IF EXISTS soh_filter_rules;
DROP TABLE IF EXISTS soh_filters;

--
-- Upgrade the schema version in the DB
--

SET @MAJOR_VERSION = 7;
SET @MINOR_VERSION = 0;
SET @SUBMINOR_VERSION = 0;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));



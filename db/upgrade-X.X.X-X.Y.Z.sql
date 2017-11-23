--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 7;
SET @MINOR_VERSION = 4;
SET @SUBMINOR_VERSION = 9;

SET @PREV_MAJOR_VERSION = 7;
SET @PREV_MINOR_VERSION = 4;
SET @PREV_SUBMINOR_VERSION = 0;


--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8 | @PREV_SUBMINOR_VERSION;

DROP PROCEDURE IF EXISTS ValidateVersion;
--
-- Updating to current version
--
DELIMITER //
CREATE PROCEDURE ValidateVersion()
BEGIN
    DECLARE PREVIOUS_VERSION int(11);
    DECLARE PREVIOUS_VERSION_STRING varchar(11);
    DECLARE _message varchar(255);
    SELECT id, version INTO PREVIOUS_VERSION, PREVIOUS_VERSION_STRING FROM pf_version ORDER BY id DESC LIMIT 1;

      IF PREVIOUS_VERSION != @PREV_VERSION_INT THEN
        SELECT CONCAT('PREVIOUS VERSION ', PREVIOUS_VERSION_STRING, ' DOES NOT MATCH ', CONCAT_WS('.', @PREV_MAJOR_VERSION, @PREV_MINOR_VERSION, @PREV_SUBMINOR_VERSION)) INTO _message;
        SIGNAL SQLSTATE VALUE '99999'
              SET MESSAGE_TEXT = _message;
      END IF;
END
//

DELIMITER ;
call ValidateVersion;

DROP TABLE IF EXISTS `ifoctetslog`;
DROP TABLE IF EXISTS `trigger`;

CREATE TABLE `tenant` (
  id int NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  portal_domain_name VARCHAR(255),
  PRIMARY KEY (id),
  UNIQUE KEY tenant_name (`name`),
  UNIQUE KEY tenant_portal_domain_name (`portal_domain_name`)
);

ALTER TABLE `violation`
    DROP FOREIGN KEY `0_60`;

ALTER TABLE `node`
    DROP FOREIGN KEY `0_57`;

INSERT INTO `tenant` (id, name, portal_domain_name) VALUES (1, 'default', NULL);

ALTER TABLE `userlog`
    DROP FOREIGN KEY `userlog_ibfk_1`;

ALTER TABLE `person`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 FIRST,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (`tenant_id`, `pid`),
    ADD CONSTRAINT `person_tenant_id` FOREIGN KEY (`tenant_id`) REFERENCES `tenant` (`id`);

ALTER TABLE `node`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 FIRST,
    DROP PRIMARY KEY,
    ADD  PRIMARY KEY (`tenant_id`, `mac`),
    ADD CONSTRAINT `0_57` FOREIGN KEY (`tenant_id`, `pid`) REFERENCES `person` (`tenant_id`, `pid`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `node_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`);

ALTER TABLE `password`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 FIRST;

ALTER TABLE `violation`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id,
    ADD CONSTRAINT `0_60` FOREIGN KEY (`tenant_id`, `mac`) REFERENCES `node` (`tenant_id`, `mac`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `violation_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`);

ALTER TABLE `userlog`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 FIRST,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (`tenant_id`, `mac`, `start_time`),
    ADD CONSTRAINT `userlog_ibfk_1` FOREIGN KEY (`tenant_id`, `mac`) REFERENCES `node` (`tenant_id`,`mac`) ON DELETE CASCADE;

ALTER TABLE `ip4log`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 FIRST,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (`tenant_id`, `ip`),
    ADD CONSTRAINT `ip4log_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`);

ALTER TABLE `ip4log_history`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;

ALTER TABLE `ip4log_archive`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;

ALTER TABLE `ip6log`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 FIRST,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (`tenant_id`, `ip`),
    ADD CONSTRAINT `ip6log_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`);

ALTER TABLE `ip6log_history`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;

ALTER TABLE `ip6log_archive`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;

ALTER TABLE `scan`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;

ALTER TABLE `activation`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER code_id;

ALTER TABLE `radius_audit_log`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;

ALTER TABLE `auth_log`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;

ALTER TABLE `inline_accounting`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER inbytes;

ALTER TABLE `locationlog`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;

ALTER TABLE `radacct`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER radacctid;

ALTER TABLE `radacct_log`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;

ALTER TABLE `radius_nas`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;

ALTER TABLE `locationlog_archive`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 AFTER id;
--
-- Trigger to insert old record from 'ip4log' in 'ip4log_history' before updating the current one
--

DROP TRIGGER IF EXISTS ip4log_insert_in_ip4log_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER ip4log_insert_in_ip4log_history_before_update_trigger BEFORE UPDATE ON ip4log
FOR EACH ROW
BEGIN
  INSERT INTO ip4log_history SET tenant_id = OLD.tenant_id, ip = OLD.ip, mac = OLD.mac, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

--
-- Trigger to insert old record from 'ip6log' in 'ip6log_history' before updating the current one
--

DROP TRIGGER IF EXISTS ip6log_insert_in_ip6log_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER ip6log_insert_in_ip6log_history_before_update_trigger BEFORE UPDATE ON ip6log
FOR EACH ROW
BEGIN
  INSERT INTO ip6log_history SET tenant_id = OLD.tenant_id, ip = OLD.ip, mac = OLD.mac, type = OLD.type, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

--
-- Trigger to delete the temp password from 'password' when deleting the pid associated with
--

DROP TRIGGER IF EXISTS password_delete_trigger;
DELIMITER /
CREATE TRIGGER password_delete_trigger AFTER DELETE ON person
FOR EACH ROW
BEGIN
  DELETE FROM `password` WHERE pid = OLD.pid AND tenant_id = OLD.tenant_id;
END /
DELIMITER ;

-- Adding RADIUS Updates Stored Procedure

DROP PROCEDURE IF EXISTS acct_start;
DELIMITER /
CREATE PROCEDURE acct_start (
    IN p_acctsessionid varchar(64),
    IN p_acctuniqueid varchar(32),
    IN p_username varchar(64),
    IN p_realm varchar(64),
    IN p_nasipaddress varchar(15),
    IN p_nasportid varchar(32),
    IN p_nasporttype varchar(32),
    IN p_acctstarttime datetime,
    IN p_acctupdatetime datetime,
    IN p_acctstoptime datetime,
    IN p_acctsessiontime int(12) unsigned,
    IN p_acctauthentic varchar(32),
    IN p_connectinfo_start varchar(50),
    IN p_connectinfo_stop varchar(50),
    IN p_acctinputoctets bigint(20),
    IN p_acctoutputoctets bigint(20),
    IN p_calledstationid varchar(50),
    IN p_callingstationid varchar(50),
    IN p_acctterminatecause varchar(32),
    IN p_servicetype varchar(32),
    IN p_framedprotocol varchar(32),
    IN p_framedipaddress varchar(15),
    IN p_acctstatustype varchar(25),
    IN p_tenant_id int
)
BEGIN

# We make sure there are no left over sessions for which we never received a "stop"
DECLARE Previous_Session_Time int(12);
SELECT acctsessiontime
INTO Previous_Session_Time
FROM radacct
WHERE acctuniqueid = p_acctuniqueid
AND (acctstoptime IS NULL OR acctstoptime = 0) LIMIT 1;

IF (Previous_Session_Time IS NOT NULL) THEN
    UPDATE radacct SET
      acctstoptime = p_acctstarttime,
      acctterminatecause = 'UNKNOWN'
      WHERE acctuniqueid = p_acctuniqueid
      AND (acctstoptime IS NULL OR acctstoptime = 0);
END IF;

INSERT INTO radacct 
           (
            acctsessionid,      acctuniqueid,       username, 
            realm,          nasipaddress,       nasportid, 
            nasporttype,        acctstarttime,      acctupdatetime, 
            acctstoptime,       acctsessiontime,    acctauthentic, 
            connectinfo_start,  connectinfo_stop,   acctinputoctets, 
            acctoutputoctets,   calledstationid,    callingstationid, 
            acctterminatecause, servicetype,        framedprotocol, 
            framedipaddress, tenant_id
           ) 
VALUES 
    (
    p_acctsessionid, p_acctuniqueid, p_username,
    p_realm, p_nasipaddress, p_nasportid,
    p_nasporttype, p_acctstarttime, p_acctupdatetime,
    p_acctstoptime, p_acctsessiontime, p_acctauthentic,
    p_connectinfo_start, p_connectinfo_stop, p_acctinputoctets,
    p_acctoutputoctets, p_calledstationid, p_callingstationid,
    p_acctterminatecause, p_servicetype, p_framedprotocol,
    p_framedipaddress, p_tenant_id
    );


  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime, acctuniqueid, tenant_id)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_acctstarttime, p_acctstatustype, p_acctinputoctets, p_acctoutputoctets, p_acctsessiontime, p_acctuniqueid, p_tenant_id);
END /
DELIMITER ;

-- Adding RADIUS Stop Stored Procedure

DROP PROCEDURE IF EXISTS acct_stop;
DELIMITER /
CREATE PROCEDURE acct_stop (
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
  IN p_connectinfo_stop varchar(50),
  IN p_calledstationid varchar(50),
  IN p_callingstationid varchar(50),
  IN p_servicetype varchar(32),
  IN p_framedprotocol varchar(32),
  IN p_acctterminatecause varchar(12),
  IN p_acctstatustype varchar(25),
  IN p_tenant_id int
)
BEGIN
  DECLARE Previous_Input_Octets bigint(20);
  DECLARE Previous_Output_Octets bigint(20);
  DECLARE Previous_Session_Time int(12);

  # Collect traffic previous values in the radacct table
  SELECT acctinputoctets, acctoutputoctets, acctsessiontime
    INTO Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time
    FROM radacct
    WHERE acctuniqueid = p_acctuniqueid
    AND (acctstoptime IS NULL OR acctstoptime = 0) LIMIT 1;

  # Set values to 0 when no previous records
  IF (Previous_Session_Time IS NULL) THEN
    SET Previous_Session_Time = 0;
    SET Previous_Input_Octets = 0;
    SET Previous_Output_Octets = 0;
    # If there is no open session for this, open one.
    INSERT INTO radacct 
           (
            acctsessionid,      acctuniqueid,       username, 
            realm,              nasipaddress,       nasportid, 
            nasporttype,        acctstoptime,       acctstarttime,
            acctsessiontime,    acctauthentic, 
            connectinfo_stop,  acctinputoctets, 
            acctoutputoctets,   calledstationid,    callingstationid, 
            servicetype,        framedprotocol,     acctterminatecause,
            framedipaddress,    tenant_id
           ) 
    VALUES 
        (
            p_acctsessionid,        p_acctuniqueid,     p_username,
            p_realm,                p_nasipaddress,     p_nasportid,
            p_nasporttype,          p_timestamp,     date_sub(p_timestamp, INTERVAL p_acctsessiontime SECOND ), 
            p_acctsessiontime,      p_acctauthentic,
            p_connectinfo_stop,     p_acctinputoctets,
            p_acctoutputoctets,     p_calledstationid,  p_callingstationid,
            p_servicetype,          p_framedprotocol,   p_acctterminatecause,
            p_framedipaddress,      p_tenant_id
        );
  ELSE 
    # Update record with new traffic
    UPDATE radacct SET
      acctstoptime = p_timestamp,
      acctsessiontime = p_acctsessiontime,
      acctinputoctets = p_acctinputoctets,
      acctoutputoctets = p_acctoutputoctets,
      acctterminatecause = p_acctterminatecause,
      connectinfo_stop = p_connectinfo_stop
      WHERE acctuniqueid = p_acctuniqueid
      AND (acctstoptime IS NULL OR acctstoptime = 0);
  END IF;

  # Create new record in the log table
  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime, acctuniqueid, tenant_id)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time), p_acctuniqueid, p_tenant_id);
END /
DELIMITER ;

-- Adding RADIUS Updates Stored Procedure

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
  IN p_acctstatustype varchar(25),
  IN p_tenant_id int
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
              framedipaddress, tenant_id
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
              p_framedipaddress, p_tenant_id
          );
     END IF;
   END IF;

 
  # Create new record in the log table
  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime, acctuniqueid, tenant_id)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time), p_acctuniqueid, p_tenant_id);
END /
DELIMITER ;

--
-- Table structure for table `api_user`
--

CREATE TABLE `api_user` (
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `valid_from` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `expiration` datetime NOT NULL,
  `access_level` varchar(255) DEFAULT 'NONE',
  `tenant_id` int(11) DEFAULT '0',
  PRIMARY KEY (`username`)
) ENGINE=InnoDB;

--
-- Table structure for table `tenant_code`
--

CREATE TABLE `tenant_code` (
  `code` varchar(255) NOT NULL,
  `switch_ip` varchar(15) NOT NULL,
  PRIMARY KEY (`code`)
) ENGINE=InnoDB;


INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));


--
-- PacketFence SQL schema upgrade from 6.3.0 to 6.4.0
--

--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 6;
SET @MINOR_VERSION = 4;
SET @SUBMINOR_VERSION = 0;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

--
-- Add new column acctuniqueid in radacct_log
--

ALTER TABLE radacct_log ADD COLUMN `acctuniqueid` varchar(32) NOT NULL default '' AFTER `acctsessiontime`;


--
-- Make the nasportid field bigger as some switch modules record the full interface name (ex: ge-0/0/20.0)
--

ALTER TABLE `radacct` modify `nasportid` VARCHAR(32);

--
-- Add 'acctuniqueid' index to radacct_log table
--

ALTER TABLE radacct_log ADD KEY `acctuniqueid` (`acctuniqueid`);


--
-- Update procedure for accounting
--

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
    IN p_acctstatustype varchar(25)
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
            framedipaddress
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
    p_framedipaddress
    );


  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime, acctuniqueid)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_acctstarttime, p_acctstatustype, p_acctinputoctets, p_acctoutputoctets, p_acctsessiontime, p_acctuniqueid);
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
  IN p_acctstatustype varchar(25)
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
            framedipaddress
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
            p_framedipaddress
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
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime, acctuniqueid)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time), p_acctuniqueid);
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
  IN p_acctstatustype varchar(25)
)
BEGIN
  DECLARE Previous_Input_Octets bigint(20);
  DECLARE Previous_Output_Octets bigint(20);
  DECLARE Previous_Session_Time int(12);
  DECLARE Previous_AcctUpdate_Time datetime;

  DECLARE Opened_Sessions int(12);
  DECLARE Latest_acctstarttime datetime;
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

  # Collect traffic previous values in the update table
  SELECT acctinputoctets, acctoutputoctets, acctsessiontime, acctupdatetime
    INTO Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time, Previous_AcctUpdate_Time
    FROM radacct
    WHERE acctuniqueid = p_acctuniqueid
    AND (acctstoptime IS NULL OR acctstoptime = 0) LIMIT 1;

  IF (Previous_Session_Time IS NULL) THEN
    # Set values to 0 when no previous records
    SET Previous_Session_Time = 0;
    SET Previous_Input_Octets = 0;
    SET Previous_Output_Octets = 0;
    SET Previous_AcctUpdate_Time = p_timestamp;
    # If there is no open session for this, open one.
    INSERT INTO radacct
           (
            acctsessionid,      acctuniqueid,       username,
            realm,              nasipaddress,       nasportid,
            nasporttype,        acctstarttime,
            acctupdatetime,     acctsessiontime,    acctauthentic,
            connectinfo_start,  acctinputoctets,
            acctoutputoctets,   calledstationid,    callingstationid,
            servicetype,        framedprotocol,
            framedipaddress
           )
    VALUES
        (
            p_acctsessionid,        p_acctuniqueid,     p_username,
            p_realm,                p_nasipaddress,     p_nasportid,
            p_nasporttype,          date_sub(p_timestamp, INTERVAL p_acctsessiontime SECOND ),
            p_timestamp,            p_acctsessiontime , p_acctauthentic,
            p_connectinfo_start,    p_acctinputoctets,
            p_acctoutputoctets,     p_calledstationid, p_callingstationid,
            p_servicetype,          p_framedprotocol,
            p_framedipaddress
        );
  ELSE
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

--
-- Remove redundent index for violation
--

DROP INDEX mac ON violation;

--
-- Remove redundent index for inline_accounting
--

DROP INDEX ip on inline_accounting;

--
-- Alter table iplog_history
--

ALTER TABLE iplog_history ADD INDEX end_time (end_time), ADD INDEX start_time (start_time);

--
-- Alter table iplog_archive
--

ALTER TABLE iplog_archive ADD INDEX end_time (end_time), ADD INDEX start_time (start_time);

-- 
-- Add index to iplog_history
-- 
ALTER TABLE iplog_history ADD INDEX iplog_history_mac_end_time (mac,end_time); 

--
-- Add index to auth_log
--
ALTER TABLE auth_log add key attempted_at (attempted_at);

--
-- This was done in the previous upgrade script but not in the schema
--

ALTER TABLE `locationlog` modify `port` VARCHAR(20) NOT NULL DEFAULT '';

--
-- Make the port field bigger as some switch modules record the full interface name (ex: ge-0/0/20.0)
-- locationlog was done in 6.3, but locationlog_archive was forgotten, this fixes it
--

ALTER TABLE `locationlog_archive` modify `port` VARCHAR(20) NOT NULL DEFAULT '';

--
-- Change end_time from timestamp to datetime in iplog_history
--

ALTER TABLE iplog_history MODIFY end_time datetime NOT NULL;


--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

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
-- This was done in the previous upgrade script but not in the schema
--

ALTER TABLE `locationlog` modify `port` VARCHAR(20);

--
-- Make the port field bigger as some switch modules record the full interface name (ex: ge-0/0/20.0)
-- locationlog was done in 6.3, but locationlog_archive was forgotten, this fixes it
--

ALTER TABLE `locationlog_archive` modify `port` VARCHAR(20);

--
-- Creating radippool table
--

CREATE TABLE radippool (
  id                    int(11) unsigned NOT NULL auto_increment,
  pool_name             varchar(30) NOT NULL,
  framedipaddress       varchar(15) NOT NULL default '',
  nasipaddress          varchar(15) NOT NULL default '',
  calledstationid       VARCHAR(30) NOT NULL,
  callingstationid      VARCHAR(30) NOT NULL,
  expiry_time           DATETIME NULL default NULL,
  start_time            DATETIME NULL default NULL,
  username              varchar(64) NOT NULL default '',
  pool_key              varchar(30) NOT NULL,
  lease_time            varchar(30) NULL,
  PRIMARY KEY (id),
  UNIQUE (framedipaddress),
  KEY radippool_poolname_expire (pool_name, expiry_time),
  KEY callingstationid (callingstationid),
  KEY radippool_framedipaddress (framedipaddress),
  KEY radippool_nasip_poolkey_ipaddress (nasipaddress, pool_key, framedipaddress),
  KEY radippool_callingstationid_expiry (callingstationid, expiry_time),
  KEY radippool_framedipaddress_expiry (framedipaddress, expiry_time)
) ENGINE=MEMORY;

--
-- Creating dhcpd table
--

CREATE TABLE dhcpd (
  ip varchar(45) NOT NULL,
  interface varchar(45) NOT NULL,
  idx int(2) NOT NULL,
  PRIMARY KEY (ip)
) ENGINE=InnoDB;

GRANT DROP ON pf.dhcpd TO 'pf'@'%';
GRANT DROP ON pf.dhcpd TO 'pf'@'localhost';

--
-- Create trigger on radippool update
--

DROP TRIGGER IF EXISTS iplog_insert_in_iplog_before_radippool_update_trigger;
DELIMITER /
CREATE TRIGGER iplog_insert_in_iplog_before_radippool_update_trigger AFTER UPDATE ON radippool
FOR EACH ROW
BEGIN
    REPLACE INTO iplog
           ( mac, ip ,
             start_time, end_time
           )
    VALUES
           ( NEW.callingstationid, NEW.framedipaddress,
             NEW.start_time, NEW.expiry_time
           );
END /
DELIMITER ;


--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 6;
SET @MINOR_VERSION = 0;
SET @SUBMINOR_VERSION = 0;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Insert 'VoIP' category
--

INSERT INTO `node_category` (name,notes) VALUES ("voice","VoIP devices");

--
-- Insert 'REJECT' category
--

INSERT INTO `node_category` (name,notes) VALUES ("REJECT","Reject role (Used to block access)");

--
-- Adding login remaining count to password table
--

ALTER TABLE password ADD `login_remaining` int(11) DEFAULT NULL;

-- Upgrade script from FR 2 to 3

DROP PROCEDURE IF EXISTS acct_start;
DELIMITER /
CREATE PROCEDURE acct_start (
    IN p_acctsessionid varchar(64),
    IN p_acctuniqueid varchar(32),
    IN p_username varchar(64),
    IN p_realm varchar(64),
    IN p_nasipaddress varchar(15),
    IN p_nasportid varchar(15),
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
AND (acctstoptime IS NULL OR acctstoptime = 0);

IF (Previous_Session_Time IS NOT NULL) THEN
    UPDATE radacct SET
      acctstoptime = p_timestamp,
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
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_acctstarttime, p_acctstatustype, p_acctinputoctets, p_acctoutputoctets, p_acctsessiontime);
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
  IN p_acctuniqueid varchar(64),
  IN p_acctsessionid varchar(64),
  IN p_username varchar(64),
  IN p_realm varchar(64),
  IN p_nasipaddress varchar(15),
  IN p_nasportid varchar(15),
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
    AND (acctstoptime IS NULL OR acctstoptime = 0);

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
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time));
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
  IN p_acctuniqueid varchar(64),
  IN p_acctsessionid varchar(64),
  IN p_username varchar(64),
  IN p_realm varchar(64),
  IN p_nasipaddress varchar(15),
  IN p_nasportid varchar(15),
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

  # Collect traffic previous values in the update table
  SELECT acctinputoctets, acctoutputoctets, acctsessiontime, acctupdatetime
    INTO Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time, Previous_AcctUpdate_Time
    FROM radacct
    WHERE acctuniqueid = p_acctuniqueid 
    AND (acctstoptime IS NULL OR acctstoptime = 0);

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

  # Create new record in the log table
  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time));
END /
DELIMITER ;


RENAME TABLE radius_nas TO radius_nas_fr2;

CREATE TABLE radius_nas (
  id int(10) NOT NULL auto_increment,
  nasname varchar(128) NOT NULL,
  shortname varchar(32),
  type varchar(30) default 'other',
  ports int(5),
  secret varchar(60) default 'secret' NOT NULL,
  server varchar(64),
  community varchar(50),
  description varchar(200) default 'RADIUS Client',
  config_timestamp BIGINT,
  start_ip INT UNSIGNED DEFAULT 0,
  end_ip INT UNSIGNED DEFAULT 0,
  range_length INT DEFAULT 0,
  PRIMARY KEY nasname (nasname),
  KEY id (id)
) ENGINE=InnoDB;


INSERT INTO radius_nas 
    (
        nasname, shortname, type,
        ports, secret, community,
        description, config_timestamp, start_ip,
        end_ip, range_length
    )
    SELECT 
        nasname, shortname, type,
        ports, secret, community,
        description, config_timestamp, start_ip,
        end_ip, range_length 
    FROM radius_nas_fr2;

#
# Table structure for table 'radacct'
#

RENAME TABLE radacct TO radacct_fr2;
CREATE TABLE radacct (
  radacctid bigint(21) NOT NULL auto_increment,
  acctsessionid varchar(64) NOT NULL default '',
  acctuniqueid varchar(32) NOT NULL default '',
  username varchar(64) NOT NULL default '',
  groupname varchar(64) NOT NULL default '',
  realm varchar(64) default '',
  nasipaddress varchar(15) NOT NULL default '',
  nasportid varchar(15) default NULL,
  nasporttype varchar(32) default NULL,
  acctstarttime datetime NULL default NULL,
  acctupdatetime datetime NULL default NULL,
  acctstoptime datetime NULL default NULL,
  acctinterval int(12) default NULL,
  acctsessiontime int(12) unsigned default NULL,
  acctauthentic varchar(32) default NULL,
  connectinfo_start varchar(50) default NULL,
  connectinfo_stop varchar(50) default NULL,
  acctinputoctets bigint(20) default NULL,
  acctoutputoctets bigint(20) default NULL,
  calledstationid varchar(50) NOT NULL default '',
  callingstationid varchar(50) NOT NULL default '',
  acctterminatecause varchar(32) NOT NULL default '',
  servicetype varchar(32) default NULL,
  framedprotocol varchar(32) default NULL,
  framedipaddress varchar(15) NOT NULL default '',
  PRIMARY KEY (radacctid),
  KEY acctuniqueid (acctuniqueid),
  KEY username (username),
  KEY framedipaddress (framedipaddress),
  KEY acctsessionid (acctsessionid),
  KEY acctsessiontime (acctsessiontime),
  KEY acctstarttime (acctstarttime),
  KEY acctinterval (acctinterval),
  KEY acctstoptime (acctstoptime),
  KEY nasipaddress (nasipaddress)
) ENGINE = INNODB;


INSERT INTO radacct 
    (
    acctsessionid, acctuniqueid, username,
    groupname, realm, nasipaddress,
    nasportid, nasporttype, acctstarttime,
    acctstoptime, acctsessiontime, acctauthentic,
    connectinfo_start, connectinfo_stop, acctinputoctets,
    acctoutputoctets, calledstationid, callingstationid,
    acctterminatecause, servicetype, framedprotocol,
    framedipaddress
    )
    SELECT 
    acctsessionid, acctuniqueid, username,
    groupname, realm, nasipaddress,
    nasportid, nasporttype, acctstarttime,
    acctstoptime, acctsessiontime, acctauthentic,
    connectinfo_start, connectinfo_stop, acctinputoctets,
    acctoutputoctets, calledstationid, callingstationid,
    acctterminatecause, servicetype, framedprotocol,
    framedipaddress
    FROM radacct_fr2;

--
-- Insert new sms carrier
--

INSERT INTO sms_carrier
    (id, name, email_pattern, created)
VALUES
    (100128, 'Google Project Fi', '%s@msg.fi.google.com', now());

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

--
-- Adding request_time to radius_audit_log table
--

ALTER TABLE radius_audit_log ADD `request_time` INT DEFAULT NULL;

-- Adding RADIUS nas client table

CREATE TABLE nas (
  id int(10) NOT NULL auto_increment,
  nasname varchar(128) NOT NULL,
  shortname varchar(32),
  type varchar(30) DEFAULT 'other',
  ports int(5),
  secret varchar(60) DEFAULT 'secret' NOT NULL,
  community varchar(50),
  description varchar(200) DEFAULT 'RADIUS Client',
  PRIMARY KEY (id),
  KEY nasname (nasname)
) ENGINE=InnoDB;

-- Adding RADIUS accounting table

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
  acctstoptime datetime NULL default NULL,
  acctsessiontime int(12) default NULL,
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
  acctstartdelay int(12) default NULL,
  acctstopdelay int(12) default NULL,
  xascendsessionsvrkey varchar(10) default NULL,
  PRIMARY KEY  (radacctid),
  KEY username (username),
  KEY framedipaddress (framedipaddress),
  KEY acctsessionid (acctsessionid),
  KEY acctsessiontime (acctsessiontime),
  KEY acctuniqueid (acctuniqueid),
  KEY acctstarttime (acctstarttime),
  KEY acctstoptime (acctstoptime),
  KEY nasipaddress (nasipaddress)
) ENGINE=InnoDB;

-- Adding RADIUS update log table

CREATE TABLE radacct_log (
  acctsessionid varchar(64) NOT NULL default '',
  username varchar(64) NOT NULL default '',
  nasipaddress varchar(15) NOT NULL default '',
  acctstatustype varchar(25) NOT NULL default '',  
  timestamp datetime NULL default NULL,
  acctinputoctets bigint(20) default NULL,
  acctoutputoctets bigint(20) default NULL,
  acctsessiontime int(12) default NULL,
  KEY acctsessionid (acctsessionid),
  KEY username (username),
  KEY nasipaddress (nasipaddress),
  KEY timestamp (timestamp)
) ENGINE=InnoDB;

-- Adding RADIUS Updates Stored Procedure

DROP PROCEDURE IF EXISTS acct_update;
DELIMITER /
CREATE PROCEDURE acct_update(
  IN p_timestamp DATETIME,
  IN p_acctsessiontime INT(12),
  IN p_acctinputoctets BIGINT(20),
  IN p_acctoutputoctets BIGINT(20),
  IN p_acctsessionid varchar(64),
  IN p_username VARCHAR(64),
  IN p_nasipaddress VARCHAR(15),
  IN p_framedipaddress VARCHAR(15),
  IN p_acctstatustype VARCHAR(25)
)
BEGIN
  DECLARE Previous_Input_Octets BIGINT(20);
  DECLARE Previous_Output_Octets BIGINT(20);
  DECLARE Previous_Session_Time INT(12);

  # Collect traffic previous values in the update table
  SELECT SUM(acctinputoctets), SUM(acctoutputoctets), SUM(acctsessiontime)
    INTO Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time
    FROM radacct_log
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress;

  # Set values to 0 when no previous records
  IF (Previous_Session_Time IS NULL) THEN
    SET Previous_Session_Time = 0;
    SET Previous_Input_Octets = 0;
    SET Previous_Output_Octets = 0;
  END IF;

  # Update record with new traffic
  UPDATE radacct SET
    framedipaddress = p_framedipaddress,
    acctsessiontime = p_acctsessiontime,
    acctinputoctets = p_acctinputoctets,
    acctoutputoctets = p_acctoutputoctets
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress
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

-- Adding RADIUS Start Stored Procedure

DROP PROCEDURE IF EXISTS acct_start;
DELIMITER /
CREATE PROCEDURE acct_start (
  IN p_acctsessionid VARCHAR(64),
  IN p_acctuniqueid VARCHAR(32),
  IN p_username VARCHAR(64),
  IN p_realm VARCHAR(64),
  IN p_nasipaddress VARCHAR(15),
  IN p_nasportid VARCHAR(15),
  IN p_nasporttype VARCHAR(32),
  IN p_acctstarttime DATETIME,
  IN p_acctstoptime DATETIME,
  IN p_acctsessiontime INT(12),
  IN p_acctauthentic VARCHAR(32),
  IN p_connectioninfo_start VARCHAR(50),
  IN p_connectioninfo_stop VARCHAR(50),
  IN p_acctinputoctets BIGINT(20),
  IN p_acctoutputoctets BIGINT(20),
  IN p_calledstationid VARCHAR(50),
  IN p_callingstationid VARCHAR(50),
  IN p_acctterminatecause VARCHAR(32),
  IN p_servicetype VARCHAR(32),
  IN p_framedprotocol VARCHAR(32),
  IN p_framedipaddress VARCHAR(15),
  IN p_acctstartdelay VARCHAR(12),
  IN p_acctstopdelay VARCHAR(12),
  IN p_xascendsessionsvrkey VARCHAR(10),
  IN p_acctstatustype VARCHAR(25)
)
BEGIN
  # Insert new record with new traffic
  INSERT INTO radacct
    (acctsessionid, acctuniqueid, username,
     realm, nasipaddress, nasportid,
     nasporttype, acctstarttime, acctstoptime,
     acctsessiontime, acctauthentic, connectinfo_start,
     connectinfo_stop, acctinputoctets, acctoutputoctets,
     calledstationid, callingstationid, acctterminatecause,
     servicetype, framedprotocol, framedipaddress,
     acctstartdelay, acctstopdelay, xascendsessionsvrkey)
  VALUES
    (p_acctsessionid, p_acctuniqueid, p_username,
     p_realm, p_nasipaddress, p_nasportid,
     p_nasporttype, p_acctstarttime, p_acctstoptime,
     p_acctsessiontime, p_acctauthentic, p_connectioninfo_start,
     p_connectioninfo_stop, p_acctinputoctets, p_acctoutputoctets,
     p_calledstationid, p_callingstationid, p_acctterminatecause,
     p_servicetype, p_framedprotocol, p_framedipaddress,
     p_acctstartdelay, p_acctstopdelay, p_xascendsessionsvrkey);

  # Create new record in the log table
  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_acctstarttime, p_acctstatustype,p_acctinputoctets,p_acctoutputoctets,p_acctsessiontime);
END /
DELIMITER ;

-- Adding RADIUS Stop Stored Procedure

DROP PROCEDURE IF EXISTS acct_stop;
DELIMITER /
CREATE PROCEDURE acct_stop(
  IN p_timestamp DATETIME,
  IN p_acctsessiontime INT(12),
  IN p_acctinputoctets BIGINT(20),
  IN p_acctoutputoctets BIGINT(20),
  IN p_acctterminatecause VARCHAR(12),
  IN p_acctdelaystop VARCHAR(32),
  IN p_connectinfo_stop VARCHAR(50),
  IN p_acctsessionid VARCHAR(64),
  IN p_username VARCHAR(64),
  IN p_nasipaddress VARCHAR(15),
  IN p_acctstatustype VARCHAR(25)
)
BEGIN
  DECLARE Previous_Input_Octets BIGINT(20);
  DECLARE Previous_Output_Octets BIGINT(20);
  DECLARE Previous_Session_Time INT(12);

  # Collect traffic previous values in the update table
  SELECT SUM(acctinputoctets), SUM(acctoutputoctets), SUM(acctsessiontime)
    INTO Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time
    FROM radacct_log
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress;

  # Set values to 0 when no previous records
  IF (Previous_Session_Time IS NULL) THEN
    SET Previous_Session_Time = 0;
    SET Previous_Input_Octets = 0;
    SET Previous_Output_Octets = 0;
  END IF;

  # Update record with new traffic
  UPDATE radacct SET
    acctstoptime = p_timestamp,
    acctsessiontime = p_acctsessiontime,
    acctinputoctets = p_acctinputoctets,
    acctoutputoctets = p_acctoutputoctets,
    acctterminatecause = p_acctterminatecause,
    connectinfo_stop = p_connectinfo_stop
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress
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

--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Alter locationlog
--

ALTER TABLE `locationlog` ADD `role` varchar(255) default NULL AFTER vlan;

--
-- Alter locationlog_archive
--

ALTER TABLE `locationlog_archive` ADD `role` varchar(255) default NULL AFTER vlan;

--
-- Creating auth_log table
--

CREATE TABLE auth_log (
  `id` int NOT NULL AUTO_INCREMENT,
  `process_name` varchar(255) NOT NULL,
  `mac` varchar(17) NOT NULL,
  `pid` varchar(255) NOT NULL default "default",
  `status` varchar(255) NOT NULL default "incomplete",
  `attempted_at` datetime NOT NULL,
  `completed_at` datetime,
  `source` varchar(255) NOT NULL,
  PRIMARY KEY (id),
  KEY pid (pid)
) ENGINE=InnoDB;

--
-- Table structure for table 'radius_audit_log'
--

CREATE TABLE radius_audit_log (
  id int NOT NULL AUTO_INCREMENT,
  created_at TIMESTAMP NOT NULL,
  mac char(17) NOT NULL,
  ip varchar(255) NULL,
  computer_name varchar(255) NULL,
  user_name varchar(255) NULL,
  stripped_user_name varchar(255) NULL,
  realm varchar(255) NULL,
  event_type varchar(255) NULL,
  switch_id varchar(255) NULL,
  switch_mac varchar(255) NULL,
  switch_ip_address varchar(255) NULL,
  radius_source_ip_address varchar(255),
  called_station_id varchar(255) NULL,
  calling_station_id varchar(255) NULL,
  nas_port_type varchar(255) NULL,
  ssid varchar(255) NULL,
  nas_port_id varchar(255) NULL,
  ifindex varchar(255) NULL,
  nas_port varchar(255) NULL,
  connection_type varchar(255) NULL,
  nas_ip_address varchar(255) NULL,
  nas_identifier varchar(255) NULL,
  auth_status varchar(255) NULL,
  reason TEXT NULL,
  auth_type varchar(255) NULL,
  eap_type varchar(255) NULL,
  role varchar(255) NULL,
  node_status varchar(255) NULL,
  profile varchar(255) NULL,
  source varchar(255) NULL,
  auto_reg char(1) NULL,
  is_phone char(1) NULL,
  pf_domain varchar(255) NULL,
  uuid varchar(255) NULL,
  radius_request TEXT,
  radius_reply TEXT,
  PRIMARY KEY (id),
  KEY `created_at` (created_at),
  KEY `mac` (mac),
  KEY `ip` (ip),
  KEY `user_name` (user_name)
) ENGINE=InnoDB;

--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 5;
SET @MINOR_VERSION = 6;
SET @SUBMINOR_VERSION = 0;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

-- Changing RADIUS Updates Stored Procedure

DROP PROCEDURE IF EXISTS acct_update;
DELIMITER /
CREATE PROCEDURE acct_update(
  IN p_timestamp datetime,
  IN p_acctsessiontime int(12),
  IN p_acctinputoctets bigint(20),
  IN p_acctoutputoctets bigint(20),
  IN p_acctsessionid varchar(64),
  IN p_username varchar(64),
  IN p_nasipaddress varchar(15),
  IN p_framedipaddress varchar(15),
  IN p_acctstatustype varchar(25)
)
BEGIN
  DECLARE Previous_Input_Octets bigint(20);
  DECLARE Previous_Output_Octets bigint(20);
  DECLARE Previous_Session_Time int(12);

  SELECT acctinputoctets, acctoutputoctets, acctsessiontime
    INTO Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time
    FROM radacct
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress;

  IF (Previous_Session_Time IS NULL) THEN
    SET Previous_Session_Time = 0;
    SET Previous_Input_Octets = 0;
    SET Previous_Output_Octets = 0;
  END IF;

  UPDATE radacct SET
    framedipaddress = p_framedipaddress,
    acctsessiontime = p_acctsessiontime,
    acctinputoctets = p_acctinputoctets,
    acctoutputoctets = p_acctoutputoctets
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress
    AND (acctstoptime IS NULL OR acctstoptime = 0);

  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time));
END /
DELIMITER ;

-- Changing RADIUS Start Stored Procedure

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
  IN p_acctstoptime datetime,
  IN p_acctsessiontime int(12),
  IN p_acctauthentic varchar(32),
  IN p_connectioninfo_start varchar(50),
  IN p_connectioninfo_stop varchar(50),
  IN p_acctinputoctets bigint(20),
  IN p_acctoutputoctets bigint(20),
  IN p_calledstationid varchar(50),
  IN p_callingstationid varchar(50),
  IN p_acctterminatecause varchar(32),
  IN p_servicetype varchar(32),
  IN p_framedprotocol varchar(32),
  IN p_framedipaddress varchar(15),
  IN p_acctstartdelay varchar(12),
  IN p_acctstopdelay varchar(12),
  IN p_xascendsessionsvrkey varchar(10),
  IN p_acctstatustype varchar(25)
)
BEGIN
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

  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_acctstarttime, p_acctstatustype,p_acctinputoctets,p_acctoutputoctets,p_acctsessiontime);
END /
DELIMITER ;

-- Changing RADIUS Stop Stored Procedure

DROP PROCEDURE IF EXISTS acct_stop;
DELIMITER /
CREATE PROCEDURE acct_stop(
  IN p_timestamp datetime,
  IN p_acctsessiontime int(12),
  IN p_acctinputoctets bigint(20),
  IN p_acctoutputoctets bigint(20),
  IN p_acctterminatecause varchar(12),
  IN p_acctdelaystop varchar(32),
  IN p_connectinfo_stop varchar(50),
  IN p_acctsessionid varchar(64),
  IN p_username varchar(64),
  IN p_nasipaddress varchar(15),
  IN p_acctstatustype varchar(25)
)
BEGIN
  DECLARE Previous_Input_Octets bigint(20);
  DECLARE Previous_Output_Octets bigint(20);
  DECLARE Previous_Session_Time int(12);

  SELECT acctinputoctets, acctoutputoctets, acctsessiontime
    INTO Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time
    FROM radacct
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress;

  IF (Previous_Session_Time IS NULL) THEN
    SET Previous_Session_Time = 0;
    SET Previous_Input_Octets = 0;
    SET Previous_Output_Octets = 0;
  END IF;

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

  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time));
END /
DELIMITER ;


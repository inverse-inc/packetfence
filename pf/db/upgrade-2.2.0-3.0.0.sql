--
-- Support new sponsor field in person
--

ALTER TABLE person
  ADD sponsor varchar(255) default NULL
;

--
-- Adding support for guest self-registration / management
--

--
-- Table structure for table `email_activation`
--

CREATE TABLE email_activation (
  `code_id` int NOT NULL AUTO_INCREMENT,
  `pid` varchar(255) default NULL,
  `mac` varchar(17) default NULL,
  `email` varchar(255) NOT NULL, -- email were approbation request is sent 
  `activation_code` varchar(255) NOT NULL,
  `expiration` DATETIME NOT NULL,
  `status` varchar(60) default NULL,
  PRIMARY KEY (code_id),
  KEY `identifier` (pid, mac),
  KEY `activation` (activation_code, status)
) ENGINE=InnoDB;

--
-- Table structure for table `temporary_password`
--

CREATE TABLE temporary_password (
  `pid` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `valid_from` DATETIME DEFAULT NULL,
  `expiration` DATETIME NOT NULL,
  `access_duration` varchar(255) DEFAULT NULL,
  PRIMARY KEY (pid)
) ENGINE=InnoDB;

--
-- Trigger to delete the temp password from 'temporary_password' when deleting the pid associated with
--

DROP TRIGGER IF EXISTS temporary_password_delete_trigger;
DELIMITER /
CREATE TRIGGER temporary_password_delete_trigger AFTER DELETE ON person
FOR EACH ROW
BEGIN
  DELETE FROM temporary_password WHERE pid = OLD.pid;
END /
DELIMITER ;

--
-- Table structure for table `sms_activation`
--

CREATE TABLE sms_activation (
  `code_id` int NOT NULL AUTO_INCREMENT,
  `mac` varchar(17) default NULL,
  `phone_number` varchar(255) NOT NULL, -- phone number where sms is sent
  `carrier_id` int(11) NOT NULL,
  `activation_code` varchar(255) NOT NULL,
  `expiration` DATETIME NOT NULL,
  `status` varchar(60) default NULL,
  PRIMARY KEY (code_id),
  KEY `identifier` (mac),
  KEY `activation` (activation_code, status)
) ENGINE=InnoDB;

--
-- Table structure for table `sms_carrier`
-- 
-- Source: StatusNet
-- Schema fetched on 2010-10-15 from:
-- http://gitorious.org/statusnet/mainline/blobs/master/classes/Sms_carrier.php
--

CREATE TABLE sms_carrier (
    id integer primary key comment 'primary key for SMS carrier',
    name varchar(64) unique key comment 'name of the carrier',
    email_pattern varchar(255) not null comment 'sprintf pattern for making an email address from a phone number',
    created datetime not null comment 'date this record was created',
    modified timestamp comment 'date this record was modified'
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_bin;

--
-- Insert data for table `sms_carrier`
--
-- Source: StatusNet
-- Data fetched on 2011-07-20 from:
-- http://gitorious.org/statusnet/mainline/blobs/raw/master/db/sms_carrier.sql
--

INSERT INTO sms_carrier
    (id, name, email_pattern, created)
VALUES
    (100056, '3 River Wireless', '%s@sms.3rivers.net', now()),
    (100057, '7-11 Speakout', '%s@cingularme.com', now()),
    (100058, 'Airtel (Karnataka, India)', '%s@airtelkk.com', now()),
    (100059, 'Alaska Communications Systems', '%s@msg.acsalaska.com', now()),
    (100060, 'Alltel Wireless', '%s@message.alltel.com', now()),
    (100061, 'AT&T Wireless', '%s@txt.att.net', now()),
    (100062, 'Bell Mobility (Canada)', '%s@txt.bell.ca', now()),
    (100063, 'Boost Mobile', '%s@myboostmobile.com', now()),
    (100064, 'Cellular One (Dobson)', '%s@mobile.celloneusa.com', now()),
    (100065, 'Cingular (Postpaid)', '%s@cingularme.com', now()),
    (100066, 'Centennial Wireless', '%s@cwemail.com', now()),
    (100067, 'Cingular (GoPhone prepaid)', '%s@cingularme.com', now()),
    (100068, 'Claro (Nicaragua)', '%s@ideasclaro-ca.com', now()),
    (100069, 'Comcel', '%s@comcel.com.co', now()),
    (100070, 'Cricket', '%s@sms.mycricket.com', now()),
    (100071, 'CTI', '%s@sms.ctimovil.com.ar', now()),
    (100072, 'Emtel (Mauritius)', '%s@emtelworld.net', now()),
    (100073, 'Fido (Canada)', '%s@fido.ca', now()),
    (100074, 'General Communications Inc.', '%s@msg.gci.net', now()),
    (100075, 'Globalstar', '%s@msg.globalstarusa.com', now()),
    (100076, 'Helio', '%s@myhelio.com', now()),
    (100077, 'Illinois Valley Cellular', '%s@ivctext.com', now()),
    (100078, 'i wireless', '%s.iws@iwspcs.net', now()),
    (100079, 'Meteor (Ireland)', '%s@sms.mymeteor.ie', now()),
    (100080, 'Mero Mobile (Nepal)', '%s@sms.spicenepal.com', now()),
    (100081, 'MetroPCS', '%s@mymetropcs.com', now()),
    (100082, 'Movicom', '%s@movimensaje.com.ar', now()),
    (100083, 'Mobitel (Sri Lanka)', '%s@sms.mobitel.lk', now()),
    (100084, 'Movistar (Colombia)', '%s@movistar.com.co', now()),
    (100085, 'MTN (South Africa)', '%s@sms.co.za', now()),
    (100086, 'MTS (Canada)', '%s@text.mtsmobility.com', now()),
    (100087, 'Nextel (Argentina)', '%s@nextel.net.ar', now()),
    (100088, 'Orange (Poland)', '%s@orange.pl', now()),
    (100089, 'Personal (Argentina)', '%s@personal-net.com.ar', now()),
    (100090, 'Plus GSM (Poland)', '%s@text.plusgsm.pl', now()),
    (100091, 'President\'s Choice (Canada)', '%s@txt.bell.ca', now()),
    (100092, 'Qwest', '%s@qwestmp.com', now()),
    (100093, 'Rogers (Canada)', '%s@pcs.rogers.com', now()),
    (100094, 'Sasktel (Canada)', '%s@sms.sasktel.com', now()),
    (100095, 'Setar Mobile email (Aruba)', '%s@mas.aw', now()),
    (100096, 'Solo Mobile', '%s@txt.bell.ca', now()),
    (100097, 'Sprint (PCS)', '%s@messaging.sprintpcs.com', now()),
    (100098, 'Sprint (Nextel)', '%s@page.nextel.com', now()),
    (100099, 'Suncom', '%s@tms.suncom.com', now()),
    (100100, 'T-Mobile', '%s@tmomail.net', now()),
    (100101, 'T-Mobile (Austria)', '%s@sms.t-mobile.at', now()),
    (100102, 'Telus Mobility (Canada)', '%s@msg.telus.com', now()),
    (100103, 'Thumb Cellular', '%s@sms.thumbcellular.com', now()),
    (100104, 'Tigo (Formerly Ola)', '%s@sms.tigo.com.co', now()),
    (100105, 'Unicel', '%s@utext.com', now()),
    (100106, 'US Cellular', '%s@email.uscc.net', now()),
    (100107, 'Verizon', '%s@vtext.com', now()),
    (100108, 'Virgin Mobile (Canada)', '%s@vmobile.ca', now()),
    (100109, 'Virgin Mobile (USA)', '%s@vmobl.com', now()),
    (100110, 'YCC', '%s@sms.ycc.ru', now()),
    (100111, 'Orange (UK)', '%s@orange.net', now()),
    (100112, 'Cincinnati Bell Wireless', '%s@gocbw.com', now()),
    (100113, 'T-Mobile Germany', '%s@t-mobile-sms.de', now()),
    (100114, 'Vodafone Germany', '%s@vodafone-sms.de', now()),
    (100115, 'E-Plus', '%s@smsmail.eplus.de', now()),
    (100116, 'Cellular South', '%s@csouth1.com', now()),
    (100117, 'ChinaMobile (139)', '%s@139.com', now()),
    (100118, 'Dialog Axiata', '%s@dialog.lk', now());


--
-- Adding support for Radius accounting
--

-- Adding RADIUS nas client table

CREATE TABLE radius_nas (
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


--
-- violation class disable becomes enabled
--

-- in order to properly migrate we empty the class table so the new code will properly update the table
DELETE FROM class;

ALTER TABLE class 
        CHANGE `disable` `enabled` char(1) NOT NULL default "N"
;

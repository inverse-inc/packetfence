--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 5;
SET @MINOR_VERSION = 1;
SET @SUBMINOR_VERSION = 0;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Table structure for table `class`
--

CREATE TABLE class (
  vid int(11) NOT NULL,
  description varchar(255) NOT NULL default "none",
  auto_enable char(1) NOT NULL default "Y",
  max_enables int(11) NOT NULL default 0,
  grace_period int(11) NOT NULL,
  window varchar(255) NOT NULL default 0,
  vclose int(11),
  priority int(11) NOT NULL,
  template varchar(255),
  max_enable_url varchar(255),
  redirect_url varchar(255),
  button_text varchar(255),
  enabled char(1) NOT NULL default "N",
  vlan varchar(255),
  target_category varchar(255),
  delay_by int(11) NOT NULL default 0,
  external_command varchar(255) DEFAULT NULL,
  PRIMARY KEY (vid)
) ENGINE=InnoDB;

--
-- Table structure for table `trigger`
--
CREATE TABLE `trigger` (
  vid int(11) default NULL,
  tid_start varchar(255) NOT NULL,
  tid_end varchar(255) NOT NULL,
  type varchar(255) default NULL,
  whitelisted_categories varchar(255) NOT NULL default '',
  PRIMARY KEY (vid,tid_start,tid_end,type),
  KEY `trigger` (tid_start,tid_end,type),
  CONSTRAINT `0_64` FOREIGN KEY (`vid`) REFERENCES `class` (`vid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--
-- Table structure for table `person`
--

CREATE TABLE person (
  pid varchar(255) NOT NULL,
  `firstname` varchar(255) default NULL,
  `lastname` varchar(255) default NULL,
  `email` varchar(255) default NULL,
  `telephone` varchar(255) default NULL,
  `company` varchar(255) default NULL,
  `address` varchar(255) default NULL,
  `notes` varchar(255),
  `sponsor` varchar(255) default NULL,
  `anniversary` varchar(255) default NULL,
  `birthday` varchar(255) default NULL,
  `gender` char(1) default NULL,
  `lang` varchar(255) default NULL,
  `nickname` varchar(255) default NULL,
  `cell_phone` varchar(255) default NULL,
  `work_phone` varchar(255) default NULL,
  `title` varchar(255) default NULL,
  `building_number` varchar(255) default NULL,
  `apartment_number` varchar(255) default NULL,
  `room_number` varchar(255) default NULL,
  `custom_field_1` varchar(255) default NULL,
  `custom_field_2` varchar(255) default NULL,
  `custom_field_3` varchar(255) default NULL,
  `custom_field_4` varchar(255) default NULL,
  `custom_field_5` varchar(255) default NULL,
  `custom_field_6` varchar(255) default NULL,
  `custom_field_7` varchar(255) default NULL,
  `custom_field_8` varchar(255) default NULL,
  `custom_field_9` varchar(255) default NULL,
  `portal` varchar(255) default NULL,
  `source` varchar(255) default NULL,
  PRIMARY KEY (pid)
) ENGINE=InnoDB;


--
-- Table structure for table `node_category`
--

CREATE TABLE `node_category` (
  `category_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `max_nodes_per_pid` int default 0,
  `notes` varchar(255) default NULL,
  PRIMARY KEY (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Insert 'default' category
--

INSERT INTO `node_category` (category_id,name,notes) VALUES ("1","default","Placeholder role/category, feel free to edit");

--
-- Insert 'guest' category
--

INSERT INTO `node_category` (category_id,name,notes) VALUES ("2","guest","Guests");

--
-- Insert 'gaming' category
--

INSERT INTO `node_category` (category_id,name,notes) VALUES ("3","gaming","Gaming devices");

--
-- Table structure for table `node`
--

CREATE TABLE node (
  mac varchar(17) NOT NULL,
  pid varchar(255) NOT NULL default "admin",
  category_id int default NULL,
  detect_date datetime NOT NULL default "0000-00-00 00:00:00",
  regdate datetime NOT NULL default "0000-00-00 00:00:00",
  unregdate datetime NOT NULL default "0000-00-00 00:00:00",
  lastskip datetime NOT NULL default "0000-00-00 00:00:00",
  time_balance int(10) unsigned DEFAULT NULL,
  bandwidth_balance int(10) unsigned DEFAULT NULL,
  status varchar(15) NOT NULL default "unreg",
  user_agent varchar(255) default NULL,
  computername varchar(255) default NULL,
  notes varchar(255) default NULL,
  last_arp datetime NOT NULL default "0000-00-00 00:00:00",
  last_dhcp datetime NOT NULL default "0000-00-00 00:00:00",
  dhcp_fingerprint varchar(255) default NULL,
  dhcp_vendor varchar(255) default NULL,
  device_type varchar(255) default NULL,
  device_class varchar(255) default NULL,
  bypass_vlan varchar(50) default NULL,
  voip enum('no','yes') NOT NULL DEFAULT 'no',
  autoreg enum('no','yes') NOT NULL DEFAULT 'no',
  sessionid varchar(30) default NULL,
  machine_account varchar(255) default NULL,
  bypass_role_id int default NULL,
  PRIMARY KEY (mac),
  KEY pid (pid),
  KEY category_id (category_id),
  KEY `node_status` (`status`, `unregdate`),
  KEY `node_dhcpfingerprint` (`dhcp_fingerprint`),
  CONSTRAINT `0_57` FOREIGN KEY (`pid`) REFERENCES `person` (`pid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `node_category_key` FOREIGN KEY (`category_id`) REFERENCES `node_category` (`category_id`)
) ENGINE=InnoDB;

--
-- Table structure for table `node_useragent`
--

CREATE TABLE `node_useragent` (
  mac varchar(17) NOT NULL,
  os varchar(255) DEFAULT NULL,
  browser varchar(255) DEFAULT NULL,
  device enum('no','yes') NOT NULL DEFAULT 'no',
  device_name varchar(255) DEFAULT NULL,
  mobile enum('no','yes') NOT NULL DEFAULT 'no',
  PRIMARY KEY (mac)
) ENGINE=InnoDB;

--
-- Trigger to delete the node_useragent associated with a mac when deleting this mac from the node table
--

DROP TRIGGER IF EXISTS node_useragent_delete_trigger;
DELIMITER /
CREATE TRIGGER node_useragent_delete_trigger AFTER DELETE ON node
FOR EACH ROW
BEGIN
  DELETE FROM node_useragent WHERE mac = OLD.mac;
END /
DELIMITER ;

--
-- Table structure for table `action`
--

CREATE TABLE action (
  vid int(11) NOT NULL,
  action varchar(255) NOT NULL,
  PRIMARY KEY (vid,action),
  CONSTRAINT `FOREIGN` FOREIGN KEY (`vid`) REFERENCES `class` (`vid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--
-- Table structure for table `violation`
--

CREATE TABLE violation (
  id int NOT NULL AUTO_INCREMENT,
  mac varchar(17) NOT NULL,
  vid int(11) NOT NULL,
  start_date datetime NOT NULL,
  release_date datetime default "0000-00-00 00:00:00",
  status varchar(10) default "open",
  ticket_ref varchar(255) default NULL,
  notes text,
  KEY mac (mac),
  KEY vid (vid),
  KEY status (status),
  KEY ind1 (mac,status,vid),
  KEY violation_release_date (release_date),
  CONSTRAINT `0_60` FOREIGN KEY (`mac`) REFERENCES `node` (`mac`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `0_61` FOREIGN KEY (`vid`) REFERENCES `class` (`vid`) ON DELETE CASCADE ON UPDATE CASCADE,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

--
-- Table structure for table `iplog`
--

CREATE TABLE iplog (
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  start_time datetime NOT NULL,
  end_time datetime default "0000-00-00 00:00:00",
  PRIMARY KEY (ip),
  KEY iplog_mac_end_time (mac,end_time),
  KEY iplog_end_time (end_time)
) ENGINE=InnoDB;

--
-- Trigger to insert old record from 'iplog' in 'iplog_history' before updating the current one
--

DROP TRIGGER IF EXISTS iplog_insert_in_iplog_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER iplog_insert_in_iplog_history_before_update_trigger BEFORE UPDATE ON iplog
FOR EACH ROW
BEGIN
  INSERT INTO iplog_history SET ip = OLD.ip, mac = OLD.mac, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

--
-- Table structure for table `iplog_history`
--

CREATE TABLE iplog_history (
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  start_time datetime NOT NULL,
  end_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

--
-- Table structure for table `iplog_archive`
--

CREATE TABLE iplog_archive (
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  start_time datetime NOT NULL,
  end_time datetime NOT NULL
) ENGINE=InnoDB;

CREATE TABLE `locationlog` (
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(50) default NULL,
  `connection_type` varchar(50) NOT NULL default '',
  `connection_sub_type` varchar(50) default NULL,
  `dot1x_username` varchar(255) NOT NULL default '',
  `ssid` varchar(32) NOT NULL default '',
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime default NULL,
  `switch_ip` varchar(17) DEFAULT NULL,
  `switch_mac` varchar(17) DEFAULT NULL,
  `stripped_user_name` varchar (255) DEFAULT NULL,
  `realm`  varchar (255) DEFAULT NULL,
  `session_id` VARCHAR(255) DEFAULT NULL,
  KEY `locationlog_view_mac` (`mac`, `end_time`),
  KEY `locationlog_end_time` ( `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`)
) ENGINE=InnoDB;

CREATE TABLE `locationlog_archive` (
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(50) default NULL,
  `connection_type` varchar(50) NOT NULL default '',
  `connection_sub_type` varchar(50) default NULL,
  `dot1x_username` varchar(255) NOT NULL default '',
  `ssid` varchar(32) NOT NULL default '',
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime default NULL,
  `switch_ip` varchar(17) DEFAULT NULL,
  `switch_mac` varchar(17) DEFAULT NULL,
  `stripped_user_name` varchar (255) DEFAULT NULL,
  `realm`  varchar (255) DEFAULT NULL,
  `session_id` VARCHAR(255) DEFAULT NULL,
  KEY `locationlog_archive_view_mac` (`mac`, `end_time`),
  KEY `locationlog_end_time` ( `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`)
) ENGINE=InnoDB;

CREATE TABLE `userlog` (
  `mac` varchar(17) NOT NULL default '',
  `pid` varchar(255) default NULL,
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime default NULL,
  PRIMARY KEY (`mac`,`start_time`),
  KEY `pid` (`pid`),
  CONSTRAINT `userlog_ibfk_1` FOREIGN KEY (`mac`) REFERENCES `node` (`mac`) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE `ifoctetslog` (
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(8) NOT NULL default '',
  `read_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `mac` varchar(17) default NULL,
  `ifInOctets` bigint(20) unsigned NOT NULL default '0',
  `ifOutOctets` bigint(20) unsigned NOT NULL default '0',
  PRIMARY KEY  (`switch`,`port`,`read_time`)
) ENGINE=InnoDB;

CREATE TABLE `traplog` (
  `switch` varchar(30) NOT NULL default '',
  `ifIndex` smallint(6) NOT NULL default '0',
  `parseTime` datetime NOT NULL default '0000-00-00 00:00:00',
  `type` varchar(30) NOT NULL default '',
  KEY `switch` (`switch`,`ifIndex`),
  KEY `parseTime` (`parseTime`)
) ENGINE=InnoDB;

CREATE TABLE `configfile` (
  `filename` varchar(255) NOT NULL,
  `filecontent` text NOT NULL,
  `lastmodified` datetime NOT NULL
) ENGINE=InnoDB default CHARSET=latin1;

--
-- Table structure for table `password`
--

CREATE TABLE `password` (
  `pid` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `valid_from` datetime default NULL,
  `expiration` datetime NOT NULL,
  `access_duration` varchar(255) default NULL,
  `access_level` varchar(255) DEFAULT 'NONE',
  `category` int DEFAULT NULL,
  `sponsor` tinyint(1) NOT NULL default 0,
  `unregdate` datetime NOT NULL default "0000-00-00 00:00:00",
  PRIMARY KEY (pid)
) ENGINE=InnoDB;

--
-- Insert default users
--

INSERT INTO `person` (pid,notes) VALUES ("admin","Default Admin User - do not delete");
INSERT INTO `person` (pid,notes) VALUES ("default","Default User - do not delete");
INSERT INTO password (pid, password, valid_from, expiration, access_duration, access_level, category) VALUES ('admin', 'admin', NOW(), '2038-01-01', NULL, 'ALL', NULL);

--
-- Trigger to delete the temp password from 'password' when deleting the pid associated with
--

DROP TRIGGER IF EXISTS password_delete_trigger;
DELIMITER /
CREATE TRIGGER password_delete_trigger AFTER DELETE ON person
FOR EACH ROW
BEGIN
  DELETE FROM `password` WHERE pid = OLD.pid;
END /
DELIMITER ;

--
-- Table structure for table `sms_carrier`
-- 
-- Source: StatusNet
-- Schema fetched on 2010-10-15 from:
-- http://gitorious.org/statusnet/mainline/blobs/raw/master/db/statusnet.sql
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
    (100118, 'Dialog Axiata', '%s@dialog.lk', now()),
    (100119, 'Swisscom', '%s@sms.bluewin.ch', now()),
    (100120, 'Orange (CH)', '%s@orange.net', now()),
    (100121, 'Sunrise', '%s@gsm.sunrise.ch', now());

-- Adding RADIUS nas client table

CREATE TABLE radius_nas (
  nasname varchar(128) NOT NULL,
  shortname varchar(32),
  type varchar(30) default 'other',
  ports int(5),
  secret varchar(60) default 'secret' NOT NULL,
  community varchar(50),
  description varchar(200) default 'RADIUS Client',
  config_timestamp BIGINT,
  start_ip INT UNSIGNED DEFAULT 0,
  end_ip INT UNSIGNED DEFAULT 0,
  range_length INT DEFAULT 0,
  PRIMARY KEY nasname (nasname)
) ENGINE=InnoDB;

-- Adding RADIUS accounting table

CREATE TABLE radacct (
  radacctid bigint(21) NOT NULL AUTO_INCREMENT,
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
  KEY nasipaddress (nasipaddress),
  KEY callingstationid (callingstationid)
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
-- Statement of Health (SoH) related
--
-- The web interface allows you to create any number of named filters,
-- which are a collection of rules. A rule is a specific condition that
-- must be satisfied by the statement of health, e.g. "anti-virus is not
-- installed". The rules in a filter are ANDed together to determine if
-- the specified action is to be executed.

--
-- One entry per filter.
--

CREATE TABLE soh_filters (
  filter_id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  name varchar(32) NOT NULL UNIQUE,

  -- If action is null, this filter won't do anything. Otherwise this
  -- column may have any value; "accept" and "violation" are currently
  -- recognised and acted upon.
  action varchar(32),

  -- If action = 'violation', then this column contains the vid of a
  -- violation to trigger. (I wish I could write a constraint to
  -- express this.)
  vid int
) ENGINE=InnoDB;

INSERT INTO soh_filters (name) VALUES ('Default');

--
-- One entry for each rule in a filter.
--

CREATE TABLE soh_filter_rules (
  rule_id int NOT NULL PRIMARY KEY AUTO_INCREMENT,

  filter_id int NOT NULL,
  FOREIGN KEY (filter_id) REFERENCES soh_filters (filter_id)
      ON DELETE CASCADE,

  -- Any valid health class, e.g. "antivirus"
  class varchar(32) NOT NULL,

  -- Must be 'is' or 'is not'
  op varchar(16) NOT NULL,

  -- May be 'ok', 'installed', 'enabled', 'disabled', 'uptodate',
  -- 'microsoft' for now; more values may be used in future.
  status varchar(16) NOT NULL
) ENGINE=InnoDB;

--
-- Table structure for table `scan`
--

CREATE TABLE scan (
  id varchar(20) NOT NULL,
  ip varchar(255) NOT NULL,
  mac varchar(17) NOT NULL,
  type varchar(255) NOT NULL,
  start_date datetime NOT NULL,
  update_date timestamp NOT NULL ON UPDATE CURRENT_TIMESTAMP,
  status varchar(255) NOT NULL,
  report_id varchar(255) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

--
-- Table structure for table `billing`
--

CREATE TABLE billing (
  id varchar(20) NOT NULL,
  ip varchar(255) NOT NULL,
  mac varchar(17) NOT NULL,
  type varchar(255) NOT NULL,
  start_date datetime NOT NULL,
  update_date timestamp NOT NULL ON UPDATE CURRENT_TIMESTAMP,
  status varchar(255) NOT NULL,
  item varchar(255) NOT NULL,
  price varchar(255) NOT NULL,
  person varchar(255) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

--
-- Table structure for table `savedsearch`
--

CREATE TABLE savedsearch (
  id int NOT NULL AUTO_INCREMENT,
  pid varchar(255) NOT NULL,
  namespace varchar(255) NOT NULL,
  name varchar(255) NOT NULL,
  query text,
  in_dashboard tinyint,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

--
-- Table structure for table 
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
-- Table structure for table `activation`
--

CREATE TABLE activation (
  `code_id` int NOT NULL AUTO_INCREMENT,
  `pid` varchar(255) default NULL,
  `mac` varchar(17) default NULL,
  `contact_info` varchar(255) NOT NULL, -- email or phone number were approbation request is sent 
  `carrier_id` int(11) NULL,
  `activation_code` varchar(255) NOT NULL,
  `expiration` datetime NOT NULL,
  `status` varchar(60) default NULL,
  `type` varchar(60) NOT NULL,
  `portal` varchar(255) default NULL,
  PRIMARY KEY (code_id),
  KEY `mac` (mac),
  KEY `identifier` (pid, mac),
  KEY `activation` (activation_code, status)
) ENGINE=InnoDB;


--
-- Table structure for table `keyed`
--

CREATE TABLE keyed (
  id VARCHAR(255),
  value LONGBLOB,
  PRIMARY KEY(id)
) ENGINE=InnoDB;

--
-- Table structure for table 'pf_version'
--

CREATE TABLE pf_version ( `id` INT NOT NULL PRIMARY KEY, `version` VARCHAR(11) NOT NULL UNIQUE KEY);

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

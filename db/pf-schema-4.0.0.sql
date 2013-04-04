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
  notes varchar(255),
  sponsor varchar(255) default NULL,
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

INSERT INTO `node_category` (category_id,name,notes) VALUES ("1","default","Placeholder category, feel free to edit");

--
-- Insert 'guest' category
--

INSERT INTO `node_category` (category_id,name,notes) VALUES ("2","guest","Guests");

--
-- Table structure for table `node`
--

CREATE TABLE node (
  mac varchar(17) NOT NULL,
  pid varchar(255) NOT NULL default "1",
  category_id int default NULL,
  detect_date datetime NOT NULL default "0000-00-00 00:00:00",
  regdate datetime NOT NULL default "0000-00-00 00:00:00",
  unregdate datetime NOT NULL default "0000-00-00 00:00:00",
  lastskip datetime NOT NULL default "0000-00-00 00:00:00",
  status varchar(15) NOT NULL default "unreg",
  user_agent varchar(255) default NULL,
  computername varchar(255) default NULL,
  notes varchar(255) default NULL,
  last_arp datetime NOT NULL default "0000-00-00 00:00:00",
  last_dhcp datetime NOT NULL default "0000-00-00 00:00:00",
  dhcp_fingerprint varchar(255) default NULL,
  `bypass_vlan` varchar(50) default NULL,
  `voip` enum('no','yes') NOT NULL DEFAULT 'no',
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
  CONSTRAINT `0_60` FOREIGN KEY (`mac`) REFERENCES `node` (`mac`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `0_61` FOREIGN KEY (`vid`) REFERENCES `class` (`vid`) ON DELETE CASCADE ON UPDATE CASCADE,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

--
-- Table structure for table `iplog`
--

CREATE TABLE iplog (
  mac varchar(17) NOT NULL,
  ip varchar(15) NOT NULL,
  start_time datetime NOT NULL,
  end_time datetime default "0000-00-00 00:00:00",
  KEY mac (mac),
  KEY `ip_view_open` (`ip`, `end_time`),
  KEY `mac_view_open` (`mac`, `end_time`),
  CONSTRAINT `0_63` FOREIGN KEY (`mac`) REFERENCES `node` (`mac`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE os_type (
  os_id int(11) NOT NULL,
  description varchar(255) NOT NULL,
  PRIMARY KEY os_id (os_id)
) ENGINE=InnoDB;

CREATE TABLE dhcp_fingerprint (
  fingerprint varchar(255) NOT NULL,
  os_id int(11) NOT NULL,
  PRIMARY KEY fingerprint (fingerprint),
  KEY os_id_key (os_id),
  CONSTRAINT `0_65` FOREIGN KEY (`os_id`) REFERENCES `os_type` (`os_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE os_class (
  class_id int(11) NOT NULL,               
  description varchar(255) NOT NULL,     
  PRIMARY KEY class_id (class_id)
) ENGINE=InnoDB;     

CREATE TABLE os_mapping (   
  os_type int(11) NOT NULL,  
  os_class int(11) NOT NULL,
  PRIMARY KEY  (os_type,os_class),
  KEY os_type_key (os_type),
  KEY os_class_key (os_class),
  CONSTRAINT `0_66` FOREIGN KEY (`os_type`) REFERENCES `os_type` (`os_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `0_67` FOREIGN KEY (`os_class`) REFERENCES `os_class` (`class_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE `locationlog` (
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(50) default NULL,
  `connection_type` varchar(50) NOT NULL default '',
  `dot1x_username` varchar(255) NOT NULL default '',
  `ssid` varchar(32) NOT NULL default '',
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime default NULL,
  KEY `locationlog_view_mac` (`mac`, `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`)
) ENGINE=InnoDB;

CREATE TABLE `locationlog_history` (
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(50) default NULL,
  `connection_type` varchar(50) NOT NULL default '',
  `dot1x_username` varchar(255) NOT NULL default '',
  `ssid` varchar(32) NOT NULL default '',
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime default NULL,
  KEY `locationlog_history_view_mac` (`mac`, `end_time`)
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

CREATE TABLE `switchlocation` (
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(8) NOT NULL default '',
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime default NULL,
  `location` varchar(50) default NULL,
  `description` varchar(50) default NULL,
  PRIMARY KEY  (`switch`,`port`,`start_time`)
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
-- Table structure for table `email_activation`
--

CREATE TABLE email_activation (
  `code_id` int NOT NULL AUTO_INCREMENT,
  `pid` varchar(255) default NULL,
  `mac` varchar(17) default NULL,
  `email` varchar(255) NOT NULL, -- email were approbation request is sent 
  `activation_code` varchar(255) NOT NULL,
  `expiration` datetime NOT NULL,
  `status` varchar(60) default NULL,
  `type` varchar(60) default NULL,
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
  `valid_from` datetime default NULL,
  `expiration` datetime NOT NULL,
  `access_duration` varchar(255) default NULL,
  `access_level` int unsigned NOT NULL default 0,
  `category` int NOT NULL,
  `sponsor` tinyint(1) NOT NULL default 0,
  `unregdate` datetime NOT NULL default "0000-00-00 00:00:00",
  PRIMARY KEY (pid)
) ENGINE=InnoDB;

--
-- Insert 'default' admin user
--

INSERT INTO `person` (pid,notes) VALUES ("admin","Default Admin User - do not delete");
INSERT INTO temporary_password (pid, password, valid_from, expiration, access_duration, access_level, category) VALUES ('admin', 'admin', NOW(), '2038-01-01', '9999D', 4294967295, 1);

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
  `expiration` datetime NOT NULL,
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
    (100118, 'Dialog Axiata', '%s@dialog.lk', now());

-- Adding RADIUS nas client table

CREATE TABLE radius_nas (
  id int(10) NOT NULL AUTO_INCREMENT,
  nasname varchar(128) NOT NULL,
  shortname varchar(32),
  type varchar(30) default 'other',
  ports int(5),
  secret varchar(60) default 'secret' NOT NULL,
  community varchar(50),
  description varchar(200) default 'RADIUS Client',
  PRIMARY KEY (id),
  KEY nasname (nasname)
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

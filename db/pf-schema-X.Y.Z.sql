--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 8;
SET @MINOR_VERSION = 2;
SET @SUBMINOR_VERSION = 9;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Table structure for table `tenant`
--

CREATE TABLE `tenant` (
  id int NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  portal_domain_name VARCHAR(255),
  domain_name VARCHAR(255),
  PRIMARY KEY (id),
  UNIQUE KEY tenant_name (`name`),
  UNIQUE KEY tenant_portal_domain_name (`portal_domain_name`),
  UNIQUE KEY tenant_domain_name (`domain_name`)
);

INSERT INTO `tenant` VALUES (1, 'default', NULL, NULL);

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
-- Table structure for table `person`
--

CREATE TABLE person (
  tenant_id int NOT NULL DEFAULT 1,
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
  `psk` varchar(255) NULL DEFAULT NULL,
  `potd` enum('no','yes') NOT NULL DEFAULT 'no',
  PRIMARY KEY (`tenant_id`, `pid`),
  CONSTRAINT `person_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`)
) ENGINE=InnoDB;


--
-- Table structure for table `node_category`
--

CREATE TABLE `node_category` (
  `category_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `max_nodes_per_pid` int default 0,
  `notes` varchar(255) default NULL,
  PRIMARY KEY (`category_id`),
  UNIQUE KEY node_category_name (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Insert 'default' category
--

INSERT INTO `node_category` (name,notes) VALUES ("default","Placeholder role/category, feel free to edit");

--
-- Insert 'guest' category
--

INSERT INTO `node_category` (name,notes) VALUES ("guest","Guests");

--
-- Insert 'gaming' category
--

INSERT INTO `node_category` (name,notes) VALUES ("gaming","Gaming devices");

--
-- Insert 'voice' category
--

INSERT INTO `node_category` (name,notes) VALUES ("voice","VoIP devices");

--
-- Insert 'REJECT' category
--

INSERT INTO `node_category` (name,notes) VALUES ("REJECT","Reject role (Used to block access)");

--
-- Table structure for table `node`
--

CREATE TABLE node (
  tenant_id int NOT NULL DEFAULT 1,
  mac varchar(17) NOT NULL,
  pid varchar(255) NOT NULL default "default",
  category_id int default NULL,
  detect_date datetime NOT NULL default "0000-00-00 00:00:00",
  regdate datetime NOT NULL default "0000-00-00 00:00:00",
  unregdate datetime NOT NULL default "0000-00-00 00:00:00",
  lastskip datetime NOT NULL default "0000-00-00 00:00:00",
  time_balance int(10) unsigned DEFAULT NULL,
  bandwidth_balance bigint(20) unsigned DEFAULT NULL,
  status varchar(15) NOT NULL default "unreg",
  user_agent varchar(255) default NULL,
  computername varchar(255) default NULL,
  notes varchar(255) default NULL,
  last_arp datetime NOT NULL default "0000-00-00 00:00:00",
  last_dhcp datetime NOT NULL default "0000-00-00 00:00:00",
  dhcp_fingerprint varchar(255) default NULL,
  dhcp6_fingerprint varchar(255) default NULL,
  dhcp_vendor varchar(255) default NULL,
  dhcp6_enterprise varchar(255) default NULL,
  device_type varchar(255) default NULL,
  device_class varchar(255) default NULL,
  device_version varchar(255) DEFAULT NULL,
  device_score int DEFAULT NULL,
  device_manufacturer varchar(255) DEFAULT NULL,
  bypass_vlan varchar(50) default NULL,
  voip enum('no','yes') NOT NULL DEFAULT 'no',
  autoreg enum('no','yes') NOT NULL DEFAULT 'no',
  sessionid varchar(30) default NULL,
  machine_account varchar(255) default NULL,
  bypass_role_id int default NULL,
  last_seen DATETIME NOT NULL DEFAULT "0000-00-00 00:00:00",
  PRIMARY KEY (`tenant_id`, `mac`),
  KEY pid (pid),
  KEY category_id (category_id),
  KEY `node_status` (`status`, `unregdate`),
  KEY `node_dhcpfingerprint` (`dhcp_fingerprint`),
  KEY `node_last_seen` (`last_seen`),
  CONSTRAINT `0_57` FOREIGN KEY (`tenant_id`, `pid`) REFERENCES `person` (`tenant_id`, `pid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `node_category_key` FOREIGN KEY (`category_id`) REFERENCES `node_category` (`category_id`),
  CONSTRAINT `node_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`)
) ENGINE=InnoDB;

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
  tenant_id int NOT NULL DEFAULT 1,
  mac varchar(17) NOT NULL,
  vid int(11) NOT NULL,
  start_date datetime NOT NULL,
  release_date datetime default "0000-00-00 00:00:00",
  status varchar(10) default "open",
  ticket_ref varchar(255) default NULL,
  notes text,
  KEY vid (vid),
  KEY status (status),
  KEY ind1 (mac,status,vid),
  KEY violation_release_date (release_date),
  CONSTRAINT `0_60` FOREIGN KEY (`tenant_id`, `mac`) REFERENCES `node` (`tenant_id`, `mac`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `0_61` FOREIGN KEY (`vid`) REFERENCES `class` (`vid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `violation_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`),
  PRIMARY KEY (id)
) ENGINE=InnoDB;

--
-- Table structure for table `ip4log`
--

CREATE TABLE ip4log (
  tenant_id int NOT NULL DEFAULT 1,
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  start_time datetime NOT NULL,
  end_time datetime default "0000-00-00 00:00:00",
  PRIMARY KEY (`tenant_id`, `ip`),
  KEY ip4log_mac_end_time (mac,end_time),
  KEY ip4log_end_time (end_time),
  CONSTRAINT `ip4log_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`)
) ENGINE=InnoDB;

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
-- Table structure for table `ip4log_history`
--

CREATE TABLE ip4log_history (
  id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  tenant_id int NOT NULL DEFAULT 1,
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  start_time datetime NOT NULL,
  end_time datetime NOT NULL,
  KEY ip4log_history_mac_end_time (mac,end_time),
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB;

--
-- Table structure for table `ip4log_archive`
--

CREATE TABLE ip4log_archive (
  id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  tenant_id int NOT NULL DEFAULT 1,
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  start_time datetime NOT NULL,
  end_time datetime NOT NULL,
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB;

--
-- Table structure for table `ip6log`
--

CREATE TABLE ip6log (
  tenant_id int NOT NULL DEFAULT 1,
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  type varchar(32) DEFAULT NULL,
  start_time datetime NOT NULL,
  end_time datetime default "0000-00-00 00:00:00",
  PRIMARY KEY (tenant_id, ip),
  KEY ip6log_mac_end_time (mac,end_time),
  KEY ip6log_end_time (end_time),
  CONSTRAINT `ip6log_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`)
) ENGINE=InnoDB;

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
-- Table structure for table `ip6log_history`
--

CREATE TABLE ip6log_history (
  id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  tenant_id int NOT NULL DEFAULT 1,
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
  tenant_id int NOT NULL DEFAULT 1,
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  type varchar(32) DEFAULT NULL,
  start_time datetime NOT NULL,
  end_time datetime NOT NULL,
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB;


CREATE TABLE `locationlog` (
  `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `tenant_id` int NOT NULL DEFAULT 1,
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(20) NOT NULL default '',
  `vlan` varchar(50) default NULL,
  `role` varchar(255) default NULL,
  `connection_type` varchar(50) NOT NULL default '',
  `connection_sub_type` varchar(50) default NULL,
  `dot1x_username` varchar(255) NOT NULL default '',
  `ssid` varchar(32) NOT NULL default '',
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `switch_ip` varchar(17) DEFAULT NULL,
  `switch_mac` varchar(17) DEFAULT NULL,
  `stripped_user_name` varchar (255) DEFAULT NULL,
  `realm`  varchar (255) DEFAULT NULL,
  `session_id` VARCHAR(255) DEFAULT NULL,
  `ifDesc` VARCHAR(255) DEFAULT NULL,
  KEY `locationlog_view_mac` (`mac`, `end_time`),
  KEY `locationlog_end_time` ( `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`)
) ENGINE=InnoDB;

CREATE TABLE `locationlog_archive` (
  `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `tenant_id` int NOT NULL DEFAULT 1,
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(20) NOT NULL default '',
  `vlan` varchar(50) default NULL,
  `role` varchar(255) default NULL,
  `connection_type` varchar(50) NOT NULL default '',
  `connection_sub_type` varchar(50) default NULL,
  `dot1x_username` varchar(255) NOT NULL default '',
  `ssid` varchar(32) NOT NULL default '',
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `switch_ip` varchar(17) DEFAULT NULL,
  `switch_mac` varchar(17) DEFAULT NULL,
  `stripped_user_name` varchar (255) DEFAULT NULL,
  `realm`  varchar (255) DEFAULT NULL,
  `session_id` VARCHAR(255) DEFAULT NULL,
  `ifDesc` VARCHAR(255) DEFAULT NULL,
  KEY `locationlog_archive_view_mac` (`mac`, `end_time`),
  KEY `locationlog_end_time` ( `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`)
) ENGINE=InnoDB;

CREATE TABLE `userlog` (
  `tenant_id` int NOT NULL DEFAULT 1,
  `mac` varchar(17) NOT NULL default '',
  `pid` varchar(255) default NULL,
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime default NULL,
  PRIMARY KEY (`tenant_id`, `mac`,`start_time`),
  KEY `pid` (`pid`),
  CONSTRAINT `userlog_ibfk_1` FOREIGN KEY (`tenant_id`, `mac`) REFERENCES `node` (`tenant_id`, `mac`) ON DELETE CASCADE
) ENGINE=InnoDB;

--
-- Table structure for table `password`
--

CREATE TABLE `password` (
  `tenant_id` int NOT NULL DEFAULT 1,
  `pid` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `valid_from` datetime NOT NULL DEFAULT "0000-00-00 00:00:00",
  `expiration` datetime NOT NULL,
  `access_duration` varchar(255) default NULL,
  `access_level` varchar(255) DEFAULT 'NONE',
  `category` int DEFAULT NULL,
  `sponsor` tinyint(1) NOT NULL default 0,
  `unregdate` datetime NOT NULL default "0000-00-00 00:00:00",
  `login_remaining` int DEFAULT NULL,
  PRIMARY KEY (tenant_id, pid)
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
  DELETE FROM `password` WHERE pid = OLD.pid AND tenant_id = OLD.tenant_id;
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
    (100121, 'Sunrise', '%s@gsm.sunrise.ch', now()),
    (100122, 'Koodo Mobile', '%s@msg.koodomobile.com', now()),
    (100123, 'Chatr', '%s@pcs.rogers.com', now()),
    (100124, 'Eastlink', '%s@txt.eastlink.ca', now()),
    (100125, 'Freedom', 'txt.freedommobile.ca', now()),
    (100126, 'PC Mobile', '%s@msg.telus.com', now()),
    (100127, 'TBayTel', '%s@pcs.rogers.com', now()),
    (100128, 'Google Project Fi', '%s@msg.fi.google.com', now());

-- Adding RADIUS nas client table

CREATE TABLE radius_nas (
  id int(10) NOT NULL auto_increment,
  `tenant_id` int NOT NULL DEFAULT 1,
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

-- Adding RADIUS accounting table

CREATE TABLE radacct (
  radacctid bigint(21) NOT NULL auto_increment,
  `tenant_id` int NOT NULL DEFAULT 1,
  acctsessionid varchar(64) NOT NULL default '',
  acctuniqueid varchar(32) NOT NULL default '',
  username varchar(64) NOT NULL default '',
  groupname varchar(64) NOT NULL default '',
  realm varchar(64) default '',
  nasipaddress varchar(15) NOT NULL default '',
  nasportid varchar(32) default NULL,
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
  KEY acctinterval (acctinterval),
  KEY acctstoptime (acctstoptime),
  KEY nasipaddress (nasipaddress),
  KEY callingstationid (callingstationid),
  KEY acctstart_acctstop (acctstarttime,acctstoptime)
) ENGINE = INNODB;

-- Adding RADIUS update log table

CREATE TABLE radacct_log (
  id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `tenant_id` int NOT NULL DEFAULT 1,
  acctsessionid varchar(64) NOT NULL default '',
  username varchar(64) NOT NULL default '',
  nasipaddress varchar(15) NOT NULL default '',
  acctstatustype varchar(25) NOT NULL default '',  
  timestamp datetime NULL default NULL,
  acctinputoctets bigint(20) default NULL,
  acctoutputoctets bigint(20) default NULL,
  acctsessiontime int(12) default NULL,
  acctuniqueid varchar(32) NOT NULL default '',
  KEY acctsessionid (acctsessionid),
  KEY username (username),
  KEY nasipaddress (nasipaddress),
  KEY timestamp (timestamp),
  KEY acctuniqueid (acctuniqueid)
) ENGINE=InnoDB;

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
  IF (Previous_Session_Time IS NOT NULL) THEN
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

    # Create new record in the log table
    INSERT INTO radacct_log
     (acctsessionid, username, nasipaddress,
      timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime, acctuniqueid, tenant_id)
    VALUES
     (p_acctsessionid, p_username, p_nasipaddress,
     p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
     (p_acctsessiontime - Previous_Session_Time), p_acctuniqueid, p_tenant_id);
  END IF;
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
-- Table structure for table `scan`
--

CREATE TABLE scan (
  id varchar(20) NOT NULL,
  `tenant_id` int NOT NULL DEFAULT 1,
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
  `tenant_id` int NOT NULL DEFAULT 1,
   ip varchar(16) NOT NULL,
   firstseen DATETIME NOT NULL,
   lastmodified DATETIME NOT NULL,
   status int unsigned NOT NULL default 0,
   PRIMARY KEY (ip, firstseen)
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
  `tenant_id` int NOT NULL DEFAULT 1,
  `pid` varchar(255) default NULL,
  `mac` varchar(17) default NULL,
  `contact_info` varchar(255) NOT NULL, -- email or phone number were approbation request is sent 
  `carrier_id` int(11) NULL,
  `activation_code` varchar(255) NOT NULL,
  `expiration` datetime NOT NULL,
  `unregdate` datetime default NULL,
  `status` varchar(60) default NULL,
  `type` varchar(60) NOT NULL,
  `portal` varchar(255) default NULL,
  `source_id` varchar(255) default NULL,
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

CREATE TABLE pf_version ( `id` INT NOT NULL PRIMARY KEY, `version` VARCHAR(11) NOT NULL UNIQUE KEY) ENGINE=InnoDB;

--
-- Table structure for table 'radius_audit_log'
--

CREATE TABLE radius_audit_log (
  id int NOT NULL AUTO_INCREMENT,
  `tenant_id` int NOT NULL DEFAULT 1,
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
  request_time int(11) DEFAULT NULL,
  PRIMARY KEY (id),
  KEY `created_at` (created_at),
  KEY `mac` (mac),
  KEY `ip` (ip),
  KEY `user_name` (user_name),
  KEY `auth_status` (auth_status, created_at)  
) ENGINE=InnoDB;

--
-- Table structure for table `dhcp_option82`
--

CREATE TABLE `dhcp_option82` (
  `mac` varchar(17) NOT NULL PRIMARY KEY,
  `created_at` TIMESTAMP NOT NULL,
  `option82_switch` varchar(17) NULL,
  `switch_id` varchar(17) NULL,
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(255) default NULL,
  `circuit_id_string` varchar(255) default NULL,
  `module` varchar(255) default NULL,
  `host` varchar(255) default NULL,
  UNIQUE KEY mac (mac)
) ENGINE=InnoDB;

--
-- Table structure for table `dhcp_option82_history`
--

CREATE TABLE `dhcp_option82_history` (
  `dhcp_option82_history_id` int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `mac` varchar(17) NOT NULL,
  `created_at` TIMESTAMP NOT NULL,
  `option82_switch` varchar(17) NULL,
  `switch_id` varchar(17) NULL,
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(255) default NULL,
  `circuit_id_string` varchar(255) default NULL,
  `module` varchar(255) default NULL,
  `host` varchar(255) default NULL,
  INDEX (mac)
) ENGINE=InnoDB;

--
-- Trigger to archive dhcp_option82 entries to the history table after an update
--

DROP TRIGGER IF EXISTS dhcp_option82_after_update_trigger;
DELIMITER /
CREATE TRIGGER dhcp_option82_after_update_trigger AFTER UPDATE ON dhcp_option82
FOR EACH ROW
BEGIN
    INSERT INTO dhcp_option82_history
           (
            created_at,
            mac,
            option82_switch,
            switch_id,
            port,
            vlan,
            circuit_id_string,
            module,
            host
           )
    VALUES
           (
            OLD.created_at,
            OLD.mac,
            OLD.option82_switch,
            OLD.switch_id,
            OLD.port,
            OLD.vlan,
            OLD.circuit_id_string,
            OLD.module,
            OLD.host
           );
END /
DELIMITER ;

--
-- Creating auth_log table
--

CREATE TABLE auth_log (
  `id` int NOT NULL AUTO_INCREMENT,
  `tenant_id` int NOT NULL DEFAULT 1,
  `process_name` varchar(255) NOT NULL,
  `mac` varchar(17) NOT NULL,
  `pid` varchar(255) NOT NULL default "default",
  `status` varchar(255) NOT NULL default "incomplete",
  `attempted_at` datetime NOT NULL,
  `completed_at` datetime,
  `source` varchar(255) NOT NULL,
  `profile` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (id),
  KEY pid (pid),
  KEY  attempted_at (attempted_at)
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
-- Dumping routines for database 'pf'
--
DROP FUNCTION IF EXISTS `FREERADIUS_DECODE`;
DELIMITER ;;
CREATE FUNCTION `FREERADIUS_DECODE`(str text) RETURNS text CHARSET latin1
    DETERMINISTIC
BEGIN 
    DECLARE result text;
    DECLARE ind INT DEFAULT 0;

    SET result = str;
    WHILE ind <= 255 DO
       SET result = REPLACE(result, CONCAT('=', LPAD(LOWER(HEX(ind)), 2, 0)), CHAR(ind));
       SET result = REPLACE(result, CONCAT('=', LPAD(HEX(ind), 2, 0)), CHAR(ind));
       SET ind = ind + 1;
    END WHILE;

    RETURN result;
END ;;
DELIMITER ;

--
-- Table structure for table `key_value_storage`
--

CREATE TABLE key_value_storage (
  id VARCHAR(255),
  value BLOB,
  PRIMARY KEY(id)
) ENGINE=InnoDB;

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));


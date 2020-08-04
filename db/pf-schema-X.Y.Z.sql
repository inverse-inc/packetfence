--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 10;
SET @MINOR_VERSION = 1;
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

SET STATEMENT sql_mode='NO_AUTO_VALUE_ON_ZERO' FOR
    INSERT INTO `tenant` VALUES (0, 'global', NULL, NULL);
INSERT INTO `tenant` VALUES (1, 'default', NULL, NULL);

--
-- Table structure for table `class`
--

CREATE TABLE class (
  security_event_id int(11) NOT NULL,
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
  PRIMARY KEY (security_event_id),
  KEY password_target_category (target_category)
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
) ENGINE=InnoDB;

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
  KEY `node_bypass_role_id` (`bypass_role_id`),
  CONSTRAINT `0_57` FOREIGN KEY (`tenant_id`, `pid`) REFERENCES `person` (`tenant_id`, `pid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `node_category_key` FOREIGN KEY (`category_id`) REFERENCES `node_category` (`category_id`),
  CONSTRAINT `node_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`)
) ENGINE=InnoDB;

--
-- Table structure for table `action`
--

CREATE TABLE action (
  security_event_id int(11) NOT NULL,
  action varchar(255) NOT NULL,
  PRIMARY KEY (security_event_id,action),
  CONSTRAINT `FOREIGN` FOREIGN KEY (`security_event_id`) REFERENCES `class` (`security_event_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

--
-- Table structure for table `security_event`
--

CREATE TABLE security_event (
  id int NOT NULL AUTO_INCREMENT,
  tenant_id int NOT NULL DEFAULT 1,
  mac varchar(17) NOT NULL,
  security_event_id int(11) NOT NULL,
  start_date datetime NOT NULL,
  release_date datetime default "0000-00-00 00:00:00",
  status varchar(10) default "open",
  ticket_ref varchar(255) default NULL,
  notes text,
  KEY security_event_id (security_event_id),
  KEY status (status),
  KEY uniq_mac_status_id (mac,status,security_event_id),
  KEY security_event_release_date (release_date),
  CONSTRAINT `tenant_id_mac_fkey_node` FOREIGN KEY (`tenant_id`, `mac`) REFERENCES `node` (`tenant_id`, `mac`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `security_event_id_fkey_class` FOREIGN KEY (`security_event_id`) REFERENCES `class` (`security_event_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `security_event_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`),
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
  `voip` enum('no','yes') NOT NULL DEFAULT 'no',
  PRIMARY KEY (`tenant_id`, `mac`),
  KEY `locationlog_end_time` ( `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`vlan`),
  KEY `locationlog_ssid` (`ssid`),
  KEY `locationlog_session_id_end_time` (`session_id`, `end_time`),
  CONSTRAINT `locationlog_tenant_id` FOREIGN KEY (`tenant_id`) REFERENCES `tenant` (`id`)
) ENGINE=InnoDB;

CREATE TABLE `locationlog_history` (
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
  `voip` enum('no','yes') NOT NULL DEFAULT 'no',
  KEY `locationlog_view_mac` (`tenant_id`, `mac`, `end_time`),
  KEY `locationlog_end_time` ( `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`),
  KEY `locationlog_ssid` (`ssid`),
  KEY `locationlog_session_id_end_time` (`session_id`, `end_time`)
) ENGINE=InnoDB;

DELIMITER /
CREATE OR REPLACE TRIGGER locationlog_insert_in_history_after_insert AFTER UPDATE on locationlog
FOR EACH ROW
BEGIN
    IF OLD.session_id <=> NEW.session_id THEN
        INSERT INTO locationlog_history
        SET
            tenant_id = OLD.tenant_id,
            mac = OLD.mac,
            switch = OLD.switch,
            port = OLD.port,
            vlan = OLD.vlan,
            role = OLD.role,
            connection_type = OLD.connection_type,
            connection_sub_type = OLD.connection_sub_type,
            dot1x_username = OLD.dot1x_username,
            ssid = OLD.ssid,
            start_time = OLD.start_time,
            end_time = CASE
            WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
            WHEN OLD.end_time > NOW() THEN NOW()
            ELSE OLD.end_time
            END,
            switch_ip = OLD.switch_ip,
            switch_mac = OLD.switch_mac,
            stripped_user_name = OLD.stripped_user_name,
            realm = OLD.realm,
            session_id = OLD.session_id,
            ifDesc = OLD.ifDesc,
            voip = OLD.voip
        ;
  END IF;
END /
DELIMITER ;

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
  PRIMARY KEY (tenant_id, pid),
  KEY password_category (category),
  UNIQUE KEY pid_password_unique (pid)
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
    id integer primary key AUTO_INCREMENT comment 'primary key for SMS carrier',
    name varchar(64) unique key comment 'name of the carrier',
    email_pattern varchar(255) not null comment 'sprintf pattern for making an email address from a phone number',
    created datetime not null comment 'date this record was created',
    modified timestamp comment 'date this record was modified'
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_bin AUTO_INCREMENT = 100056;

--
-- Insert data for table `sms_carrier`
--
-- Source: StatusNet
-- Data fetched on 2011-07-20 from:
-- http://gitorious.org/statusnet/mainline/blobs/raw/master/db/sms_carrier.sql
--

INSERT INTO sms_carrier
    (name, email_pattern, created)
VALUES
    ('3 River Wireless', '%s@sms.3rivers.net', now()),
    ('7-11 Speakout', '%s@cingularme.com', now()),
    ('Airtel (Karnataka, India)', '%s@airtelkk.com', now()),
    ('Alaska Communications Systems', '%s@msg.acsalaska.com', now()),
    ('Alltel Wireless', '%s@message.alltel.com', now()),
    ('AT&T Wireless', '%s@txt.att.net', now()),
    ('Bell Mobility (Canada)', '%s@txt.bell.ca', now()),
    ('Boost Mobile', '%s@myboostmobile.com', now()),
    ('Cellular One (Dobson)', '%s@mobile.celloneusa.com', now()),
    ('Cingular (Postpaid)', '%s@cingularme.com', now()),
    ('Centennial Wireless', '%s@cwemail.com', now()),
    ('Cingular (GoPhone prepaid)', '%s@cingularme.com', now()),
    ('Claro (Nicaragua)', '%s@ideasclaro-ca.com', now()),
    ('Comcel', '%s@comcel.com.co', now()),
    ('Cricket', '%s@sms.mycricket.com', now()),
    ('CTI', '%s@sms.ctimovil.com.ar', now()),
    ('Emtel (Mauritius)', '%s@emtelworld.net', now()),
    ('Fido (Canada)', '%s@fido.ca', now()),
    ('General Communications Inc.', '%s@msg.gci.net', now()),
    ('Globalstar', '%s@msg.globalstarusa.com', now()),
    ('Helio', '%s@myhelio.com', now()),
    ('Illinois Valley Cellular', '%s@ivctext.com', now()),
    ('i wireless', '%s.iws@iwspcs.net', now()),
    ('Meteor (Ireland)', '%s@sms.mymeteor.ie', now()),
    ('Mero Mobile (Nepal)', '%s@sms.spicenepal.com', now()),
    ('MetroPCS', '%s@mymetropcs.com', now()),
    ('Movicom', '%s@movimensaje.com.ar', now()),
    ('Mobitel (Sri Lanka)', '%s@sms.mobitel.lk', now()),
    ('Movistar (Colombia)', '%s@movistar.com.co', now()),
    ('MTN (South Africa)', '%s@sms.co.za', now()),
    ('MTS (Canada)', '%s@text.mtsmobility.com', now()),
    ('Nextel (Argentina)', '%s@nextel.net.ar', now()),
    ('Orange (Poland)', '%s@orange.pl', now()),
    ('Personal (Argentina)', '%s@personal-net.com.ar', now()),
    ('Plus GSM (Poland)', '%s@text.plusgsm.pl', now()),
    ('President\'s Choice (Canada)', '%s@txt.bell.ca', now()),
    ('Qwest', '%s@qwestmp.com', now()),
    ('Rogers (Canada)', '%s@pcs.rogers.com', now()),
    ('Sasktel (Canada)', '%s@sms.sasktel.com', now()),
    ('Setar Mobile email (Aruba)', '%s@mas.aw', now()),
    ('Solo Mobile', '%s@txt.bell.ca', now()),
    ('Sprint (PCS)', '%s@messaging.sprintpcs.com', now()),
    ('Sprint (Nextel)', '%s@page.nextel.com', now()),
    ('Suncom', '%s@tms.suncom.com', now()),
    ('T-Mobile', '%s@tmomail.net', now()),
    ('T-Mobile (Austria)', '%s@sms.t-mobile.at', now()),
    ('Telus Mobility (Canada)', '%s@msg.telus.com', now()),
    ('Thumb Cellular', '%s@sms.thumbcellular.com', now()),
    ('Tigo (Formerly Ola)', '%s@sms.tigo.com.co', now()),
    ('Unicel', '%s@utext.com', now()),
    ('US Cellular', '%s@email.uscc.net', now()),
    ('Verizon', '%s@vtext.com', now()),
    ('Virgin Mobile (Canada)', '%s@vmobile.ca', now()),
    ('Virgin Mobile (USA)', '%s@vmobl.com', now()),
    ('YCC', '%s@sms.ycc.ru', now()),
    ('Orange (UK)', '%s@orange.net', now()),
    ('Cincinnati Bell Wireless', '%s@gocbw.com', now()),
    ('T-Mobile Germany', '%s@t-mobile-sms.de', now()),
    ('Vodafone Germany', '%s@vodafone-sms.de', now()),
    ('E-Plus', '%s@smsmail.eplus.de', now()),
    ('Cellular South', '%s@csouth1.com', now()),
    ('ChinaMobile (139)', '%s@139.com', now()),
    ('Dialog Axiata', '%s@dialog.lk', now()),
    ('Swisscom', '%s@sms.bluewin.ch', now()),
    ('Orange (CH)', '%s@orange.net', now()),
    ('Sunrise', '%s@gsm.sunrise.ch', now()),
    ('Koodo Mobile', '%s@msg.koodomobile.com', now()),
    ('Chatr', '%s@pcs.rogers.com', now()),
    ('Eastlink', '%s@txt.eastlink.ca', now()),
    ('Freedom', '%s@txt.freedommobile.ca', now()),
    ('PC Mobile', '%s@msg.telus.com', now()),
    ('TBayTel', '%s@pcs.rogers.com', now()),
    ('Google Project Fi', '%s@msg.fi.google.com', now());

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
  unique_session_attributes varchar(255),
  PRIMARY KEY nasname (nasname),
  KEY id (id),
  INDEX radius_nas_start_ip_end_ip (start_ip, end_ip)
) ENGINE=InnoDB;

-- Adding RADIUS accounting table

CREATE TABLE radacct (
  `radacctid` bigint(21) NOT NULL AUTO_INCREMENT,
  `tenant_id` int(11) NOT NULL DEFAULT '1',
  `acctsessionid` varchar(64) NOT NULL DEFAULT '',
  `acctuniqueid` varchar(32) NOT NULL DEFAULT '',
  `username` varchar(64) NOT NULL DEFAULT '',
  `groupname` varchar(64) NOT NULL DEFAULT '',
  `realm` varchar(64) DEFAULT '',
  `nasipaddress` varchar(15) NOT NULL DEFAULT '',
  `nasportid` varchar(32) DEFAULT NULL,
  `nasporttype` varchar(32) DEFAULT NULL,
  `acctstarttime` datetime DEFAULT NULL,
  `acctupdatetime` datetime DEFAULT NULL,
  `acctstoptime` datetime DEFAULT NULL,
  `acctinterval` int(12) DEFAULT NULL,
  `acctsessiontime` int(12) unsigned DEFAULT NULL,
  `acctauthentic` varchar(32) DEFAULT NULL,
  `connectinfo_start` varchar(50) DEFAULT NULL,
  `connectinfo_stop` varchar(50) DEFAULT NULL,
  `acctinputoctets` bigint(20) DEFAULT NULL,
  `acctoutputoctets` bigint(20) DEFAULT NULL,
  `calledstationid` varchar(50) NOT NULL DEFAULT '',
  `callingstationid` varchar(50) NOT NULL DEFAULT '',
  `acctterminatecause` varchar(32) NOT NULL DEFAULT '',
  `servicetype` varchar(32) DEFAULT NULL,
  `framedprotocol` varchar(32) DEFAULT NULL,
  `framedipaddress` varchar(15) NOT NULL DEFAULT '',
  `nasidentifier` varchar(64) DEFAULT NULL,
  `calledstationssid` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`radacctid`),
  KEY `acctuniqueid` (`acctuniqueid`),
  KEY `username` (`username`),
  KEY `framedipaddress` (`framedipaddress`),
  KEY `acctsessionid` (`acctsessionid`),
  KEY `acctsessiontime` (`acctsessiontime`),
  KEY `acctinterval` (`acctinterval`),
  KEY `acctstoptime` (`acctstoptime`),
  KEY `nasipaddress` (`nasipaddress`),
  KEY `callingstationid` (`callingstationid`),
  KEY `acctstart_acctstop` (`acctstarttime`,`acctstoptime`)
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

DROP PROCEDURE IF EXISTS `acct_start`;
DELIMITER /
CREATE PROCEDURE `acct_start` (
    IN `p_acctsessionid` varchar(64),
    IN `p_acctuniqueid` varchar(32),
    IN `p_username` varchar(64),
    IN `p_realm` varchar(64),
    IN `p_nasipaddress` varchar(15),
    IN `p_nasportid` varchar(32),
    IN `p_nasporttype` varchar(32),
    IN `p_acctstarttime` datetime,
    IN `p_acctupdatetime` datetime,
    IN `p_acctstoptime` datetime,
    IN `p_acctsessiontime` int(12) unsigned,
    IN `p_acctauthentic` varchar(32),
    IN `p_connectinfo_start` varchar(50),
    IN `p_connectinfo_stop` varchar(50),
    IN `p_acctinputoctets` bigint(20) unsigned,
    IN `p_acctoutputoctets` bigint(20) unsigned,
    IN `p_calledstationid` varchar(50),
    IN `p_callingstationid` varchar(50),
    IN `p_acctterminatecause` varchar(32),
    IN `p_servicetype` varchar(32),
    IN `p_framedprotocol` varchar(32),
    IN `p_framedipaddress` varchar(15),
    IN `p_acctstatustype` varchar(25),
    IN `p_nasidentifier` varchar(64),
    IN `p_calledstationssid` varchar(64),
    IN `p_tenant_id` int(11) unsigned
)
BEGIN

# We make sure there are no left over sessions for which we never received a "stop"
DECLARE `Previous_Session_Time` int(12) unsigned;
SELECT `acctsessiontime`
INTO `Previous_Session_Time`
FROM `radacct`
WHERE `acctuniqueid` = `p_acctuniqueid`
AND (`acctstoptime` IS NULL OR `acctstoptime` = 0) LIMIT 1;

IF (`Previous_Session_Time` IS NOT NULL) THEN
    UPDATE `radacct` SET
      `acctstoptime` = `p_acctstarttime`,
      `acctterminatecause` = 'UNKNOWN'
      WHERE `acctuniqueid` = `p_acctuniqueid`
      AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);
END IF;

INSERT INTO `radacct`
           (
            `acctsessionid`,      `acctuniqueid`,       `username`,
            `realm`,              `nasipaddress`,       `nasportid`,
            `nasporttype`,        `acctstarttime`,      `acctupdatetime`,
            `acctstoptime`,       `acctsessiontime`,    `acctauthentic`,
            `connectinfo_start`,  `connectinfo_stop`,   `acctinputoctets`,
            `acctoutputoctets`,   `calledstationid`,    `callingstationid`,
            `acctterminatecause`, `servicetype`,        `framedprotocol`,
            `framedipaddress`,    `nasidentifier`,      `calledstationssid`,
            `tenant_id`
           )
VALUES
    (
    `p_acctsessionid`, `p_acctuniqueid`, `p_username`,
    `p_realm`, `p_nasipaddress`, `p_nasportid`,
    `p_nasporttype`, `p_acctstarttime`, `p_acctupdatetime`,
    `p_acctstoptime`, `p_acctsessiontime`, `p_acctauthentic`,
    `p_connectinfo_start`, `p_connectinfo_stop`, `p_acctinputoctets`,
    `p_acctoutputoctets`, `p_calledstationid`, `p_callingstationid`,
    `p_acctterminatecause`, `p_servicetype`, `p_framedprotocol`,
    `p_framedipaddress`, `p_nasidentifier`, `p_calledstationssid`,
    `p_tenant_id`
    );



  INSERT INTO `radacct_log`
   (`acctsessionid`, `username`, `nasipaddress`,
    `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`, `tenant_id`)
  VALUES
   (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
    `p_acctstarttime`, `p_acctstatustype`, `p_acctinputoctets`, `p_acctoutputoctets`, `p_acctsessiontime`, `p_acctuniqueid`, `p_tenant_id`);
END /
DELIMITER ;

-- Adding RADIUS Stop Stored Procedure

DROP PROCEDURE IF EXISTS `acct_stop`;
DELIMITER /
CREATE PROCEDURE `acct_stop` (
  IN `p_timestamp` datetime,
  IN `p_framedipaddress` varchar(15),
  IN `p_acctsessiontime` int(12) unsigned,
  IN `p_acctinputoctets` bigint(20) unsigned,
  IN `p_acctoutputoctets` bigint(20) unsigned,
  IN `p_acctuniqueid` varchar(32),
  IN `p_acctsessionid` varchar(64),
  IN `p_username` varchar(64),
  IN `p_realm` varchar(64),
  IN `p_nasipaddress` varchar(15),
  IN `p_nasportid` varchar(32),
  IN `p_nasporttype` varchar(32),
  IN `p_acctauthentic` varchar(32),
  IN `p_connectinfo_stop` varchar(50),
  IN `p_calledstationid` varchar(50),
  IN `p_callingstationid` varchar(50),
  IN `p_servicetype` varchar(32),
  IN `p_framedprotocol` varchar(32),
  IN `p_acctterminatecause` varchar(12),
  IN `p_acctstatustype` varchar(25),
  IN `p_nasidentifier` varchar(64),
  IN `p_calledstationssid` varchar(64),
  IN `p_tenant_id` int(11) unsigned
)
BEGIN
  DECLARE `Previous_Input_Octets` bigint(20) unsigned;
  DECLARE `Previous_Output_Octets` bigint(20) unsigned;
  DECLARE `Previous_Session_Time` int(12) unsigned;

  # Collect traffic previous values in the radacct table
  SELECT `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`
    INTO `Previous_Input_Octets`, `Previous_Output_Octets`, `Previous_Session_Time`
    FROM `radacct`
    WHERE `acctuniqueid` = `p_acctuniqueid`
    AND (`acctstoptime` IS NULL OR `acctstoptime` = 0) LIMIT 1;

  # Set values to 0 when no previous records
  IF (`Previous_Session_Time` IS NOT NULL) THEN
    # Update record with new traffic
    UPDATE `radacct` SET
      `acctstoptime` = `p_timestamp`,
      `acctsessiontime` = `p_acctsessiontime`,
      `acctinputoctets` = `p_acctinputoctets`,
      `acctoutputoctets` = `p_acctoutputoctets`,
      `acctterminatecause` = `p_acctterminatecause`,
      `connectinfo_stop` = `p_connectinfo_stop`
      WHERE `acctuniqueid` = `p_acctuniqueid`
      AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);

    # Create new record in the log table
    INSERT INTO `radacct_log`
     (`acctsessionid`, `username`, `nasipaddress`,
      `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`, `tenant_id`)
    VALUES
     (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
     `p_timestamp`, `p_acctstatustype`, (`p_acctinputoctets` - `Previous_Input_Octets`), (`p_acctoutputoctets` - `Previous_Output_Octets`),
     (`p_acctsessiontime` - `Previous_Session_Time`), `p_acctuniqueid`, `p_tenant_id`);
  END IF;
END /
DELIMITER ;

-- Adding RADIUS Updates Stored Procedure

DROP PROCEDURE IF EXISTS `acct_update`;
DELIMITER /
CREATE PROCEDURE `acct_update`(
  IN `p_timestamp` datetime,
  IN `p_framedipaddress` varchar(15),
  IN `p_acctsessiontime` int(12) unsigned,
  IN `p_acctinputoctets` bigint(20) unsigned,
  IN `p_acctoutputoctets` bigint(20) unsigned,
  IN `p_acctuniqueid` varchar(32),
  IN `p_acctsessionid` varchar(64),
  IN `p_username` varchar(64),
  IN `p_realm` varchar(64),
  IN `p_nasipaddress` varchar(15),
  IN `p_nasportid` varchar(32),
  IN `p_nasporttype` varchar(32),
  IN `p_acctauthentic` varchar(32),
  IN `p_connectinfo_start` varchar(50),
  IN `p_calledstationid` varchar(50),
  IN `p_callingstationid` varchar(50),
  IN `p_servicetype` varchar(32),
  IN `p_framedprotocol` varchar(32),
  IN `p_acctstatustype` varchar(25),
  IN `p_nasidentifier` varchar(64),
  IN `p_calledstationssid` varchar(64),
  IN `p_tenant_id` int(11) unsigned
)
BEGIN
  DECLARE `Previous_Input_Octets` bigint(20) unsigned;
  DECLARE `Previous_Output_Octets` bigint(20) unsigned;
  DECLARE `Previous_Session_Time` int(12) unsigned;
  DECLARE `Previous_AcctUpdate_Time` datetime;

  DECLARE `Opened_Sessions` int(12) unsigned;
  DECLARE `Latest_acctstarttime` datetime;
  DECLARE `cnt` int(12) unsigned;
  DECLARE `countmac` int(12) unsigned;
  SELECT count(`acctuniqueid`), max(`acctstarttime`)
  INTO `Opened_Sessions`, `Latest_acctstarttime`
  FROM `radacct`
  WHERE `acctuniqueid` = `p_acctuniqueid`
  AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);

  IF (`Opened_Sessions` > 1) THEN
      UPDATE `radacct` SET
        `acctstoptime` = NOW(),
        `acctterminatecause` = 'UNKNOWN'
        WHERE `acctuniqueid` = `p_acctuniqueid`
        AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);
  END IF;
  # Detect if we receive in the same time a stop before the interim update
  SELECT COUNT(*)
  INTO `cnt`
  FROM `radacct`
  WHERE `acctuniqueid` = `p_acctuniqueid`
  AND (`acctstoptime` = `p_timestamp`);

  # If there is an old closed entry then update it
  IF (`cnt` = 1) THEN
    UPDATE `radacct` SET
        `framedipaddress` = `p_framedipaddress`,
        `acctsessiontime` = `p_acctsessiontime`,
        `acctinputoctets` = `p_acctinputoctets`,
        `acctoutputoctets` = `p_acctoutputoctets`,
        `acctupdatetime` = `p_timestamp`
    WHERE `acctuniqueid` = `p_acctuniqueid`
    AND (`acctstoptime` = `p_timestamp`);
  END IF;

  #Detect if there is an radacct entry open
  SELECT count(`callingstationid`), `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctupdatetime`
    INTO `countmac`, `Previous_Input_Octets`, `Previous_Output_Octets`, `Previous_Session_Time`, `Previous_AcctUpdate_Time`
    FROM `radacct`
    WHERE (`acctuniqueid` = `p_acctuniqueid`)
    AND (`acctstoptime` IS NULL OR `acctstoptime` = 0) LIMIT 1;

  IF (`countmac` = 1) THEN
    # Update record with new traffic
    UPDATE `radacct` SET
        `framedipaddress` = `p_framedipaddress`,
        `acctsessiontime` = `p_acctsessiontime`,
        `acctinputoctets` = `p_acctinputoctets`,
        `acctoutputoctets` = `p_acctoutputoctets`,
        `acctupdatetime` = `p_timestamp`,
        `acctinterval` = timestampdiff( second, `Previous_AcctUpdate_Time`,  `p_timestamp`  )
    WHERE `acctuniqueid` = `p_acctuniqueid`
    AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);
  ELSE
    IF (`cnt` = 0) THEN
      # If there is no open session for this, open one.
      # Set values to 0 when no previous records
      SET `Previous_Session_Time` = 0;
      SET `Previous_Input_Octets` = 0;
      SET `Previous_Output_Octets` = 0;
      SET `Previous_AcctUpdate_Time` = `p_timestamp`;
      INSERT INTO `radacct`
             (
              `acctsessionid`,`acctuniqueid`,`username`,
              `realm`,`nasipaddress`,`nasportid`,
              `nasporttype`,`acctstarttime`,
              `acctupdatetime`,`acctsessiontime`,`acctauthentic`,
              `connectinfo_start`,`acctinputoctets`,
              `acctoutputoctets`,`calledstationid`,`callingstationid`,
              `servicetype`,`framedprotocol`,
              `framedipaddress`, `nasidentifier`,
              `calledstationssid`, `tenant_id`
             )
      VALUES
          (
              `p_acctsessionid`,`p_acctuniqueid`,`p_username`,
              `p_realm`,`p_nasipaddress`,`p_nasportid`,
              `p_nasporttype`,date_sub(`p_timestamp`, INTERVAL `p_acctsessiontime` SECOND ),
              `p_timestamp`,`p_acctsessiontime`,`p_acctauthentic`,
              `p_connectinfo_start`,`p_acctinputoctets`,
              `p_acctoutputoctets`,`p_calledstationid`,`p_callingstationid`,
              `p_servicetype`,`p_framedprotocol`,
              `p_framedipaddress`, `p_nasidentifier`, `p_calledstationssid`, `p_tenant_id`
          );
     END IF;
   END IF;

  # Create new record in the log table
  INSERT INTO `radacct_log`
   (`acctsessionid`, `username`, `nasipaddress`,
    `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`, `tenant_id`)
  VALUES
   (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
    `p_timestamp`, `p_acctstatustype`, (`p_acctinputoctets` - `Previous_Input_Octets`), (`p_acctoutputoctets` - `Previous_Output_Octets`),
    (`p_acctsessiontime` - `Previous_Session_Time`), `p_acctuniqueid`, `p_tenant_id`);
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
  radius_ip varchar(45) NULL,
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
-- Table structure for table `user_preference`
--

CREATE TABLE user_preference (
  tenant_id int NOT NULL DEFAULT 1,
  pid varchar(255) NOT NULL,
  id varchar(255) NOT NULL,
  value LONGBLOB,
  PRIMARY KEY (`tenant_id`, `pid`, `id`)
) ENGINE=InnoDB;

--
-- Table structure for table `dns_audit_log`
--

CREATE TABLE `dns_audit_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tenant_id` int(11) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `ip` varchar(45) NOT NULL,
  `mac` char(17) NOT NULL,
  `qname` varchar(255) DEFAULT NULL,
  `qtype` varchar(255) DEFAULT NULL,
  `scope` varchar(22) DEFAULT NULL,
  `answer` varchar(255) DEFAULT NULL,
   PRIMARY KEY (`id`),
   KEY `created_at` (`created_at`),
   KEY `mac` (`mac`),
   KEY `ip` (`ip`)
) ENGINE=InnoDB;

--
-- Table structure for table `admin_api_audit_log`
--

CREATE TABLE `admin_api_audit_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tenant_id` int(11) NOT NULL DEFAULT '1',
  `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `user_name` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `action` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `object_id` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `method` varchar(10) COLLATE utf8mb4_bin DEFAULT NULL,
  `request` mediumtext COLLATE utf8mb4_bin,
  `status` smallint(5) NOT NULL,
   PRIMARY KEY (`id`),
   KEY `action` (`action`),
   KEY `user_name` (`user_name`),
   KEY `object_id_action` (`object_id`, `action`),
   KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin ROW_FORMAT=COMPRESSED;


--
-- Table structure for table `dhcppool`
--

CREATE TABLE dhcppool (
  id                    int(11) unsigned NOT NULL auto_increment,
  pool_name             varchar(30) NOT NULL,
  idx                   int(11) NOT NULL,
  mac                   VARCHAR(30) NOT NULL,
  free                  BOOLEAN NOT NULL default '1',
  released              DATETIME(6) NULL default NULL,
  PRIMARY KEY (id),
  UNIQUE KEY dhcppool_poolname_idx (pool_name, idx),
  KEY mac (mac),
  KEY released (released)
) ENGINE=InnoDB;

--
-- Table structure for table `pki_cas`
--

CREATE TABLE `pki_cas` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `cn` varchar(255) DEFAULT NULL,
  `mail` varchar(255) DEFAULT NULL,
  `organisation` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `locality` varchar(255) DEFAULT NULL,
  `street_address` varchar(255) DEFAULT NULL,
  `postal_code` varchar(255) DEFAULT NULL,
  `key_type` int(11) DEFAULT NULL,
  `key_size` int(11) DEFAULT NULL,
  `digest` int(11) DEFAULT NULL,
  `key_usage` varchar(255) DEFAULT NULL,
  `extended_key_usage` varchar(255) DEFAULT NULL,
  `days` int(11) DEFAULT NULL,
  `key` longtext,
  `cert` longtext,
  `issuer_key_hash` varchar(255) DEFAULT NULL,
  `issuer_name_hash` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `cn` (`cn`),
  UNIQUE KEY `uix_cas_issuer_key_hash` (`issuer_key_hash`),
  UNIQUE KEY `uix_cas_issuer_name_hash` (`issuer_name_hash`),
  KEY `mail` (`mail`),
  KEY `organisation` (`organisation`),
  KEY `idx_cas_deleted_at` (`deleted_at`)
) ENGINE=InnoDB AUTO_INCREMENT=2;

--
-- Table structure for table `pki_certs`
--

CREATE TABLE `pki_certs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `cn` varchar(255) DEFAULT NULL,
  `mail` varchar(255) DEFAULT NULL,
  `ca_id` int(10) unsigned DEFAULT NULL,
  `ca_name` varchar(255) DEFAULT NULL,
  `street_address` varchar(255) DEFAULT NULL,
  `organisation` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `locality` varchar(255) DEFAULT NULL,
  `postal_code` varchar(255) DEFAULT NULL,
  `key` longtext,
  `cert` longtext,
  `profile_id` int(10) unsigned DEFAULT NULL,
  `profile_name` varchar(255) DEFAULT NULL,
  `valid_until` timestamp NULL DEFAULT NULL,
  `date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `serial_number` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `cn` (`cn`),
  KEY `profile_name` (`profile_name`),
  KEY `valid_until` (`valid_until`),
  KEY `idx_certs_deleted_at` (`deleted_at`),
  KEY `mail` (`mail`),
  KEY `ca_id` (`ca_id`),
  KEY `ca_name` (`ca_name`),
  KEY `organisation` (`organisation`),
  KEY `profile_id` (`profile_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2;

--
-- Table structure for table `pki_profiles`
--

CREATE TABLE `pki_profiles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `ca_id` int(10) unsigned DEFAULT NULL,
  `ca_name` varchar(255) DEFAULT NULL,
  `validity` int(11) DEFAULT NULL,
  `key_type` int(11) DEFAULT NULL,
  `key_size` int(11) DEFAULT NULL,
  `digest` int(11) DEFAULT NULL,
  `key_usage` varchar(255) DEFAULT NULL,
  `extended_key_usage` varchar(255) DEFAULT NULL,
  `p12_mail_password` int(11) DEFAULT NULL,
  `p12_mail_subject` varchar(255) DEFAULT NULL,
  `p12_mail_from` varchar(255) DEFAULT NULL,
  `p12_mail_header` varchar(255) DEFAULT NULL,
  `p12_mail_footer` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `idx_profiles_deleted_at` (`deleted_at`),
  KEY `ca_id` (`ca_id`),
  KEY `ca_name` (`ca_name`)
) ENGINE=InnoDB AUTO_INCREMENT=3;


--
-- Table structure for table `pki_revoked_certs`
--

CREATE TABLE `pki_revoked_certs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `cn` varchar(255) DEFAULT NULL,
  `mail` varchar(255) DEFAULT NULL,
  `ca_id` int(10) unsigned DEFAULT NULL,
  `ca_name` varchar(255) DEFAULT NULL,
  `street_address` varchar(255) DEFAULT NULL,
  `organisation` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `locality` varchar(255) DEFAULT NULL,
  `postal_code` varchar(255) DEFAULT NULL,
  `key` longtext,
  `cert` longtext,
  `profile_id` int(10) unsigned DEFAULT NULL,
  `profile_name` varchar(255) DEFAULT NULL,
  `valid_until` timestamp NULL DEFAULT NULL,
  `date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `serial_number` varchar(255) DEFAULT NULL,
  `revoked` timestamp NULL DEFAULT NULL,
  `crl_reason` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `valid_until` (`valid_until`),
  KEY `crl_reason` (`crl_reason`),
  KEY `idx_revoked_certs_deleted_at` (`deleted_at`),
  KEY `cn` (`cn`),
  KEY `mail` (`mail`),
  KEY `ca_id` (`ca_id`),
  KEY `profile_id` (`profile_id`),
  KEY `profile_name` (`profile_name`),
  KEY `ca_name` (`ca_name`),
  KEY `organisation` (`organisation`),
  KEY `revoked` (`revoked`)
) ENGINE=InnoDB;

--
-- Table structure for table `bandwidth_accounting`
--

CREATE TABLE bandwidth_accounting (
    node_id BIGINT UNSIGNED NOT NULL,
    unique_session_id BIGINT UNSIGNED NOT NULL,
    time_bucket DATETIME NOT NULL,
    source_type ENUM('net_flow','radius') NOT NULL,
    in_bytes BIGINT SIGNED NOT NULL,
    out_bytes BIGINT SIGNED NOT NULL,
    mac CHAR(17) NOT NULL,
    tenant_id SMALLINT NOT NULL,
    last_updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_bytes BIGINT SIGNED AS (in_bytes + out_bytes) VIRTUAL,
    PRIMARY KEY (node_id, time_bucket, unique_session_id),
    KEY bandwidth_aggregate_buckets (time_bucket, node_id, unique_session_id, in_bytes, out_bytes),
    KEY bandwidth_source_type_time_bucket (source_type, time_bucket),
    KEY bandwidth_last_updated_source_type (last_updated, source_type),
    KEY bandwidth_node_id_unique_session_id_last_updated (node_id, unique_session_id, last_updated),
    KEY bandwidth_accounting_tenant_id_mac (tenant_id, mac)
);

--
-- Table structure for table `bandwidth_accounting_history`
--

CREATE TABLE bandwidth_accounting_history (
    node_id BIGINT UNSIGNED NOT NULL,
    time_bucket DATETIME NOT NULL,
    in_bytes BIGINT SIGNED NOT NULL,
    out_bytes BIGINT SIGNED NOT NULL,
    total_bytes BIGINT SIGNED AS (in_bytes + out_bytes) VIRTUAL,
    mac CHAR(17) NOT NULL,
    tenant_id SMALLINT NOT NULL,
    PRIMARY KEY (node_id, time_bucket),
    KEY bandwidth_aggregate_buckets (time_bucket, node_id, in_bytes, out_bytes),
    KEY bandwidth_accounting_tenant_id_mac (tenant_id, mac)
);

CREATE OR REPLACE FUNCTION ROUND_TO_HOUR (d DATETIME)
    RETURNS DATETIME DETERMINISTIC
        RETURN DATE_ADD(DATE(d), INTERVAL HOUR(d) HOUR);

CREATE OR REPLACE FUNCTION ROUND_TO_MONTH (d DATETIME)
    RETURNS DATETIME DETERMINISTIC
        RETURN DATE_ADD(DATE(d),interval -DAY(d)+1 DAY);

DROP PROCEDURE IF EXISTS `bandwidth_aggregation`;
DELIMITER /
CREATE PROCEDURE `bandwidth_aggregation` (
  IN `p_bucket_size` varchar(255),
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN

    DROP TABLE IF EXISTS to_delete;
    SET @end_bucket= p_end_bucket, @batch = p_batch;
    SET @create_table_to_delete_stmt = CONCAT('CREATE TEMPORARY TABLE to_delete ENGINE=MEMORY, MAX_ROWS=', @batch, ' SELECT node_id, tenant_id, mac, time_bucket as new_time_bucket, time_bucket, unique_session_id, in_bytes, out_bytes, last_updated FROM bandwidth_accounting LIMIT 0');
    PREPARE create_table_to_delete FROM @create_table_to_delete_stmt;
    EXECUTE create_table_to_delete;
    DEALLOCATE PREPARE create_table_to_delete;
    SET @date_rounding = CASE WHEN p_bucket_size = 'monthly' THEN 'ROUND_TO_MONTH' WHEN p_bucket_size = 'daily' THEN 'DATE' ELSE 'ROUND_TO_HOUR' END;
    SET @insert_into_to_delete_stmt = CONCAT('INSERT INTO to_delete SELECT node_id, tenant_id, mac, ',@date_rounding,'(time_bucket) as new_time_bucket, time_bucket, unique_session_id, in_bytes, out_bytes, last_updated FROM bandwidth_accounting FORCE INDEX (bandwidth_source_type_time_bucket) WHERE time_bucket <= ? AND source_type = "radius" AND time_bucket != ',@date_rounding,'(time_bucket) ORDER BY time_bucket DESC LIMIT ?');
    PREPARE insert_into_to_delete FROM @insert_into_to_delete_stmt;

    START TRANSACTION;
    EXECUTE insert_into_to_delete using @end_bucket, @batch;
    SELECT COUNT(*) INTO @count FROM to_delete;
    IF @count > 0 THEN

        INSERT INTO bandwidth_accounting
        (node_id, unique_session_id, tenant_id, mac, time_bucket, in_bytes, out_bytes, last_updated, source_type)
         SELECT
             node_id,
             unique_session_id,
             tenant_id,
             mac,
             new_time_bucket,
             sum(in_bytes) AS in_bytes,
             sum(out_bytes) AS out_bytes,
             MAX(last_updated),
             "radius"
            FROM to_delete
            GROUP BY node_id, unique_session_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes),
                last_updated = GREATEST(last_updated, VALUES(last_updated))
            ;

        DELETE bandwidth_accounting
            FROM to_delete INNER JOIN bandwidth_accounting
            WHERE
                to_delete.node_id = bandwidth_accounting.node_id AND
                to_delete.time_bucket = bandwidth_accounting.time_bucket AND
                to_delete.unique_session_id = bandwidth_accounting.unique_session_id;
    END IF;
    COMMIT;

    DROP TABLE to_delete;
    DEALLOCATE PREPARE insert_into_to_delete;
    SELECT @count AS aggreated;
END /
DELIMITER ;

DROP PROCEDURE IF EXISTS `process_bandwidth_accounting_netflow`;
DELIMITER /
CREATE PROCEDURE `process_bandwidth_accounting_netflow` (
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN
    SET @batch = p_batch;
    SET @end_bucket = p_end_bucket;
    DROP TABLE IF EXISTS to_process;
    CREATE TEMPORARY TABLE to_process ENGINE=MEMORY SELECT node_id, tenant_id, mac, time_bucket, time_bucket as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting LIMIT 0;
    START TRANSACTION;
    PREPARE insert_into_to_process FROM 'INSERT to_process SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting WHERE source_type = "net_flow" AND time_bucket < ? LIMIT ?';
    EXECUTE insert_into_to_process USING @end_bucket, @batch;
    DEALLOCATE PREPARE insert_into_to_process;
    SELECT COUNT(*) INTO @count FROM to_process;
    IF @count > 0 THEN
        UPDATE 
            (SELECT tenant_id, mac, SUM(total_bytes) AS total_bytes FROM to_process GROUP BY node_id) AS x 
            LEFT JOIN node USING(tenant_id, mac)
            SET node.bandwidth_balance = GREATEST(node.bandwidth_balance - total_bytes, 0)
            WHERE node.bandwidth_balance IS NOT NULL;

        INSERT INTO bandwidth_accounting_history
        (node_id, tenant_id, mac, time_bucket, in_bytes, out_bytes)
         SELECT
             node_id,
             tenant_id,
             mac,
             new_time_bucket,
             sum(in_bytes) AS in_bytes,
             sum(out_bytes) AS out_bytes
            FROM to_process
            GROUP BY node_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes)
            ;

        DELETE bandwidth_accounting
            FROM to_process INNER JOIN bandwidth_accounting
            WHERE
                to_process.node_id = bandwidth_accounting.node_id AND
                to_process.time_bucket = bandwidth_accounting.time_bucket AND
                to_process.unique_session_id = bandwidth_accounting.unique_session_id;

    END IF;
    COMMIT;

    DROP TABLE to_process;
    SELECT @count as count;
END/

DELIMITER ;

DROP PROCEDURE IF EXISTS `bandwidth_accounting_radius_to_history`;
DELIMITER /
CREATE PROCEDURE `bandwidth_accounting_radius_to_history` (
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN
    SET @batch = p_batch;
    SET @end_bucket = p_end_bucket;
    DROP TABLE IF EXISTS to_delete;
    CREATE TEMPORARY TABLE to_delete ENGINE=MEMORY SELECT node_id, tenant_id, mac, time_bucket, time_bucket as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting LIMIT 0;
    START TRANSACTION;
    PREPARE insert_into_to_delete FROM 'INSERT to_delete SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting WHERE source_type = "radius" AND time_bucket < ? AND last_updated = "0000-00-00 00:00:00" LIMIT ?';
    EXECUTE insert_into_to_delete USING @end_bucket, @batch;
    DEALLOCATE PREPARE insert_into_to_delete;
    SELECT COUNT(*) INTO @count FROM to_delete;
    IF @count > 0 THEN

        INSERT INTO bandwidth_accounting_history
        (node_id, tenant_id, mac, time_bucket, in_bytes, out_bytes)
         SELECT
             node_id,
             tenant_id,
             mac,
             new_time_bucket,
             sum(in_bytes) AS in_bytes,
             sum(out_bytes) AS out_bytes
            FROM to_delete
            GROUP BY node_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes)
            ;

        DELETE bandwidth_accounting
            FROM to_delete INNER JOIN bandwidth_accounting
            WHERE
                to_delete.node_id = bandwidth_accounting.node_id AND
                to_delete.time_bucket = bandwidth_accounting.time_bucket AND
                to_delete.unique_session_id = bandwidth_accounting.unique_session_id;

    END IF;
    COMMIT;

    DROP TABLE to_delete;
    SELECT @count as count;
END/

DELIMITER ;

DROP PROCEDURE IF EXISTS `bandwidth_aggregation_history`;
DELIMITER /
CREATE PROCEDURE `bandwidth_aggregation_history` (
  IN `p_bucket_size` varchar(255),
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN

    DROP TABLE IF EXISTS to_delete;
    SET @end_bucket= p_end_bucket, @batch = p_batch;
    SET @create_table_to_delete_stmt = CONCAT('CREATE TEMPORARY TABLE to_delete ENGINE=MEMORY, MAX_ROWS=', @batch, ' SELECT node_id, tenant_id, mac, time_bucket as new_time_bucket, time_bucket, in_bytes, out_bytes FROM bandwidth_accounting_history LIMIT 0');
    PREPARE create_table_to_delete FROM @create_table_to_delete_stmt;
    EXECUTE create_table_to_delete;
    DEALLOCATE PREPARE create_table_to_delete;
    SET @date_rounding = CASE WHEN p_bucket_size = 'monthly' THEN 'ROUND_TO_MONTH' WHEN p_bucket_size = 'daily' THEN 'DATE' ELSE 'ROUND_TO_HOUR' END;
    SET @insert_into_to_delete_stmt = CONCAT('INSERT INTO to_delete SELECT node_id, tenant_id, mac, ', @date_rounding,'(time_bucket) as new_time_bucket, time_bucket, in_bytes, out_bytes FROM bandwidth_accounting_history WHERE time_bucket <= ? AND time_bucket != ', @date_rounding, '(time_bucket) LIMIT ?');
    PREPARE insert_into_to_delete FROM @insert_into_to_delete_stmt;

    START TRANSACTION;
    EXECUTE insert_into_to_delete using @end_bucket, @batch;
    SELECT COUNT(*) INTO @count FROM to_delete;
    IF @count > 0 THEN
        INSERT INTO bandwidth_accounting_history
        (node_id, tenant_id, mac, time_bucket, in_bytes, out_bytes)
         SELECT
             node_id,
             tenant_id,
             mac,
             new_time_bucket,
             sum(in_bytes) AS in_bytes,
             sum(out_bytes) AS out_bytes
            FROM to_delete
            GROUP BY node_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes)
            ;

        DELETE bandwidth_accounting_history
            FROM to_delete INNER JOIN bandwidth_accounting_history
            WHERE
                to_delete.node_id = bandwidth_accounting_history.node_id AND
                to_delete.time_bucket = bandwidth_accounting_history.time_bucket;
    END IF;
    COMMIT;

    DROP TABLE to_delete;
    DEALLOCATE PREPARE insert_into_to_delete;
    SELECT @count AS aggreated;
END /
DELIMITER ;

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

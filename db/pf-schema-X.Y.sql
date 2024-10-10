SET sql_mode = "NO_ENGINE_SUBSTITUTION";

--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 14;
SET @MINOR_VERSION = 1;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8;

--
-- Table structure for table `class`
--

CREATE TABLE class (
  `security_event_id` int(11) NOT NULL,
  `description` varchar(255) NOT NULL default "none",
  `auto_enable` char(1) NOT NULL default "Y",
  `max_enables` int(11) NOT NULL default 0,
  `grace_period` int(11) NOT NULL,
  `window` varchar(255) NOT NULL default 0,
  `vclose` int(11),
  `priority` int(11) NOT NULL,
  `template` varchar(255),
  `max_enable_url` varchar(255),
  `redirect_url` varchar(255),
  `button_text` varchar(255),
  `enabled` char(1) NOT NULL default "N",
  `vlan` varchar(255),
  `target_category` varchar(255),
  `delay_by` int(11) NOT NULL default 0,
  `external_command` varchar(255) DEFAULT NULL,
  PRIMARY KEY (security_event_id),
  KEY password_target_category (target_category)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `person`
--

CREATE TABLE person (
  `pid` varchar(255) NOT NULL,
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
  `otp` MEDIUMTEXT NULL DEFAULT NULL,
  `sponsored_date` DATETIME DEFAULT NULL,
  PRIMARY KEY (`pid`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `node_category`
--

CREATE TABLE `node_category` (
  `category_id` BIGINT NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `max_nodes_per_pid` int default 0,
  `notes` varchar(255) default NULL,
  `include_parent_acls` varchar(255) default NULL,
  `fingerbank_dynamic_access_list` varchar(255) default NULL,
  `acls` MEDIUMTEXT NOT NULL default '',
  `inherit_vlan` varchar(50) default NULL,
  `inherit_role` varchar(50) default NULL,
  `inherit_web_auth_url` varchar(50) default NULL,
  PRIMARY KEY (`category_id`),
  UNIQUE KEY node_category_name (`name`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

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
  `mac` varchar(17) NOT NULL,
  `pid` varchar(255) NOT NULL default "default",
  `category_id` bigint default NULL,
  `detect_date` datetime NOT NULL default "0000-00-00 00:00:00",
  `regdate` datetime NOT NULL default "0000-00-00 00:00:00",
  `unregdate` datetime NOT NULL default "0000-00-00 00:00:00",
  `time_balance` int(10) unsigned DEFAULT NULL,
  `bandwidth_balance` bigint(20) unsigned DEFAULT NULL,
  `status` varchar(15) NOT NULL default "unreg",
  `user_agent` varchar(255) default NULL,
  `computername` varchar(255) default NULL,
  `notes` varchar(255) default NULL,
  `last_arp` datetime NOT NULL default "0000-00-00 00:00:00",
  `last_dhcp` datetime NOT NULL default "0000-00-00 00:00:00",
  `dhcp_fingerprint` varchar(255) default NULL,
  `dhcp6_fingerprint` varchar(255) default NULL,
  `dhcp_vendor` varchar(255) default NULL,
  `dhcp6_enterprise` varchar(255) default NULL,
  `device_type` varchar(255) default NULL,
  `device_class` varchar(255) default NULL,
  `device_version` varchar(255) DEFAULT NULL,
  `device_score` int DEFAULT NULL,
  `device_manufacturer` varchar(255) DEFAULT NULL,
  `bypass_vlan` varchar(50) default NULL,
  `voip` enum('no','yes') NOT NULL DEFAULT 'no',
  `autoreg` enum('no','yes') NOT NULL DEFAULT 'no',
  `sessionid` varchar(30) default NULL,
  `machine_account` varchar(255) default NULL,
  `bypass_role_id` int default NULL,
  `last_seen` DATETIME NOT NULL DEFAULT "0000-00-00 00:00:00",
  `bypass_acls` MEDIUMTEXT DEFAULT NULL,
  PRIMARY KEY (mac),
  KEY pid (pid),
  KEY category_id (category_id),
  KEY `node_status` (`status`, `unregdate`),
  KEY `node_dhcpfingerprint` (`dhcp_fingerprint`),
  KEY `node_last_seen` (`last_seen`),
  KEY `node_bypass_role_id` (`bypass_role_id`),
  CONSTRAINT `0_57` FOREIGN KEY (`pid`) REFERENCES `person` ( `pid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `node_category_key` FOREIGN KEY (`category_id`) REFERENCES `node_category` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `node_current_session`
--

CREATE TABLE node_current_session (
  `mac` varchar(17) NOT NULL,
  `updated` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_session_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `is_online` BOOLEAN DEFAULT 1,
  PRIMARY KEY (mac)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `node_meta`
--

CREATE TABLE node_meta (
    `name` varchar(255) NOT NULL,
    `mac` varchar(17) NOT NULL,
    `value` MEDIUMBLOB NULL,
    PRIMARY KEY(name, mac)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci' ROW_FORMAT=COMPRESSED;

--
-- Table structure for table `action`
--

CREATE TABLE action (
  `security_event_id` int(11) NOT NULL,
  `action` varchar(255) NOT NULL,
  PRIMARY KEY (security_event_id,action),
  CONSTRAINT `FOREIGN` FOREIGN KEY (`security_event_id`) REFERENCES `class` (`security_event_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `security_event`
--

CREATE TABLE security_event (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `mac` varchar(17) NOT NULL,
  `security_event_id` int(11) NOT NULL,
  `start_date` datetime NOT NULL,
  `release_date` datetime default "0000-00-00 00:00:00",
  `status` varchar(10) default "open",
  `ticket_ref` varchar(255) default NULL,
  `notes` MEDIUMTEXT,
  KEY security_event_id (security_event_id),
  KEY status (status),
  KEY uniq_mac_status_id (mac,status,security_event_id),
  KEY security_event_release_date (release_date),
  CONSTRAINT `mac_fkey_node` FOREIGN KEY (`mac`) REFERENCES `node` (`mac`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `security_event_id_fkey_class` FOREIGN KEY (`security_event_id`) REFERENCES `class` (`security_event_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `ip4log`
--

CREATE TABLE ip4log (
  `mac` varchar(17) NOT NULL,
  `ip` varchar(45) NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime default "0000-00-00 00:00:00",
  PRIMARY KEY (`ip`),
  KEY ip4log_mac_end_time (mac,end_time),
  KEY ip4log_mac_start_time (mac, start_time),
  KEY ip4log_end_time (end_time)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Trigger to insert old record from 'ip4log' in 'ip4log_history' before updating the current one
--

DROP TRIGGER IF EXISTS ip4log_insert_in_ip4log_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER ip4log_insert_in_ip4log_history_before_update_trigger BEFORE UPDATE ON ip4log
FOR EACH ROW
BEGIN
  INSERT INTO ip4log_history SET ip = OLD.ip, mac = OLD.mac, start_time = OLD.start_time, end_time = CASE
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
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `mac` varchar(17) NOT NULL,
  `ip` varchar(45) NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  KEY ip4log_history_mac_end_time (mac,end_time),
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `ip4log_archive`
--

CREATE TABLE ip4log_archive (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `mac` varchar(17) NOT NULL,
  `ip` varchar(45) NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `ip6log`
--

CREATE TABLE ip6log (
  `mac` varchar(17) NOT NULL,
  `ip` varchar(45) NOT NULL,
  `type` varchar(32) DEFAULT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime default "0000-00-00 00:00:00",
  PRIMARY KEY (ip),
  KEY ip6log_mac_end_time (mac,end_time),
  KEY ip6log_end_time (end_time)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Trigger to insert old record from 'ip6log' in 'ip6log_history' before updating the current one
--

DROP TRIGGER IF EXISTS ip6log_insert_in_ip6log_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER ip6log_insert_in_ip6log_history_before_update_trigger BEFORE UPDATE ON ip6log
FOR EACH ROW
BEGIN
  INSERT INTO ip6log_history SET ip = OLD.ip, mac = OLD.mac, type = OLD.type, start_time = OLD.start_time, end_time = CASE
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
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `mac` varchar(17) NOT NULL,
  `ip` varchar(45) NOT NULL,
  `type` varchar(32) DEFAULT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  KEY ip6log_history_mac_end_time (mac,end_time),
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `ip6log_archive`
--

CREATE TABLE ip6log_archive (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `mac` varchar(17) NOT NULL,
  `ip` varchar(45) NOT NULL,
  `type` varchar(32) DEFAULT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';


CREATE TABLE `locationlog` (
  `mac` varchar(17) NOT NULL,
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
  `switch_ip_int` int(10) unsigned AS (INET_ATON(`switch_ip`)) STORED,
  `switch_mac` varchar(17) DEFAULT NULL,
  `stripped_user_name` varchar (255) DEFAULT NULL,
  `realm`  varchar (255) DEFAULT NULL,
  `session_id` VARCHAR(255) DEFAULT NULL,
  `ifDesc` VARCHAR(255) DEFAULT NULL,
  `voip` enum('no','yes') NOT NULL DEFAULT 'no',
  PRIMARY KEY (`mac`),
  KEY `locationlog_end_time` ( `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`vlan`),
  KEY `locationlog_ssid` (`ssid`),
  KEY `locationlog_session_id_end_time` (`session_id`, `end_time`),
  KEY `locationlog_switch_ip_int` (`switch_ip_int`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

CREATE TABLE `locationlog_history` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
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
  `switch_ip_int` int(10) unsigned AS (INET_ATON(`switch_ip`)) STORED,
  `switch_mac` varchar(17) DEFAULT NULL,
  `stripped_user_name` varchar (255) DEFAULT NULL,
  `realm`  varchar (255) DEFAULT NULL,
  `session_id` VARCHAR(255) DEFAULT NULL,
  `ifDesc` VARCHAR(255) DEFAULT NULL,
  `voip` enum('no','yes') NOT NULL DEFAULT 'no',
  KEY `locationlog_view_mac` (`mac`, `end_time`),
  KEY `locationlog_end_time` ( `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`),
  KEY `locationlog_ssid` (`ssid`),
  KEY `locationlog_session_id_end_time` (`session_id`, `end_time`),
  KEY `locationlog_switch_ip_int` (`switch_ip_int`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

DELIMITER /
DROP TRIGGER IF EXISTS locationlog_insert_in_history_after_insert;
CREATE TRIGGER locationlog_insert_in_history_after_insert AFTER UPDATE on locationlog
FOR EACH ROW
BEGIN
    IF OLD.session_id <=> NEW.session_id THEN
        INSERT INTO locationlog_history
        SET
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

--
-- Table structure for table `password`
--

CREATE TABLE `password` (
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
  PRIMARY KEY (pid),
  KEY password_category (category),
  UNIQUE KEY pid_password_unique (pid)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Insert default users
--

INSERT INTO `person` (pid,notes) VALUES ("admin","Default Admin User - do not delete");
INSERT INTO `person` (pid,notes) VALUES ("default","Default User - do not delete");
INSERT INTO password (pid, password, valid_from, expiration, access_duration, access_level, category) VALUES ('admin', 'admin', '1970-01-01', '2038-01-01', NULL, 'ALL', NULL);

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
    `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT comment 'primary key for SMS carrier',
    `name` varchar(64) unique key comment 'name of the carrier',
    `email_pattern` varchar(255) not null comment 'sprintf pattern for making an email address from a phone number',
    `created` datetime not null comment 'date this record was created',
    `modified` timestamp comment 'date this record was modified'
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci' AUTO_INCREMENT = 100056;

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
    ('Google Project Fi', '%s@msg.fi.google.com', now()),
    ('RingRing', '%s@smsemail.be', now());

-- Adding RADIUS nas client table

CREATE TABLE radius_nas (
  `id` int(10) NOT NULL auto_increment,
  `nasname` varchar(128) NOT NULL,
  `shortname` varchar(32),
  `type` varchar(30) default 'other',
  `ports` int(5),
  `secret` varchar(60) default 'secret' NOT NULL,
  `server` varchar(64),
  `community` varchar(50),
  `description` varchar(200) default 'RADIUS Client',
  `config_timestamp` BIGINT,
  `start_ip` INT UNSIGNED DEFAULT 0,
  `end_ip` INT UNSIGNED DEFAULT 0,
  `range_length` INT DEFAULT 0,
  `unique_session_attributes` varchar(255),
  PRIMARY KEY nasname (nasname),
  KEY id (id),
  INDEX radius_nas_start_ip_end_ip (start_ip, end_ip)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

-- Adding RADIUS accounting table

CREATE TABLE radacct (
  `radacctid` bigint(21) NOT NULL AUTO_INCREMENT,
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
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

-- Adding RADIUS update log table

CREATE TABLE radacct_log (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `acctsessionid` varchar(64) NOT NULL default '',
  `username` varchar(64) NOT NULL default '',
  `nasipaddress` varchar(15) NOT NULL default '',
  `acctstatustype` varchar(25) NOT NULL default '',
  `timestamp` datetime NULL default NULL,
  `acctinputoctets` bigint(20) default NULL,
  `acctoutputoctets` bigint(20) default NULL,
  `acctsessiontime` int(12) default NULL,
  `acctuniqueid` varchar(32) NOT NULL default '',
  KEY acctsessionid (acctsessionid),
  KEY username (username),
  KEY nasipaddress (nasipaddress),
  KEY timestamp (timestamp),
  KEY acctuniqueid (acctuniqueid)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

-- Adding RADIUS radreply table

CREATE TABLE radreply (
  `id` int(11) unsigned NOT NULL auto_increment,
  `username` varchar(64) NOT NULL default '',
  `attribute` varchar(64) NOT NULL default '',
  `op` char(2) NOT NULL DEFAULT ':=',
  `value` varchar(253) NOT NULL default '',
  PRIMARY KEY (id),
  KEY (`username`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

INSERT INTO radreply (username, attribute, value, op) values ('00:00:00:00:00:00','User-Name','*', '=*');

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
    IN `p_calledstationssid` varchar(64)
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
            `framedipaddress`,    `nasidentifier`,      `calledstationssid`
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
    `p_framedipaddress`, `p_nasidentifier`, `p_calledstationssid`
    );



  INSERT INTO `radacct_log`
   (`acctsessionid`, `username`, `nasipaddress`,
    `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`)
  VALUES
   (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
    `p_acctstarttime`, `p_acctstatustype`, `p_acctinputoctets`, `p_acctoutputoctets`, `p_acctsessiontime`, `p_acctuniqueid`);
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
  IN `p_calledstationssid` varchar(64)
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
      `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`)
    VALUES
     (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
     `p_timestamp`, `p_acctstatustype`, (`p_acctinputoctets` - `Previous_Input_Octets`), (`p_acctoutputoctets` - `Previous_Output_Octets`),
     (`p_acctsessiontime` - `Previous_Session_Time`), `p_acctuniqueid`);
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
  IN `p_calledstationssid` varchar(64)
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

    INSERT INTO `radacct_log`
     (`acctsessionid`, `username`, `nasipaddress`,
      `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`)
    VALUES
     (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
      `p_timestamp`, `p_acctstatustype`, (`p_acctinputoctets` - `Previous_Input_Octets`), (`p_acctoutputoctets` - `Previous_Output_Octets`),
      (`p_acctsessiontime` - `Previous_Session_Time`), `p_acctuniqueid`);

  ELSE
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
              `calledstationssid`
             )
      VALUES
          (
              `p_acctsessionid`,`p_acctuniqueid`,`p_username`,
              `p_realm`,`p_nasipaddress`,`p_nasportid`,
              `p_nasporttype`,`p_timestamp`,
              `p_timestamp`,0,`p_acctauthentic`,
              `p_connectinfo_start`,0,
              0,`p_calledstationid`,`p_callingstationid`,
              `p_servicetype`,`p_framedprotocol`,
              `p_framedipaddress`, `p_nasidentifier`, `p_calledstationssid`
          );

      INSERT INTO `radacct_log`
       (`acctsessionid`, `username`, `nasipaddress`,
        `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`)
      VALUES
       (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
       `p_timestamp`, `p_acctstatustype`, 0, 0,
       0, `p_acctuniqueid`);

   END IF;
END /
DELIMITER ;

--
-- Table structure for table `scan`
--

CREATE TABLE scan (
  `id` varchar(20) NOT NULL,
  `ip` varchar(255) NOT NULL,
  `mac` varchar(17) NOT NULL,
  `type` varchar(255) NOT NULL,
  `start_date` datetime NOT NULL,
  `update_date` timestamp NOT NULL ON UPDATE CURRENT_TIMESTAMP,
  `status` varchar(255) NOT NULL,
  `report_id` varchar(255) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `billing`
--

CREATE TABLE billing (
  `id` varchar(20) NOT NULL,
  `ip` varchar(255) NOT NULL,
  `mac` varchar(17) NOT NULL,
  `type` varchar(255) NOT NULL,
  `start_date` datetime NOT NULL,
  `update_date` timestamp NOT NULL ON UPDATE CURRENT_TIMESTAMP,
  `status` varchar(255) NOT NULL,
  `item` varchar(255) NOT NULL,
  `price` varchar(255) NOT NULL,
  `person` varchar(255) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for wrix
--

CREATE TABLE wrix (
  `id` varchar(255) NOT NULL,
  `Provider_Identifier` varchar(64) NULL DEFAULT NULL,
  `Location_Identifier` varchar(64) NULL DEFAULT NULL,
  `Service_Provider_Brand` varchar(64) NULL DEFAULT NULL,
  `Location_Type` varchar(64) NULL DEFAULT NULL,
  `Sub_Location_Type` varchar(64) NULL DEFAULT NULL,
  `English_Location_Name` MEDIUMTEXT NULL DEFAULT NULL,
  `Location_Address1` varchar(128) NULL DEFAULT NULL,
  `Location_Address2` varchar(128) NULL DEFAULT NULL,
  `English_Location_City` varchar(64) NULL DEFAULT NULL,
  `Location_Zip_Postal_Code` varchar(32) NULL DEFAULT NULL,
  `Location_State_Province_Name` varchar(64) NULL DEFAULT NULL,
  `Location_Country_Name` varchar(16) NULL DEFAULT NULL,
  `Location_Phone_Number` varchar(32) NULL DEFAULT NULL,
  `SSID_Open_Auth` varchar(32) NULL DEFAULT NULL,
  `SSID_Broadcasted` char(1) NULL DEFAULT NULL,
  `WEP_Key` varchar(128) NULL DEFAULT NULL,
  `WEP_Key_Entry_Method` varchar(32) NULL DEFAULT NULL,
  `WEP_Key_Size` varchar(32) NULL DEFAULT NULL,
  `SSID_1X` varchar(32) NULL DEFAULT NULL,
  `SSID_1X_Broadcasted` varchar(1) NULL DEFAULT NULL,
  `Security_Protocol_1X` varchar(16) NULL DEFAULT NULL,
  `Client_Support` varchar(128) NULL DEFAULT NULL,
  `Restricted_Access` varchar(1) NULL DEFAULT NULL,
  `Location_URL` varchar(128) NULL DEFAULT NULL,
  `Coverage_Area` varchar(255) NULL DEFAULT NULL,
  `Open_Monday` varchar(32) NULL DEFAULT NULL,
  `Open_Tuesday` varchar(32) NULL DEFAULT NULL,
  `Open_Wednesday` varchar(32) NULL DEFAULT NULL,
  `Open_Thursday` varchar(32) NULL DEFAULT NULL,
  `Open_Friday` varchar(32) NULL DEFAULT NULL,
  `Open_Saturday` varchar(32) NULL DEFAULT NULL,
  `Open_Sunday` varchar(32) NULL DEFAULT NULL,
  `Longitude` varchar(32) NULL DEFAULT NULL,
  `Latitude` varchar(32) NULL DEFAULT NULL,
  `UTC_Timezone` varchar(16) NULL DEFAULT NULL,
  `MAC_Address` varchar(32) NULL DEFAULT NULL,
   PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `activation`
--

CREATE TABLE activation (
  `code_id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `pid` varchar(255) default NULL,
  `mac` varchar(17) default NULL,
  `contact_info` varchar(255) NOT NULL, -- email or phone number were approbation request is sent
  `carrier_id` int(11) NULL,
  `activation_code` varchar(255) NOT NULL,
  `expiration` datetime NOT NULL,
  `unregdate` datetime default NULL,
  `category_id` int default NULL,
  `status` varchar(60) default NULL,
  `type` varchar(60) NOT NULL,
  `portal` varchar(255) default NULL,
  `source_id` varchar(255) default NULL,
  KEY `mac` (mac),
  KEY `identifier` (pid, mac),
  KEY `activation` (activation_code, status)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';


--
-- Table structure for table `keyed`
--

CREATE TABLE keyed (
  `id` VARCHAR(255),
  `value` LONGBLOB,
  PRIMARY KEY(id)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table 'pf_version'
--

CREATE TABLE pf_version (`id` INT NOT NULL PRIMARY KEY, `version` VARCHAR(11) NOT NULL UNIQUE KEY, `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table 'radius_audit_log'
--

CREATE TABLE radius_audit_log (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `mac` char(17) NOT NULL,
  `ip` varchar(255) NULL,
  `computer_name` varchar(255) NULL,
  `user_name` varchar(255) NULL,
  `stripped_user_name` varchar(255) NULL,
  `realm` varchar(255) NULL,
  `event_type` varchar(255) NULL,
  `switch_id` varchar(255) NULL,
  `switch_mac` varchar(255) NULL,
  `switch_ip_address` varchar(255) NULL,
  `radius_source_ip_address` varchar(255),
  `called_station_id` varchar(255) NULL,
  `calling_station_id` varchar(255) NULL,
  `nas_port_type` varchar(255) NULL,
  `ssid` varchar(255) NULL,
  `nas_port_id` varchar(255) NULL,
  `ifindex` varchar(255) NULL,
  `nas_port` varchar(255) NULL,
  `connection_type` varchar(255) NULL,
  `nas_ip_address` varchar(255) NULL,
  `nas_identifier` varchar(255) NULL,
  `auth_status` varchar(255) NULL,
  `reason` MEDIUMTEXT NULL,
  `auth_type` varchar(255) NULL,
  `eap_type` varchar(255) NULL,
  `role` varchar(255) NULL,
  `node_status` varchar(255) NULL,
  `profile` varchar(255) NULL,
  `source` varchar(255) NULL,
  `auto_reg` char(1) NULL,
  `is_phone` char(1) NULL,
  `pf_domain` varchar(255) NULL,
  `uuid` varchar(255) NULL,
  `radius_request` MEDIUMTEXT,
  `radius_reply` MEDIUMTEXT,
  `request_time` int(11) DEFAULT NULL,
  `radius_ip` varchar(45) NULL,
  KEY `created_at` (created_at),
  KEY `mac` (mac),
  KEY `ip` (ip),
  KEY `user_name` (user_name),
  KEY `auth_status` (auth_status, created_at)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `dhcp_option82`
--

CREATE TABLE `dhcp_option82` (
  `mac` varchar(17) NOT NULL PRIMARY KEY,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  `option82_switch` varchar(17) NULL,
  `switch_id` varchar(17) NULL,
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(255) default NULL,
  `circuit_id_string` varchar(255) default NULL,
  `module` varchar(255) default NULL,
  `host` varchar(255) default NULL,
  UNIQUE KEY mac (mac)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `dhcp_option82_history`
--

CREATE TABLE `dhcp_option82_history` (
  `dhcp_option82_history_id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `mac` varchar(17) NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
  `option82_switch` varchar(17) NULL,
  `switch_id` varchar(17) NULL,
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(255) default NULL,
  `circuit_id_string` varchar(255) default NULL,
  `module` varchar(255) default NULL,
  `host` varchar(255) default NULL,
  INDEX (mac)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

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
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `process_name` varchar(255) NOT NULL,
  `mac` varchar(17) NOT NULL,
  `pid` varchar(255) NOT NULL default "default",
  `status` varchar(255) NOT NULL default "incomplete",
  `attempted_at` datetime NOT NULL,
  `completed_at` datetime,
  `source` varchar(255) NOT NULL,
  `profile` VARCHAR(255) DEFAULT NULL,
  KEY pid (pid),
  KEY attempted_at (attempted_at),
  KEY completed_at (completed_at)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Creating chi_cache table
--

CREATE TABLE `chi_cache` (
  `key` VARCHAR(767),
  `value` LONGBLOB,
  `expires_at` REAL,
  PRIMARY KEY (`key`),
  KEY chi_cache_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Dumping routines for database 'pf'
--
DROP FUNCTION IF EXISTS `FREERADIUS_DECODE`;
DELIMITER ;;
CREATE FUNCTION `FREERADIUS_DECODE`(str text) RETURNS MEDIUMTEXT CHARSET utf8mb4
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
  `id` VARCHAR(255),
  `value` BLOB,
  PRIMARY KEY(id)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `user_preference`
--

CREATE TABLE user_preference (
  `pid` varchar(255) NOT NULL,
  `id` varchar(255) NOT NULL,
  `value` LONGBLOB,
  PRIMARY KEY ( `pid`, `id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `dns_audit_log`
--

CREATE TABLE `dns_audit_log` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `ip` varchar(45) NOT NULL,
  `mac` char(17) NOT NULL,
  `qname` varchar(255) DEFAULT NULL,
  `qtype` varchar(255) DEFAULT NULL,
  `scope` varchar(22) DEFAULT NULL,
  `answer` varchar(255) DEFAULT NULL,
   KEY `created_at` (`created_at`),
   KEY `mac` (`mac`),
   KEY `ip` (`ip`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `admin_api_audit_log`
--

CREATE TABLE `admin_api_audit_log` (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `user_name` varchar(255) DEFAULT NULL,
  `action` varchar(255) DEFAULT NULL,
  `object_id` varchar(255) DEFAULT NULL,
  `url` varchar(255) DEFAULT NULL,
  `method` varchar(10) DEFAULT NULL,
  `request` MEDIUMTEXT,
  `status` smallint(5) NOT NULL,
   KEY `action` (`action`),
   KEY `user_name` (`user_name`),
   KEY `object_id_action` (`object_id`, `action`),
   KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=COMPRESSED;


--
-- Table structure for table `dhcppool`
--

CREATE TABLE dhcppool (
  `id` BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `pool_name`             varchar(30) NOT NULL,
  `idx`                   int(11) NOT NULL,
  `mac`                   VARCHAR(30) NOT NULL,
  `free`                  BOOLEAN NOT NULL default '1',
  `released`              DATETIME(6) NULL default NULL,
  UNIQUE KEY dhcppool_poolname_idx (pool_name, idx),
  KEY mac (mac),
  KEY released (released)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `pki_scep_servers`
--

CREATE TABLE `pki_scep_servers` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `name` varchar(191) DEFAULT NULL,
  `url` longtext DEFAULT NULL,
  `shared_secret` longtext DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `idx_pki_scep_servers_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Default values for pki_scep_servers table
--

INSERT INTO `pki_scep_servers` VALUES (1,'2023-11-09 10:36:34.489','2023-11-09 10:36:34.489',NULL,'Null','http://127.0.0.1','password');

--
-- Table structure for table `pki_cas`
--

CREATE TABLE `pki_cas` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `cn` varchar(191) DEFAULT NULL,
  `mail` varchar(191) DEFAULT NULL,
  `organisation` varchar(191) DEFAULT NULL,
  `organisational_unit` longtext DEFAULT NULL,
  `country` longtext DEFAULT NULL,
  `state` longtext DEFAULT NULL,
  `locality` longtext DEFAULT NULL,
  `street_address` longtext DEFAULT NULL,
  `postal_code` longtext DEFAULT NULL,
  `key_type` bigint(20) DEFAULT NULL,
  `key_size` bigint(20) DEFAULT NULL,
  `digest` bigint(20) DEFAULT NULL,
  `key_usage` longtext DEFAULT NULL,
  `extended_key_usage` longtext DEFAULT NULL,
  `days` bigint(20) DEFAULT NULL,
  `key` longtext DEFAULT NULL,
  `cert` longtext DEFAULT NULL,
  `issuer_key_hash` longtext DEFAULT NULL,
  `issuer_name_hash` longtext DEFAULT NULL,
  `ocsp_url` longtext DEFAULT NULL,
  `serial_number` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `cn` (`cn`),
  KEY `idx_pki_cas_deleted_at` (`deleted_at`),
  KEY `mail` (`mail`),
  KEY `organisation` (`organisation`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `pki_profiles`
--

CREATE TABLE `pki_profiles` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `name` varchar(191) DEFAULT NULL,
  `mail` varchar(191) DEFAULT NULL,
  `organisation` varchar(191) DEFAULT NULL,
  `organisational_unit` longtext DEFAULT NULL,
  `country` longtext DEFAULT NULL,
  `state` longtext DEFAULT NULL,
  `locality` longtext DEFAULT NULL,
  `street_address` longtext DEFAULT NULL,
  `postal_code` longtext DEFAULT NULL,
  `ca_id` bigint(20) unsigned DEFAULT NULL,
  `ca_name` varchar(191) DEFAULT NULL,
  `validity` bigint(20) DEFAULT NULL,
  `key_type` bigint(20) DEFAULT NULL,
  `key_size` bigint(20) DEFAULT NULL,
  `digest` bigint(20) DEFAULT NULL,
  `key_usage` longtext DEFAULT NULL,
  `extended_key_usage` longtext DEFAULT NULL,
  `ocsp_url` longtext DEFAULT NULL,
  `p12_mail_password` bigint(20) DEFAULT NULL,
  `p12_mail_subject` longtext DEFAULT NULL,
  `p12_mail_from` longtext DEFAULT NULL,
  `p12_mail_header` longtext DEFAULT NULL,
  `p12_mail_footer` longtext DEFAULT NULL,
  `scep_enabled` bigint(20) DEFAULT NULL,
  `scep_challenge_password` longtext DEFAULT NULL,
  `scep_days_before_renewal` bigint(20) DEFAULT 14,
  `days_before_renewal` bigint(20) DEFAULT 14,
  `renewal_mail` bigint(20) DEFAULT 1,
  `days_before_renewal_mail` bigint(20) DEFAULT 14,
  `renewal_mail_subject` varchar(191) DEFAULT 'Certificate expiration',
  `renewal_mail_from` longtext DEFAULT NULL,
  `renewal_mail_header` longtext DEFAULT NULL,
  `renewal_mail_footer` longtext DEFAULT NULL,
  `revoked_valid_until` bigint(20) DEFAULT 14,
  `cloud_enabled` bigint(20) DEFAULT NULL,
  `cloud_service` longtext DEFAULT NULL,
  `scep_server_id` bigint(20) unsigned DEFAULT NULL,
  `scep_server_enabled` bigint(20) DEFAULT 0,
  `allow_duplicated_cn` bigint(20) unsigned DEFAULT 0,
  `maximum_duplicated_cn` bigint(20) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `ca_name` (`ca_name`),
  KEY `scep_server_id` (`scep_server_id`),
  KEY `idx_pki_profiles_deleted_at` (`deleted_at`),
  KEY `mail` (`mail`),
  KEY `organisation` (`organisation`),
  KEY `ca_id` (`ca_id`),
  CONSTRAINT `fk_pki_profiles_ca` FOREIGN KEY (`ca_id`) REFERENCES `pki_cas` (`id`),
  CONSTRAINT `fk_pki_profiles_scep_server` FOREIGN KEY (`scep_server_id`) REFERENCES `pki_scep_servers` (`id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `pki_certs`
--

CREATE TABLE `pki_certs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `cn` longtext DEFAULT NULL,
  `mail` varchar(191) DEFAULT NULL,
  `ca_id` bigint(20) unsigned DEFAULT NULL,
  `ca_name` varchar(191) DEFAULT NULL,
  `street_address` longtext DEFAULT NULL,
  `organisation` varchar(191) DEFAULT NULL,
  `organisational_unit` longtext DEFAULT NULL,
  `country` longtext DEFAULT NULL,
  `state` longtext DEFAULT NULL,
  `locality` longtext DEFAULT NULL,
  `postal_code` longtext DEFAULT NULL,
  `key` longtext DEFAULT NULL,
  `cert` longtext DEFAULT NULL,
  `profile_id` bigint(20) unsigned DEFAULT NULL,
  `profile_name` varchar(191) DEFAULT NULL,
  `valid_until` datetime(3) DEFAULT NULL,
  `not_before` datetime(3) DEFAULT NULL,
  `date` datetime(3) DEFAULT current_timestamp(3),
  `serial_number` longtext DEFAULT NULL,
  `dns_names` longtext DEFAULT NULL,
  `ip_addresses` longtext DEFAULT NULL,
  `scep` tinyint(1) DEFAULT 0,
  `csr` tinyint(1) DEFAULT 0,
  `alert` tinyint(1) DEFAULT 0,
  `subject` longtext DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `cn_serial` (`cn`,`serial_number`) USING HASH,
  KEY `ca_id` (`ca_id`),
  KEY `ca_name` (`ca_name`),
  KEY `profile_name` (`profile_name`),
  KEY `valid_until` (`valid_until`),
  KEY `idx_pki_certs_deleted_at` (`deleted_at`),
  KEY `mail` (`mail`),
  KEY `organisation` (`organisation`),
  KEY `profile_id` (`profile_id`),
  KEY `not_before` (`not_before`),
  CONSTRAINT `fk_pki_certs_ca` FOREIGN KEY (`ca_id`) REFERENCES `pki_cas` (`id`),
  CONSTRAINT `fk_pki_certs_profile` FOREIGN KEY (`profile_id`) REFERENCES `pki_profiles` (`id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `pki_revoked_certs`
--

CREATE TABLE `pki_revoked_certs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `cn` varchar(191) DEFAULT NULL,
  `mail` varchar(191) DEFAULT NULL,
  `ca_id` bigint(20) unsigned DEFAULT NULL,
  `ca_name` varchar(191) DEFAULT NULL,
  `street_address` longtext DEFAULT NULL,
  `organisation` varchar(191) DEFAULT NULL,
  `organisational_unit` longtext DEFAULT NULL,
  `country` longtext DEFAULT NULL,
  `state` longtext DEFAULT NULL,
  `locality` longtext DEFAULT NULL,
  `postal_code` longtext DEFAULT NULL,
  `key` longtext DEFAULT NULL,
  `cert` longtext DEFAULT NULL,
  `profile_id` bigint(20) unsigned DEFAULT NULL,
  `profile_name` varchar(191) DEFAULT NULL,
  `valid_until` datetime(3) DEFAULT NULL,
  `not_before` datetime(3) DEFAULT NULL,
  `date` datetime(3) DEFAULT current_timestamp(3),
  `serial_number` longtext DEFAULT NULL,
  `dns_names` longtext DEFAULT NULL,
  `ip_addresses` longtext DEFAULT NULL,
  `revoked` datetime(3) DEFAULT NULL,
  `crl_reason` bigint(20) DEFAULT NULL,
  `subject` longtext DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `mail` (`mail`),
  KEY `valid_until` (`valid_until`),
  KEY `not_before` (`not_before`),
  KEY `revoked` (`revoked`),
  KEY `crl_reason` (`crl_reason`),
  KEY `profile_id` (`profile_id`),
  KEY `profile_name` (`profile_name`),
  KEY `idx_pki_revoked_certs_deleted_at` (`deleted_at`),
  KEY `cn` (`cn`),
  KEY `ca_id` (`ca_id`),
  KEY `ca_name` (`ca_name`),
  KEY `organisation` (`organisation`),
  CONSTRAINT `fk_pki_revoked_certs_ca` FOREIGN KEY (`ca_id`) REFERENCES `pki_cas` (`id`),
  CONSTRAINT `fk_pki_revoked_certs_profile` FOREIGN KEY (`profile_id`) REFERENCES `pki_profiles` (`id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `bandwidth_accounting`
--

CREATE TABLE bandwidth_accounting (
    `node_id` BIGINT UNSIGNED NOT NULL,
    `unique_session_id` BIGINT UNSIGNED NOT NULL,
    `time_bucket` DATETIME NOT NULL,
    `source_type` ENUM('net_flow','radius') NOT NULL,
    `in_bytes` BIGINT SIGNED NOT NULL,
    `out_bytes` BIGINT SIGNED NOT NULL,
    `mac` CHAR(17) NOT NULL,
    `last_updated` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `total_bytes` BIGINT SIGNED AS (in_bytes + out_bytes) VIRTUAL,
    PRIMARY KEY (node_id, time_bucket, unique_session_id),
    KEY bandwidth_aggregate_buckets (time_bucket, node_id, unique_session_id, in_bytes, out_bytes),
    KEY bandwidth_source_type_time_bucket (source_type, time_bucket),
    KEY bandwidth_last_updated_source_type_time_bucket (last_updated, source_type, time_bucket),
    KEY bandwidth_node_id_unique_session_id_last_updated (node_id, unique_session_id, last_updated),
    KEY bandwidth_accounting_mac_last_updated (mac, last_updated)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Table structure for table `bandwidth_accounting_history`
--

CREATE TABLE bandwidth_accounting_history (
    `node_id` BIGINT UNSIGNED NOT NULL,
    `time_bucket` DATETIME NOT NULL,
    `in_bytes` BIGINT SIGNED NOT NULL,
    `out_bytes` BIGINT SIGNED NOT NULL,
    `total_bytes` BIGINT SIGNED AS (in_bytes + out_bytes) VIRTUAL,
    `mac` CHAR(17) NOT NULL,
    PRIMARY KEY (node_id, time_bucket),
    KEY bandwidth_aggregate_buckets (time_bucket, node_id, in_bytes, out_bytes),
    KEY bandwidth_accounting_mac (mac)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

DROP FUNCTION IF EXISTS ROUND_TO_HOUR;
CREATE FUNCTION ROUND_TO_HOUR (d DATETIME)
    RETURNS DATETIME DETERMINISTIC
        RETURN DATE_ADD(DATE(d), INTERVAL HOUR(d) HOUR);

DROP FUNCTION IF EXISTS ROUND_TO_MONTH;
CREATE FUNCTION ROUND_TO_MONTH (d DATETIME)
    RETURNS DATETIME DETERMINISTIC
        RETURN DATE_ADD(DATE(d),interval -DAY(d)+1 DAY);

--
-- Updating to current version
--

INSERT INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());

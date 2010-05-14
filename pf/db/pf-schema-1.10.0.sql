--
-- Table structure for table `class`
--

CREATE TABLE class (
  vid int(11) NOT NULL,
  description varchar(255) NOT NULL default "none",
  auto_enable char(1) NOT NULL default "Y",
  max_enables int(11) NOT NULL default 0,
  grace_period int(11) NOT NULL,
  priority int(11) NOT NULL,
  url varchar(255),
  max_enable_url varchar(255),
  redirect_url varchar(255),
  button_text varchar(255),
  disable char(1) NOT NULL default "Y",
  vlan varchar(255),
  PRIMARY KEY (vid)
) TYPE=InnoDB;

--
-- Table structure for table `trigger`
--
CREATE TABLE `trigger` (
  vid int(11) default NULL,
  tid_start int(11) NOT NULL,
  tid_end int(11) NOT NULL,
  type varchar(255) default NULL,
  whitelisted_categories varchar(255) NOT NULL default '',
  PRIMARY KEY (vid,tid_start,tid_end,type),
  KEY `trigger` (tid_start,tid_end,type),
  CONSTRAINT `0_64` FOREIGN KEY (`vid`) REFERENCES `class` (`vid`) ON DELETE CASCADE ON UPDATE CASCADE
) TYPE=InnoDB;

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
  PRIMARY KEY (pid)
) TYPE=InnoDB;


--
-- Table structure for table `node_category`
--

CREATE TABLE `node_category` (
  `category_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `notes` varchar(255) default NULL,
  PRIMARY KEY (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Insert 'default' category
--

INSERT INTO `node_category` (category_id,name,notes) VALUES ("1","default","Placeholder category, feel free to edit");

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
  switch varchar(17) default NULL,
  port varchar(8) default NULL,
  vlan varchar(50) default NULL,
  `voip` enum('no','yes') NOT NULL DEFAULT 'no',
  `connection_type` varchar(50) NOT NULL default '',
  PRIMARY KEY (mac),
  KEY pid (pid),
  KEY category_id (category_id),
  KEY `node_status` (`status`, `unregdate`),
  KEY `node_dhcpfingerprint` (`dhcp_fingerprint`),
  CONSTRAINT `0_57` FOREIGN KEY (`pid`) REFERENCES `person` (`pid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `node_category_key` FOREIGN KEY (`category_id`) REFERENCES `node_category` (`category_id`)
) TYPE=InnoDB;

--
-- Table structure for table `action`
--

CREATE TABLE action (
  vid int(11) NOT NULL,
  action varchar(255) NOT NULL,
  PRIMARY KEY (vid,action),
  CONSTRAINT `FOREIGN` FOREIGN KEY (`vid`) REFERENCES `class` (`vid`) ON DELETE CASCADE ON UPDATE CASCADE
) TYPE=InnoDB;

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
) TYPE=InnoDB;

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
) TYPE=InnoDB;

CREATE TABLE os_type (
  os_id int(11) NOT NULL,
  description varchar(255) NOT NULL,
  PRIMARY KEY os_id (os_id)
) TYPE=InnoDB;

CREATE TABLE dhcp_fingerprint (
  fingerprint varchar(255) NOT NULL,
  os_id int(11) NOT NULL,
  PRIMARY KEY fingerprint (fingerprint),
  KEY os_id_key (os_id),
  CONSTRAINT `0_65` FOREIGN KEY (`os_id`) REFERENCES `os_type` (`os_id`) ON DELETE CASCADE ON UPDATE CASCADE
) TYPE=InnoDB;

CREATE TABLE os_class (
  class_id int(11) NOT NULL,               
  description varchar(255) NOT NULL,     
  PRIMARY KEY class_id (class_id)
) TYPE=InnoDB;     

CREATE TABLE os_mapping (   
  os_type int(11) NOT NULL,  
  os_class int(11) NOT NULL,
  PRIMARY KEY  (os_type,os_class),
  KEY os_type_key (os_type),
  KEY os_class_key (os_class),
  CONSTRAINT `0_66` FOREIGN KEY (`os_type`) REFERENCES `os_type` (`os_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `0_67` FOREIGN KEY (`os_class`) REFERENCES `os_class` (`class_id`) ON DELETE CASCADE ON UPDATE CASCADE
) TYPE=InnoDB;

insert into person (pid,notes) values("1","Default User - do not delete");

CREATE TABLE `locationlog` (
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(50) default NULL,
  `voip` enum('no','yes') NOT NULL DEFAULT 'no',
  `connection_type` varchar(50) NOT NULL default '',
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime default NULL,
  KEY `locationlog_view_mac` (`mac`, `end_time`),
  KEY `locationlog_view_switchport` (`switch`,`port`,`voip`,`end_time`,`vlan`)
) ENGINE=InnoDB;

CREATE TABLE `locationlog_history` (
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(50) default NULL,
  `voip` enum('no','yes') NOT NULL DEFAULT 'no',
  `connection_type` varchar(50) NOT NULL default '',
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `useragent_class`
--

CREATE TABLE `useragent_class` (
  `class_id` int(11) NOT NULL,
  `description` varchar(255) NOT NULL,
  PRIMARY KEY  (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `useragent_type`
--

CREATE TABLE `useragent_type` (
  `useragent_id` int(11) NOT NULL,
  `description` varchar(255) NOT NULL,
  `match_expression` varchar(255) NOT NULL,
  PRIMARY KEY  (`useragent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `useragent_mapping`
--

CREATE TABLE `useragent_mapping` (
  `useragent_type` int(11) NOT NULL,
  `useragent_class` int(11) NOT NULL,
  PRIMARY KEY  (`useragent_type`,`useragent_class`),
  KEY `useragent_type_key` (`useragent_type`),
  KEY `useragent_class_key` (`useragent_class`),
  CONSTRAINT `0_68` FOREIGN KEY (`useragent_type`) REFERENCES `useragent_type` (`useragent_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `0_69` FOREIGN KEY (`useragent_class`) REFERENCES `useragent_class` (`class_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


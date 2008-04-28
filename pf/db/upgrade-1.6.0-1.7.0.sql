ALTER TABLE `node` ADD COLUMN `unregdate` datetime NOT NULL default '0000-00-00 00:00:00' AFTER `regdate`;
ALTER TABLE `node` ADD COLUMN `notes` varchar(255) NULL default NULL AFTER `computername`;

CREATE TABLE `locationlog` (
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(4) default NULL,
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime default NULL,
  KEY `mac` (`mac`),
  KEY `locationlog_view_open` (`mac`,`switch`,`port`,`vlan`,`start_time`,`end_time`),
  KEY `locationlog_view_open_switchport` (`switch`,`port`,`end_time`),
  KEY `start_time` (`start_time`)
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


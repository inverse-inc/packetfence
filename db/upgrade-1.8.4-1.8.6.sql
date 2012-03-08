--
-- Table structure for table `locationlog_history`
--

CREATE TABLE `locationlog_history` (
  `mac` varchar(17) default NULL,
  `switch` varchar(17) NOT NULL default '',
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(4) default NULL,
  `start_time` datetime NOT NULL default '0000-00-00 00:00:00',
  `end_time` datetime default NULL,
  KEY `locationlog_history_view_mac` (`mac`, `end_time`)
) ENGINE=InnoDB;

CREATE TABLE `traplog` (
  `switch` varchar(30) NOT NULL default '',
  `ifIndex` smallint(6) NOT NULL default '0',
  `parseTime` datetime NOT NULL default '0000-00-00 00:00:00',
  `type` varchar(30) NOT NULL default '',
  KEY `switch` (`switch`,`ifIndex`),
  KEY `parseTime` (`parseTime`)
) ENGINE=MyISAM;

delete from class where vid=1200000;
delete from class where vid=1200002;

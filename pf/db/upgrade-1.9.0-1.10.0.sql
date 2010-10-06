--
-- Support new fields in locationlog, locationlog_history and node
--

ALTER TABLE locationlog
	MODIFY `vlan` varchar(50) default NULL,
	ADD `connection_type` varchar(50) NOT NULL default '' AFTER `vlan`,
	ADD `dot1x_username` varchar(255) NOT NULL default '' AFTER `connection_type`,
	ADD `ssid` varchar(32) NOT NULL default '' AFTER `dot1x_username`
;

ALTER TABLE locationlog_history
	MODIFY `vlan` varchar(50) default NULL,
	ADD `connection_type` varchar(50) NOT NULL default '' AFTER `vlan`,
	ADD `dot1x_username` varchar(255) NOT NULL default '' AFTER `connection_type`,
	ADD `ssid` varchar(32) NOT NULL default '' AFTER `dot1x_username`
;

ALTER TABLE node
	CHANGE `vlan` `bypass_vlan` varchar(50) default NULL,
	ADD `voip` enum('no','yes') NOT NULL DEFAULT 'no' AFTER `bypass_vlan`,
	DROP `switch`,
	DROP `port`
;

--
-- Modify indexes
--

ALTER TABLE locationlog
  DROP KEY `locationlog_view_switchport`,
  ADD KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`)
;

--
-- Migrate important fields over to the new format
-- 

-- VoIP device status now stored in node
UPDATE node INNER JOIN locationlog USING (mac) SET node.voip='yes' WHERE locationlog.vlan = 'VoIP';

-- Add basic connection type from what was supported so far
-- These are good defaults for people using stock PF, if you customized, feel free to modify
UPDATE locationlog SET connection_type = 'Wireless-802.11-NoEAP' WHERE port='WIFI';
UPDATE locationlog SET connection_type = 'SNMP-Traps' WHERE port is not null and port != 'WIFI';

-- You can note that we don't really care about updating locationlog_history's fields since it's history

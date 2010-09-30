--
-- Support new fields in locationlog, locationlog_history and node
--

ALTER TABLE locationlog
	MODIFY `vlan` varchar(50) default NULL,
	ADD `voip` enum('no','yes') NOT NULL DEFAULT 'no' AFTER `vlan`,
	ADD `connection_type` varchar(50) NOT NULL default '' AFTER `voip`
;

ALTER TABLE locationlog_history
	MODIFY `vlan` varchar(50) default NULL,
	ADD `voip` enum('no','yes') NOT NULL DEFAULT 'no' AFTER `vlan`,
	ADD `connection_type` varchar(50) NOT NULL default '' AFTER `voip`
;

ALTER TABLE node
	CHANGE `vlan` `bypass_vlan` varchar(50) default NULL,
	ADD `voip` enum('no','yes') NOT NULL DEFAULT 'no' AFTER `bypass_vlan`,
	ADD `connection_type` varchar(50) NOT NULL default '' AFTER `voip`
;

--
-- Modify indexes
--

ALTER TABLE locationlog
  DROP KEY `locationlog_view_switchport`,
  ADD KEY `locationlog_view_switchport` (`switch`,`port`,`voip`,`end_time`,`vlan`)
;

--
-- Migrate important fields over to the new format
-- 

-- VoIP (only of interest for locationlog)
UPDATE locationlog SET voip='yes' WHERE vlan='VoIP';

-- Add basic connection type from what was supported so far
-- These are good defaults for people using stock PF, if you customized, feel free to modify
UPDATE locationlog SET connection_type = 'Wireless-802.11-NoEAP' WHERE port='WIFI';
UPDATE locationlog SET connection_type = 'SNMP-Traps' WHERE port is not null and port != 'WIFI';
UPDATE node SET connection_type = 'Wireless-802.11-NoEAP' WHERE port='WIFI';
UPDATE node SET connection_type = 'SNMP-Traps' WHERE port is not null and port != 'WIFI';

-- You can note that we don't really care about updating locationlog_history since it's not used by packetfence

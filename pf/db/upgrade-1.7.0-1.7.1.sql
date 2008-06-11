ALTER TABLE locationlog
  ADD KEY `locationlog_view_mac` (`mac`, `end_time`),
  ADD KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`);

ALTER TABLE locationlog
  DROP KEY `mac`,
  DROP KEY `locationlog_view_open`,
  DROP KEY `locationlog_view_open_switchport`,
  DROP KEY `start_time`;


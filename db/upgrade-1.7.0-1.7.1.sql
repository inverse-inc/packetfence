ALTER TABLE locationlog
  ADD KEY `locationlog_view_mac` (`mac`, `end_time`),
  ADD KEY `locationlog_view_switchport` (`switch`,`port`,`end_time`,`vlan`);

ALTER TABLE locationlog
  DROP KEY `mac`,
  DROP KEY `locationlog_view_open`,
  DROP KEY `locationlog_view_open_switchport`,
  DROP KEY `start_time`;

ALTER TABLE node
  DROP KEY `node_lookup_person`,
  ADD KEY `node_status` (`status`, `unregdate`),
  ADD KEY `node_dhcpfingerprint` (`dhcp_fingerprint`);

ALTER TABLE os_mapping
  ADD PRIMARY KEY (`os_type`, `os_class`),
  DROP KEY `os_mapping_view`;

ALTER TABLE person
  DROP KEY `person_view`;

ALTER TABLE violation
  DROP KEY `violation_exist`;

ALTER TABLE iplog
  ADD KEY `ip_view_open` (`ip`, `end_time`),
  ADD KEY `mac_view_open` (`mac`, `end_time`);

ALTER TABLE iplog
  DROP KEY `iplog_view_open`,
  DROP KEY `ip`;

ALTER TABLE os_type
  DROP KEY `os_id_key`,
  DROP KEY `os_type_view`;

ALTER TABLE os_class
  DROP KEY `os_class_view`;

ALTER TABLE dhcp_fingerprint
  DROP KEY `fingerprint_view`;

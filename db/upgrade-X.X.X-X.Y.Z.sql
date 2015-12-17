--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Alter locationlog
--

ALTER TABLE `locationlog` ADD `role` varchar(255) default NULL AFTER vlan;

--
-- Alter locationlog_archive
--

ALTER TABLE `locationlog_archive` ADD `role` varchar(255) default NULL AFTER vlan;

--
-- Creating auth_log table
--

CREATE TABLE auth_log (
  `id` int NOT NULL AUTO_INCREMENT,
  `process_name` varchar(255) NOT NULL,
  `mac` varchar(17) NOT NULL,
  `pid` varchar(255) NOT NULL default "default",
  `status` varchar(255) NOT NULL default "incomplete",
  `attempted_at` datetime NOT NULL,
  `completed_at` datetime,
  `source` varchar(255) NOT NULL,
  PRIMARY KEY (id),
  KEY pid (pid)
) ENGINE=InnoDB;

--
-- Table structure for table 'radius_audit_log'
--

CREATE TABLE radius_audit_log (
  id int NOT NULL AUTO_INCREMENT,
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
  PRIMARY KEY (id),
  KEY `created_at` (created_at),
  KEY `mac` (mac),
  KEY `ip` (ip),
  KEY `user_name` (user_name)
) ENGINE=InnoDB;

--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 5;
SET @MINOR_VERSION = 6;
SET @SUBMINOR_VERSION = 0;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

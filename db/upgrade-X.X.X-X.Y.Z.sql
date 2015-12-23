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

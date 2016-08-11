--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Additionnal fields for the Fingerbank integration
--

ALTER TABLE node ADD COLUMN `device_version` varchar(255) DEFAULT NULL AFTER `device_class`;
ALTER TABLE node ADD COLUMN `device_score` varchar(255) DEFAULT NULL AFTER `device_version`;

--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 6;
SET @MINOR_VERSION = 2;
SET @SUBMINOR_VERSION = 9;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Table structure for table `dhcp_option82`
--

CREATE TABLE `dhcp_option82` (
  `mac` varchar(17) NOT NULL PRIMARY KEY,
  `created_at` TIMESTAMP NOT NULL,
  `option82_switch` varchar(17) NULL,
  `switch_id` varchar(17) NULL,
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(255) default NULL,
  `circuit_id_string` varchar(255) default NULL,
  `module` varchar(255) default NULL,
  `host` varchar(255) default NULL,
  UNIQUE KEY mac (mac)
) ENGINE=InnoDB;

--
-- Table structure for table `dhcp_option82_history`
--

CREATE TABLE `dhcp_option82_history` (
  `dhcp_option82_history_id` int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `mac` varchar(17) NOT NULL,
  `created_at` TIMESTAMP NOT NULL,
  `option82_switch` varchar(17) NULL,
  `switch_id` varchar(17) NULL,
  `port` varchar(8) NOT NULL default '',
  `vlan` varchar(255) default NULL,
  `circuit_id_string` varchar(255) default NULL,
  `module` varchar(255) default NULL,
  `host` varchar(255) default NULL,
  INDEX (mac)
) ENGINE=InnoDB;

--
-- Trigger to archive dhcp_option82 entries to the history table after an update
--

DROP TRIGGER IF EXISTS dhcp_option82_after_update_trigger;
DELIMITER /
CREATE TRIGGER dhcp_option82_after_update_trigger AFTER UPDATE ON dhcp_option82
FOR EACH ROW
BEGIN
    INSERT INTO dhcp_option82_history
           (
            created_at,
            mac,
            option82_switch,
            switch_id,
            port,
            vlan,
            circuit_id_string,
            module,
            host
           )
    VALUES
           (
            OLD.created_at,
            OLD.mac,
            OLD.option82_switch,
            OLD.switch_id,
            OLD.port,
            OLD.vlan,
            OLD.circuit_id_string,
            OLD.module,
            OLD.host
           );
END /
DELIMITER ;

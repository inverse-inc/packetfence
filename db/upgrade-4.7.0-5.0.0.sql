--
-- PacketFence SQL schema upgrade from 4.7.0 to 5.0.0
--

--
-- Add table to cache in MySQL
--

CREATE TABLE keyed (
  id VARCHAR(255),
  value LONGBLOB,
  PRIMARY KEY(id)
) ENGINE=InnoDB;

RENAME TABLE temporary_password TO `password`;

--
-- Rename existing `iplog_history` to `iplog_archive`
--

RENAME TABLE iplog_history TO iplog_archive;

--
-- Rename existing `locationlog_history` to `locationlog_archive`
--

RENAME TABLE locationlog_history TO locationlog_archive;

--
-- Table structure for new `iplog_history` table
--

CREATE TABLE iplog_history (
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  start_time datetime NOT NULL,
  end_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

--
--  Drop Table structure for table 'iplog'
--

DROP TABLE iplog;

--
-- Table structure for table `iplog`
--

CREATE TABLE iplog (
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  start_time datetime NOT NULL,
  end_time datetime default "0000-00-00 00:00:00",
  PRIMARY KEY (ip),
  KEY iplog_mac_end_time (mac,end_time),
  KEY iplog_end_time (end_time)
) ENGINE=InnoDB;

--
-- Trigger to insert old record from 'iplog' in 'iplog_history' before updating the current one
--

DROP TRIGGER IF EXISTS iplog_insert_in_iplog_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER iplog_insert_in_iplog_history_before_update_trigger BEFORE UPDATE ON iplog
FOR EACH ROW
BEGIN
  INSERT INTO iplog_history SET ip = OLD.ip, mac = OLD.mac, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

--
-- Table structure for table 'iplog_archive'
--

ALTER TABLE iplog_archive MODIFY mac varchar(17) NOT NULL,
            MODIFY ip varchar(45) NOT NULL,
            MODIFY end_time datetime NOT NULL;

--
-- Insert a new 'default' user
--

INSERT INTO `person` (pid,notes) VALUES ("default","Default User - do not delete");

--
-- Reassigning all unregistered nodes to the 'default' pid
--

UPDATE `node` SET pid = 'default' WHERE status = 'unreg' AND pid = 'admin';

--
-- Alter node table for bypass_role,dhcp_vendor,device_type,device_class
--

ALTER TABLE node ADD `bypass_role_id` INT DEFAULT NULL,
                 ADD dhcp_vendor VARCHAR(255) AFTER dhcp_fingerprint,
                 ADD device_type VARCHAR(255) AFTER dhcp_vendor,
                 ADD device_class VARCHAR(255) AFTER device_type;

--
-- Add a column to store the session id in the locationlog
--

ALTER TABLE locationlog ADD `session_id` VARCHAR(255) DEFAULT NULL;
ALTER TABLE locationlog_archive ADD `session_id` VARCHAR(255) DEFAULT NULL;

DROP TABLE IF EXISTS dhcp_fingerprint;
DROP TABLE IF EXISTS os_mapping;
DROP TABLE IF EXISTS os_class;
DROP TABLE IF EXISTS os_type;

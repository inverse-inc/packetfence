--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
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
-- Table structure for table 'iplog'
--

ALTER TABLE iplog MODIFY mac varchar(17) NOT NULL,
            MODIFY ip varchar(45) NOT NULL,
            ADD PRIMARY KEY(ip),
            DROP INDEX ip_view_open,
            DROP INDEX mac_view_open,
            DROP INDEX iplog_end_time,
            DROP FOREIGN KEY 0_63;

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


---
--- Alter for bypass_role
---
ALTER TABLE node ADD `bypass_role_id` INT DEFAULT NULL;

--
-- Insert a new 'default' user
--

INSERT INTO `person` (pid,notes) VALUES ("default","Default User - do not delete");

--
-- Reassigning all unregistered nodes to the 'default' pid
--

UPDATE `node` SET pid = 'default' WHERE status = 'unreg';

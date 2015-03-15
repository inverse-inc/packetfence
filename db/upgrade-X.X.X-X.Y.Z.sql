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
-- Table structure for table `iplog_old`
--

CREATE TABLE iplog_old (
  mac varchar(17) NOT NULL,
  ip varchar(255) NOT NULL,
  start_time datetime NOT NULL,
  end_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

--
-- Table structure for table 'iplog'
--

ALTER TABLE iplog MODIFY mac varchar(17) NOT NULL;
ALTER TABLE iplog MODIFY ip varchar(255) NOT NULL;
ALTER TABLE iplog ADD PRIMARY KEY(ip);
ALTER TABLE iplog DROP INDEX ip_view_open;
ALTER TABLE iplog DROP INDEX mac_view_open;
ALTER TABLE iplog DROP INDEX iplog_end_time;
ALTER TABLE iplog DROP FOREIGN KEY 0_63;

--
-- Trigger to insert old record from 'iplog' in 'iplog_old' before updating the current one
--

DROP TRIGGER IF EXISTS iplog_insert_iplog_old_before_update_trigger;
DELIMITER /
CREATE TRIGGER iplog_insert_iplog_old_before_update_trigger BEFORE UPDATE ON iplog
FOR EACH ROW
BEGIN
  INSERT INTO iplog_old SET ip = OLD.ip, mac = OLD.mac, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

--
-- Table structure for table 'iplog_history'
--

ALTER TABLE iplog_history MODIFY mac varchar(17) NOT NULL;
ALTER TABLE iplog_history MODIFY ip varchar(255) NOT NULL;
ALTER TABLE iplog_history MODIFY end_time datetime NOT NULL;

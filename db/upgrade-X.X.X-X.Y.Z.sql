--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Add a primary key to the radacct_log
--

ALTER TABLE `radacct_log` ADD COLUMN `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the iplog_history
--

ALTER TABLE `iplog_history` ADD COLUMN `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the iplog_archive
--

ALTER TABLE `iplog_archive` ADD COLUMN `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the locationlog
--

ALTER TABLE `locationlog` ADD COLUMN `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the locationlog_archive
--

ALTER TABLE `locationlog_archive` ADD COLUMN `id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Table structure for table `ip4log`
--

RENAME TABLE iplog TO ip4log;

ALTER TABLE ip4log
    DROP INDEX iplog_mac_end_time, ADD INDEX ip4log_mac_end_time (mac,end_time),
    DROP INDEX iplog_end_time, ADD INDEX ip4log_end_time (end_time);

--
-- Trigger to insert old record from 'ip4log' in 'ip4log_history' before updating the current one
--

DROP TRIGGER IF EXISTS iplog_insert_in_iplog_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER ip4log_insert_in_ip4log_history_before_update_trigger BEFORE UPDATE ON ip4log
FOR EACH ROW
BEGIN
  INSERT INTO ip4log_history SET ip = OLD.ip, mac = OLD.mac, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

--
-- Table structure for table `ip4log_history`
--

RENAME TABLE iplog_history TO ip4log_history;

ALTER TABLE ip4log_history
    DROP INDEX iplog_history_mac_end_time, ADD INDEX ip4log_history_mac_end_time (mac,end_time);

--
-- Table structure for table `ip4log_archive`
--

RENAME TABLE iplog_archive TO ip4log_archive;

--
-- Table structure for table `ip6log`
--

CREATE TABLE ip6log (
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  type varchar(32) DEFAULT NULL,
  start_time datetime NOT NULL,
  end_time datetime default "0000-00-00 00:00:00",
  PRIMARY KEY (ip),
  KEY ip6log_mac_end_time (mac,end_time),
  KEY ip6log_end_time (end_time)
) ENGINE=InnoDB;

--
-- Trigger to insert old record from 'ip6log' in 'ip6log_history' before updating the current one
--

DROP TRIGGER IF EXISTS ip6log_insert_in_ip6log_history_before_update_trigger;
DELIMITER /
CREATE TRIGGER ip6log_insert_in_ip6log_history_before_update_trigger BEFORE UPDATE ON ip6log
FOR EACH ROW
BEGIN
  INSERT INTO ip6log_history SET ip = OLD.ip, mac = OLD.mac, type = OLD.type, start_time = OLD.start_time, end_time = CASE
    WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
    WHEN OLD.end_time > NOW() THEN NOW()
    ELSE OLD.end_time
  END;
END /
DELIMITER ;

--
-- Table structure for table `ip6log_history`
--

CREATE TABLE ip6log_history (
  id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  type varchar(32) DEFAULT NULL,
  start_time datetime NOT NULL,
  end_time datetime NOT NULL,
  KEY ip6log_history_mac_end_time (mac,end_time),
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB;

--
-- Table structure for table `ip6log_archive`
--

CREATE TABLE ip6log_archive (
  id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
  mac varchar(17) NOT NULL,
  ip varchar(45) NOT NULL,
  type varchar(32) DEFAULT NULL,
  start_time datetime NOT NULL,
  end_time datetime NOT NULL,
  KEY end_time (end_time),
  KEY start_time (start_time)
) ENGINE=InnoDB;

--
-- Creating chi_cache table
--

CREATE TABLE `chi_cache` (
  `key` VARCHAR(767),
  `value` LONGTEXT,
  PRIMARY KEY (`key`)
);


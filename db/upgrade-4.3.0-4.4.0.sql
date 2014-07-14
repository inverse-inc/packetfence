--
-- Alter for dynamic controller
--

ALTER TABLE locationlog_history
    ADD `switch_ip` varchar(17) DEFAULT NULL,
    ADD `switch_mac` varchar(17) DEFAULT NULL,
    ADD `stripped_user_name` varchar(255) DEFAULT NULL,
    ADD `realm` varchar(255) DEFAULT NULL;

UPDATE locationlog_history SET switch_ip = switch;

--
-- Table structure for table `iplog_history`
--

CREATE TABLE iplog_history (
  mac varchar(17) NOT NULL,
  ip varchar(15) NOT NULL,
  start_time datetime NOT NULL,
  end_time datetime default "0000-00-00 00:00:00"
) ENGINE=InnoDB;

-- Alter for realm
--

ALTER TABLE locationlog
    ADD `stripped_user_name` varchar(255) DEFAULT NULL,
    ADD `realm` varchar(255) DEFAULT NULL;



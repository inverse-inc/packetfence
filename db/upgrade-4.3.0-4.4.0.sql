--
-- Table structure for table `iplog_history`
--

CREATE TABLE iplog_history (
  mac varchar(17) NOT NULL,
  ip varchar(15) NOT NULL,
  start_time datetime NOT NULL,
  end_time datetime default "0000-00-00 00:00:00"
) ENGINE=InnoDB;

DROP TABLE IF EXISTS switchlocation;

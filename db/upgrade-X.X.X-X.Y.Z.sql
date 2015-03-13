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
  mac varchar(255) NOT NULL,
  ip varchar(255) NOT NULL,
  start_time datetime NOT NULL,
  end_time datetime NOT NULL default CURRENT_TIMESTAMP
) ENGINE=InnoDB;

--
-- Table structure for table 'iplog'
--

ALTER TABLE iplog MODIFY mac varchar(255) NOT NULL;
ALTER TABLE iplog MODIFY ip varchar(255) NOT NULL;
ALTER TABLE iplog ADD PRIMARY KEY(ip);
ALTER TABLE iplog DROP INDEX ip_view_open;
ALTER TABLE iplog DROP INDEX mac_view_open;
ALTER TABLE iplog DROP INDEX iplog_end_time;
ALTER TABLE iplog DROP FOREIGN KEY 0_63;

--
-- Table structure for table 'iplog_history'
--

ALTER TABLE iplog_history MODIFY mac varchar(255) NOT NULL;
ALTER TABLE iplog_history MODIFY ip varchar(255) NOT NULL;
ALTER TABLE iplog_history MODIFY end_time datetime NOT NULL;

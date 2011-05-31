--
-- Table structure for table `temporary_password`
--

CREATE TABLE temporary_password (
  `pid` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `valid_from` DATETIME DEFAULT NULL,
  `expiration` DATETIME NOT NULL,
  `access_duration` varchar(255) DEFAULT NULL,
  PRIMARY KEY (pid)
) ENGINE=InnoDB;


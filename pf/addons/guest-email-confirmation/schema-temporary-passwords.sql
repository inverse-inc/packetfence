--
-- Table structure for table `temporary_password`
--

CREATE TABLE temporary_password (
  `tp_id` int NOT NULL AUTO_INCREMENT,
  `pid` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `expiration` DATETIME NOT NULL,
  PRIMARY KEY (tp_id),
  KEY (pid)
) ENGINE=InnoDB;


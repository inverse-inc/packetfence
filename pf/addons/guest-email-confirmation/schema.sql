--
-- Table structure for table `email_activation`
--

CREATE TABLE email_activation (
  `code_id` int NOT NULL AUTO_INCREMENT,
  `mac` varchar(17) NOT NULL,
  `email` varchar(255) NOT NULL,
  `activation_code` varchar(255) NOT NULL,
  `expiration` DATETIME NOT NULL,
  `status` varchar(60) default NULL,
  PRIMARY KEY (code_id)
) TYPE=InnoDB;


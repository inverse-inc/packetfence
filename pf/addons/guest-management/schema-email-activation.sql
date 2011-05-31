--
-- Table structure for table `email_activation`
--

CREATE TABLE email_activation (
  `code_id` int NOT NULL AUTO_INCREMENT,
  `pid` varchar(255) default NULL,
  `mac` varchar(17) default NULL,
  `email` varchar(255) NOT NULL, -- email were approbation request is sent 
  `activation_code` varchar(255) NOT NULL,
  `expiration` DATETIME NOT NULL,
  `status` varchar(60) default NULL,
  PRIMARY KEY (code_id),
  KEY `identifier` (pid, mac),
  KEY `activation` (activation_code, status)
) ENGINE=InnoDB;


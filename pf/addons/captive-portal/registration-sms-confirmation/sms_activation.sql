--
-- Table structure for table `sms_activation`
--

CREATE TABLE sms_activation (
  `code_id` int NOT NULL AUTO_INCREMENT,
  `mac` varchar(17) default NULL,
  `phone_number` varchar(255) NOT NULL, -- phone number where sms is sent
  `carrier_id` int(11) NOT NULL,
  `activation_code` varchar(255) NOT NULL,
  `expiration` DATETIME NOT NULL,
  `status` varchar(60) default NULL,
  PRIMARY KEY (code_id),
  KEY `identifier` (mac),
  KEY `activation` (activation_code, status)
) ENGINE=InnoDB;

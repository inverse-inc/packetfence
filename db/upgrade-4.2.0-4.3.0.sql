--
-- Add column to store portal and source in person table
--

ALTER TABLE person ADD `portal` varchar(255) default NULL;
ALTER TABLE person ADD `source` varchar(255) default NULL;

--
-- Table structure for table `activation`
--

CREATE TABLE activation (
  `code_id` int NOT NULL AUTO_INCREMENT,
  `pid` varchar(255) default NULL,
  `mac` varchar(17) default NULL,
  `contact_info` varchar(255) NOT NULL, -- email or phone number were approbation request is sent 
  `carrier_id` int(11) NULL,
  `activation_code` varchar(255) NOT NULL,
  `expiration` datetime NOT NULL,
  `status` varchar(60) default NULL,
  `type` varchar(60) NOT NULL,
  `portal` varchar(255) NOT NULL DEFAULT 'default',
  PRIMARY KEY (code_id),
  KEY `mac` (mac),
  KEY `identifier` (pid, mac),
  KEY `activation` (activation_code, status)
) ENGINE=InnoDB;

INSERT INTO activation ( pid, mac, contact_info, activation_code, expiration, status, `type`, portal) SELECT  pid, mac, email, activation_code, expiration, status, IFNULL(`type`,'guest'), 'default' from email_activation;
INSERT INTO activation ( mac, contact_info, carrier_id, activation_code, expiration, status, `type`, portal) SELECT mac, phone_number, carrier_id, activation_code, expiration, status, 'sms', 'default' from sms_activation;

-- DROP TABLE email_activation;
-- DROP TABLE sms_activation;


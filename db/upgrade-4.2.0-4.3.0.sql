--
-- Add column to store portal and source in person table
--

ALTER TABLE person ADD `portal` varchar(255) default NULL;
ALTER TABLE person ADD `source` varchar(255) default NULL;

--
-- The tables email_activation and sms_activation have been merged in a table named `activation`
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
  `portal` varchar(255) default NULL,
  PRIMARY KEY (code_id),
  KEY `mac` (mac),
  KEY `identifier` (pid, mac),
  KEY `activation` (activation_code, status)
) ENGINE=InnoDB;

-- Migrate entries from email_activation
INSERT INTO activation ( pid, mac, contact_info, activation_code, expiration, status, `type`, portal) SELECT  pid, mac, email, activation_code, expiration, status, IFNULL(`type`,'guest'), 'default' FROM email_activation;

-- Migrate entries from sms_activation
INSERT INTO activation ( mac, contact_info, carrier_id, activation_code, expiration, status, `type`, portal) SELECT mac, phone_number, carrier_id, activation_code, expiration, status, 'sms', 'default' FROM sms_activation;

-- Drop old tables

DROP TABLE IF EXISTS email_activation;
DROP TABLE IF EXISTS sms_activation;

--
-- Drop saved simple searches on nodes since their structure has changed
--
DELETE FROM savedsearch WHERE namespace='pfappserver::Model::SavedSearch::Node' AND query LIKE '%simple_search?filter%';

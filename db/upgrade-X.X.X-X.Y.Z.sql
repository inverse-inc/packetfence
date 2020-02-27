--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 9;
SET @MINOR_VERSION = 3;
SET @SUBMINOR_VERSION = 9;



SET @PREV_MAJOR_VERSION = 9;
SET @PREV_MINOR_VERSION = 3;
SET @PREV_SUBMINOR_VERSION = 0;


--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8 | @PREV_SUBMINOR_VERSION;

DROP PROCEDURE IF EXISTS ValidateVersion;


--
-- Create the pki table cas
--

\! echo "Creating table 'pki_cas'...";
CREATE TABLE IF NOT EXISTS `pki_cas` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `cn` varchar(255) DEFAULT NULL,
  `mail` varchar(255) DEFAULT NULL,
  `organisation` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `locality` varchar(255) DEFAULT NULL,
  `street_address` varchar(255) DEFAULT NULL,
  `postal_code` varchar(255) DEFAULT NULL,
  `key_type` int(11) DEFAULT NULL,
  `key_size` int(11) DEFAULT NULL,
  `digest` int(11) DEFAULT NULL,
  `key_usage` varchar(255) DEFAULT NULL,
  `extended_key_usage` varchar(255) DEFAULT NULL,
  `days` int(11) DEFAULT NULL,
  `key` longtext,
  `cert` longtext,
  `issuer_key_hash` varchar(255) DEFAULT NULL,
  `issuer_name_hash` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `cn` (`cn`),
  UNIQUE KEY `uix_cas_issuer_key_hash` (`issuer_key_hash`),
  UNIQUE KEY `uix_cas_issuer_name_hash` (`issuer_name_hash`),
  KEY `mail` (`mail`),
  KEY `organisation` (`organisation`),
  KEY `idx_cas_deleted_at` (`deleted_at`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;

--
-- Create the pki table certs
--

\! echo "Creating table 'pki_certs'...";
CREATE TABLE IF NOT EXISTS `pki_certs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `cn` varchar(255) DEFAULT NULL,
  `mail` varchar(255) DEFAULT NULL,
  `ca_id` int(10) unsigned DEFAULT NULL,
  `ca_name` varchar(255) DEFAULT NULL,
  `street_address` varchar(255) DEFAULT NULL,
  `organisation` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `locality` varchar(255) DEFAULT NULL,
  `postal_code` varchar(255) DEFAULT NULL,
  `key` longtext,
  `cert` longtext,
  `profile_id` int(10) unsigned DEFAULT NULL,
  `profile_name` varchar(255) DEFAULT NULL,
  `valid_until` timestamp NULL DEFAULT NULL,
  `date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `serial_number` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `cn` (`cn`),
  KEY `profile_name` (`profile_name`),
  KEY `valid_until` (`valid_until`),
  KEY `idx_certs_deleted_at` (`deleted_at`),
  KEY `mail` (`mail`),
  KEY `ca_id` (`ca_id`),
  KEY `ca_name` (`ca_name`),
  KEY `organisation` (`organisation`),
  KEY `profile_id` (`profile_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;

--
-- Create the pki table profiles
--

\! echo "Creating table 'pki_profiles'...";
CREATE TABLE IF NOT EXISTS `pki_profiles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `ca_id` int(10) unsigned DEFAULT NULL,
  `ca_name` varchar(255) DEFAULT NULL,
  `validity` int(11) DEFAULT NULL,
  `key_type` int(11) DEFAULT NULL,
  `key_size` int(11) DEFAULT NULL,
  `digest` int(11) DEFAULT NULL,
  `key_usage` varchar(255) DEFAULT NULL,
  `extended_key_usage` varchar(255) DEFAULT NULL,
  `p12_mail_password` int(11) DEFAULT NULL,
  `p12_mail_subject` varchar(255) DEFAULT NULL,
  `p12_mail_from` varchar(255) DEFAULT NULL,
  `p12_mail_header` varchar(255) DEFAULT NULL,
  `p12_mail_footer` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `idx_profiles_deleted_at` (`deleted_at`),
  KEY `ca_id` (`ca_id`),
  KEY `ca_name` (`ca_name`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;


--
-- Create the pki table revoked_certs
--

\! echo "Creating table 'pki_revoked_certs'...";
CREATE TABLE IF NOT EXISTS `pki_revoked_certs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `cn` varchar(255) DEFAULT NULL,
  `mail` varchar(255) DEFAULT NULL,
  `ca_id` int(10) unsigned DEFAULT NULL,
  `ca_name` varchar(255) DEFAULT NULL,
  `street_address` varchar(255) DEFAULT NULL,
  `organisation` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `locality` varchar(255) DEFAULT NULL,
  `postal_code` varchar(255) DEFAULT NULL,
  `key` longtext,
  `cert` longtext,
  `profile_id` int(10) unsigned DEFAULT NULL,
  `profile_name` varchar(255) DEFAULT NULL,
  `valid_until` timestamp NULL DEFAULT NULL,
  `date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `serial_number` varchar(255) DEFAULT NULL,
  `revoked` timestamp NULL DEFAULT NULL,
  `crl_reason` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `valid_until` (`valid_until`),
  KEY `crl_reason` (`crl_reason`),
  KEY `idx_revoked_certs_deleted_at` (`deleted_at`),
  KEY `cn` (`cn`),
  KEY `mail` (`mail`),
  KEY `ca_id` (`ca_id`),
  KEY `profile_id` (`profile_id`),
  KEY `profile_name` (`profile_name`),
  KEY `ca_name` (`ca_name`),
  KEY `organisation` (`organisation`),
  KEY `revoked` (`revoked`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Updating to current version
--
DELIMITER //
CREATE PROCEDURE ValidateVersion()
BEGIN
    DECLARE PREVIOUS_VERSION int(11);
    DECLARE PREVIOUS_VERSION_STRING varchar(11);
    DECLARE _message varchar(255);
    SELECT id, version INTO PREVIOUS_VERSION, PREVIOUS_VERSION_STRING FROM pf_version ORDER BY id DESC LIMIT 1;

      IF PREVIOUS_VERSION != @PREV_VERSION_INT THEN
        SELECT CONCAT('PREVIOUS VERSION ', PREVIOUS_VERSION_STRING, ' DOES NOT MATCH ', CONCAT_WS('.', @PREV_MAJOR_VERSION, @PREV_MINOR_VERSION, @PREV_SUBMINOR_VERSION)) INTO _message;
        SIGNAL SQLSTATE VALUE '99999'
              SET MESSAGE_TEXT = _message;
      END IF;
END
//

DELIMITER ;
\! echo "Checking PacketFence schema version...";
call ValidateVersion;
DROP PROCEDURE IF EXISTS ValidateVersion;


\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

\! echo "Upgrade completed successfully.";

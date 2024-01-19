SET sql_mode = "NO_ENGINE_SUBSTITUTION";

--
-- PacketFence SQL schema upgrade from 11.0 to 11.1
--


--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 13;
SET @MINOR_VERSION = 1;


SET @PREV_MAJOR_VERSION = 13;
SET @PREV_MINOR_VERSION = 0;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8;

SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8;

DROP PROCEDURE IF EXISTS ValidateVersion;
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
        SELECT CONCAT('PREVIOUS VERSION ', PREVIOUS_VERSION_STRING, ' DOES NOT MATCH ', CONCAT_WS('.', @PREV_MAJOR_VERSION, @PREV_MINOR_VERSION)) INTO _message;
        SIGNAL SQLSTATE VALUE '99999'
              SET MESSAGE_TEXT = _message;
      END IF;
END
//

DELIMITER ;

\! echo "Checking PacketFence schema version...";
call ValidateVersion;

DROP PROCEDURE IF EXISTS ValidateVersion;

--
-- UPGRADE STATEMENTS GO HERE
--

--
-- Table structure for table `pki_scep_servers`
--

CREATE TABLE IF NOT EXISTS `pki_scep_servers` (
    `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    `created_at` datetime(3) DEFAULT NULL,
    `updated_at` datetime(3) DEFAULT NULL,
    `deleted_at` datetime(3) DEFAULT NULL,
    `name` varchar(191) DEFAULT NULL,
    `url` longtext DEFAULT NULL,
    `shared_secret` longtext DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`),
    KEY `idx_pki_scep_servers_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';
--
-- Default values for pki_scep_servers table
--

INSERT IGNORE INTO `pki_scep_servers` VALUES (1,'2023-11-09 10:36:34.489','2023-11-09 10:36:34.489',NULL,'Null','http://127.0.0.1','password');

\! echo "altering pki_cas"
ALTER TABLE `pki_cas`
    MODIFY `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    MODIFY`created_at` datetime(3) DEFAULT NULL,
    MODIFY`updated_at` datetime(3) DEFAULT NULL,
    MODIFY`deleted_at` datetime(3) DEFAULT NULL,
    MODIFY`cn` varchar(191) DEFAULT NULL,
    MODIFY`mail` varchar(191) DEFAULT NULL,
    MODIFY`organisation` varchar(191) DEFAULT NULL,
    MODIFY`organisational_unit` longtext DEFAULT NULL,
    MODIFY`country` longtext DEFAULT NULL,
    MODIFY`state` longtext DEFAULT NULL,
    MODIFY`locality` longtext DEFAULT NULL,
    MODIFY`street_address` longtext DEFAULT NULL,
    MODIFY`postal_code` longtext DEFAULT NULL,
    MODIFY`key_type` bigint(20) DEFAULT NULL,
    MODIFY`key_size` bigint(20) DEFAULT NULL,
    MODIFY`digest` bigint(20) DEFAULT NULL,
    MODIFY`key_usage` longtext DEFAULT NULL,
    MODIFY`extended_key_usage` longtext DEFAULT NULL,
    MODIFY`days` bigint(20) DEFAULT NULL,
    MODIFY`key` longtext DEFAULT NULL,
    MODIFY`cert` longtext DEFAULT NULL,
    MODIFY`issuer_key_hash` longtext DEFAULT NULL,
    MODIFY`issuer_name_hash` longtext DEFAULT NULL,
    MODIFY`ocsp_url` longtext DEFAULT NULL,
    MODIFY`serial_number` bigint(20) DEFAULT NULL,
    DROP KEY IF EXISTS `uix_cas_issuer_key_hash`,
    DROP KEY IF EXISTS `uix_cas_issuer_name_hash`,
    DROP KEY IF EXISTS `idx_cas_deleted_at`,
    ADD KEY IF NOT EXISTS `idx_pki_cas_deleted_at` (`deleted_at`);

\! echo "altering pki_profiles"
ALTER TABLE `pki_profiles`
    ADD IF NOT EXISTS `scep_server_id` bigint(20) unsigned DEFAULT NULL  AFTER `cloud_service`,
    ADD IF NOT EXISTS `scep_server_enabled` bigint(20) unsigned DEFAULT NULL;


\! echo "altering pki_profiles 2nd pass"
ALTER TABLE `pki_profiles`
    MODIFY `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    MODIFY `created_at` datetime(3) DEFAULT NULL,
    MODIFY `updated_at` datetime(3) DEFAULT NULL,
    MODIFY `deleted_at` datetime(3) DEFAULT NULL,
    MODIFY `name` varchar(191) DEFAULT NULL,
    MODIFY `mail` varchar(191) DEFAULT NULL,
    MODIFY `organisation` varchar(191) DEFAULT NULL,
    MODIFY `organisational_unit` longtext DEFAULT NULL,
    MODIFY `country` longtext DEFAULT NULL,
    MODIFY `state` longtext DEFAULT NULL,
    MODIFY `locality` longtext DEFAULT NULL,
    MODIFY `street_address` longtext DEFAULT NULL,
    MODIFY `postal_code` longtext DEFAULT NULL,
    MODIFY `ca_id` bigint(20) unsigned DEFAULT NULL,
    MODIFY `ca_name` varchar(191) DEFAULT NULL,
    MODIFY `validity` bigint(20) DEFAULT NULL,
    MODIFY `key_type` bigint(20) DEFAULT NULL,
    MODIFY `key_size` bigint(20) DEFAULT NULL,
    MODIFY `digest` bigint(20) DEFAULT NULL,
    MODIFY `key_usage` longtext DEFAULT NULL,
    MODIFY `extended_key_usage` longtext DEFAULT NULL,
    MODIFY `ocsp_url` longtext DEFAULT NULL,
    MODIFY `p12_mail_password` bigint(20) DEFAULT NULL,
    MODIFY `p12_mail_subject` longtext DEFAULT NULL,
    MODIFY `p12_mail_from` longtext DEFAULT NULL,
    MODIFY `p12_mail_header` longtext DEFAULT NULL,
    MODIFY `p12_mail_footer` longtext DEFAULT NULL,
    MODIFY `scep_enabled` bigint(20) DEFAULT NULL,
    MODIFY `scep_challenge_password` longtext DEFAULT NULL,
    MODIFY `scep_days_before_renewal` bigint(20) DEFAULT 14,
    MODIFY `days_before_renewal` bigint(20) DEFAULT 14,
    MODIFY `renewal_mail` bigint(20) DEFAULT 1,
    MODIFY `days_before_renewal_mail` bigint(20) DEFAULT 14,
    MODIFY `renewal_mail_subject` varchar(191) DEFAULT 'Certificate expiration',
    MODIFY `renewal_mail_from` longtext DEFAULT NULL,
    MODIFY `renewal_mail_header` longtext DEFAULT NULL,
    MODIFY `renewal_mail_footer` longtext DEFAULT NULL,
    MODIFY `revoked_valid_until` bigint(20) DEFAULT 14,
    MODIFY `cloud_enabled` bigint(20) DEFAULT NULL,
    MODIFY `cloud_service` longtext DEFAULT NULL,
    MODIFY `scep_server_enabled` bigint(20) unsigned DEFAULT NULL,
    MODIFY `scep_server_id` bigint(20) unsigned DEFAULT NULL,
    ADD PRIMARY KEY IF NOT EXISTS (`id`),
    ADD UNIQUE KEY IF NOT EXISTS `name` (`name`),
    ADD KEY IF NOT EXISTS `organisation` (`organisation`),
    ADD KEY IF NOT EXISTS `idx_pki_profiles_deleted_at` (`deleted_at`),
    ADD KEY IF NOT EXISTS `scep_server__id` (`scep_server_id`),
    ADD KEY IF NOT EXISTS `mail` (`mail`),
    DROP KEY IF EXISTS `profile_id`,
    DROP KEY IF EXISTS `idx_profiles_deleted_at`,
    ADD CONSTRAINT `fk_pki_profiles_ca` FOREIGN KEY IF NOT EXISTS (`ca_id`) REFERENCES `pki_cas` (`id`),
    ADD CONSTRAINT `fk_pki_profiles_scep_server` FOREIGN KEY IF NOT EXISTS (`scep_server_id`) REFERENCES `pki_scep_servers` (`id`);

\! echo "altering pki_certs"
ALTER TABLE `pki_certs`
    MODIFY `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    MODIFY `created_at` datetime(3) DEFAULT NULL,
    MODIFY `updated_at` datetime(3) DEFAULT NULL,
    MODIFY `deleted_at` datetime(3) DEFAULT NULL,
    MODIFY `cn` longtext DEFAULT NULL,
    MODIFY `mail` varchar(191) DEFAULT NULL,
    MODIFY `ca_id` bigint(20) unsigned DEFAULT NULL,
    MODIFY `ca_name` varchar(191) DEFAULT NULL,
    MODIFY `street_address` longtext DEFAULT NULL,
    MODIFY `organisation` varchar(191) DEFAULT NULL,
    MODIFY `organisational_unit` longtext DEFAULT NULL,
    MODIFY `country` longtext DEFAULT NULL,
    MODIFY `state` longtext DEFAULT NULL,
    MODIFY `locality` longtext DEFAULT NULL,
    MODIFY `postal_code` longtext DEFAULT NULL,
    MODIFY `key` longtext DEFAULT NULL,
    MODIFY `cert` longtext DEFAULT NULL,
    MODIFY `profile_id` bigint(20) unsigned DEFAULT NULL,
    MODIFY `profile_name` varchar(191) DEFAULT NULL,
    MODIFY `valid_until` datetime(3) DEFAULT NULL,
    MODIFY `not_before` datetime(3) DEFAULT NULL,
    MODIFY `date` datetime(3) DEFAULT current_timestamp(3),
    MODIFY `serial_number` longtext DEFAULT NULL,
    MODIFY `dns_names` longtext DEFAULT NULL,
    MODIFY `ip_addresses` longtext DEFAULT NULL,
    MODIFY `scep` tinyint(1) DEFAULT 0,
    MODIFY `csr` tinyint(1) DEFAULT 0,
    MODIFY `alert` tinyint(1) DEFAULT 0,
    MODIFY `subject` varchar(191) DEFAULT NULL,
    ADD PRIMARY KEY IF NOT EXISTS (`id`),
    ADD UNIQUE KEY IF NOT EXISTS `subject` (`subject`),
    ADD KEY IF NOT EXISTS `idx_pki_certs_deleted_at` (`deleted_at`),
    ADD KEY IF NOT EXISTS `mail` (`mail`),
    ADD KEY IF NOT EXISTS `profile_id` (`profile_id`),
    ADD KEY IF NOT EXISTS `valid_until` (`valid_until`),
    ADD KEY IF NOT EXISTS `not_before` (`not_before`),
    ADD KEY IF NOT EXISTS `ca_name` (`ca_name`),
    ADD KEY IF NOT EXISTS `organisation` (`organisation`),
    ADD KEY IF NOT EXISTS `profile_name` (`profile_name`),
    DROP KEY IF EXISTS `idx_certs_deleted_at`,
    ADD CONSTRAINT `fk_pki_certs_ca` FOREIGN KEY IF NOT EXISTS (`ca_id`) REFERENCES `pki_cas` (`id`),
    ADD CONSTRAINT `fk_pki_certs_profile` FOREIGN KEY IF NOT EXISTS (`profile_id`) REFERENCES `pki_profiles` (`id`);


\! echo "altering pki_revoked_certs"
ALTER TABLE `pki_revoked_certs`
    MODIFY `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    MODIFY `created_at` datetime(3) DEFAULT NULL,
    MODIFY `updated_at` datetime(3) DEFAULT NULL,
    MODIFY `deleted_at` datetime(3) DEFAULT NULL,
    MODIFY `cn` varchar(191) DEFAULT NULL,
    MODIFY `mail` varchar(191) DEFAULT NULL,
    MODIFY `ca_id` bigint(20) unsigned DEFAULT NULL,
    MODIFY `ca_name` varchar(191) DEFAULT NULL,
    MODIFY `street_address` longtext DEFAULT NULL,
    MODIFY `organisation` varchar(191) DEFAULT NULL,
    MODIFY `organisational_unit` longtext DEFAULT NULL,
    MODIFY `country` longtext DEFAULT NULL,
    MODIFY `state` longtext DEFAULT NULL,
    MODIFY `locality` longtext DEFAULT NULL,
    MODIFY `postal_code` longtext DEFAULT NULL,
    MODIFY `key` longtext DEFAULT NULL,
    MODIFY `cert` longtext DEFAULT NULL,
    MODIFY `profile_id` bigint(20) unsigned DEFAULT NULL,
    MODIFY `profile_name` varchar(191) DEFAULT NULL,
    MODIFY `valid_until` datetime(3) DEFAULT NULL,
    MODIFY `not_before` datetime(3) DEFAULT NULL,
    MODIFY `date` datetime(3) DEFAULT current_timestamp(3),
    MODIFY `serial_number` longtext DEFAULT NULL,
    MODIFY `dns_names` longtext DEFAULT NULL,
    MODIFY `ip_addresses` longtext DEFAULT NULL,
    MODIFY `revoked` datetime(3) DEFAULT NULL,
    MODIFY `crl_reason` bigint(20) DEFAULT NULL,
    MODIFY `subject` longtext DEFAULT NULL,
    ADD PRIMARY KEY IF NOT EXISTS (`id`),
    ADD KEY IF NOT EXISTS `mail` (`mail`),
    ADD KEY IF NOT EXISTS `not_before` (`not_before`),
    ADD KEY IF NOT EXISTS `revoked` (`revoked`),
    DROP KEY IF EXISTS `idx_revoked_certs_deleted_at`,
    ADD KEY IF NOT EXISTS `idx_pki_revoked_certs_deleted_at` (`deleted_at`),
    ADD CONSTRAINT `fk_pki_revoked_certs_ca` FOREIGN KEY IF NOT EXISTS (`ca_id`) REFERENCES `pki_cas` (`id`),
    ADD CONSTRAINT `fk_pki_revoked_certs_profile` FOREIGN KEY IF NOT EXISTS (`profile_id`) REFERENCES `pki_profiles` (`id`);


\! echo "altering pki_cas charset"
ALTER TABLE pki_cas
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

\! echo "altering pki_profiles charset"
ALTER TABLE pki_profiles
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

\! echo "altering pki_certs charset"
ALTER TABLE pki_certs
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

\! echo "altering pki_revoked_certs charset"
ALTER TABLE pki_revoked_certs
    CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

\! echo "altering node"
ALTER TABLE node
    DROP IF EXISTS lastskip;

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());


\! echo "Upgrade completed successfully.";

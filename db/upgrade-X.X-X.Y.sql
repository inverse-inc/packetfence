SET sql_mode = "NO_ENGINE_SUBSTITUTION";

--
-- PacketFence SQL schema upgrade from 15.0 to 15.1
--


--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 16;
SET @MINOR_VERSION = 0;


SET @PREV_MAJOR_VERSION = 15;
SET @PREV_MINOR_VERSION = 2;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8;

SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8;

--
-- Stored procedures
--
-- All procedures used by this upgrade are defined together here, then dropped
-- in the cleanup section at the end.
--
-- The Add*/Drop* helpers exist for cross-engine portability: MariaDB supports
-- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, `ADD [UNIQUE] {KEY|INDEX} IF NOT
-- EXISTS` and `DROP INDEX IF EXISTS`, but stock MySQL (5.6/5.7/8.0) does NOT.
-- To keep a single upgrade script that runs cleanly and re-runnably
-- (idempotent) on MariaDB, MySQL 5 and MySQL 8, do NOT use the `IF [NOT]
-- EXISTS` clause on ALTER TABLE -- call these helpers instead. They check
-- INFORMATION_SCHEMA and emit the DDL via a prepared statement only when
-- needed. Every construct used (stored procedures with IN params,
-- INFORMATION_SCHEMA, PREPARE/EXECUTE/DEALLOCATE on ALTER TABLE) is supported
-- on MySQL >= 5.0.13 and every MariaDB release.
--

--
-- ValidateVersion: aborts the upgrade unless the DB is at the expected
-- previous version (@PREV_VERSION_INT).
--
DROP PROCEDURE IF EXISTS ValidateVersion;
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

--
-- AddColumnUnlessExists: add a column only if it is missing.
--   Example:
--   CALL AddColumnUnlessExists('locationlog', 'switch_id',
--       'VARCHAR(255) DEFAULT NULL AFTER `switch_mac`');
--
DROP PROCEDURE IF EXISTS AddColumnUnlessExists;
DELIMITER //
CREATE PROCEDURE AddColumnUnlessExists(
    IN p_table      VARCHAR(64),
    IN p_column     VARCHAR(64),
    IN p_definition TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME   = p_table
          AND COLUMN_NAME  = p_column
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_column, '` ', p_definition);
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END
//
DELIMITER ;

--
-- DropColumnIfExists: drop a column only if it exists.
--   Example:
--   CALL DropColumnIfExists('locationlog', 'old_column');
--
DROP PROCEDURE IF EXISTS DropColumnIfExists;
DELIMITER //
CREATE PROCEDURE DropColumnIfExists(
    IN p_table  VARCHAR(64),
    IN p_column VARCHAR(64)
)
BEGIN
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME   = p_table
          AND COLUMN_NAME  = p_column
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `', p_table, '` DROP COLUMN `', p_column, '`');
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END
//
DELIMITER ;

--
-- AddIndexUnlessExists: add an index/key only if it is missing. p_definition
-- is the full index clause as it would follow `ADD `.
--   Examples:
--   CALL AddIndexUnlessExists('node', 'node_bypass_role_id',
--       'INDEX `node_bypass_role_id` (`bypass_role_id`)');
--   CALL AddIndexUnlessExists('pki_certs', 'cn_serial',
--       'UNIQUE KEY `cn_serial` (`cn`,`serial_number`) USING HASH');
--
DROP PROCEDURE IF EXISTS AddIndexUnlessExists;
DELIMITER //
CREATE PROCEDURE AddIndexUnlessExists(
    IN p_table      VARCHAR(64),
    IN p_index      VARCHAR(64),
    IN p_definition TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME   = p_table
          AND INDEX_NAME   = p_index
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `', p_table, '` ADD ', p_definition);
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END
//
DELIMITER ;

--
-- DropIndexIfExists: drop an index only if it exists.
--   Example:
--   CALL DropIndexIfExists('bandwidth_accounting', 'bandwidth_accounting_tenant_id_mac');
--
DROP PROCEDURE IF EXISTS DropIndexIfExists;
DELIMITER //
CREATE PROCEDURE DropIndexIfExists(
    IN p_table VARCHAR(64),
    IN p_index VARCHAR(64)
)
BEGIN
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME   = p_table
          AND INDEX_NAME   = p_index
    ) THEN
        SET @ddl = CONCAT('ALTER TABLE `', p_table, '` DROP INDEX `', p_index, '`');
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END
//
DELIMITER ;

--
-- Updating to current version
--
\! echo "Checking PacketFence schema version...";
call ValidateVersion;

--
-- UPGRADE STATEMENTS GO HERE
--

--
-- Index switch_observability_acls by mac for the switch_observability_acls_cleanup task
-- and for per-device ACL lookups
--
\! echo "Adding index switch_observability_acls_mac_enforcement to switch_observability_acls...";
CALL AddIndexUnlessExists('switch_observability_acls', 'switch_observability_acls_mac_enforcement',
    'KEY `switch_observability_acls_mac_enforcement` (`mac`,`enforcement_timestamp`)');

--
-- Remove phantom switch_observability rows written by 15.1 / 15.2: the flow
-- aggregator upserted the agent address even when the collector had not set
-- it ("invalid IP") or when it was 0.0.0.0, and pfacct accepted an empty id.
--
\! echo "Removing phantom switch_observability rows...";
DELETE FROM switch_observability WHERE switch_id IN ('', 'invalid IP', '0.0.0.0');

--
-- Record the authentication source type alongside the source id in auth_log
--
\! echo "Adding column source_type to auth_log...";
CALL AddColumnUnlessExists('auth_log', 'source_type',
    'VARCHAR(255) NOT NULL DEFAULT "" AFTER `source`');

--
-- pfpki: configurable renewal-mail schedule (Profile.RenewalMailDays /
-- Cert.AlertedDays)
--
\! echo "Adding column renewal_mail_days to pki_profiles...";
CALL AddColumnUnlessExists('pki_profiles', 'renewal_mail_days',
    'longtext DEFAULT NULL AFTER `maximum_duplicated_cn`');

\! echo "Adding column alerted_days to pki_certs...";
CALL AddColumnUnlessExists('pki_certs', 'alerted_days',
    'longtext DEFAULT NULL AFTER `alert`');

--
-- pfpki: ACME account back-link on issued certs (ownership check for
-- ACME cert download / revoke-cert)
--
\! echo "Adding column acme_account_id to pki_certs...";
CALL AddColumnUnlessExists('pki_certs', 'acme_account_id',
    'bigint(20) unsigned DEFAULT NULL AFTER `alerted_days`');
CALL AddIndexUnlessExists('pki_certs', 'idx_pki_certs_acme_account_id',
    'KEY `idx_pki_certs_acme_account_id` (`acme_account_id`)');

--
-- pfpki: ACME (RFC 8555) per-profile settings
--
\! echo "Adding ACME columns to pki_profiles...";
CALL AddColumnUnlessExists('pki_profiles', 'acme_enabled',
    'bigint(20) DEFAULT 0 AFTER `renewal_mail_days`');
CALL AddColumnUnlessExists('pki_profiles', 'acme_allowed_identifiers',
    'longtext DEFAULT NULL AFTER `acme_enabled`');
CALL AddColumnUnlessExists('pki_profiles', 'acme_eab_required',
    'bigint(20) DEFAULT 1 AFTER `acme_allowed_identifiers`');
CALL AddColumnUnlessExists('pki_profiles', 'acme_attestation_formats',
    'longtext DEFAULT NULL AFTER `acme_eab_required`');
CALL AddColumnUnlessExists('pki_profiles', 'acme_attestation_roots',
    'longtext DEFAULT NULL AFTER `acme_attestation_formats`');
CALL AddColumnUnlessExists('pki_profiles', 'acme_account_expiry',
    'bigint(20) DEFAULT 365 AFTER `acme_attestation_roots`');
CALL AddColumnUnlessExists('pki_profiles', 'acme_order_expiry',
    'bigint(20) DEFAULT 7 AFTER `acme_account_expiry`');
CALL AddColumnUnlessExists('pki_profiles', 'acme_authz_expiry',
    'bigint(20) DEFAULT 24 AFTER `acme_order_expiry`');

--
-- pfpki: ACME state tables
--
\! echo "Creating ACME tables...";
CREATE TABLE IF NOT EXISTS `pki_acme_accounts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `profile_id` bigint(20) unsigned NOT NULL,
  `key_id` varchar(256) DEFAULT NULL,
  `key_thumbprint` varchar(64) DEFAULT NULL,
  `jwk` longtext DEFAULT NULL,
  `status` varchar(16) DEFAULT 'valid',
  `contact` text DEFAULT NULL,
  `external_account_key_id` varchar(64) DEFAULT NULL,
  `expires_at` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `acme_account_keyid` (`key_id`),
  KEY `acme_account_thumbprint` (`key_thumbprint`),
  KEY `idx_pki_acme_accounts_profile_id` (`profile_id`),
  KEY `idx_pki_acme_accounts_external_account_key_id` (`external_account_key_id`),
  KEY `idx_pki_acme_accounts_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_pki_acme_accounts_profile` FOREIGN KEY (`profile_id`) REFERENCES `pki_profiles` (`id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

CREATE TABLE IF NOT EXISTS `pki_acme_nonces` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `token` varchar(64) DEFAULT NULL,
  `expires_at` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `acme_nonce_token` (`token`),
  KEY `idx_pki_acme_nonces_expires_at` (`expires_at`),
  KEY `idx_pki_acme_nonces_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

CREATE TABLE IF NOT EXISTS `pki_acme_orders` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `account_id` bigint(20) unsigned NOT NULL,
  `status` varchar(16) DEFAULT 'pending',
  `expires_at` datetime(3) DEFAULT NULL,
  `not_before` datetime(3) DEFAULT NULL,
  `not_after` datetime(3) DEFAULT NULL,
  `identifiers` text DEFAULT NULL,
  `authz_ids` text DEFAULT NULL,
  `cert_serial_number` varchar(80) DEFAULT NULL,
  `error` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pki_acme_orders_account_id` (`account_id`),
  KEY `idx_pki_acme_orders_expires_at` (`expires_at`),
  KEY `idx_pki_acme_orders_cert_serial_number` (`cert_serial_number`),
  KEY `idx_pki_acme_orders_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_pki_acme_orders_account` FOREIGN KEY (`account_id`) REFERENCES `pki_acme_accounts` (`id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

CREATE TABLE IF NOT EXISTS `pki_acme_authzs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `account_id` bigint(20) unsigned NOT NULL,
  `order_id` bigint(20) unsigned NOT NULL,
  `identifier_type` varchar(32) DEFAULT NULL,
  `value` varchar(255) DEFAULT NULL,
  `status` varchar(16) DEFAULT 'pending',
  `expires_at` datetime(3) DEFAULT NULL,
  `wildcard` tinyint(1) DEFAULT 0,
  `attested_spki` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pki_acme_authzs_account_id` (`account_id`),
  KEY `idx_pki_acme_authzs_order_id` (`order_id`),
  KEY `idx_pki_acme_authzs_expires_at` (`expires_at`),
  KEY `idx_pki_acme_authzs_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_pki_acme_authzs_account` FOREIGN KEY (`account_id`) REFERENCES `pki_acme_accounts` (`id`),
  CONSTRAINT `fk_pki_acme_authzs_order` FOREIGN KEY (`order_id`) REFERENCES `pki_acme_orders` (`id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

CREATE TABLE IF NOT EXISTS `pki_acme_challenges` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `authz_id` bigint(20) unsigned NOT NULL,
  `type` varchar(32) DEFAULT NULL,
  `token` varchar(64) DEFAULT NULL,
  `status` varchar(16) DEFAULT 'pending',
  `validated` datetime(3) DEFAULT NULL,
  `error` text DEFAULT NULL,
  `retry_after` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pki_acme_challenges_authz_id` (`authz_id`),
  KEY `idx_pki_acme_challenges_token` (`token`),
  KEY `idx_pki_acme_challenges_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_pki_acme_challenges_authz` FOREIGN KEY (`authz_id`) REFERENCES `pki_acme_authzs` (`id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

CREATE TABLE IF NOT EXISTS `pki_acme_eab_keys` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  `profile_id` bigint(20) unsigned NOT NULL,
  `key_id` varchar(64) DEFAULT NULL,
  `hmac_key` varchar(128) DEFAULT NULL,
  `reference` varchar(128) DEFAULT NULL,
  `bound_account_id` bigint(20) unsigned DEFAULT NULL,
  `bound_at` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `acme_eab_keyid` (`key_id`),
  KEY `idx_pki_acme_eab_keys_profile_id` (`profile_id`),
  KEY `idx_pki_acme_eab_keys_bound_account_id` (`bound_account_id`),
  KEY `idx_pki_acme_eab_keys_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_pki_acme_eab_keys_profile` FOREIGN KEY (`profile_id`) REFERENCES `pki_profiles` (`id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Clean up the helper / validation procedures
--
DROP PROCEDURE IF EXISTS ValidateVersion;
DROP PROCEDURE IF EXISTS AddColumnUnlessExists;
DROP PROCEDURE IF EXISTS DropColumnIfExists;
DROP PROCEDURE IF EXISTS AddIndexUnlessExists;
DROP PROCEDURE IF EXISTS DropIndexIfExists;

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());


\! echo "Upgrade completed successfully.";

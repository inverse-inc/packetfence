SET sql_mode = "NO_ENGINE_SUBSTITUTION";

--
-- PacketFence SQL schema upgrade from 15.0 to 15.1
--


--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 15;
SET @MINOR_VERSION = 2;


SET @PREV_MAJOR_VERSION = 15;
SET @PREV_MINOR_VERSION = 1;

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
-- Record the authentication source type alongside the source id in auth_log
--
\! echo "Adding column source_type to auth_log...";
CALL AddColumnUnlessExists('auth_log', 'source_type',
    'VARCHAR(255) NOT NULL DEFAULT "" AFTER `source`');

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

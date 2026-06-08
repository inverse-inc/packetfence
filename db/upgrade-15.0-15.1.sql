SET sql_mode = "NO_ENGINE_SUBSTITUTION";

--
-- PacketFence SQL schema upgrade from 15.0 to 15.1
--


--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 15;
SET @MINOR_VERSION = 1;


SET @PREV_MAJOR_VERSION = 15;
SET @PREV_MINOR_VERSION = 0;

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

\! echo "Updating locationlog";
CALL AddColumnUnlessExists('locationlog', 'switch_id',
    'VARCHAR(255) DEFAULT NULL AFTER `switch_mac`');

\! echo "Updating locationlog_history";
CALL AddColumnUnlessExists('locationlog_history', 'switch_id',
    'VARCHAR(255) DEFAULT NULL AFTER `switch_mac`');

\! echo "Updating locationlog_insert_in_history_after_insert";
DELIMITER /
DROP TRIGGER IF EXISTS locationlog_insert_in_history_after_insert;
CREATE TRIGGER locationlog_insert_in_history_after_insert AFTER UPDATE on locationlog
FOR EACH ROW
BEGIN
    IF OLD.session_id <=> NEW.session_id THEN
        INSERT INTO locationlog_history
        SET
            mac = OLD.mac,
            switch = OLD.switch,
            port = OLD.port,
            vlan = OLD.vlan,
            role = OLD.role,
            connection_type = OLD.connection_type,
            connection_sub_type = OLD.connection_sub_type,
            dot1x_username = OLD.dot1x_username,
            ssid = OLD.ssid,
            start_time = OLD.start_time,
            end_time = CASE
            WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
            WHEN OLD.end_time > NOW() THEN NOW()
            ELSE OLD.end_time
            END,
            switch_ip = OLD.switch_ip,
            switch_mac = OLD.switch_mac,
            switch_id = OLD.switch_id,
            stripped_user_name = OLD.stripped_user_name,
            realm = OLD.realm,
            session_id = OLD.session_id,
            ifDesc = OLD.ifDesc,
            voip = OLD.voip
        ;
  END IF;
END /
DELIMITER ;

--
-- Create switch_observability
--

CREATE TABLE IF NOT EXISTS switch_observability (
  `switch_id` varchar(255) PRIMARY KEY NOT NULL,
  `visibility_timestamp` DATETIME default NULL
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

--
-- Create switch_observability_acls
--

CREATE TABLE IF NOT EXISTS switch_observability_acls (
  `switch_id` varchar(255) NOT NULL,
  `mac` varchar(255) NOT NULL,
  `port` varchar(255) DEFAULT NULL,
  `role_id` varchar(255) NOT NULL,
  `acl_type` varchar(255) NOT NULL,
  `acls` MEDIUMTEXT NOT NULL,
  `enforcement_timestamp` DATETIME default NULL,
  PRIMARY KEY (`switch_id`, `mac`, `role_id`),
  UNIQUE KEY `switch_observability_acls_switch_port` (`switch_id`, `port`)
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

--
-- Helper procedures for the schema files of the packages that add tables to
-- the PacketFence database (pfcmd plugin schema).
--
-- pfcmd plugin schema runs this file in the same session as each schema,
-- upgrade or teardown file of a package (both on the standard input of the
-- mysql client), and drops the procedures after it.
--
-- The Add*/Drop* helpers are the ones of db/upgrade-X.X-X.Y.sql (keep them in
-- sync, t/unittest/ui_plugins/upgrade_helpers.t checks it). They exist for
-- cross-engine portability: MariaDB supports `ALTER TABLE ... ADD COLUMN IF
-- NOT EXISTS`, `ADD [UNIQUE] {KEY|INDEX} IF NOT EXISTS` and `DROP INDEX IF
-- EXISTS`, but stock MySQL (5.6/5.7/8.0) does NOT. Do not use the `IF [NOT]
-- EXISTS` clause on ALTER TABLE in a package file: call these helpers, so the
-- file runs again cleanly (it is idempotent) on MariaDB and on MySQL 8.
--

--
-- ValidatePluginVersion: aborts unless the latest schema version of the
-- package p_name in plugin_version is p_prev_version_int
-- (MAJOR << 16 | MINOR << 8, as in pf_version).
--   Example, at the top of upgrade-1.0-1.1.sql of the package "acme":
--   CALL ValidatePluginVersion('acme', 1 << 16 | 0 << 8);
--
DROP PROCEDURE IF EXISTS ValidatePluginVersion;
DELIMITER //
CREATE PROCEDURE ValidatePluginVersion(
    IN p_name             VARCHAR(63) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci,
    IN p_prev_version_int INT
)
BEGIN
    DECLARE _previous_version INT DEFAULT NULL;
    DECLARE _previous_version_string VARCHAR(11) DEFAULT NULL;
    DECLARE _message VARCHAR(255);
    SELECT id, version INTO _previous_version, _previous_version_string FROM plugin_version
        WHERE name = p_name ORDER BY id DESC LIMIT 1;

    IF _previous_version IS NULL OR _previous_version != p_prev_version_int THEN
        SELECT CONCAT('PREVIOUS VERSION OF ', p_name, ' ', IFNULL(_previous_version_string, 'NONE'),
            ' DOES NOT MATCH ', CONCAT_WS('.', p_prev_version_int >> 16, (p_prev_version_int >> 8) & 255)) INTO _message;
        SIGNAL SQLSTATE VALUE '99999'
            SET MESSAGE_TEXT = _message;
    END IF;
END
//
DELIMITER ;

--
-- CopyRowsInBatches: copies the rows of p_from into p_to, p_batch values of
-- the integer key p_key at a time, one transaction per batch. A single
-- INSERT ... SELECT of a large table is one transaction, too large for a
-- Galera cluster (wsrep_max_ws_size) and long to replicate. p_columns is the
-- column list, the same for both tables.
--   Example, rebuilding a large table (see the Developers Guide, "Admin UI plugins"):
--   CALL CopyRowsInBatches('acme_item', 'acme_item_new', '`id`, `name`', 'id', 10000);
--
DROP PROCEDURE IF EXISTS CopyRowsInBatches;
DELIMITER //
CREATE PROCEDURE CopyRowsInBatches(
    IN p_from    VARCHAR(64),
    IN p_to      VARCHAR(64),
    IN p_columns TEXT,
    IN p_key     VARCHAR(64),
    IN p_batch   INT
)
BEGIN
    SET @copy_rows_min = NULL;
    SET @copy_rows_max = NULL;
    SET @ddl = CONCAT('SELECT MIN(`', p_key, '`), MAX(`', p_key, '`) INTO @copy_rows_min, @copy_rows_max FROM `', p_from, '`');
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    WHILE @copy_rows_min IS NOT NULL AND @copy_rows_min <= @copy_rows_max DO
        SET @ddl = CONCAT('INSERT INTO `', p_to, '` (', p_columns, ') SELECT ', p_columns, ' FROM `', p_from,
            '` WHERE `', p_key, '` >= ', @copy_rows_min, ' AND `', p_key, '` < ', @copy_rows_min + p_batch);
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
        SET @copy_rows_min = @copy_rows_min + p_batch;
    END WHILE;
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

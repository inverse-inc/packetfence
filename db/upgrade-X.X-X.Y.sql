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
-- Bound the metadata-lock wait for every ALTER below. lock_wait_timeout defaults
-- to 86400s, so a single blocked ALTER TABLE would park every later query on the
-- table behind its metadata lock for up to a day. Fail fast instead -- the
-- Add*UnlessExists helpers make a retry safe -- and stagger the rollout across
-- tenants rather than running them all at once.
--
\! echo "Bounding metadata-lock wait for the metering ALTERs...";
SET SESSION lock_wait_timeout = 5;

--
-- Record the authentication source type alongside the source id in auth_log
--
\! echo "Adding column source_type to auth_log...";
CALL AddColumnUnlessExists('auth_log', 'source_type',
    'VARCHAR(255) NOT NULL DEFAULT "" AFTER `source`');

--
-- Record the authentication source on the node itself.
--
-- pf::radius already resolves the matched source id and already treats it as a
-- node attribute (%NODE_ATTRIBUTES_TO_RADIUS_ATTRIBUTES maps source =>
-- PacketFence-Source), but it was only ever forwarded to radius_audit_log and
-- never persisted. person.source cannot serve this purpose: person is 1:N with
-- node (many devices share a pid, commonly 'default'), so it is last-write-wins
-- across a person's devices.
--
-- Not backfillable: existing rows keep NULL / "". Consumers must treat an empty
-- source_type as UNCLASSIFIED, never as a guest or a non-guest.
--
\! echo "Adding columns source and source_type to node...";
CALL AddColumnUnlessExists('node', 'source',
    'VARCHAR(255) DEFAULT NULL AFTER `bypass_acls`');
CALL AddColumnUnlessExists('node', 'source_type',
    'VARCHAR(255) NOT NULL DEFAULT "" AFTER `source`');

--
-- Record the source FAMILY alongside the concrete type.
--
-- source_type is the leaf: a Facebook login records 'Facebook', a Github login
-- 'Github', and so on. Anything that wants to ask "was this a social login?" has
-- to enumerate every provider that exists, and quietly gets the wrong answer the
-- next time one is added.
--
-- source_base_type is the family, taken from the class hierarchy
-- (pf::Authentication::Source::base_type): all six OAuth providers record
-- 'OAuth', AD/EDIR/GoogleWorkspaceLDAP record 'LDAP', Paypal/Stripe record
-- 'Billing'. A new provider inherits its family the moment it is written.
--
-- Not backfillable: existing rows keep "". Consumers must treat an empty value
-- as UNCLASSIFIED, never as a match or a non-match.
--
\! echo "Adding column source_base_type to node and auth_log...";
CALL AddColumnUnlessExists('node', 'source_base_type',
    'VARCHAR(255) NOT NULL DEFAULT "" AFTER `source_type`');
CALL AddColumnUnlessExists('auth_log', 'source_base_type',
    'VARCHAR(255) NOT NULL DEFAULT "" AFTER `source_type`');

--
-- Indexes for the usage-counting queries, and for the captive portal write path.
--
-- Each index is added by its own guarded ALTER (AddIndexUnlessExists) so a partial
-- prior run re-runs cleanly -- combining them into one ALTER would fail the retry
-- once any single index already existed. So this is three separate builds and three
-- metadata-lock windows, not one combined ALTER; each is bounded by the
-- lock_wait_timeout set above, and the rollout should be staggered across tenants.
--
-- auth_log_completion covers the UPDATE issued by pf::auth_log::invalidate_previous
-- and record_completed_guest/_oauth (WHERE process_name/source/mac ORDER BY
-- attempted_at DESC LIMIT 1), which has no usable index today: measured as a
-- full scan of every row on the synchronous path of every portal login. With 8
-- concurrent completions on a 5M-row auth_log a single UPDATE ran 322s and the
-- others timed out (ER_LOCK_WAIT_TIMEOUT); with the index the same workload
-- completes in 5.5s.
--
-- attempted_at must remain the last part and must be reached through full-length
-- equalities: prefix key parts are excluded from const_key_parts, which would
-- reintroduce the filesort this index exists to remove.
--
\! echo "Adding index auth_log_completion to auth_log...";
CALL AddIndexUnlessExists('auth_log', 'auth_log_completion',
    'KEY `auth_log_completion` (`mac`,`source`,`process_name`,`attempted_at`)');

--
-- The third column is source_base_type, not source_type. Filtering on a column
-- the index does not contain does not merely lose covering -- measured on 5M
-- rows, the optimizer dropped completed_at from the range entirely, degrading to
-- a ref on status alone (70% of the table) and taking the query from 1.1s to
-- over two minutes. Both columns will not fit: 1022 + 6 + 1022 + 1022 + 69 =
-- 3141 bytes exceeds InnoDB's 3072 key limit.
--
-- Nothing else loses an index path by this: the report.conf reports that display
-- source_type use date_field=attempted_at and are served by KEY attempted_at.
--
\! echo "Adding index auth_log_billing to auth_log...";
CALL AddIndexUnlessExists('auth_log', 'auth_log_billing',
    'KEY `auth_log_billing` (`status`,`completed_at`,`source_base_type`,`mac`)');

\! echo "Adding index node_status_last_seen to node...";
CALL AddIndexUnlessExists('node', 'node_status_last_seen',
    'KEY `node_status_last_seen` (`status`,`last_seen`,`pid`)');

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

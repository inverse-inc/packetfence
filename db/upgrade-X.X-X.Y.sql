--
-- PacketFence SQL schema upgrade from X.X to X.Y
--


--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 11;
SET @MINOR_VERSION = 0;


SET @PREV_MAJOR_VERSION = 10;
SET @PREV_MINOR_VERSION = 3;
-- SET @PREV_SUBMINOR_VERSION = 0;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8;

SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8;
-- SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8 | @PREV_SUBMINOR_VERSION;

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
        -- SELECT CONCAT('PREVIOUS VERSION ', PREVIOUS_VERSION_STRING, ' DOES NOT MATCH ', CONCAT_WS('.', @PREV_MAJOR_VERSION, @PREV_MINOR_VERSION, @PREV_SUBMINOR_VERSION)) INTO _message;
        SIGNAL SQLSTATE VALUE '99999'
              SET MESSAGE_TEXT = _message;
      END IF;
END
//

DELIMITER ;
\! echo "Checking PacketFence schema version...";
call ValidateVersion;
DROP PROCEDURE IF EXISTS ValidateVersion;

\! echo "altering pki_profiles"
ALTER TABLE pki_profiles
    ADD COLUMN IF NOT EXISTS `cloud_enabled` int(11) DEFAULT NULL AFTER scep_days_before_renewal,
    ADD COLUMN IF NOT EXISTS `cloud_service` varchar(255) DEFAULT NULL AFTER cloud_enabled;

DELIMITER /
CREATE OR REPLACE PROCEDURE `bandwidth_aggregation` (
  IN `p_bucket_size` varchar(255),
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN

    SET @end_bucket= p_end_bucket, @batch = p_batch;
    CREATE OR REPLACE TEMPORARY TABLE to_delete SELECT node_id, tenant_id, mac, time_bucket as new_time_bucket, time_bucket, unique_session_id, in_bytes, out_bytes, last_updated FROM bandwidth_accounting LIMIT 0;
    SET @date_rounding = CASE WHEN p_bucket_size = 'monthly' THEN 'ROUND_TO_MONTH' WHEN p_bucket_size = 'daily' THEN 'DATE' ELSE 'ROUND_TO_HOUR' END;
    SET @insert_into_to_delete_stmt = CONCAT('INSERT INTO to_delete SELECT node_id, tenant_id, mac, ',@date_rounding,'(time_bucket) as new_time_bucket, time_bucket, unique_session_id, in_bytes, out_bytes, last_updated FROM bandwidth_accounting FORCE INDEX (bandwidth_source_type_time_bucket) WHERE time_bucket <= ? AND source_type = "radius" AND time_bucket != ',@date_rounding,'(time_bucket) ORDER BY time_bucket DESC LIMIT ?');
    PREPARE insert_into_to_delete FROM @insert_into_to_delete_stmt;

    START TRANSACTION;
    EXECUTE insert_into_to_delete using @end_bucket, @batch;
    SELECT COUNT(*) INTO @count FROM to_delete;
    IF @count > 0 THEN

        INSERT INTO bandwidth_accounting
        (node_id, unique_session_id, tenant_id, mac, time_bucket, in_bytes, out_bytes, last_updated, source_type)
         SELECT
             node_id,
             unique_session_id,
             tenant_id,
             mac,
             new_time_bucket,
             sum(in_bytes) AS in_bytes,
             sum(out_bytes) AS out_bytes,
             MAX(last_updated),
             "radius"
            FROM to_delete
            GROUP BY node_id, unique_session_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes),
                last_updated = GREATEST(last_updated, VALUES(last_updated))
            ;

        DELETE bandwidth_accounting
            FROM to_delete INNER JOIN bandwidth_accounting
            WHERE
                to_delete.node_id = bandwidth_accounting.node_id AND
                to_delete.time_bucket = bandwidth_accounting.time_bucket AND
                to_delete.unique_session_id = bandwidth_accounting.unique_session_id;
    END IF;
    COMMIT;

    DROP TEMPORARY TABLE IF EXISTS to_delete;
    DEALLOCATE PREPARE insert_into_to_delete;
    SELECT @count AS aggreated;
END /
DELIMITER ;

DELIMITER /
CREATE OR REPLACE PROCEDURE `bandwidth_accounting_radius_to_history` (
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN
    SET @batch = p_batch;
    SET @end_bucket = p_end_bucket;
    CREATE OR REPLACE TEMPORARY TABLE to_delete SELECT node_id, tenant_id, mac, time_bucket, time_bucket as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting LIMIT 0;
    PREPARE insert_into_to_delete FROM 'INSERT to_delete SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting WHERE source_type = "radius" AND time_bucket < ? AND last_updated = "0000-00-00 00:00:00" LIMIT ?';
    START TRANSACTION;
    EXECUTE insert_into_to_delete USING @end_bucket, @batch;
    SELECT COUNT(*) INTO @count FROM to_delete;
    IF @count > 0 THEN

        INSERT INTO bandwidth_accounting_history
        (node_id, tenant_id, mac, time_bucket, in_bytes, out_bytes)
         SELECT
             node_id,
             tenant_id,
             mac,
             new_time_bucket,
             sum(in_bytes) AS in_bytes,
             sum(out_bytes) AS out_bytes
            FROM to_delete
            GROUP BY node_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes)
            ;

        DELETE bandwidth_accounting
            FROM to_delete INNER JOIN bandwidth_accounting
            WHERE
                to_delete.node_id = bandwidth_accounting.node_id AND
                to_delete.time_bucket = bandwidth_accounting.time_bucket AND
                to_delete.unique_session_id = bandwidth_accounting.unique_session_id;

    END IF;
    COMMIT;

    DEALLOCATE PREPARE insert_into_to_delete;
    DROP TEMPORARY TABLE IF EXISTS to_delete;
    SELECT @count as count;
END/

DELIMITER ;

DELIMITER /
CREATE OR REPLACE PROCEDURE `bandwidth_aggregation_history` (
  IN `p_bucket_size` varchar(255),
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN

    SET @end_bucket= p_end_bucket, @batch = p_batch;
    CREATE OR REPLACE TEMPORARY TABLE to_delete SELECT node_id, tenant_id, mac, time_bucket as new_time_bucket, time_bucket, in_bytes, out_bytes FROM bandwidth_accounting_history LIMIT 0;
    SET @date_rounding = CASE WHEN p_bucket_size = 'monthly' THEN 'ROUND_TO_MONTH' WHEN p_bucket_size = 'daily' THEN 'DATE' ELSE 'ROUND_TO_HOUR' END;
    SET @insert_into_to_delete_stmt = CONCAT('INSERT INTO to_delete SELECT node_id, tenant_id, mac, ', @date_rounding,'(time_bucket) as new_time_bucket, time_bucket, in_bytes, out_bytes FROM bandwidth_accounting_history WHERE time_bucket <= ? AND time_bucket != ', @date_rounding, '(time_bucket) LIMIT ?');
    PREPARE insert_into_to_delete FROM @insert_into_to_delete_stmt;

    START TRANSACTION;
    EXECUTE insert_into_to_delete USING @end_bucket, @batch;
    SELECT COUNT(*) INTO @count FROM to_delete;
    IF @count > 0 THEN
        INSERT INTO bandwidth_accounting_history
        (node_id, tenant_id, mac, time_bucket, in_bytes, out_bytes)
         SELECT
             node_id,
             tenant_id,
             mac,
             new_time_bucket,
             sum(in_bytes) AS in_bytes,
             sum(out_bytes) AS out_bytes
            FROM to_delete
            GROUP BY node_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes)
            ;

        DELETE bandwidth_accounting_history
            FROM to_delete INNER JOIN bandwidth_accounting_history
            WHERE
                to_delete.node_id = bandwidth_accounting_history.node_id AND
                to_delete.time_bucket = bandwidth_accounting_history.time_bucket;
    END IF;
    COMMIT;

    DEALLOCATE PREPARE insert_into_to_delete;
    DROP TEMPORARY TABLE IF EXISTS to_delete;
    SELECT @count AS aggreated;
END /
DELIMITER ;

DELIMITER /
CREATE OR REPLACE PROCEDURE `process_bandwidth_accounting_netflow` (
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN
    SET @batch = p_batch;
    SET @end_bucket = p_end_bucket;
    CREATE OR REPLACE TEMPORARY TABLE to_process SELECT node_id, tenant_id, mac, time_bucket, time_bucket as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting LIMIT 0;
    START TRANSACTION;
    PREPARE insert_into_to_process FROM 'INSERT to_process SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting WHERE source_type = "net_flow" AND time_bucket < ? LIMIT ?';
    EXECUTE insert_into_to_process USING @end_bucket, @batch;
    DEALLOCATE PREPARE insert_into_to_process;
    SELECT COUNT(*) INTO @count FROM to_process;
    IF @count > 0 THEN
        UPDATE 
            (SELECT tenant_id, mac, SUM(total_bytes) AS total_bytes FROM to_process GROUP BY node_id) AS x 
            LEFT JOIN node USING(tenant_id, mac)
            SET node.bandwidth_balance = GREATEST(node.bandwidth_balance - total_bytes, 0)
            WHERE node.bandwidth_balance IS NOT NULL;

        INSERT INTO bandwidth_accounting_history
        (node_id, tenant_id, mac, time_bucket, in_bytes, out_bytes)
         SELECT
             node_id,
             tenant_id,
             mac,
             new_time_bucket,
             sum(in_bytes) AS in_bytes,
             sum(out_bytes) AS out_bytes
            FROM to_process
            GROUP BY node_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes)
            ;

        DELETE bandwidth_accounting
            FROM to_process INNER JOIN bandwidth_accounting
            WHERE
                to_process.node_id = bandwidth_accounting.node_id AND
                to_process.time_bucket = bandwidth_accounting.time_bucket AND
                to_process.unique_session_id = bandwidth_accounting.unique_session_id;

    END IF;
    COMMIT;

    DROP TEMPORARY TABLE IF EXISTS to_process;
    SELECT @count as count;
END/

DELIMITER ;

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());

\! echo "Upgrade completed successfully.";

--
-- PacketFence SQL schema upgrade from 11.0 to 11.1
--


--
-- Setting the major/minor version of the DB
--


DELIMITER /
CREATE OR REPLACE PROCEDURE `bandwidth_aggregation` (
  IN `p_bucket_size` varchar(255),
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN
    SET @count = 0;
    SET @end_bucket= p_end_bucket, @batch = p_batch;
    SET @date_rounding = CASE WHEN p_bucket_size = 'monthly' THEN 'ROUND_TO_MONTH' WHEN p_bucket_size = 'daily' THEN 'DATE' ELSE 'ROUND_TO_HOUR' END;

    SET @insert_into_to_delete_stmt = CONCAT('INSERT to_delete_bandwidth_aggregation SELECT node_id, tenant_id, mac, ',@date_rounding,'(time_bucket) as new_time_bucket, time_bucket, unique_session_id, in_bytes, out_bytes, last_updated FROM bandwidth_accounting WHERE time_bucket <= ? AND source_type = "radius" AND time_bucket != ',@date_rounding,'(time_bucket) LIMIT ? FOR UPDATE');
    START TRANSACTION;
    tblock: BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            SET @count = -1;
            ROLLBACK;
        END;
        CREATE OR REPLACE TEMPORARY TABLE to_delete_bandwidth_aggregation ENGINE=MEMORY SELECT node_id, tenant_id, mac, time_bucket as new_time_bucket, time_bucket, unique_session_id, in_bytes, out_bytes, last_updated FROM bandwidth_accounting LIMIT 0;
        EXECUTE IMMEDIATE @insert_into_to_delete_stmt USING @end_bucket, @batch;
        SELECT COUNT(*) INTO @count FROM to_delete_bandwidth_aggregation;
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
                FROM to_delete_bandwidth_aggregation
                GROUP BY node_id, unique_session_id, new_time_bucket
                ON DUPLICATE KEY UPDATE
                    in_bytes = in_bytes + VALUES(in_bytes),
                    out_bytes = out_bytes + VALUES(out_bytes),
                    last_updated = GREATEST(last_updated, VALUES(last_updated))
                ;

            DELETE bandwidth_accounting
                FROM  bandwidth_accounting RIGHT JOIN to_delete_bandwidth_aggregation USING(node_id, time_bucket, unique_session_id);
        END IF;
        COMMIT;
    END tblock;

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
    START TRANSACTION;
    CREATE OR REPLACE TEMPORARY TABLE to_process_bandwidth_accounting_netflow ENGINE=MEMORY SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting LIMIT 0;
    EXECUTE IMMEDIATE 'INSERT to_process_bandwidth_accounting_netflow SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting WHERE source_type = "net_flow" AND time_bucket < ? LIMIT ?' USING @end_bucket, @batch;
    SELECT COUNT(*) INTO @count FROM to_process_bandwidth_accounting_netflow;
    IF @count > 0 THEN
        UPDATE
            (SELECT tenant_id, mac, SUM(total_bytes) AS total_bytes FROM to_process_bandwidth_accounting_netflow GROUP BY node_id) AS x
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
            FROM to_process_bandwidth_accounting_netflow
            GROUP BY node_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes)
            ;

        DELETE bandwidth_accounting
            FROM bandwidth_accounting RIGHT JOIN to_process_bandwidth_accounting_netflow USING (node_id, time_bucket, unique_session_id);

    END IF;
    COMMIT;

    SELECT @count as count;
END/
DELIMITER ;

DELIMITER /
CREATE OR REPLACE PROCEDURE `bandwidth_accounting_radius_to_history` (
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN
    SET @batch = p_batch;
    SET @end_bucket = p_end_bucket;
    START TRANSACTION;
    CREATE OR REPLACE TEMPORARY TABLE to_delete_bandwidth_accounting_radius_to_history ENGINE=MEMORY SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting LIMIT 0;
    EXECUTE IMMEDIATE 'INSERT to_delete_bandwidth_accounting_radius_to_history SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting WHERE source_type = "radius" AND time_bucket < ? AND last_updated = "0000-00-00 00:00:00" LIMIT ? FOR UPDATE' USING @end_bucket, @batch;
    SELECT COUNT(*) INTO @count FROM to_delete_bandwidth_accounting_radius_to_history;

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
            FROM to_delete_bandwidth_accounting_radius_to_history
            GROUP BY node_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes)
            ;

         DELETE bandwidth_accounting
            FROM bandwidth_accounting RIGHT JOIN to_delete_bandwidth_accounting_radius_to_history USING (node_id, time_bucket, unique_session_id);

    END IF;
    COMMIT;

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
    SET @date_rounding = CASE WHEN p_bucket_size = 'monthly' THEN 'ROUND_TO_MONTH' WHEN p_bucket_size = 'daily' THEN 'DATE' ELSE 'ROUND_TO_HOUR' END;

    START TRANSACTION;
    CREATE OR REPLACE TEMPORARY TABLE to_delete_bandwidth_aggregation_history ENGINE=MEMORY SELECT node_id, tenant_id, mac, time_bucket as new_time_bucket, time_bucket, in_bytes, out_bytes FROM bandwidth_accounting_history LIMIT 0;
    EXECUTE IMMEDIATE CONCAT('INSERT to_delete_bandwidth_aggregation_history SELECT node_id, tenant_id, mac, ', @date_rounding,'(time_bucket) as new_time_bucket, time_bucket, in_bytes, out_bytes FROM bandwidth_accounting_history WHERE time_bucket <= ? AND time_bucket != ', @date_rounding, '(time_bucket) ORDER BY time_bucket LIMIT ? FOR UPDATE') USING @end_bucket, @batch;
    SELECT COUNT(*) INTO @count FROM to_delete_bandwidth_aggregation_history;
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
            FROM to_delete_bandwidth_aggregation_history
            GROUP BY node_id, new_time_bucket
            ON DUPLICATE KEY UPDATE
                in_bytes = in_bytes + VALUES(in_bytes),
                out_bytes = out_bytes + VALUES(out_bytes)
            ;

        DELETE bandwidth_accounting_history
            FROM bandwidth_accounting_history RIGHT JOIN to_delete_bandwidth_aggregation_history USING (node_id, time_bucket);
    END IF;
    COMMIT;

    SELECT @count AS aggreated;
END /
DELIMITER ;


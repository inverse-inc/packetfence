--
-- PacketFence SQL schema upgrade from 11.0 to 11.1
--


--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 11;
SET @MINOR_VERSION = 2;


SET @PREV_MAJOR_VERSION = 11;
SET @PREV_MINOR_VERSION = 1;

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

\! echo "altering pki_certs"
ALTER TABLE pki_certs
    DROP INDEX IF EXISTS cn,
    ADD COLUMN IF NOT EXISTS `scep` BOOLEAN DEFAULT FALSE AFTER ip_addresses,
    ADD COLUMN IF NOT EXISTS `alert` BOOLEAN DEFAULT FALSE AFTER scep,
    ADD COLUMN IF NOT EXISTS `subject` VARCHAR(255) UNIQUE AFTER alert;

\! echo "set pki_certs.scep to true if private key is empty"
UPDATE pki_certs
    SET `scep`=1 WHERE `key` = "";

\! echo "Alter table pki_certs"
ALTER TABLE `pki_certs`
  MODIFY valid_until DATETIME,
  MODIFY date DATETIME DEFAULT CURRENT_TIMESTAMP,
  MODIFY deleted_at DATETIME,
  MODIFY created_at DATETIME,
  MODIFY updated_at DATETIME;

\! echo "Alter table pki_cas"
ALTER TABLE `pki_cas`
  MODIFY deleted_at DATETIME,
  MODIFY created_at DATETIME,
  MODIFY updated_at DATETIME;

\! echo "Alter table pki_profiles"
ALTER TABLE `pki_profiles`
  MODIFY deleted_at DATETIME,
  MODIFY created_at DATETIME,
  MODIFY updated_at DATETIME;

\! echo "Alter table pki_revoked_certs"
ALTER TABLE `pki_revoked_certs`
  MODIFY valid_until DATETIME,
  MODIFY date DATETIME DEFAULT CURRENT_TIMESTAMP,
  MODIFY deleted_at DATETIME,
  MODIFY created_at DATETIME,
  MODIFY updated_at DATETIME;

\! echo "Alter table dhcp_option82"
ALTER TABLE `dhcp_option82`
  MODIFY `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL;

\! echo "Alter table dhcp_option82_history"
ALTER TABLE `dhcp_option82_history`
  MODIFY `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL;

\! echo "Updating bandwidth_accounting indexes";
ALTER TABLE bandwidth_accounting
 DROP INDEX IF EXISTS bandwidth_accounting_tenant_id_mac,
 ADD INDEX IF NOT EXISTS bandwidth_accounting_tenant_id_mac_last_updated (tenant_id, mac, last_updated);

\! echo "altering pki_profiles"
ALTER TABLE pki_profiles
    ADD COLUMN IF NOT EXISTS `days_before_renewal` varchar(255) DEFAULT 14 AFTER scep_days_before_renewal,
    ALTER scep_days_before_renewal SET DEFAULT 14,
    ADD COLUMN IF NOT EXISTS `renewal_mail` int(11) DEFAULT 1 AFTER days_before_renewal,
    ADD COLUMN IF NOT EXISTS `days_before_renewal_mail` varchar(255) DEFAULT 14 AFTER renewal_mail,
    ADD COLUMN IF NOT EXISTS `renewal_mail_subject` varchar(255) DEFAULT 'Certificate expiration' AFTER days_before_renewal_mail,
    ADD COLUMN IF NOT EXISTS `renewal_mail_from` varchar(255) DEFAULT NULL AFTER renewal_mail_subject,
    ADD COLUMN IF NOT EXISTS `renewal_mail_header` varchar(255) DEFAULT NULL AFTER renewal_mail_from,
    ADD COLUMN IF NOT EXISTS `renewal_mail_footer` varchar(255) DEFAULT NULL AFTER renewal_mail_header,
    ADD COLUMN IF NOT EXISTS `revoked_valid_until` varchar(255) DEFAULT 14 AFTER renewal_mail_footer;

\! echo "altering pki_cas"
ALTER TABLE pki_cas
    ADD COLUMN IF NOT EXISTS `serial_number` int(11) DEFAULT 1 AFTER ocsp_url;

\! echo "altering pki_revoked_certs"
ALTER TABLE pki_revoked_certs
    ADD COLUMN IF NOT EXISTS `subject` varchar(255) AFTER crl_reason;

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
    CREATE OR REPLACE TEMPORARY TABLE to_delete_bandwidth_aggregation ENGINE=MEMORY SELECT node_id, tenant_id, mac, time_bucket as new_time_bucket, time_bucket, unique_session_id, in_bytes, out_bytes, last_updated FROM bandwidth_accounting LIMIT 0;
    START TRANSACTION;
    tblock: BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            SET @count = -1;
            ROLLBACK;
        END;
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
    SET @count = 0;
    SET @batch = p_batch;
    SET @end_bucket = p_end_bucket;
    CREATE OR REPLACE TEMPORARY TABLE to_process_bandwidth_accounting_netflow ENGINE=MEMORY SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting LIMIT 0;
    START TRANSACTION;
    tblock: BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            SET @count = -1;
            ROLLBACK;
        END;
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
    END tblock;

    SELECT @count AS `count`;
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
    SET @count = 0;
    CREATE OR REPLACE TEMPORARY TABLE to_delete_bandwidth_accounting_radius_to_history ENGINE=MEMORY SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting LIMIT 0;
    START TRANSACTION;
    tblock: BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            SET @count = -1;
            ROLLBACK;
        END;
        EXECUTE IMMEDIATE 'INSERT to_delete_bandwidth_accounting_radius_to_history SELECT node_id, tenant_id, mac, time_bucket, ROUND_TO_HOUR(time_bucket) as new_time_bucket, unique_session_id, in_bytes, out_bytes, total_bytes FROM bandwidth_accounting WHERE source_type = "radius" AND time_bucket < ? AND last_updated = "0000-00-00 00:00:00" ORDER BY time_bucket LIMIT ? FOR UPDATE' USING @end_bucket, @batch;
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
                HAVING SUM(in_bytes) != 0 OR sum(out_bytes) != 0
                ON DUPLICATE KEY UPDATE
                    in_bytes = in_bytes + VALUES(in_bytes),
                    out_bytes = out_bytes + VALUES(out_bytes)
                ;

             DELETE bandwidth_accounting
                FROM bandwidth_accounting RIGHT JOIN to_delete_bandwidth_accounting_radius_to_history USING (node_id, time_bucket, unique_session_id);

        END IF;
        COMMIT;
    END tblock;

    SELECT @count as `count`;
END/
DELIMITER ;

DELIMITER /
CREATE OR REPLACE PROCEDURE `bandwidth_aggregation_history` (
  IN `p_bucket_size` varchar(255),
  IN `p_end_bucket` datetime,
  IN `p_batch` int(11) unsigned
)
BEGIN

    SET @count = 0;
    SET @end_bucket= p_end_bucket, @batch = p_batch;
    SET @date_rounding = CASE WHEN p_bucket_size = 'monthly' THEN 'ROUND_TO_MONTH' WHEN p_bucket_size = 'daily' THEN 'DATE' ELSE 'ROUND_TO_HOUR' END;

    CREATE OR REPLACE TEMPORARY TABLE to_delete_bandwidth_aggregation_history ENGINE=MEMORY SELECT node_id, tenant_id, mac, time_bucket as new_time_bucket, time_bucket, in_bytes, out_bytes FROM bandwidth_accounting_history LIMIT 0;
    START TRANSACTION;
    tblock: BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            SET @count = -1;
            ROLLBACK;
        END;
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
    END tblock;

    SELECT @count as aggreated;
END /
DELIMITER ;

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());

\! echo "Upgrade completed successfully.";

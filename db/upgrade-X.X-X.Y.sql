SET sql_mode = "NO_ENGINE_SUBSTITUTION";

--
-- PacketFence SQL schema upgrade from 13.1 to 13.2
--


--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 14;
SET @MINOR_VERSION = 1;


SET @PREV_MAJOR_VERSION = 14;
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

\! echo "altering pki_profiles"
ALTER TABLE `pki_profiles`
    ADD IF NOT EXISTS `allow_duplicated_cn` bigint(20) UNSIGNED DEFAULT 0,
    ADD IF NOT EXISTS `maximum_duplicated_cn` bigint(20) DEFAULT 0,
    MODIFY `scep_server_enabled` bigint(20) DEFAULT 0,
    RENAME INDEX scep_server__id TO scep_server_id;

\! echo "altering pki_certs"
ALTER TABLE `pki_certs`
    MODIFY `subject` longtext DEFAULT NULL,
    DROP INDEX IF EXISTS `subject`,
    ADD UNIQUE KEY IF NOT EXISTS `cn_serial` (`cn`,`serial_number`) USING HASH;

\! echo "Adding default timestamp to RADIUS audit logs";
ALTER TABLE radius_audit_log MODIFY created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());


\! echo "Upgrade completed successfully.";

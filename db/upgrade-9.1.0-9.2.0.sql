--
-- PacketFence SQL schema upgrade from 9.1.0 to 9.1.9
--


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 9;
SET @MINOR_VERSION = 2;
SET @SUBMINOR_VERSION = 0;



SET @PREV_MAJOR_VERSION = 9;
SET @PREV_MINOR_VERSION = 1;
SET @PREV_SUBMINOR_VERSION = 0;


--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8 | @PREV_SUBMINOR_VERSION;

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
        SELECT CONCAT('PREVIOUS VERSION ', PREVIOUS_VERSION_STRING, ' DOES NOT MATCH ', CONCAT_WS('.', @PREV_MAJOR_VERSION, @PREV_MINOR_VERSION, @PREV_SUBMINOR_VERSION)) INTO _message;
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
-- Table structure for table `admin_api_audit_log`
--
\! echo "Creating table 'admin_api_audit_log'...";
CREATE TABLE IF NOT EXISTS `admin_api_audit_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tenant_id` int(11) NOT NULL DEFAULT '1',
  `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `user_name` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `action` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `object_id` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `method` varchar(10) COLLATE utf8mb4_bin DEFAULT NULL,
  `request` mediumtext COLLATE utf8mb4_bin,
  `status` smallint(5) NOT NULL,
   PRIMARY KEY (`id`),
   KEY `action` (`action`),
   KEY `user_name` (`user_name`),
   KEY `object_id_action` (`object_id`, `action`),
   KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin ROW_FORMAT=COMPRESSED;

--
-- Add an index on ssid on the locationlog
--
\! echo "Adding index 'locationlog_ssid' and 'locationlog_session_id_end_time' to 'locationlog' table...";
ALTER TABLE locationlog ADD INDEX IF NOT EXISTS `locationlog_ssid` (`ssid`), ADD INDEX IF NOT EXISTS `locationlog_session_id_end_time` (`session_id`, `end_time`);

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

\! echo "Upgrade completed successfully.";

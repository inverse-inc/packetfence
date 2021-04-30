SET sql_mode = "NO_ENGINE_SUBSTITUTION";

--
-- PacketFence SQL schema upgrade from 11.0 to 11.1
--


--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 13;
SET @MINOR_VERSION = 0;


SET @PREV_MAJOR_VERSION = 12;
SET @PREV_MINOR_VERSION = 2;

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

\! echo "Altering admin_api_audit_log"
ALTER TABLE admin_api_audit_log
    CHANGE COLUMN `created_at` `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP;

\! echo "Altering dhcp_option82_history"
ALTER TABLE dhcp_option82_history
    CHANGE COLUMN `created_at` `created_at` datetime NOT NULL;

\! echo "Altering dns_audit_log"
ALTER TABLE dns_audit_log
    CHANGE COLUMN `created_at` `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

\! echo "Altering pki_cas"
ALTER TABLE pki_cas
    CHANGE COLUMN `created_at` `created_at` datetime DEFAULT NULL,
    CHANGE COLUMN `updated_at` `updated_at` datetime DEFAULT NULL,
    CHANGE COLUMN `deleted_at` `deleted_at` datetime DEFAULT NULL;

\! echo "Altering pki_certs"
ALTER TABLE pki_certs
    CHANGE COLUMN `created_at` `created_at` datetime DEFAULT NULL,
    CHANGE COLUMN `updated_at` `updated_at` datetime DEFAULT NULL,
    CHANGE COLUMN `deleted_at` `deleted_at` datetime DEFAULT NULL,
    CHANGE COLUMN `valid_until` `valid_until` datetime DEFAULT NULL,
    CHANGE COLUMN `date` `date` datetime DEFAULT CURRENT_TIMESTAMP;

\! echo "Altering pki_profiles"
ALTER TABLE pki_profiles
    CHANGE COLUMN `created_at` `created_at` datetime DEFAULT NULL,
    CHANGE COLUMN `updated_at` `updated_at` datetime DEFAULT NULL,
    CHANGE COLUMN `deleted_at` `deleted_at` datetime DEFAULT NULL;

\! echo "Altering pki_revoked_certs"
ALTER TABLE pki_revoked_certs
    CHANGE COLUMN `created_at` `created_at` datetime DEFAULT NULL,
    CHANGE COLUMN `updated_at` `updated_at` datetime DEFAULT NULL,
    CHANGE COLUMN `deleted_at` `deleted_at` datetime DEFAULT NULL,
    CHANGE COLUMN `valid_until` `valid_until` datetime DEFAULT NULL,
    CHANGE COLUMN `date` `date` datetime DEFAULT CURRENT_TIMESTAMP,
    CHANGE COLUMN `revoked` `revoked` datetime DEFAULT NULL;

\! echo "Altering radacct_log"
ALTER TABLE radacct_log
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering radius_audit_log"
ALTER TABLE radius_audit_log
    CHANGE COLUMN `created_at` `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP;

\! echo "Altering sms_carrier"
ALTER TABLE sms_carrier
   CHANGE COLUMN `modified` `modified` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT 'date this record was modified';

\! echo "Altering table billing"
ALTER TABLE billing
    CHANGE COLUMN `update_date` `update_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' ON UPDATE CURRENT_TIMESTAMP;

\! echo "Altering table dhcp_option82"
ALTER TABLE dhcp_option82
    CHANGE COLUMN `created_at` `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP;

\! echo "Altering table scan"
ALTER TABLE scan
   CHANGE COLUMN `update_date` `update_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00' ON UPDATE CURRENT_TIMESTAMP;

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());


\! echo "Upgrade completed successfully.";

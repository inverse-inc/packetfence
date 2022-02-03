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

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());

\! echo "Upgrade completed successfully.";

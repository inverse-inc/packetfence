-- PacketFence SQL schema upgrade from 10.2.0 to 10.3.0
--


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 10;
SET @MINOR_VERSION = 3;
SET @SUBMINOR_VERSION = 0;



SET @PREV_MAJOR_VERSION = 10;
SET @PREV_MINOR_VERSION = 2;
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

\! echo "Altering pf_version"
ALTER TABLE pf_version
    ADD COLUMN IF NOT EXISTS created_at DATETIME DEFAULT CURRENT_TIMESTAMP;

\! echo "Dropping table userlog"
DROP TABLE IF EXISTS userlog;

\! echo "Dropping table inline_accounting"
DROP TABLE IF EXISTS `inline_accounting`;

\! echo "Altering node"
ALTER TABLE node
    DROP FOREIGN KEY `node_category_key`,
    MODIFY `category_id` BIGINT DEFAULT NULL;

\! echo "Altering node_category"
ALTER TABLE node_category
    MODIFY `category_id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    ADD COLUMN IF NOT EXISTS `include_parent_acls` varchar(255) default NULL,
    ADD COLUMN IF NOT EXISTS `fingerbank_dynamic_access_list` varchar(255) default NULL,
    ADD COLUMN IF NOT EXISTS `acls` TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS `inherit_vlan` varchar(50) default NULL,
    ADD COLUMN IF NOT EXISTS `inherit_role` varchar(50) default NULL,
    ADD COLUMN IF NOT EXISTS `inherit_web_auth_url` varchar(50) default NULL;

\! echo "Altering node"
ALTER TABLE node
    ADD CONSTRAINT FOREIGN KEY `node_category_key` (`category_id`) REFERENCES `node_category` (`category_id`);

\! echo "Altering activation"
ALTER TABLE activation
    MODIFY `code_id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering admin_api_audit_log"
ALTER TABLE admin_api_audit_log
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering auth_log"
ALTER TABLE auth_log
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering dhcp_option82_history"
ALTER TABLE dhcp_option82_history
    MODIFY `dhcp_option82_history_id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering dhcppool"
ALTER TABLE dhcppool
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering dns_audit_log"
ALTER TABLE dns_audit_log
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering ip4log_archive"
ALTER TABLE ip4log_archive
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering ip4log_history"
ALTER TABLE ip4log_history
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering ip6log_archive"
ALTER TABLE ip6log_archive
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering ip6log_history"
ALTER TABLE ip6log_history
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering locationlog_history"
ALTER TABLE locationlog_history
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering pki_cas"
ALTER TABLE pki_cas
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering pki_certs"
ALTER TABLE pki_certs
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering pki_profiles"
ALTER TABLE pki_profiles
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering pki_revoked_certs"
ALTER TABLE pki_revoked_certs
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering radacct_log"
ALTER TABLE radacct_log
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering radius_audit_log"
ALTER TABLE radius_audit_log
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering savedsearch"
ALTER TABLE savedsearch
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering security_event"
ALTER TABLE security_event
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;

\! echo "Altering sms_carrier"
ALTER TABLE sms_carrier
    MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT 'primary key for SMS carrier';

\! echo "altering pki_profiles"
ALTER TABLE pki_profiles
    ADD COLUMN IF NOT EXISTS `mail` varchar(255) DEFAULT NULL AFTER name,
    ADD COLUMN IF NOT EXISTS `organisation` varchar(255) DEFAULT NULL AFTER mail,
    ADD COLUMN IF NOT EXISTS `organisational_unit` varchar(255) DEFAULT NULL AFTER organisation,
    ADD COLUMN IF NOT EXISTS `country` varchar(255) DEFAULT NULL AFTER organisational_unit,
    ADD COLUMN IF NOT EXISTS `state` varchar(255) DEFAULT NULL AFTER country,
    ADD COLUMN IF NOT EXISTS `locality` varchar(255) DEFAULT NULL AFTER state,
    ADD COLUMN IF NOT EXISTS `street_address` varchar(255) DEFAULT NULL AFTER locality,
    ADD COLUMN IF NOT EXISTS `postal_code` varchar(255) DEFAULT NULL AFTER street_address,
    ADD COLUMN IF NOT EXISTS `ocsp_url` varchar(255) DEFAULT NULL AFTER extended_key_usage,
    ADD COLUMN IF NOT EXISTS `scep_enabled` int(11) AFTER p12_mail_footer,
    ADD COLUMN IF NOT EXISTS `scep_challenge_password` varchar(255) AFTER scep_enabled,
    ADD COLUMN IF NOT EXISTS `scep_days_before_renewal` varchar(255) AFTER scep_challenge_password;


\! echo "altering pki_cas"
ALTER TABLE pki_cas
    ADD COLUMN IF NOT EXISTS `organisational_unit` varchar(255) DEFAULT NULL AFTER organisation,
    ADD COLUMN IF NOT EXISTS `ocsp_url` varchar(255) DEFAULT NULL AFTER issuer_name_hash;

\! echo "altering pki_certs"
ALTER TABLE pki_certs
    ADD COLUMN IF NOT EXISTS `organisational_unit` varchar(255) DEFAULT NULL AFTER organisation,
    ADD COLUMN IF NOT EXISTS `dns_names` varchar(255) DEFAULT NULL AFTER serial_number,
    ADD COLUMN IF NOT EXISTS `ip_addresses` varchar(255) DEFAULT NULL AFTER dns_names;

\! echo "altering pki_revoked_certs"
ALTER TABLE pki_revoked_certs
    ADD COLUMN IF NOT EXISTS `organisational_unit` varchar(255) DEFAULT NULL AFTER organisation,
    ADD COLUMN IF NOT EXISTS `dns_names` varchar(255) DEFAULT NULL AFTER serial_number,
    ADD COLUMN IF NOT EXISTS `ip_addresses` varchar(255) DEFAULT NULL AFTER dns_names;

\! echo "Altering wrix"
ALTER TABLE wrix
MODIFY `Provider_Identifier` varchar(64) NULL DEFAULT NULL,
MODIFY `Location_Identifier` varchar(64) NULL DEFAULT NULL,
MODIFY `Service_Provider_Brand` varchar(64) NULL DEFAULT NULL,
MODIFY `Location_Type` varchar(64) NULL DEFAULT NULL,
MODIFY `Sub_Location_Type` varchar(64) NULL DEFAULT NULL,
MODIFY `English_Location_Name` TEXT NULL DEFAULT NULL,
MODIFY `Location_Address1` varchar(128) NULL DEFAULT NULL,
MODIFY `Location_Address2` varchar(128) NULL DEFAULT NULL,
MODIFY `English_Location_City` varchar(64) NULL DEFAULT NULL,
MODIFY `Location_Zip_Postal_Code` varchar(32) NULL DEFAULT NULL,
MODIFY `Location_State_Province_Name` varchar(64) NULL DEFAULT NULL,
MODIFY `Location_Country_Name` varchar(16) NULL DEFAULT NULL,
MODIFY `Location_Phone_Number` varchar(32) NULL DEFAULT NULL,
MODIFY `SSID_Open_Auth` varchar(32) NULL DEFAULT NULL,
MODIFY `SSID_Broadcasted` char(1) NULL DEFAULT NULL,
MODIFY `WEP_Key` varchar(128) NULL DEFAULT NULL,
MODIFY `WEP_Key_Entry_Method` varchar(32) NULL DEFAULT NULL,
MODIFY `WEP_Key_Size` varchar(32) NULL DEFAULT NULL,
MODIFY `SSID_1X` varchar(32) NULL DEFAULT NULL,
MODIFY `SSID_1X_Broadcasted` varchar(1) NULL DEFAULT NULL,
MODIFY `Security_Protocol_1X` varchar(16) NULL DEFAULT NULL,
MODIFY `Client_Support` varchar(128) NULL DEFAULT NULL,
MODIFY `Restricted_Access` varchar(1) NULL DEFAULT NULL,
MODIFY `Location_URL` varchar(128) NULL DEFAULT NULL,
MODIFY `Coverage_Area` varchar(255) NULL DEFAULT NULL,
MODIFY `Open_Monday` varchar(32) NULL DEFAULT NULL,
MODIFY `Open_Tuesday` varchar(32) NULL DEFAULT NULL,
MODIFY `Open_Wednesday` varchar(32) NULL DEFAULT NULL,
MODIFY `Open_Thursday` varchar(32) NULL DEFAULT NULL,
MODIFY `Open_Friday` varchar(32) NULL DEFAULT NULL,
MODIFY `Open_Saturday` varchar(32) NULL DEFAULT NULL,
MODIFY `Open_Sunday` varchar(32) NULL DEFAULT NULL,
MODIFY `Longitude` varchar(32) NULL DEFAULT NULL,
MODIFY `Latitude` varchar(32) NULL DEFAULT NULL,
MODIFY `UTC_Timezone` varchar(16) NULL DEFAULT NULL,
MODIFY `MAC_Address` varchar(32) NULL DEFAULT NULL;

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION), NOW());

\! echo "Upgrade completed successfully.";

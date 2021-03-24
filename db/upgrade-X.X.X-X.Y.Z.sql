-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 10;
SET @MINOR_VERSION = 2;
SET @SUBMINOR_VERSION = 9;



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

\! echo "Altering node"
ALTER TABLE node
    DROP FOREIGN KEY `node_category_key`,
    MODIFY `category_id` BIGINT DEFAULT NULL;

\! echo "Altering node_category"
ALTER TABLE node_category
    MODIFY `category_id` BIGINT(20) NOT NULL AUTO_INCREMENT,
    ADD COLUMN IF NOT EXISTS `include_parent_acls` varchar(255) default NULL,
    ADD COLUMN IF NOT EXISTS `fingerbank_dynamic_access_list` varchar(255) default NULL,
    ADD COLUMN IF NOT EXISTS `acls` TEXT NOT NULL,
    ADD COLUMN IF NOT EXISTS `inherit_vlan` varchar(50) default NULL,
    ADD COLUMN IF NOT EXISTS `inherit_role` varchar(50) default NULL,
    ADD COLUMN IF NOT EXISTS `inherit_web_auth` varchar(50) default NULL;

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

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION), NOW());

\! echo "Upgrade completed successfully.";

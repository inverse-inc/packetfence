\! echo "Altering node"
ALTER TABLE node
    DROP FOREIGN KEY `node_category_key`,
    MODIFY `category_id` BIGINT DEFAULT NULL;

\! echo "Altering node_category"
ALTER TABLE node_category
    MODIFY `category_id` BIGINT NOT NULL AUTO_INCREMENT;

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

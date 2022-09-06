DROP PROCEDURE IF EXISTS DeleteTenant;
DELIMITER //
CREATE PROCEDURE DeleteTenant(IN TableName VARCHAR(255))
BEGIN
    DECLARE TenantExists BOOL;
    SELECT TRUE INTO TenantExists FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=TableName AND COLUMN_NAME='tenant_id';
    IF TenantExists THEN
        SET @stmt = CONCAT('DELETE FROM ', TableName, ' WHERE tenant_id != ', 1);
        PREPARE stmt FROM @stmt;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END;
//
DELIMITER ;
CALL DeleteTenant('activation');
CALL DeleteTenant('admin_api_audit_log');
CALL DeleteTenant('auth_log');
CALL DeleteTenant('bandwidth_accounting');
CALL DeleteTenant('bandwidth_accounting_history');
CALL DeleteTenant('dns_audit_log');
CALL DeleteTenant('ip4log');
CALL DeleteTenant('ip4log_archive');
CALL DeleteTenant('ip4log_history');
CALL DeleteTenant('ip6log');
CALL DeleteTenant('ip6log_archive');
CALL DeleteTenant('ip6log_history');
CALL DeleteTenant('locationlog');
CALL DeleteTenant('locationlog_history');
CALL DeleteTenant('node');
CALL DeleteTenant('password');
CALL DeleteTenant('person');
CALL DeleteTenant('radacct');
CALL DeleteTenant('radacct_log');
CALL DeleteTenant('radius_audit_log');
CALL DeleteTenant('radius_nas');
CALL DeleteTenant('radreply');
CALL DeleteTenant('scan');
CALL DeleteTenant('security_event');
CALL DeleteTenant('user_preference');
DROP PROCEDURE IF EXISTS DeleteTenant;
UPDATE bandwidth_accounting SET node_id = node_id & 0x0000ffffffffffff;
UPDATE bandwidth_accounting_history SET node_id = node_id & 0x0000ffffffffffff;

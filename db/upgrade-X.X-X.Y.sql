--
-- PacketFence SQL schema upgrade from 11.0 to 11.1
--


--
-- Setting the major/minor version of the DB
--

SET @MAJOR_VERSION = 11;
SET @MINOR_VERSION = 3;


SET @PREV_MAJOR_VERSION = 11;
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

ALTER TABLE security_event
   DROP CONSTRAINT security_event_tenant_id,
   DROP CONSTRAINT `tenant_id_mac_fkey_node`,
   DROP tenant_id;

ALTER TABLE ip4log
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (`ip`),
    DROP tenant_id;

ALTER TABLE ip4log_history
   DROP tenant_id;

ALTER TABLE ip4log_archive
   DROP tenant_id;

ALTER TABLE ip6log
   DROP tenant_id;

ALTER TABLE ip6log_history
   DROP tenant_id;

ALTER TABLE ip6log_archive
   DROP tenant_id;

ALTER TABLE locationlog
   DROP tenant_id;

ALTER TABLE locationlog_history
   DROP tenant_id;

ALTER TABLE password
   DROP tenant_id;

ALTER TABLE bandwidth_accounting
   DROP tenant_id;

ALTER TABLE radius_nas
   DROP tenant_id;

ALTER TABLE radacct
   DROP tenant_id;

ALTER TABLE radacct_log
   DROP tenant_id;

ALTER TABLE radreply
   DROP tenant_id;

ALTER TABLE scan
   DROP tenant_id;

ALTER TABLE activation
   DROP tenant_id;

ALTER TABLE radius_audit_log
   DROP tenant_id;

ALTER TABLE auth_log
   DROP tenant_id;

ALTER TABLE user_preference
   DROP tenant_id;

ALTER TABLE dns_audit_log
   DROP tenant_id;

ALTER TABLE admin_api_audit_log
   DROP tenant_id;

ALTER TABLE bandwidth_accounting_history
   DROP tenant_id;

ALTER TABLE node
   DROP PRIMARY KEY,
   ADD PRIMARY KEY (`mac`),
   DROP CONSTRAINT `0_57`,
   DROP tenant_id;

ALTER TABLE person
   DROP PRIMARY KEY,
   ADD PRIMARY KEY (`pid`),
   DROP tenant_id;


-- DROP TABLE tenant;

INSERT INTO sms_carrier
    (name, email_pattern, created)
VALUES
    ('RingRing', '%s@smsemail.be', now());

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());


\! echo "Upgrade completed successfully.";

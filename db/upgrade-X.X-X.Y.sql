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


ALTER TABLE `locationlog`
    MODIFY `switch` varchar(255),
    ADD COLUMN IF NOT EXISTS `tenant` varchar(255) AFTER voip;

ALTER TABLE `locationlog_history`
    MODIFY `switch` varchar(255),
    ADD COLUMN IF NOT EXISTS `tenant` varchar(255) AFTER voip;


DELIMITER /
CREATE OR REPLACE TRIGGER locationlog_insert_in_history_after_insert AFTER UPDATE on locationlog
FOR EACH ROW
BEGIN
    IF OLD.session_id <=> NEW.session_id THEN
        INSERT INTO locationlog_history
        SET
            tenant_id = OLD.tenant_id,
            mac = OLD.mac,
            switch = OLD.switch,
            port = OLD.port,
            vlan = OLD.vlan,
            role = OLD.role,
            connection_type = OLD.connection_type,
            connection_sub_type = OLD.connection_sub_type,
            dot1x_username = OLD.dot1x_username,
            ssid = OLD.ssid,
            start_time = OLD.start_time,
            end_time = CASE
            WHEN OLD.end_time = '0000-00-00 00:00:00' THEN NOW()
            WHEN OLD.end_time > NOW() THEN NOW()
            ELSE OLD.end_time
            END,
            switch_ip = OLD.switch_ip,
            switch_mac = OLD.switch_mac,
            stripped_user_name = OLD.stripped_user_name,
            realm = OLD.realm,
            session_id = OLD.session_id,
            ifDesc = OLD.ifDesc,
            voip = OLD.voip,
            tenant = OLD.tenant
        ;
  END IF;
END /
DELIMITER ;


\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version, created_at) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());


\! echo "Upgrade completed successfully.";

--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 8;
SET @MINOR_VERSION = 2;
SET @SUBMINOR_VERSION = 9;

SET @PREV_MAJOR_VERSION = 8;
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
call ValidateVersion;
DROP PROCEDURE IF EXISTS ValidateVersion;

--
-- Delete Google Project Fi from SMS carriers if it was added by the 5.7 to 6.0 script
--
DELETE FROM sms_carrier where id=100122 and name="Google Project Fi";
--
-- Delete Google Project Fi from SMS carriers that may have been added during 8.1 to 8.2 upgrade if patched script was used 
--
DELETE FROM sms_carrier where id=100128;

-- Add Project Fi SMS carrier now that its been fully removed above
--
INSERT INTO sms_carrier VALUES(100128, 'Google Project Fi', '%s@msg.fi.google.com', now(), now());

--
-- Updated freeradius acct_stop procedure
--

DROP PROCEDURE IF EXISTS acct_stop;
DELIMITER /
CREATE PROCEDURE acct_stop (
  IN `p_timestamp` datetime,
  IN `p_framedipaddress` varchar(15),
  IN `p_acctsessiontime` int(12),
  IN `p_acctinputoctets` bigint(20) unsigned,
  IN `p_acctoutputoctets` bigint(20) unsigned,
  IN `p_acctuniqueid` varchar(32),
  IN `p_acctsessionid` varchar(64),
  IN `p_username` varchar(64),
  IN `p_realm` varchar(64),
  IN `p_nasipaddress` varchar(15),
  IN `p_nasportid` varchar(32),
  IN `p_nasporttype` varchar(32),
  IN `p_acctauthentic` varchar(32),
  IN `p_connectinfo_stop` varchar(50),
  IN `p_calledstationid` varchar(50),
  IN `p_callingstationid` varchar(50),
  IN `p_servicetype` varchar(32),
  IN `p_framedprotocol` varchar(32),
  IN `p_acctterminatecause` varchar(12),
  IN `p_acctstatustype` varchar(25),
  IN `p_tenant_id` int(11) unsigned
)
BEGIN
  DECLARE `Previous_Input_Octets` bigint(20) unsigned;
  DECLARE `Previous_Output_Octets` bigint(20) unsigned;
  DECLARE `Previous_Session_Time` int(12) unsigned;

  # Collect traffic previous values in the radacct table
  SELECT `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`
    INTO `Previous_Input_Octets`, `Previous_Output_Octets`, `Previous_Session_Time`
    FROM `radacct`
    WHERE `acctuniqueid` = `p_acctuniqueid`
    AND (`acctstoptime` IS NULL OR `acctstoptime` = 0) LIMIT 1;

  # Set values to 0 when no previous records
  IF (`Previous_Session_Time` IS NOT NULL) THEN
    # Update record with new traffic
    UPDATE radacct SET
      `acctstoptime` = `p_timestamp`,
      `acctsessiontime` = `p_acctsessiontime`,
      `acctinputoctets` = `p_acctinputoctets`,
      `acctoutputoctets` = `p_acctoutputoctets`,
      acctterminatecause = p_acctterminatecause,
      connectinfo_stop = p_connectinfo_stop
      WHERE acctuniqueid = p_acctuniqueid
      AND (acctstoptime IS NULL OR acctstoptime = 0);

    # Create new record in the log table
    INSERT INTO radacct_log
     (acctsessionid, username, nasipaddress,
      timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime, acctuniqueid, tenant_id)
    VALUES
     (p_acctsessionid, p_username, p_nasipaddress,
     p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
     (p_acctsessiontime - Previous_Session_Time), p_acctuniqueid, p_tenant_id);
  END IF;
END /
DELIMITER ;


INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 10;
SET @MINOR_VERSION = 1;
SET @SUBMINOR_VERSION = 9;



SET @PREV_MAJOR_VERSION = 10;
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

ALTER TABLE node
  ADD INDEX `node_bypass_role_id` (`bypass_role_id`);

ALTER TABLE `password`
  ADD INDEX password_category (category);

ALTER TABLE `class`
  ADD INDEX password_target_category (target_category);

DROP PROCEDURE IF EXISTS `acct_update`;
DELIMITER /
CREATE PROCEDURE `acct_update`(
  IN `p_timestamp` datetime,
  IN `p_framedipaddress` varchar(15),
  IN `p_acctsessiontime` int(12) unsigned,
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
  IN `p_connectinfo_start` varchar(50),
  IN `p_calledstationid` varchar(50),
  IN `p_callingstationid` varchar(50),
  IN `p_servicetype` varchar(32),
  IN `p_framedprotocol` varchar(32),
  IN `p_acctstatustype` varchar(25),
  IN `p_nasidentifier` varchar(64),
  IN `p_calledstationssid` varchar(64),
  IN `p_tenant_id` int(11) unsigned
)
BEGIN
  DECLARE `Previous_Input_Octets` bigint(20) unsigned;
  DECLARE `Previous_Output_Octets` bigint(20) unsigned;
  DECLARE `Previous_Session_Time` int(12) unsigned;
  DECLARE `Previous_AcctUpdate_Time` datetime;

  DECLARE `Opened_Sessions` int(12) unsigned;
  DECLARE `Latest_acctstarttime` datetime;
  DECLARE `cnt` int(12) unsigned;
  DECLARE `countmac` int(12) unsigned;
  SELECT count(`acctuniqueid`), max(`acctstarttime`)
  INTO `Opened_Sessions`, `Latest_acctstarttime`
  FROM `radacct`
  WHERE `acctuniqueid` = `p_acctuniqueid`
  AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);

  IF (`Opened_Sessions` > 1) THEN
      UPDATE `radacct` SET
        `acctstoptime` = NOW(),
        `acctterminatecause` = 'UNKNOWN'
        WHERE `acctuniqueid` = `p_acctuniqueid`
        AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);
  END IF;
  # Detect if we receive in the same time a stop before the interim update
  SELECT COUNT(*)
  INTO `cnt`
  FROM `radacct`
  WHERE `acctuniqueid` = `p_acctuniqueid`
  AND (`acctstoptime` = `p_timestamp`);

  # If there is an old closed entry then update it
  IF (`cnt` = 1) THEN
    UPDATE `radacct` SET
        `framedipaddress` = `p_framedipaddress`,
        `acctsessiontime` = `p_acctsessiontime`,
        `acctinputoctets` = `p_acctinputoctets`,
        `acctoutputoctets` = `p_acctoutputoctets`,
        `acctupdatetime` = `p_timestamp`
    WHERE `acctuniqueid` = `p_acctuniqueid`
    AND (`acctstoptime` = `p_timestamp`);
  END IF;

  #Detect if there is an radacct entry open
  SELECT count(`callingstationid`), `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctupdatetime`
    INTO `countmac`, `Previous_Input_Octets`, `Previous_Output_Octets`, `Previous_Session_Time`, `Previous_AcctUpdate_Time`
    FROM `radacct`
    WHERE (`acctuniqueid` = `p_acctuniqueid`)
    AND (`acctstoptime` IS NULL OR `acctstoptime` = 0) LIMIT 1;

  IF (`countmac` = 1) THEN
    # Update record with new traffic
    UPDATE `radacct` SET
        `framedipaddress` = `p_framedipaddress`,
        `acctsessiontime` = `p_acctsessiontime`,
        `acctinputoctets` = `p_acctinputoctets`,
        `acctoutputoctets` = `p_acctoutputoctets`,
        `acctupdatetime` = `p_timestamp`,
        `acctinterval` = timestampdiff( second, `Previous_AcctUpdate_Time`,  `p_timestamp`  )
    WHERE `acctuniqueid` = `p_acctuniqueid`
    AND (`acctstoptime` IS NULL OR `acctstoptime` = 0);
  ELSE
    IF (`cnt` = 0) THEN
      # If there is no open session for this, open one.
      # Set values to 0 when no previous records
      SET `Previous_Session_Time` = 0;
      SET `Previous_Input_Octets` = 0;
      SET `Previous_Output_Octets` = 0;
      SET `Previous_AcctUpdate_Time` = `p_timestamp`;
      INSERT INTO `radacct`
             (
              `acctsessionid`,`acctuniqueid`,`username`,
              `realm`,`nasipaddress`,`nasportid`,
              `nasporttype`,`acctstarttime`,
              `acctupdatetime`,`acctsessiontime`,`acctauthentic`,
              `connectinfo_start`,`acctinputoctets`,
              `acctoutputoctets`,`calledstationid`,`callingstationid`,
              `servicetype`,`framedprotocol`,
              `framedipaddress`, `nasidentifier`,
              `calledstationssid`, `tenant_id`
             )
      VALUES
          (
              `p_acctsessionid`,`p_acctuniqueid`,`p_username`,
              `p_realm`,`p_nasipaddress`,`p_nasportid`,
              `p_nasporttype`,date_sub(`p_timestamp`, INTERVAL `p_acctsessiontime` SECOND ),
              `p_timestamp`,`p_acctsessiontime`,`p_acctauthentic`,
              `p_connectinfo_start`,`p_acctinputoctets`,
              `p_acctoutputoctets`,`p_calledstationid`,`p_callingstationid`,
              `p_servicetype`,`p_framedprotocol`,
              `p_framedipaddress`, `p_nasidentifier`, `p_calledstationssid`, `p_tenant_id`
          );
     END IF;
   END IF;

  # Create new record in the log table
  INSERT INTO `radacct_log`
   (`acctsessionid`, `username`, `nasipaddress`,
    `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`, `tenant_id`)
  VALUES
   (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
    `p_timestamp`, `p_acctstatustype`, (`p_acctinputoctets` - `Previous_Input_Octets`), (`p_acctoutputoctets` - `Previous_Output_Octets`),
    (`p_acctsessiontime` - `Previous_Session_Time`), `p_acctuniqueid`, `p_tenant_id`);
END /
DELIMITER ;

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

\! echo "Upgrade completed successfully.";

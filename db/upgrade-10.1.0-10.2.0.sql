--
-- PacketFence SQL schema upgrade from 10.1.0 to 10.2.0
--


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 10;
SET @MINOR_VERSION = 2;
SET @SUBMINOR_VERSION = 0;



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

\! echo "Adding node_bypass_role_id index to node table"
ALTER TABLE node
  ADD INDEX IF NOT EXISTS `node_bypass_role_id` (`bypass_role_id`);

\! echo "Adding password_category index to password table"
ALTER TABLE `password`
  ADD INDEX IF NOT EXISTS password_category (category);

\! echo "Adding password_target_category index to class table"
ALTER TABLE `class`
  ADD INDEX IF NOT EXISTS password_target_category (target_category);

\! echo "Updating acct_update procedure"
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

    INSERT INTO `radacct_log`
   (`acctsessionid`, `username`, `nasipaddress`,
    `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`, `tenant_id`)
  VALUES
   (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
    `p_timestamp`, `p_acctstatustype`, (`p_acctinputoctets` - `Previous_Input_Octets`), (`p_acctoutputoctets` - `Previous_Output_Octets`),
    (`p_acctsessiontime` - `Previous_Session_Time`), `p_acctuniqueid`, `p_tenant_id`);

  ELSE
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
              `p_nasporttype`,`p_timestamp`,
              `p_timestamp`,0,`p_acctauthentic`,
              `p_connectinfo_start`,0,
              0,`p_calledstationid`,`p_callingstationid`,
              `p_servicetype`,`p_framedprotocol`,
              `p_framedipaddress`, `p_nasidentifier`, `p_calledstationssid`, `p_tenant_id`
          );

      INSERT INTO `radacct_log`
       (`acctsessionid`, `username`, `nasipaddress`,
        `timestamp`, `acctstatustype`, `acctinputoctets`, `acctoutputoctets`, `acctsessiontime`, `acctuniqueid`, `tenant_id`)
      VALUES
       (`p_acctsessionid`, `p_username`, `p_nasipaddress`,
       `p_timestamp`, `p_acctstatustype`, 0, 0,
       0, `p_acctuniqueid`, `p_tenant_id`);

   END IF;
END /
DELIMITER ;

\! echo "Adding category_id column to activation table"
ALTER TABLE `activation`
  ADD COLUMN IF NOT EXISTS `category_id` INT AFTER `unregdate`;

\! echo "Adding radreply table";
CREATE TABLE IF NOT EXISTS `radreply` (
  `id` int(11) unsigned NOT NULL auto_increment,
  `tenant_id` int NOT NULL DEFAULT 1,
  `username` varchar(64) NOT NULL default '',
  `attribute` varchar(64) NOT NULL default '',
  `op` char(2) NOT NULL DEFAULT ':=',
  `value` varchar(253) NOT NULL default '',
  PRIMARY KEY (`id`),
  KEY (`tenant_id`, `username`)
);

\! echo "Adding default radreply row";
INSERT INTO `radreply` (`tenant_id`, `username`, `attribute`, `value`, `op`)
    SELECT * FROM (SELECT '1', '00:00:00:00:00:00','User-Name', '*', '=*') as x
     WHERE NOT EXISTS ( SELECT 1 FROM `radreply` WHERE `tenant_id`='1' AND `username`='00:00:00:00:00:00' AND `attribute`='User-Name' AND `value`='*' AND `op`='=*');

\! echo "Adding integer column to locationlog switch_ip"
ALTER table `locationlog` ADD COLUMN IF NOT EXISTS `switch_ip_int` INT UNSIGNED AS (INET_ATON(`switch_ip`)) PERSISTENT AFTER `switch_ip`,
    ADD KEY IF NOT EXISTS `locationlog_switch_ip_int` (`switch_ip_int`);

\! echo "Adding integer column to locationlog_history switch_ip"
ALTER table `locationlog_history` ADD COLUMN IF NOT EXISTS `switch_ip_int` INT UNSIGNED AS (INET_ATON(`switch_ip`)) PERSISTENT AFTER `switch_ip`,
    ADD KEY IF NOT EXISTS `locationlog_switch_ip_int` (`switch_ip_int`);

\! echo "Incrementing PacketFence schema version...";
INSERT IGNORE INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

\! echo "Upgrade completed successfully.";

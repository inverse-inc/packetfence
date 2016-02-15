--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

-- Adding RADIUS Updates Stored Procedure

DROP PROCEDURE IF EXISTS acct_update;
DELIMITER /
CREATE PROCEDURE acct_update(
  IN p_timestamp datetime,
  IN p_acctsessiontime int(12),
  IN p_acctinputoctets bigint(20),
  IN p_acctoutputoctets bigint(20),
  IN p_acctsessionid varchar(64),
  IN p_username varchar(64),
  IN p_nasipaddress varchar(15),
  IN p_framedipaddress varchar(15),
  IN p_acctstatustype varchar(25)
)
BEGIN
  DECLARE Previous_Input_Octets bigint(20);
  DECLARE Previous_Output_Octets bigint(20);
  DECLARE Previous_Session_Time int(12);

  # Collect traffic previous values in the update table
  SELECT acctinputoctets, acctoutputoctets, acctsessiontime
    INTO Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time
    FROM radacct
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress
    AND (acctstoptime IS NULL OR acctstoptime = 0);

  # Set values to 0 when no previous records
  IF (Previous_Session_Time IS NULL) THEN
    SET Previous_Session_Time = 0;
    SET Previous_Input_Octets = 0;
    SET Previous_Output_Octets = 0;
  END IF;

  # Update record with new traffic
  UPDATE radacct SET
    framedipaddress = p_framedipaddress,
    acctsessiontime = p_acctsessiontime,
    acctinputoctets = p_acctinputoctets,
    acctoutputoctets = p_acctoutputoctets
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress
    AND (acctstoptime IS NULL OR acctstoptime = 0);

  # Create new record in the log table
  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time));
END /
DELIMITER ;

-- Adding RADIUS Stop Stored Procedure

DROP PROCEDURE IF EXISTS acct_stop;
DELIMITER /
CREATE PROCEDURE acct_stop(
  IN p_timestamp datetime,
  IN p_acctsessiontime int(12),
  IN p_acctinputoctets bigint(20),
  IN p_acctoutputoctets bigint(20),
  IN p_acctterminatecause varchar(12),
  IN p_acctdelaystop varchar(32),
  IN p_connectinfo_stop varchar(50),
  IN p_acctsessionid varchar(64),
  IN p_username varchar(64),
  IN p_nasipaddress varchar(15),
  IN p_acctstatustype varchar(25)
)
BEGIN
  DECLARE Previous_Input_Octets bigint(20);
  DECLARE Previous_Output_Octets bigint(20);
  DECLARE Previous_Session_Time int(12);

  # Collect traffic previous values in the update table
  SELECT acctinputoctets, acctoutputoctets, acctsessiontime
    INTO Previous_Input_Octets, Previous_Output_Octets, Previous_Session_Time
    FROM radacct
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress
    AND (acctstoptime IS NULL OR acctstoptime = 0);

  # Set values to 0 when no previous records
  IF (Previous_Session_Time IS NULL) THEN
    SET Previous_Session_Time = 0;
    SET Previous_Input_Octets = 0;
    SET Previous_Output_Octets = 0;
  END IF;

  # Update record with new traffic
  UPDATE radacct SET
    acctstoptime = p_timestamp,
    acctsessiontime = p_acctsessiontime,
    acctinputoctets = p_acctinputoctets,
    acctoutputoctets = p_acctoutputoctets,
    acctterminatecause = p_acctterminatecause,
    connectinfo_stop = p_connectinfo_stop
    WHERE acctsessionid = p_acctsessionid
    AND username = p_username
    AND nasipaddress = p_nasipaddress
    AND (acctstoptime IS NULL OR acctstoptime = 0);

  # Create new record in the log table
  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    timestamp, acctstatustype, acctinputoctets, acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_timestamp, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets), (p_acctoutputoctets - Previous_Output_Octets),
    (p_acctsessiontime - Previous_Session_Time));
END /
DELIMITER ;

--
-- Alter locationlog
--

ALTER TABLE `locationlog` MODIFY `end_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00';

--
-- Alter locationlog_archive
--

ALTER TABLE `locationlog_archive` MODIFY `end_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00';

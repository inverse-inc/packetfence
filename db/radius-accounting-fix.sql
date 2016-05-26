
-- Adding RADIUS Updates Stored Procedure
DROP PROCEDURE IF EXISTS acct_update;
DELIMITER /
CREATE PROCEDURE acct_update(
  IN p_acctsessionid varchar(64),
  IN p_acctuniqueid varchar(32),
  IN p_username varchar(64),
  IN p_realm varchar(64),
  IN p_nasipaddress varchar(15),
  IN p_nasportid varchar(15),
  IN p_nasporttype varchar(32),
  IN p_acctstarttime datetime,
  IN p_acctstoptime datetime,
  IN p_acctsessiontime int(12),
  IN p_acctauthentic varchar(32),
  IN p_connectioninfo_start varchar(50),
  IN p_connectioninfo_stop varchar(50),
  IN p_acctinputoctets bigint(20),
  IN p_acctoutputoctets bigint(20),
  IN p_calledstationid varchar(50),
  IN p_callingstationid varchar(50),
  IN p_acctterminatecause varchar(32),
  IN p_servicetype varchar(32),
  IN p_framedprotocol varchar(32),
  IN p_framedipaddress varchar(15),
  IN p_acctstartdelay varchar(12),
  IN p_acctstopdelay varchar(12),
  IN p_xascendsessionsvrkey varchar(10),
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
    AND (acctstoptime IS NULL OR acctstoptime = 0) LIMIT 1;

  # Set values to 0 when no previous records
  IF (Previous_Session_Time IS NULL) THEN
    SET Previous_Session_Time = 0;
    SET Previous_Input_Octets = 0;
    SET Previous_Output_Octets = 0;
  ELSE
    INSERT INTO radacct
      (acctsessionid, acctuniqueid, username,
       realm, nasipaddress, nasportid,
       nasporttype, acctstarttime, acctstoptime,
       acctsessiontime, acctauthentic, connectinfo_start,
       connectinfo_stop, acctinputoctets, acctoutputoctets,
       calledstationid, callingstationid, acctterminatecause,
       servicetype, framedprotocol, framedipaddress,
       acctstartdelay, acctstopdelay, xascendsessionsvrkey)
    VALUES
      (p_acctsessionid, p_acctuniqueid, p_username,
       p_realm, p_nasipaddress, p_nasportid,
       p_nasporttype, p_acctstarttime, p_acctstoptime,
       p_acctsessiontime, p_acctauthentic, p_connectioninfo_start,
       p_connectioninfo_stop, p_acctinputoctets, p_acctoutputoctets,
       p_calledstationid, p_callingstationid, p_acctterminatecause,
       p_servicetype, p_framedprotocol, p_framedipaddress,
       p_acctstartdelay, p_acctstopdelay, p_xascendsessionsvrkey);
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

    END IF;

  # Create new record in the log table
  INSERT INTO radacct_log
   (acctsessionid, username, nasipaddress,
    `timestamp`, acctstatustype, acctinputoctets, 
    acctoutputoctets, acctsessiontime)
  VALUES
   (p_acctsessionid, p_username, p_nasipaddress,
    p_acctstarttime, p_acctstatustype, (p_acctinputoctets - Previous_Input_Octets),
    (p_acctoutputoctets - Previous_Output_Octets), (p_acctsessiontime - Previous_Session_Time));
END /
DELIMITER ;

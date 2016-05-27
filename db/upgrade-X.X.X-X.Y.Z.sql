--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Setting the major/minor/sub-minor version of the DB
--

DROP TABLE configfile;

SET @MAJOR_VERSION = 6;
SET @MINOR_VERSION = 4;
SET @SUBMINOR_VERSION = 9;

--
-- Set passwords with NULL value to the new default value
--
UPDATE password set valid_from="0000-00-00 00:00:00" WHERE valid_from IS NULL;

--
-- Make valid_from default to 0000-00-00 00:00:00
--

ALTER TABLE password MODIFY valid_from DATETIME NOT NULL DEFAULT "0000-00-00 00:00:00";

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));


--
-- Remove acctstarttime index on radacct
--

DROP INDEX acctstarttime on radacct;

--
-- Add index on acctstarttime and acctstoptime
--

ALTER TABLE radacct ADD INDEX acctstart_acctstop (acctstarttime,acctstoptime);

--
-- Creating radippool table
--

CREATE TABLE radippool (
  id                    int(11) unsigned NOT NULL auto_increment,
  pool_name             varchar(30) NOT NULL,
  framedipaddress       varchar(15) NOT NULL default '',
  nasipaddress          varchar(15) NOT NULL default '',
  calledstationid       VARCHAR(30) NOT NULL,
  callingstationid      VARCHAR(30) NOT NULL,
  expiry_time           DATETIME NULL default NULL,
  start_time            DATETIME NULL default NULL,
  username              varchar(64) NOT NULL default '',
  pool_key              varchar(30) NOT NULL,
  lease_time            varchar(30) NULL,
  PRIMARY KEY (id),
  UNIQUE (framedipaddress),
  KEY radippool_poolname_expire (pool_name, expiry_time),
  KEY callingstationid (callingstationid),
  KEY radippool_framedipaddress (framedipaddress),
  KEY radippool_nasip_poolkey_ipaddress (nasipaddress, pool_key, framedipaddress),
  KEY radippool_callingstationid_expiry (callingstationid, expiry_time),
  KEY radippool_framedipaddress_expiry (framedipaddress, expiry_time)
) ENGINE=InnoDB;

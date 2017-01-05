--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Setting the major/minor/sub-minor version of the DB
--

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

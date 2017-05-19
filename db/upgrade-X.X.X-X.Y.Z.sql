--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Remove hash prefix from activation table
--

UPDATE activation SET activation_code = SUBSTR(activation_code, INSTR(activation_code, ":") + 1 );

--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 7;
SET @MINOR_VERSION = 0;
SET @SUBMINOR_VERSION = 9;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));

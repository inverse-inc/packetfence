--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 6;
SET @MINOR_VERSION = 2;
SET @SUBMINOR_VERSION = 9;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = X;
SET @MINOR_VERSION = Y;
SET @SUBMINOR_VERSION = Z;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));
--
-- PacketFence SQL schema upgrade from 5.7.0 to 5.8.0
--

--
-- Insert 'VoIP' category
--

INSERT INTO `node_category` (name,notes) VALUES ("voice","VoIP devices");

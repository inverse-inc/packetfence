--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Setting the major/minor/patch version of the DB
--

SET @MAJOR_VERSION = 5;
SET @MINOR_VERSION = 1;
SET @PATCH_LEVEL = 0;

--
-- The VERSION_INT to ensure proper ordering of the version in queries
--

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @PATCH_LEVEL;

--
-- Table structure for table 'pf_version'
--

CREATE TABLE pf_version ( `id` INT NOT NULL PRIMARY KEY, `version` VARCHAR(11) NOT NULL UNIQUE KEY);

--
-- Updating to current version
--

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @PATCH_LEVEL));

--
-- Alter Class for external_command
--

ALTER TABLE class
    ADD `external_command` varchar(255) DEFAULT NULL;


SET @MAJOR_VERSION = 5,@MINOR_VERSION = 1, @PATCH_LEVEL = 0;
SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @PATCH_LEVEL;

--
-- Table structure for table 'pf_version'
--

CREATE TABLE pf_version ( `id` INT NOT NULL, `version` VARCHAR(11) NOT NULL , PRIMARY KEY (id));

--
-- Updating to current version
--

INSERT INTO pf_version (id,version) VALUES (@VERSION_INT,CONCAT(@MAJOR_VERSION,'.',@MINOR_VERSION,'.',@PATCH_LEVEL));

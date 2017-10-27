--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--


--
-- Setting the major/minor/sub-minor version of the DB
--

SET @MAJOR_VERSION = 7;
SET @MINOR_VERSION = 4;
SET @SUBMINOR_VERSION = 9;

SET @PREV_MAJOR_VERSION = 7;
SET @PREV_MINOR_VERSION = 4;
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
call ValidateVersion;


CREATE TABLE `tenant` (
  id int NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY tenant_name (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO `tenant` (id, name) VALUES (1, 'default');

ALTER TABLE `violation`
    DROP FOREIGN KEY `0_60`;

ALTER TABLE `userlog`
    DROP FOREIGN KEY `userlog_ibfk_1`;

ALTER TABLE `node`
    DROP FOREIGN KEY `0_57`,
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1,
    DROP PRIMARY KEY,
    ADD  PRIMARY KEY (`tenant_id`, `mac`),
    ADD CONSTRAINT `node_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`);

ALTER TABLE `person`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1 FIRST,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (`tenant_id`, `pid`),
    ADD CONSTRAINT `person_tenant_id` FOREIGN KEY (`tenant_id`) REFERENCES `tenant` (`id`);

ALTER TABLE `violation`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1,
    ADD CONSTRAINT `violation_tenant_id_mac` FOREIGN KEY (`tenant_id`, `mac`) REFERENCES `node` (`tenant_id`,`mac`);

ALTER TABLE `userlog`
    ADD COLUMN tenant_id int NOT NULL DEFAULT 1,
    ADD CONSTRAINT `userlog_tenant_id_mac` FOREIGN KEY (`tenant_id`, `mac`) REFERENCES `node` (`tenant_id`,`mac`);

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION));


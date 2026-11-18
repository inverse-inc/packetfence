--
-- The tables of the test package "acme", version 1.2: a fresh install
--
SET sql_mode = "NO_ENGINE_SUBSTITUTION";

SET @MAJOR_VERSION = 1;
SET @MINOR_VERSION = 2;
SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8;

\! echo "Creating the acme tables...";
CREATE TABLE IF NOT EXISTS `acme_item` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(512) NOT NULL,
  `note` VARCHAR(255) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `acme_item_name` (`name`),
  KEY `acme_item_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARACTER SET = 'utf8mb4' COLLATE = 'utf8mb4_general_ci';

INSERT IGNORE INTO plugin_version (name, id, version, created_at) VALUES ('acme', @VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());

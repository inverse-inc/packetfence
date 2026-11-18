--
-- The tables of the test package "acme", from 1.0 to 1.1: an upgrade that
-- adds a column and an index, safe to run again
--
SET sql_mode = "NO_ENGINE_SUBSTITUTION";

SET @MAJOR_VERSION = 1;
SET @MINOR_VERSION = 1;
SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8;

\! echo "Checking the acme schema version...";
CALL ValidatePluginVersion('acme', 1 << 16 | 0 << 8);

\! echo "Adding acme_item.note...";
CALL AddColumnUnlessExists('acme_item', 'note', 'VARCHAR(255) DEFAULT NULL AFTER `name`');
CALL AddIndexUnlessExists('acme_item', 'acme_item_created_at', 'KEY `acme_item_created_at` (`created_at`)');

INSERT IGNORE INTO plugin_version (name, id, version, created_at) VALUES ('acme', @VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());

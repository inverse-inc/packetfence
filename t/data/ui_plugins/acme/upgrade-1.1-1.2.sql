--
-- The tables of the test package "acme", from 1.1 to 1.2: widening
-- acme_item.name by rebuilding the table, the way a large table is changed
-- (docs/developer/ui_plugins.asciidoc). Safe to run again after a failure.
--
SET sql_mode = "NO_ENGINE_SUBSTITUTION";

SET @MAJOR_VERSION = 1;
SET @MINOR_VERSION = 2;
SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8;

\! echo "Checking the acme schema version...";
CALL ValidatePluginVersion('acme', 1 << 16 | 1 << 8);

-- leftovers of a run that failed
DROP TABLE IF EXISTS `acme_item_new`;
DROP TABLE IF EXISTS `acme_item_old`;

\! echo "Rebuilding acme_item...";
-- 1. a copy of the table, with its primary key only (Galera needs it)
CREATE TABLE `acme_item_new` LIKE `acme_item`;
CALL DropIndexIfExists('acme_item_new', 'acme_item_name');
CALL DropIndexIfExists('acme_item_new', 'acme_item_created_at');

-- 2. the change, on the copy only
ALTER TABLE `acme_item_new` MODIFY `name` VARCHAR(512) NOT NULL;

-- 3. the rows, in batches
CALL CopyRowsInBatches('acme_item', 'acme_item_new', '`id`, `name`, `note`, `created_at`', 'id', 10000);

-- 4. the indexes, on the copy
CALL AddIndexUnlessExists('acme_item_new', 'acme_item_name', 'KEY `acme_item_name` (`name`)');
CALL AddIndexUnlessExists('acme_item_new', 'acme_item_created_at', 'KEY `acme_item_created_at` (`created_at`)');

-- 5. the copy replaces the table, in one statement
RENAME TABLE `acme_item` TO `acme_item_old`, `acme_item_new` TO `acme_item`;

-- 6. the old table goes
DROP TABLE `acme_item_old`;

INSERT IGNORE INTO plugin_version (name, id, version, created_at) VALUES ('acme', @VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION), NOW());

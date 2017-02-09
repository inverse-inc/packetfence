--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Add a primary key to the radacct_log
--

ALTER TABLE `radacct_log` ADD COLUMN `radacct_log_id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the iplog_history
--

ALTER TABLE `iplog_history` ADD COLUMN `iplog_history_id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the iplog_archive
--

ALTER TABLE `iplog_archive` ADD COLUMN `iplog_archive_id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the locationlog
--

ALTER TABLE `locationlog` ADD COLUMN `locationlog_id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

--
-- Add a primary key to the locationlog_archive
--

ALTER TABLE `locationlog_archive` ADD COLUMN `locationlog_archive_id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

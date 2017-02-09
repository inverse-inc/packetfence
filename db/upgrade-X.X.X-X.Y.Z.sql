--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Add a primary key to the radacct_log
--

ALTER TABLE `radacct_log` ADD COLUMN `radacct_log_id` int NOT NULL PRIMARY KEY AUTO_INCREMENT FIRST;

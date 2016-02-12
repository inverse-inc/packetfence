--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Alter locationlog
--

ALTER TABLE `locationlog` MODIFY `end_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00';

--
-- Alter locationlog_archive
--

ALTER TABLE `locationlog_archive` MODIFY `end_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00';


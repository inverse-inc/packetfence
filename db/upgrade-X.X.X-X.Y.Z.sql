--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Alter locationlog
--

ALTER TABLE `locationlog`
    ADD `connection_sub_type` varchar(50) NOT NULL default '' AFTER connection_type;

--
-- Alter locationlog_archive
--

ALTER TABLE `locationlog_archive`
    ADD `connection_sub_type` varchar(50) NOT NULL default '' AFTER connection_type;

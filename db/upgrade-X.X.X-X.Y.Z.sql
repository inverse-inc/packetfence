--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Alter Class for external_command
--

ALTER TABLE class
    ADD `external_command` varchar(255) DEFAULT NULL;

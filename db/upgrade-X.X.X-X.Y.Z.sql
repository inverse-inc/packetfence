--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Alter for machine_account
--

ALTER TABLE node
    ADD `machine_account` varchar(255) DEFAULT NULL;

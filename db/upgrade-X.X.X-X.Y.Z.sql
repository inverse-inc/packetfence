--
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--

--
-- Alter node
--

ALTER TABLE `node`
    ADD `dhcp6_fingerprint` varchar(255) default NULL AFTER dhcp_fingerprint,
    ADD `dhcp6_enterprise` varchar(255) default NULL AFTER dhcp_vendor;

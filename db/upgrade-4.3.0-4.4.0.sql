--
-- Alter for dynamic controller
--

ALTER TABLE locationlog_history
    ADD `switch_ip` varchar(17) DEFAULT NULL,
    ADD `switch_mac` varchar(17) DEFAULT NULL;

UPDATE locationlog_history SET switch_ip = switch;


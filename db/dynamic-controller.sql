
ALTER TABLE locationlog 
    ADD `switch_ip` varchar(17) DEFAULT NULL,
    ADD `switch_mac` varchar(17) DEFAULT NULL;

UPDATE locationlog SET switch_ip = switch;

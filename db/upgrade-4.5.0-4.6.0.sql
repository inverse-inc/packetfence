-- Alter for realm
--

ALTER TABLE locationlog
    ADD `stripped_user_name` varchar(255) DEFAULT NULL,
    ADD `realm` varchar(255) DEFAULT NULL;

ALTER TABLE locationlog_history
    ADD `stripped_user_name` varchar(255) DEFAULT NULL,
    ADD `realm` varchar(255) DEFAULT NULL;


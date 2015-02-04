-- Alter for realm
--

ALTER TABLE locationlog
    ADD `stripped_user_name` varchar(255) DEFAULT NULL,
    ADD `realm` varchar(255) DEFAULT NULL;

ALTER TABLE locationlog_history
    ADD `stripped_user_name` varchar(255) DEFAULT NULL,
    ADD `realm` varchar(255) DEFAULT NULL;

--
-- Alter to improve iplog clean up
--

ALTER TABLE iplog ADD INDEX iplog_end_time (end_time), DROP INDEX mac;

--
-- Alter to improve violation maintenance
--

ALTER TABLE violation ADD INDEX violation_release_date (release_date);

--
-- Alter to locationlog clean up
--

ALTER TABLE locationlog ADD INDEX locationlog_end_time (end_time);

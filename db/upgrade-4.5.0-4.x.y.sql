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


DROP INDEX `mac` FROM iplog;
CREATE INDEX iplog_end_time ON iplog (end_time);

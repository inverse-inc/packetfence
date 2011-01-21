--
-- Adding an index to locationlog
--

ALTER TABLE locationlog
	ADD KEY `locationlog_start_time` (`start_time`)
;

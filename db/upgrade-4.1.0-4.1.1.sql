--
-- Added a new column to keep the audit-session-id from the radius request to use with the CoA
--

ALTER TABLE `node` ADD `sessionid` varchar(30) default NULL AFTER autoreg;


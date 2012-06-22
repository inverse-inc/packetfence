--
-- Alter table structure for node_category to add max_nodes_per_pid
--

ALTER TABLE class
  ADD `window` varchar(255) default 0 AFTER grace_period
;

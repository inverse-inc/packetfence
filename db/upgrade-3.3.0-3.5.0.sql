--
-- Alter table structure for class to add the class.window
--

ALTER TABLE class
  ADD `window` varchar(255) NOT NULL default 0 AFTER grace_period
;

--
-- Alter table structure for class to add the class.vclose         
--

ALTER TABLE class
  ADD `vclose` int(11) AFTER `window`
;

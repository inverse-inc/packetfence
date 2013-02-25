--
-- Insert 'target_category' class
--

ALTER TABLE `class` ADD `target_category` varchar(255) default '' AFTER `vlan`;

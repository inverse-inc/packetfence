
--
-- Table structure for table `node_category`
--

CREATE TABLE `node_category` (
  `category_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `notes` varchar(255) default NULL,
  PRIMARY KEY (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Insert 'default' category
--

INSERT INTO `node_category` (category_id,name,notes) VALUES ("1","default","Placeholder category, feel free to edit");

--
-- Add a category column to the node table
--
ALTER TABLE `node` ADD `category_id` int default NULL after `pid`;
ALTER TABLE `node` ADD KEY category_id (category_id);
ALTER TABLE `node` ADD
  CONSTRAINT `node_category_key` FOREIGN KEY (`category_id`) REFERENCES `node_category` (`category_id`);

--
-- Add a column to store whitelisted categories in violation triggers
--
ALTER TABLE `trigger` ADD `whitelisted_categories` varchar(255) NOT NULL default '' AFTER `type`;


--
-- Table structure for table `useragent_class`
--

CREATE TABLE `useragent_class` (
  `class_id` int(11) NOT NULL,
  `description` varchar(255) NOT NULL,
  PRIMARY KEY  (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `useragent_type`
--

CREATE TABLE `useragent_type` (
  `useragent_id` int(11) NOT NULL,
  `description` varchar(255) NOT NULL,
  `match_expression` varchar(255) NOT NULL,
  PRIMARY KEY  (`useragent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `useragent_mapping`
--

CREATE TABLE `useragent_mapping` (
  `useragent_type` int(11) NOT NULL,
  `useragent_class` int(11) NOT NULL,
  PRIMARY KEY  (`useragent_type`,`useragent_class`),
  KEY `useragent_type_key` (`useragent_type`),
  KEY `useragent_class_key` (`useragent_class`),
  CONSTRAINT `0_68` FOREIGN KEY (`useragent_type`) REFERENCES `useragent_type` (`useragent_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `0_69` FOREIGN KEY (`useragent_class`) REFERENCES `useragent_class` (`class_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Add vlan parameter to the class table
--

ALTER TABLE `class` ADD vlan varchar(255) after `disable`;


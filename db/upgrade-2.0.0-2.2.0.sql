
--
-- Changes are related to easier User-Agent violation support
--

-- dropping old tables (mapping first because of its constraints)
DROP TABLE `useragent_mapping`;
DROP TABLE `useragent_class`;
DROP TABLE `useragent_type`;

-- new node_useragent table
CREATE TABLE `node_useragent` (
  mac varchar(17) NOT NULL,
  os varchar(255) DEFAULT NULL,
  browser varchar(255) DEFAULT NULL,
  device enum('no','yes') NOT NULL DEFAULT 'no',
  device_name varchar(255) DEFAULT NULL,
  mobile enum('no','yes') NOT NULL DEFAULT 'no',
  PRIMARY KEY (mac)
) ENGINE=InnoDB;


--
-- Table structure for table `scan`
--

CREATE TABLE scan (
id varchar(20) NOT NULL,
ip varchar(255) NOT NULL,
mac varchar(17) NOT NULL,
type varchar(255) NOT NULL,
start_date datetime NOT NULL,
update_date timestamp NOT NULL ON UPDATE CURRENT_TIMESTAMP,
status varchar(255) NOT NULL,
report_id varchar(255) NOT NULL,
PRIMARY KEY (id)
) ENGINE=InnoDB;

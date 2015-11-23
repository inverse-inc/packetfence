--
-- Table structure for table 'radius_audit_log'
--

DROP TABLE IF EXISTS radius_audit_log;

CREATE TABLE radius_audit_log (
  id int NOT NULL AUTO_INCREMENT,
  nas_ip_address varchar(255) NULL,
  nas_port_type varchar(255) NULL,
  called_station_id varchar(255) NULL,
  calling_station_id varchar(255) NULL,
  module_failure_message varchar(255) NULL,
  user_name varchar(255) NULL,
  radius_request TEXT,
  radius_reply TEXT,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

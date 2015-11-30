--
-- Table structure for table 'radius_audit_log'
--

DROP TABLE IF EXISTS radius_audit_log;

CREATE TABLE radius_audit_log (
  id int NOT NULL AUTO_INCREMENT,
  created_at TIMESTAMP NOT NULL,
  mac char(17) NULL,
  user_name varchar(255) NULL,
  status varchar(255) NULL,
  auth_type varhcar(255) NULL,
  source varchar(255) NULL,
  role varchar(255) NULL,
  status varchar(255) NULL,
  unreg varchar(255) NULL,
  ifindex varchar(255) NULL,
  reason varchar(255) NULL,
  nas_port varchar(255) NULL,
  profile varchar(255) NULL,
  event_type varchar(255) NULL,
  uuid varchar(255) NULL,
  nas_ip_address varchar(255) NULL,
  nas_port_type varchar(255) NULL,
  called_station_id varchar(255) NULL,
  calling_station_id varchar(255) NULL,
  radius_reply TEXT,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

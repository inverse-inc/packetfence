drop table scan;
CREATE TABLE `trigger` (
  vid int(11) default NULL,
  tid_start int(11) NOT NULL,
  tid_end int(11) NOT NULL,
  type varchar(255) default NULL,
  PRIMARY KEY (vid,tid_start,tid_end,type),
  KEY `trigger` (tid_start,tid_end,type),
  CONSTRAINT `0_64` FOREIGN KEY (`vid`) REFERENCES `class` (`vid`) ON DELETE CASCADE ON UPDATE CASCADE
) TYPE=InnoDB;

DROP TABLE dhcp_fingerprint;

CREATE TABLE os_type (
  os_id int(11) NOT NULL,
  description varchar(255) NOT NULL,
  PRIMARY KEY os_id (os_id),
  KEY os_type_view (os_id,description),
  KEY os_id_key (os_id)
) TYPE=InnoDB;

CREATE TABLE dhcp_fingerprint (
  fingerprint varchar(255) NOT NULL,
  os_id int(11) NOT NULL,
  PRIMARY KEY fingerprint (fingerprint),
  KEY fingerprint_view (fingerprint,os_id),
  KEY os_id_key (os_id),
  CONSTRAINT `0_65` FOREIGN KEY (`os_id`) REFERENCES `os_type` (`os_id`) ON DELETE CASCADE ON UPDATE CASCADE
) TYPE=InnoDB;

CREATE TABLE os_class (
  class_id int(11) NOT NULL,               
  description varchar(255) NOT NULL,     
  PRIMARY KEY class_id (class_id),
  KEY os_class_view (class_id,description)
) TYPE=InnoDB;     

CREATE TABLE os_mapping (   
  os_type int(11) NOT NULL,  
  os_class int(11) NOT NULL,
  KEY os_mapping_view (os_type,os_class),
  KEY os_type_key (os_type),
  KEY os_class_key (os_class),
  CONSTRAINT `0_66` FOREIGN KEY (`os_type`) REFERENCES `os_type` (`os_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `0_67` FOREIGN KEY (`os_class`) REFERENCES `os_class` (`class_id`) ON DELETE CASCADE ON UPDATE CASCADE
) TYPE=InnoDB;

alter table violation add ticket_ref varchar(255) default NULL after status;

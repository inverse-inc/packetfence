--                                                                                                                     
-- PacketFence SQL schema upgrade from X.X.X to X.Y.Z
--                                                                                                                     
                                                                                                                       

--
-- Setting the major/minor/sub-minor version of the DB                                                                 
--                                                                                                                     

SET @MAJOR_VERSION = 8; 
SET @MINOR_VERSION = 3;
SET @SUBMINOR_VERSION = 9;                                                                                             
                                                                                                                       
SET @PREV_MAJOR_VERSION = 8;                                                                                           
SET @PREV_MINOR_VERSION = 3;
SET @PREV_SUBMINOR_VERSION = 0;                                                                                        
                                                                                                                       

--                                                                                                                     
-- The VERSION_INT to ensure proper ordering of the version in queries
--                                                                                                                     

SET @VERSION_INT = @MAJOR_VERSION << 16 | @MINOR_VERSION << 8 | @SUBMINOR_VERSION;                                     

SET @PREV_VERSION_INT = @PREV_MAJOR_VERSION << 16 | @PREV_MINOR_VERSION << 8 | @PREV_SUBMINOR_VERSION;                 

DROP PROCEDURE IF EXISTS ValidateVersion;                                                                              
--
-- Updating to current version
--  
DELIMITER //
CREATE PROCEDURE ValidateVersion()
BEGIN                                                                                                                  
    DECLARE PREVIOUS_VERSION int(11);
    DECLARE PREVIOUS_VERSION_STRING varchar(11);
    DECLARE _message varchar(255);
    SELECT id, version INTO PREVIOUS_VERSION, PREVIOUS_VERSION_STRING FROM pf_version ORDER BY id DESC LIMIT 1;        
              
      IF PREVIOUS_VERSION != @PREV_VERSION_INT THEN                                                                    
        SELECT CONCAT('PREVIOUS VERSION ', PREVIOUS_VERSION_STRING, ' DOES NOT MATCH ', CONCAT_WS('.', @PREV_MAJOR_VERSION, @PREV_MINOR_VERSION, @PREV_SUBMINOR_VERSION)) INTO _message;
        SIGNAL SQLSTATE VALUE '99999'                                                                                  
              SET MESSAGE_TEXT = _message;                                                                             
      END IF;                                                                                                          
END
//                                                                                                                     

DELIMITER ;                                                                                                            
call ValidateVersion;                                                                                                  

DROP PROCEDURE IF EXISTS `ValidateVersion`;


alter table class change vid security_event_id int(11) NOT NULL;
alter table action change vid security_event_id int(11) NOT NULL;

CREATE TABLE security_event (
  id int NOT NULL AUTO_INCREMENT,
  tenant_id int NOT NULL DEFAULT 1,
  mac varchar(17) NOT NULL,
  security_event_id int(11) NOT NULL,
  start_date datetime NOT NULL,
  release_date datetime default "0000-00-00 00:00:00",
  status varchar(10) default "open",
  ticket_ref varchar(255) default NULL,
  notes text,
  KEY security_event_id (security_event_id),
  KEY status (status),
  KEY uniq_mac_status_id (mac,status,security_event_id),
  KEY security_event_release_date (release_date),
  CONSTRAINT `tenant_id_mac_fkey_node` FOREIGN KEY (`tenant_id`, `mac`) REFERENCES `node` (`tenant_id`, `mac`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `security_event_id_fkey_class` FOREIGN KEY (`security_event_id`) REFERENCES `class` (`security_event_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `security_event_tenant_id` FOREIGN KEY(`tenant_id`) REFERENCES `tenant` (`id`),
  PRIMARY KEY (id)
) ENGINE=InnoDB;

insert into security_event select id, tenant_id, mac, vid, start_date, release_date, status, ticket_ref, notes from violation;

drop table violation;

INSERT INTO pf_version (id, version) VALUES (@VERSION_INT, CONCAT_WS('.', @MAJOR_VERSION, @MINOR_VERSION, @SUBMINOR_VERSION)); 

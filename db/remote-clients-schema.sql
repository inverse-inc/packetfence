

create table `remote_clients` (
  id int NOT NULL AUTO_INCREMENT,
  tenant_id int NOT NULL DEFAULT 1,
  private_key varchar(255) NOT NULL,
  public_key varchar(255) NOT NULL,
  ip_address varchar(255) NOT NULL,
  bypass_role int NOT NULL, 
  PRIMARY KEY (id),
  UNIQUE KEY remote_clients_private_key (`private_key`),
  UNIQUE KEY remote_clients_ip_address (`ip_address`),
  KEY remote_clients_bypass_role (`bypass_role`),
  CONSTRAINT `remote_clients_bypass_role_constraint` FOREIGN KEY (`bypass_role`) REFERENCES `node_category` (`category_id`)
) ENGINE=InnoDB;

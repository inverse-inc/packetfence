
drop table remote_clients;
create table `remote_clients` (
  id int NOT NULL AUTO_INCREMENT,
  tenant_id int NOT NULL DEFAULT 1,
  public_key varchar(255) NOT NULL,
  bypass_role int NOT NULL, 
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY remote_clients_private_key (`public_key`),
  KEY remote_clients_bypass_role (`bypass_role`)
) ENGINE=InnoDB;

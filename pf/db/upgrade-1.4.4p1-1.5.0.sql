alter table person add notes varchar(255) after pid;
alter table node add detect_date datetime NOT NULL default "0000-00-00 00:00:00" after pid;
alter table node add last_arp datetime NOT NULL default "0000-00-00 00:00:00" after computername;
alter table node add last_dhcp datetime NOT NULL default "0000-00-00 00:00:00" after last_arp;
alter table node add dhcp_fingerprint varchar(255) after last_dhcp;
alter table node add switch varchar(17) after dhcp_fingerprint;
alter table node add port varchar(8) after switch;
alter table node add vlan varchar(4) after port;
alter table violation_actions rename action;
alter table violation add id int NOT NULL AUTO_INCREMENT Primary Key first;
alter table violation add key status (status);
alter table iplog drop last_seen;
alter table action add primary key(vid,action);

create index macip on iplog (mac,ip,end_time);
drop table nessusid;

update person set notes="Default User - do not delete" where pid=1;
update node set detect_date=regdate where detect_date="";

CREATE TABLE scan (
  sid int(11) NOT NULL,
  vid int(11) default NULL,
  KEY (sid,vid),
  CONSTRAINT `0_62` FOREIGN KEY (`vid`) REFERENCES `class` (`vid`) ON DELETE CASCADE ON UPDATE CASCADE
) TYPE=InnoDB;

alter table scan add primary key(sid,vid);

CREATE TABLE dhcp_fingerprint (
  fingerprint varchar(255) NOT NULL,
  description varchar(255) NOT NULL,
  class varchar(255) NOT NULL,
  auto_register char(1) NOT NULL default "N",
  PRIMARY KEY (fingerprint)
) TYPE=InnoDB;

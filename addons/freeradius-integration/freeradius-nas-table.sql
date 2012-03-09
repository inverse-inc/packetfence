--
-- FreeRADIUS clients (NAS) are stored in this table
--
-- Changes from upstream FreeRADIUS 2.1.7:
-- * renamed table from nas to radius_nas
--
CREATE TABLE radius_nas (
  id int(10) NOT NULL auto_increment,
  nasname varchar(128) NOT NULL,
  shortname varchar(32),
  type varchar(30) DEFAULT 'other',
  ports int(5),
  secret varchar(60) DEFAULT 'secret' NOT NULL,
  community varchar(50),
  description varchar(200) DEFAULT 'RADIUS Client',
  PRIMARY KEY (id),
  KEY nasname (nasname)
);

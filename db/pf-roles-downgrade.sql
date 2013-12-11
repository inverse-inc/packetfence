update temporary_password SET access_level = '4294967295' WHERE access_level = 'ALL' ;
update temporary_password SET access_level = '0' where access_level = 'NONE';
ALTER TABLE temporary_password CHANGE access_level access_level int unsigned NOT NULL default 0;

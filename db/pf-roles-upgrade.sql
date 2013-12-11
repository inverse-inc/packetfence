ALTER TABLE temporary_password CHANGE access_level access_level  varchar(255) default 'NONE';
update temporary_password SET access_level = 'ALL' where access_level = '4294967295';
update temporary_password SET access_level = 'NONE' where access_level = '0';

-- Test database setup
--
-- create a database of the proper PacketFence version
-- mysql -u root -p pf-test < db/pf-schema.sql
--
-- then create proper user
CREATE USER 'pf-test'@'%' IDENTIFIED BY 'p@ck3tf3nc3';
GRANT USAGE ON *.* TO 'pf-test'@'%' IDENTIFIED BY 'p@ck3tf3nc3' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON `pf-test`.* TO 'pf-test'@'%';

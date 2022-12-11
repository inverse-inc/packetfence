DROP USER IF EXISTS pf_smoke_tester@'%';
DROP USER IF EXISTS pf_smoke_tester@'localhost';
CREATE USER 'pf_smoke_tester'@'localhost' IDENTIFIED BY 'Packet^1';
CREATE USER 'pf_smoke_tester'@'%' IDENTIFIED BY 'Packet^1';
GRANT ALL PRIVILEGES ON `pf_smoke_test%`.* TO pf_smoke_tester@'%';
GRANT ALL PRIVILEGES ON `pf_smoke_test%`.* TO pf_smoke_tester@'localhost';
GRANT INSERT, ALTER ROUTINE, CREATE ROUTINE ON mysql.* TO pf_smoke_tester@'localhost';
GRANT INSERT, ALTER ROUTINE, CREATE ROUTINE ON mysql.* TO pf_smoke_tester@'%';
FLUSH PRIVILEGES;

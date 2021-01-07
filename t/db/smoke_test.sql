REVOKE ALL PRIVILEGES, GRANT OPTION FROM pf_smoke_tester@'%', pf_smoke_tester@'localhost';
GRANT ALL PRIVILEGES ON `pf_smoke_test%`.* TO pf_smoke_tester@'%' IDENTIFIED BY 'packet';
GRANT ALL PRIVILEGES ON `pf_smoke_test%`.* TO pf_smoke_tester@'localhost' IDENTIFIED BY 'packet';
GRANT INSERT, ALTER ROUTINE, CREATE ROUTINE ON mysql.* TO pf_smoke_tester@'localhost' IDENTIFIED BY 'packet';
GRANT INSERT, ALTER ROUTINE, CREATE ROUTINE ON mysql.* TO pf_smoke_tester@'%' IDENTIFIED BY 'packet';
FLUSH PRIVILEGES;

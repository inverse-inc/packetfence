
GRANT ALL PRIVILEGES ON `pf_smoke_test%`.* TO pf_smoke_tester@'%' IDENTIFIED BY 'packet';
GRANT ALL PRIVILEGES ON `pf_smoke_test%`.* TO pf_smoke_tester@'localhost' IDENTIFIED BY 'packet';
FLUSH PRIVILEGES;

-- Test database setup
--
-- create a database of the proper PacketFence version
-- mysql -u root -p pf-test < db/pf-schema.sql
--
-- then create proper user
CREATE USER 'pf-test'@'%' IDENTIFIED BY 'p@ck3tf3nc3';
GRANT USAGE ON *.* TO 'pf-test'@'%' IDENTIFIED BY 'p@ck3tf3nc3' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
GRANT SELECT, INSERT, UPDATE, DELETE, LOCK TABLES ON `pf-test`.* TO 'pf-test'@'%';

-- Add test data

INSERT INTO `node` (
    `mac`, `pid`, `detect_date`, `status`, `computername`, `user_agent`, `last_dhcp`, `dhcp_fingerprint`
) VALUES (
    'f0:4d:a2:cb:d9:c5', '1', NOW(), 'unreg', 'TestLaptop', 'Mozilla 5.0  X11; U; Linux x86_64; en-CA; rv:1.9.2.10  Gecko 20100922 Ubuntu 10.10  maverick  Firefox 3.6.10', NOW(), '1,28,2,3,15,6,119,12,44,47,26,121,42'
);

INSERT INTO `node` (
    `mac`, `pid`, `detect_date`, `status`, `regdate`, `computername`, `user_agent`, `last_dhcp`, `dhcp_fingerprint`
) VALUES (
    '00:1b:b1:8b:82:13', '1', NOW(), 'reg', NOW(), 'TestLaptop', 'Mozilla 5.0  X11; U; Linux x86_64; en-CA; rv:1.9.2.10  Gecko 20100922 Ubuntu 10.10  maverick  Firefox 3.6.10', NOW(), '1,28,2,3,15,6,119,12,44,47,26,121,42'
);

-- for os.t
INSERT INTO `os_class` (`class_id`, `description`) VALUES(14, 'BSD');
INSERT INTO `os_type` (`os_id`, `description`) VALUES(1400, 'OpenBSD');
INSERT INTO `os_mapping` (`os_type`, `os_class`) VALUES(1400, 14);
INSERT INTO `dhcp_fingerprint` (`fingerprint`, `os_id`) VALUES('1,28,3,15,6,12', 1400);

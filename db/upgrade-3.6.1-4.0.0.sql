ALTER TABLE temporary_password 
  ADD `access_level` int unsigned NOT NULL DEFAULT 0 AFTER `access_duration`,
  ADD `category` int NOT NULL AFTER `access_level`,
  ADD `sponsor` tinyint(1) NOT NULL DEFAULT 0 AFTER `category`,
  ADD `unregdate` datetime NOT NULL default "0000-00-00 00:00:00" AFTER `sponsor`
;

UPDATE person SET pid = 'admin' WHERE pid = '1';

INSERT INTO temporary_password (pid, password, valid_from, expiration, access_duration, access_level, category) VALUES ('admin', 'admin', NOW(), '2199-01-01', '9999D', 4294967295, 1);

ALTER TABLE class CHANGE url template varchar(255);
ALTER TABLE temporary_password 
  ADD `access_level` int NOT NULL DEFAULT 0 AFTER `access_duration`,
  ADD `category` int NOT NULL AFTER `access_level`,
  ADD `sponsor` tinyint(1) NOT NULL DEFAULT 0 AFTER `category`,
  ADD `unregdate` datetime NOT NULL default "0000-00-00 00:00:00" AFTER `sponsor`
;

CREATE TABLE temporary_password (
  `pid` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `valid_from` DATETIME DEFAULT NULL,
  `expiration` DATETIME NOT NULL,
  `access_duration` varchar(255) DEFAULT NULL,
  `access_level` int NOT NULL DEFAULT 0,
  `category` int NOT NULL,
  `sponsor` tinyint(1) NOT NULL DEFAULT 0,
  `unregdate` datetime NOT NULL default "0000-00-00 00:00:00",
  PRIMARY KEY (pid)
) ENGINE=InnoDB;

UPDATE person SET pid = 'admin' WHERE pid = '1';

INSERT INTO temporary_password (pid, password, valid_from, expiration, access_duration, access_level, category) VALUES ('admin', 'admin', NOW(), '2199-01-01', '9999D', 2147483647, 1);

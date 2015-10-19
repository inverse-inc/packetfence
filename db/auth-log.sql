CREATE TABLE auth_log (
  `id` int NOT NULL AUTO_INCREMENT,
  `process_name` varchar(255) NOT NULL,
  `mac` varchar(17) NOT NULL,
  `pid` varchar(255) NOT NULL default "default",
  `status` varchar(255) NOT NULL default "incomplete",
  `attempted_at` datetime NOT NULL,
  `completed_at` datetime,
  `source` varchar(255) NOT NULL,
  PRIMARY KEY (id),
  KEY pid (pid)
) ENGINE=InnoDB;

ALTER TABLE `person` ADD firstname varchar(255) after pid;
ALTER TABLE `person` ADD lastname varchar(255) after firstname;
ALTER TABLE `person` ADD email varchar(255) after lastname;
ALTER TABLE `person` ADD telephone varchar(255) after email;
ALTER TABLE `person` ADD company varchar(255) after telephone;
ALTER TABLE `person` ADD address varchar(255) after company;

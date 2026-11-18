--
-- The tables of the test package "acme": dropped when the package is purged
--
\! echo "Dropping the acme tables...";
DROP TABLE IF EXISTS `acme_item_new`;
DROP TABLE IF EXISTS `acme_item_old`;
DROP TABLE IF EXISTS `acme_item`;

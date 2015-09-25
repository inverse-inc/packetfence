DROP TABLE IF EXISTS billing_transaction;
--
-- Table structure for table `billing_transaction`
--

CREATE TABLE billing_transaction (
  id int NOT NULL AUTO_INCREMENT,
  ip varchar(255) NOT NULL,
  mac varchar(17) NOT NULL,
  source_id varchar(255) NOT NULL,
  create_data datetime NOT NULL,
  update_date timestamp NOT NULL ON UPDATE CURRENT_TIMESTAMP,
  status varchar(255) NOT NULL,
  tier_id varchar(255) DEFAULT NULL,
  price varchar(255) DEFAULT NULL,
  person varchar(255) NOT NULL,
  external_transaction_id varchar(255) DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;


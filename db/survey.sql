DROP TABLE IF EXISTS survey;
CREATE TABLE survey (
  id int NOT NULL AUTO_INCREMENT,
  time_taken TIMESTAMP,
  survey_value int,
  email VARCHAR(255),
  age VARCHAR(255),
  gender VARCHAR(255),
  origin VARCHAR(255),
   PRIMARY KEY (id)
) ENGINE=InnoDB;

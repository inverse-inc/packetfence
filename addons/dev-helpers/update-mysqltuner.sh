#!/bin/bash

LATEST=$(curl --silent "https://api.github.com/repos/major/MySQLTuner-perl/releases/latest" | jq -r .tag_name)
MYSQLTUNER_DIR=/usr/local/pf/bin/mysqltuner/
wget http://mysqltuner.pl/ -O "$MYSQLTUNER_DIR/mysqltuner.pl"

for f in basic_passwords.txt vulnerabilities.csv mysqltuner.pl LICENSE;do
    wget "https://raw.githubusercontent.com/major/MySQLTuner-perl/$LATEST/$f" -O "$MYSQLTUNER_DIR/$f"
done

#!/bin/bash
MYSQLTUNER_DIR=/usr/local/pf/bin/mysqltuner/
wget http://mysqltuner.pl/ -O "$MYSQLTUNER_DIR/mysqltuner.pl"

for f in basic_passwords.txt vulnerabilities.csv LICENSE;do
    wget "https://raw.githubusercontent.com/major/MySQLTuner-perl/master/$f" -O "$MYSQLTUNER_DIR/$f"
done

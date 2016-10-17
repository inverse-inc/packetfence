#!/bin/bash
#fname:check-innodb_file_per_table.sh

DB_USER=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{user}');
DB_PWD=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{pass}');
DB_NAME=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{db}');
DB_HOST=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{host}');

# check if MySQL or MariaDB is installed
if mysql -V | grep -q "MariaDB"; then
    SQL_ENGINE='mariadb'
else
    SQL_ENGINE="mysqld"
fi

if [ -f /var/run/$SQL_ENGINE/$SQL_ENGINE.pid ]; then
    INNODB=`mysql -h $DB_HOST -u $DB_USER -p$DB_PWD -D $DB_NAME -e "select 1 from information_schema.GLOBAL_VARIABLES where VARIABLE_NAME=\"INNODB_FILE_PER_TABLE\" and VARIABLE_VALUE=\"ON\";"`
    if [ -z "$INNODB" ]; then
        exit 1
    fi
fi
exit 0

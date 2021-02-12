#!/bin/bash

# See #3652

# Stop at first error
set -e

# Get correct pf user from pf.conf
PF_USER=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{user}')
PF_DB=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{db}')

# Apply new privileges on DB for PF_USER with root account
echo "Hit MariaDB root password"
 mysql -u root -p \
-e "GRANT CREATE TEMPORARY TABLES ON ${PF_DB}.* TO $PF_USER@'%';" \
-e "GRANT CREATE TEMPORARY TABLES ON ${PF_DB}.* TO $PF_USER@'localhost';" \
-e "FLUSH PRIVILEGES;"

echo "New privileges applied"

exit 0

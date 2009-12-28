#!/bin/bash
#
# Database maintenance and backup
# - Move entries older than two days from locationlog to locationlog_history
# - Optimize tables on sunday
# - compressed mysqldump to $BACKUP_DIRECTORY, rotate and clean
#
# Copyright (C) 2009 Inverse inc.
# Authors: Regis Balzard <rbalzard@inverse.ca>
#          Olivier Bilodeau <obilodeau@inverse.ca>
#          Dominik Gehl <dgehl@inverse.ca>
#
# Licensed under the GPL
#
# Installation: make sure you have locationlog_history (based on locationlog) and edit DB_PWD to fit your password.

NB_DAYS_TO_KEEP=70
DB_USER='pf';
# make sure access to this file is properly secured! (chmod a=,u=rwx)
DB_PWD='';
DB_NAME='pf';
BACKUP_DIRECTORY='/root/backup'
BACKUP_DB_FILENAME='packetfence-db-dump'

# is MySQL running? meaning we are the live packetfence
if [ -f /var/run/mysqld/mysqld.pid ]; then

   # locationlog cleanup: all the closed entries older than 15 days are moved to locationlog_history
   # in order to keep locationlog small
   mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "INSERT INTO locationlog_history SELECT * FROM locationlog WHERE ((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_SUB(CURDATE(), INTERVAL 15 DAY));"
   mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "DELETE FROM locationlog WHERE ((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_SUB(CURDATE(), INTERVAL 15 DAY));"

   # lets optimize on Sunday
   DOW=`date +%w`
   if [ $DOW -eq 0 ]
   then 
        TABLENAMES=`mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "SHOW TABLES\G;"|grep 'Tables_in_'|sed -n 's/.*Tables_in_.*: \([_0-9A-Za-z]*\).*/\1/p'`

        # loop through the tables and optimize them
        for TABLENAME in $TABLENAMES
        do  
            mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "OPTIMIZE TABLE $TABLENAME;"
        done
    fi

    # dump the database, gzip and remove old files
    current_filename=$BACKUP_DIRECTORY/$BACKUP_DB_FILENAME-`date +%F_%Hh%M`.sql
    mysqldump --opt -h 127.0.0.1 -u $DB_USER -p$DB_PWD $DB_NAME > $current_filename && \
    gzip $current_filename && \
    find $BACKUP_DIRECTORY -name "$BACKUP_DB_FILENAME-*.sql.gz" -mtime +$NB_DAYS_TO_KEEP -print0 | xargs -0r rm -f
fi


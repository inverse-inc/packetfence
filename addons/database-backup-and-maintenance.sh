#!/bin/bash
#
# Database maintenance and backup
#
# - Move entries older than a month from locationlog to locationlog_history
# - Optimize tables on sunday
# - compressed mysqldump to $BACKUP_DIRECTORY, rotate and clean
# - archive locationlog_history entries older than a year the first day of each month
#
# Copyright (C) 2005-2013 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
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
ARCHIVE_DIRECTORY=$BACKUP_DIRECTORY
ARCHIVE_DB_FILENAME='packetfence-archive'

# is MySQL running? meaning we are the live packetfence
if [ -f /var/run/mysqld/mysqld.pid ]; then

   # locationlog cleanup: all the closed entries older than a month are moved to locationlog_history
   # in order to keep locationlog small
   mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "INSERT INTO locationlog_history SELECT * FROM locationlog WHERE ((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_SUB(CURDATE(), INTERVAL 1 MONTH));"
   mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "DELETE FROM locationlog WHERE ((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_SUB(CURDATE(), INTERVAL 1 MONTH));"

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

    # let's archive on the first day of the month
    if [ `/bin/date +%d` -eq '01' ]; then
        # flushing old locationlog_history records into sql files for archival then removing from database
        current_filename=$ARCHIVE_DIRECTORY/$ARCHIVE_DB_FILENAME-`date +%Y%m%d`.sql
        mysqldump -u $DB_USER -p$DB_PWD $DB_NAME --tables locationlog_history --skip-opt --no-create-info --quick --where='((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 YEAR),"%Y-%m-01"))' > $current_filename && \
        gzip $current_filename && \
        mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e 'LOCK TABLES locationlog_history WRITE; DELETE FROM locationlog_history WHERE ((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 YEAR),"%Y-%m-01")); UNLOCK TABLES;'

        #Clean Accounting for previous year... if needed
        mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e 'LOCK TABLES radacct WRITE; DELETE FROM radacct WHERE YEAR(acctstarttime) < YEAR(CURRENT_DATE()); UNLOCK TABLES;'
        mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e 'LOCK TABLES radacct_log WRITE; DELETE FROM radacct_log WHERE YEAR(timestamp) < YEAR(CURRENT_DATE()); UNLOCK TABLES;'
    fi
fi

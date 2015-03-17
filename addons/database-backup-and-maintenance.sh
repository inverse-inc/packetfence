#!/bin/bash
#
# Database maintenance and backup
#
# - Move entries older than a month from locationlog to locationlog_archive
# - Optimize tables on sunday
# - compressed mysqldump to $BACKUP_DIRECTORY, rotate and clean
# - archive locationlog_archive entries older than a year the first day of each month
#
# Copyright (C) 2005-2015 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
#
# Licensed under the GPL
#
# Installation: make sure you have locationlog_archive (based on locationlog) and edit DB_PWD to fit your password.

NB_DAYS_TO_KEEP_DB=30
NB_DAYS_TO_KEEP_FILES=30
DB_USER='pf';
DB_PWD='';
DB_NAME='pf';
PF_DIRECTORY='/usr/local/pf/'
PF_DIRECTORY_EXCLUDED='/usr/local/pf/logs'
BACKUP_DIRECTORY='/root/backup/'
BACKUP_DB_FILENAME='packetfence-db-dump'
BACKUP_PF_FILENAME='packetfence-files-dump'
ARCHIVE_DIRECTORY=$BACKUP_DIRECTORY
ARCHIVE_DB_FILENAME='packetfence-archive'

# For replication
ACTIVATE_REPLICATION=0
REPLICATION_USER=''
NODE1_HOSTNAME=''
NODE2_HOSTNAME=''
NODE1_IP=''
NODE2_IP=''

# Create the backup directory
if [ ! -d "$BACKUP_DIRECTORY" ]; then
    mkdir -p $BACKUP_DIRECTORY
    echo -e "$BACKUP_DIRECTORY , created. \n"
else
    echo -e "$BACKUP_DIRECTORY , folder already created. \n"
fi

# Backup complete PacketFence installation except logs
current_tgz=$BACKUP_DIRECTORY/$BACKUP_PF_FILENAME-`date +%F_%Hh%M`.tgz
if [ ! -f $BACKUP_DIRECTORY$BACKUP_PF_FILENAME ]; then
    tar -czf $current_tgz $PF_DIRECTORY --exclude=$PF_DIRECTORY_EXCLUDED
    echo -e $BACKUP_PF_FILENAME "have been created in  $BACKUP_DIRECTORY \n"
    find $BACKUP_DIRECTORY -name "packetfence-files-dump-*.tgz" -mtime +$NB_DAYS_TO_KEEP_FILES -print0 | xargs -0r rm -f
    echo -e "$BACKUP_PF_FILENAME older than $NB_DAYS_TO_KEEP_FILES days have been removed. \n"
else
    echo -e $BACKUP_DIRECTORY$BACKUP_PF_FILENAME ", file already created. \n"
fi


# is MySQL running? meaning we are the live packetfence
if [ -f /var/run/mysqld/mysqld.pid ]; then

    # locationlog cleanup: all the closed entries older than a month are moved to locationlog_archive
    # in order to keep locationlog small
    mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "INSERT INTO locationlog_archive SELECT * FROM locationlog WHERE ((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_SUB(CURDATE(), INTERVAL 1 MONTH));"
    mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "DELETE FROM locationlog WHERE ((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_SUB(CURDATE(), INTERVAL 1 MONTH));"

    # iplog cleanup: all the closed entries older than a month are moved to iplog_archive
    # in order to keep iplog small
    mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "INSERT INTO iplog_archive SELECT * FROM iplog WHERE (end_time <> '0000-00-00 00:00:00' AND end_time < DATE_SUB(CURDATE(), INTERVAL 1 MONTH));"
    mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "DELETE FROM iplog WHERE (end_time <> '0000-00-00 00:00:00' AND end_time < DATE_SUB(CURDATE(), INTERVAL 1 MONTH));"

    ## accounting cleanup. We keep only the last 2 months of acounting data to prevent those tables from getting to large.
    #mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "DELETE FROM radacct WHERE acctstarttime <  ( NOW() - INTERVAL 2 MONTH ) ;"
    #mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e "DELETE FROM radacct_log WHERE timestamp <  ( NOW() - INTERVAL 2 MONTH ) ;"

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
        find $BACKUP_DIRECTORY -name "$BACKUP_DB_FILENAME-*.sql.gz" -mtime +$NB_DAYS_TO_KEEP_DB -print0 | xargs -0r rm -f

    # let's archive on the first day of the month
    if [ `/bin/date +%d` -eq '01' ]; then
        # flushing old locationlog_archive records into sql files for archival then removing from database
        current_filename=$ARCHIVE_DIRECTORY/$ARCHIVE_DB_FILENAME-`date +%Y%m%d`.sql
        mysqldump -u $DB_USER -p$DB_PWD $DB_NAME --tables locationlog_archive --skip-opt --no-create-info --quick --where='((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 YEAR),"%Y-%m-01"))' > $current_filename && \
            gzip $current_filename && \
            mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e 'LOCK TABLES locationlog_archive WRITE; DELETE FROM locationlog_archive WHERE ((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 YEAR),"%Y-%m-01")); UNLOCK TABLES;'

        #Clean Accounting for previous year... if needed
        mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e 'DELETE FROM radacct WHERE YEAR(acctstarttime) < YEAR(CURRENT_DATE());'
        mysql -u $DB_USER -p$DB_PWD -D $DB_NAME -e 'DELETE FROM radacct_log WHERE YEAR(timestamp) < YEAR(CURRENT_DATE());'
    fi

    # Replicate the db backups between both servers
    if [ $ACTIVATE_REPLICATION == 1 ];then
      if [ $HOSTNAME == $NODE1_HOSTNAME ];then
        replicate_to=$NODE2_IP
      elif [ $HOSTNAME == $NODE2_HOSTNAME ];then
        replicate_to=$NODE1_IP 
      else
        echo "Cannot recognize hostname. This script is made for $NODE1_HOSTNAME and $NODE2_HOSTNAME. Exiting"
        exit
      fi;
      eval "rsync -auv -e ssh --delete --include '$BACKUP_DB_FILENAME*' --exclude='*' $BACKUP_DIRECTORY $REPLICATION_USER@$replicate_to:$BACKUP_DIRECTORY"
    fi

fi

#!/bin/bash
#
# Database maintenance and backup
#
# - Move entries older than a month from locationlog to locationlog_archive
# - Optimize tables on sunday
# - compressed mysqldump to $BACKUP_DIRECTORY, rotate and clean
# - archive locationlog_archive entries older than a year the first day of each month
#
# Copyright (C) 2005-2016 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
#
# Licensed under the GPL
#
# Installation: make sure you have locationlog_archive (based on locationlog) and edit DB_PWD to fit your password.

NB_DAYS_TO_KEEP_DB=30
NB_DAYS_TO_KEEP_FILES=30
DB_USER=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{user}');
DB_PWD=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{pass}');
DB_NAME=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{db}');
DB_HOST=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{host}');
PF_DIRECTORY='/usr/local/pf/'
BACKUP_DIRECTORY='/root/backup/'
BACKUP_DB_FILENAME='packetfence-db-dump'
BACKUP_PF_FILENAME='packetfence-files-dump'
ARCHIVE_DIRECTORY=$BACKUP_DIRECTORY
ARCHIVE_DB_FILENAME='packetfence-archive'
PERCONA_XTRABACKUP_INSTALLED=0

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
    tar -czf $current_tgz $PF_DIRECTORY --exclude=$PF_DIRECTORY'logs/*' --exclude=$PF_DIRECTORY'var/*'
    echo -e $BACKUP_PF_FILENAME "have been created in  $BACKUP_DIRECTORY \n"
    find $BACKUP_DIRECTORY -name "packetfence-files-dump-*.tgz" -mtime +$NB_DAYS_TO_KEEP_FILES -print0 | xargs -0r rm -f
    echo -e "$BACKUP_PF_FILENAME older than $NB_DAYS_TO_KEEP_FILES days have been removed. \n"
else
    echo -e $BACKUP_DIRECTORY$BACKUP_PF_FILENAME ", file already created. \n"
fi

# check if MySQL or MariaDB is installed
if mysql -V | grep -q "MariaDB"; then
    SQL_ENGINE='mariadb'
else
    SQL_ENGINE="mysqld"
fi

# is MySQL running? meaning we are the live packetfence
if [ -f /var/run/$SQL_ENGINE/$SQL_ENGINE.pid ]; then

    /usr/local/pf/addons/database-cleaner.pl --table=radacct --date-field=acctstarttime --older-than="1 WEEK" --additionnal-condition="acctstoptime IS NOT NULL"
    
    /usr/local/pf/addons/database-cleaner.pl --table=radacct_log --date-field=timestamp --older-than="1 WEEK"
    
    /usr/local/pf/addons/database-cleaner.pl --table=iplog_archive --date-field=timestamp --older-than="1 MONTH"
    
    /usr/local/pf/addons/database-cleaner.pl --table=locationlog_archive --date-field=timestamp --older-than="1 MONTH"
    
    # lets optimize on Sunday
    DOW=`date +%w`
    if [ $DOW -eq 0 ]
    then
        TABLENAMES=`mysql -h $DB_HOST -u $DB_USER -p$DB_PWD -D $DB_NAME -e "SHOW TABLES\G;"|grep 'Tables_in_'|sed -n 's/.*Tables_in_.*: \([_0-9A-Za-z]*\).*/\1/p' | grep -v '_archive$'` 

        # loop through the tables and optimize them
        for TABLENAME in $TABLENAMES
        do
            mysql -h $DB_HOST -u $DB_USER -p$DB_PWD -D $DB_NAME -e "OPTIMIZE TABLE $TABLENAME;"
        done
    fi

    # Check to see if Percona XtraBackup is installed
    if hash innobackupex 2>/dev/null; then
        echo -e "Percona XtraBackup is available. Will proceed using it for DB backup to avoid locking tables and easier recovery process. \n"
        PERCONA_XTRABACKUP_INSTALLED=1
    fi

    if [ $PERCONA_XTRABACKUP_INSTALLED -eq 1 ]; then
        echo "----- Backup started on `date +%F_%Hh%M` -----" >> /usr/local/pf/logs/innobackup.log
        innobackupex --password=$DB_PWD  --no-timestamp --stream=tar ./ 2>> /usr/local/pf/logs/innobackup.log | gzip - > $BACKUP_DIRECTORY/$BACKUP_DB_FILENAME-innobackup-`date +%F_%Hh%M`.tar.gz
        tail -1 /usr/local/pf/logs/innobackup.log | grep 'innobackupex: completed OK!' && \
          find $BACKUP_DIRECTORY -name "$BACKUP_DB_FILENAME-innobackup-*.tar.gz" -mtime +$NB_DAYS_TO_KEEP_DB -print0 | xargs -0r rm -f
        INNOBACK_RC=$?
    else
        current_filename=$BACKUP_DIRECTORY/$BACKUP_DB_FILENAME-`date +%F_%Hh%M`.sql
        mysqldump --opt -h $DB_HOST -u $DB_USER -p$DB_PWD $DB_NAME > $current_filename && \
          gzip $current_filename && \
          find $BACKUP_DIRECTORY -name "$BACKUP_DB_FILENAME-*.sql.gz" -mtime +$NB_DAYS_TO_KEEP_DB -print0 | xargs -0r rm -f
    fi

    # let's archive on the first day of the month
    if [ `/bin/date +%d` -eq '01' ]; then
        # flushing old locationlog_archive records into sql files for archival then removing from database
        current_filename=$ARCHIVE_DIRECTORY/$ARCHIVE_DB_FILENAME-`date +%Y%m%d`.sql
        mysqldump -h $DB_HOST -u $DB_USER -p$DB_PWD $DB_NAME --tables locationlog_archive --skip-opt --no-create-info --quick --where='((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 YEAR),"%Y-%m-01"))' > $current_filename && \
            gzip $current_filename && \
            mysql -h $DB_HOST -u $DB_USER -p$DB_PWD -D $DB_NAME -e 'LOCK TABLES locationlog_archive WRITE; DELETE FROM locationlog_archive WHERE ((end_time IS NOT NULL OR end_time <> 0) AND end_time < DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL 1 YEAR),"%Y-%m-01")); UNLOCK TABLES;'

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

    if [ $PERCONA_XTRABACKUP_INSTALLED -eq 1 ]; then
      exit $INNOBACK_RC
    fi

fi

#!/bin/bash
#
# Database maintenance and backup
#
# - Move entries older than a month from locationlog to locationlog_archive
# - Optimize tables on sunday
# - compressed mysqldump to $BACKUP_DIRECTORY, rotate and clean
# - archive locationlog_archive entries older than a year the first day of each month
#
# Copyright (C) 2005-2019 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
#
# Licensed under the GPL
#
# Installation: make sure you have locationlog_archive (based on locationlog) and edit DB_PWD to fit your password.

NB_DAYS_TO_KEEP_DB=7
NB_DAYS_TO_KEEP_FILES=7
DB_USER=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{user}');
DB_PWD=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{pass}');
DB_NAME=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{db}');
DB_HOST=$(perl -I/usr/local/pf/lib -Mpf::db -e 'print $pf::db::DB_Config->{host}');
REP_USER=$(perl -I/usr/local/pf/lib -Mpf::config -e 'print $pf::config::Config{active_active}{galera_replication_username}');
REP_PWD=$(perl -I/usr/local/pf/lib -Mpf::config -e 'print $pf::config::Config{active_active}{galera_replication_password}');
PF_DIRECTORY='/usr/local/pf/'
BACKUP_DIRECTORY='/root/backup/'
BACKUP_DB_FILENAME='packetfence-db-dump'
BACKUP_PF_FILENAME='packetfence-files-dump'
ARCHIVE_DIRECTORY=$BACKUP_DIRECTORY
ARCHIVE_DB_FILENAME='packetfence-archive'
PERCONA_XTRABACKUP_INSTALLED=0
BACKUPRC=1

# For replication
ACTIVATE_REPLICATION=0
REPLICATION_USER=''
NODE1_HOSTNAME=''
NODE2_HOSTNAME=''
NODE1_IP=''
NODE2_IP=''

# Only for MariaDB remote clusters
MARIADB_REMOTE_CLUSTER=0
# should be equal to return of hostname command
MARIADB_BACKUP_SERVER_HOSTNAME=''

# Create the backup directory
if [ ! -d "$BACKUP_DIRECTORY" ]; then
    mkdir -p $BACKUP_DIRECTORY
    echo -e "$BACKUP_DIRECTORY , created. \n"
else
    echo -e "$BACKUP_DIRECTORY , folder already created. \n"
fi

PF_USED_SPACE=`du -s $PF_DIRECTORY --exclude=logs --exclude=var | awk '{ print $1 }'`
BACKUPS_AVAILABLE_SPACE=`df --output=avail $BACKUP_DIRECTORY | awk 'NR == 2 { print $1  }'`

if ((  $BACKUPS_AVAILABLE_SPACE > (( $PF_USED_SPACE / 2 )) )); then 
    # Backup complete PacketFence installation except logs
    current_tgz=$BACKUP_DIRECTORY/$BACKUP_PF_FILENAME-`date +%F_%Hh%M`.tgz
    if [ ! -f $BACKUP_DIRECTORY$BACKUP_PF_FILENAME ]; then
        tar -czf $current_tgz $PF_DIRECTORY --exclude=$PF_DIRECTORY'logs/*' --exclude=$PF_DIRECTORY'var/*' --exclude=$PF_DIRECTORY'.git/*'
        BACKUPRC=$?
        if (( $BACKUPRC > 0 )); then
            echo "ERROR: PacketFence files backup was not successful" >&2
            echo "ERROR: PacketFence files backup was not successful" > /usr/local/pf/var/backup_files.status
        else
            echo -e $BACKUP_PF_FILENAME "have been created in  $BACKUP_DIRECTORY \n"
            echo "OK" > /usr/local/pf/var/backup_files.status
            find $BACKUP_DIRECTORY -name "packetfence-files-dump-*.tgz" -mtime +$NB_DAYS_TO_KEEP_FILES -print0 | xargs -0r rm -f
            echo -e "$BACKUP_PF_FILENAME older than $NB_DAYS_TO_KEEP_FILES days have been removed. \n"
        fi
    else
        echo -e $BACKUP_DIRECTORY$BACKUP_PF_FILENAME ", file already created. \n"
    fi
else 
    echo "ERROR: There is not enough space in $BACKUP_DIRECTORY to safely backup files. Skipping the backup." >&2
    echo "ERROR: There is not enough space in $BACKUP_DIRECTORY to safely backup files. Skipping the backup." > /usr/local/pf/var/backup_files.status
fi 

should_backup(){
    # Default choices
    SHOULD_BACKUP=1
    MARIADB_LOCAL_CLUSTER=0
    # If we are using Galera cluster and that we're not the first server in the galera incomming addresses, we will not backup
    if [ -f /var/lib/mysql/grastate.dat ]; then
        MARIADB_LOCAL_CLUSTER=1
        FIRST_SERVER=`mysql -u$REP_USER -p$REP_PWD -e 'show status like "wsrep_incoming_addresses";' | tail -1 | awk '{ print $2 }' | awk -F "," '{ print $1 }' | awk -F ":" '{ print $1 }'`
        if ! ip a | grep $FIRST_SERVER > /dev/null; then
            SHOULD_BACKUP=0
            echo "Not the first server of the cluster: database backup canceled."
            exit $BACKUPRC
        else
            echo -e "First server of the cluster : database backup will start.\n"
        fi
    elif [ $MARIADB_REMOTE_CLUSTER -eq 1 ]; then
        PF_SERVER_HOSTNAME=$(hostname)
        if [ "$MARIADB_BACKUP_SERVER_HOSTNAME" == "$PF_SERVER_HOSTNAME" ]; then
            echo "Backup server detected: database backup will start"
        else
            SHOULD_BACKUP=0
            echo "Server not configured to do DB backups: database backup canceled."
            exit $BACKUPRC
        fi
    else
        echo "Database backup will start"
    fi
}

backup_db(){
    /usr/local/pf/addons/database-cleaner.pl --table=locationlog_archive --date-field=end_time --older-than="1 MONTH"

    # Check to see if Percona XtraBackup is installed
    if hash innobackupex 2>/dev/null; then
        echo -e "Percona XtraBackup is available. Will proceed using it for DB backup to avoid locking tables and easier recovery process. \n"
        PERCONA_XTRABACKUP_INSTALLED=1
    fi

    BACKUPS_AVAILABLE_SPACE=`df --output=avail $BACKUP_DIRECTORY | awk 'NR == 2 { print $1  }'`
    MYSQL_USED_SPACE=`du -s /var/lib/mysql | awk '{ print $1 }'`
    if (( $BACKUPS_AVAILABLE_SPACE > (( $MYSQL_USED_SPACE /2 )) )); then 
        if [ $MARIADB_LOCAL_CLUSTER -eq 1 ]; then
             echo "Temporarily stopping Galera cluster sync for DB backup"
             mysql -u$REP_USER -p$REP_PWD -e 'set global wsrep_desync=ON;'
        elif [ $MARIADB_REMOTE_CLUSTER -eq 1 ]; then
             echo "Temporarily stopping remote Galera cluster sync for DB backup"
             # We couldn't use the local socket
             mysql -u$REP_USER -p$REP_PWD -h $DB_HOST -e 'set global wsrep_desync=ON;'
        else
            echo "Not a Galera cluster, nothing to stop"
        fi

        if [ $PERCONA_XTRABACKUP_INSTALLED -eq 1 ]; then
            find $BACKUP_DIRECTORY -name "$BACKUP_DB_FILENAME-innobackup-*.xbstream.gz" -mtime +$NB_DAYS_TO_KEEP_DB -delete
            echo "----- Backup started on `date +%F_%Hh%M` -----" >> /usr/local/pf/logs/innobackup.log
            INNO_TMP="/tmp/pf-innobackups"
            mkdir -p $INNO_TMP
            if [ $MARIADB_LOCAL_CLUSTER -eq 1 ]; then
                innobackupex --defaults-file=/usr/local/pf/var/conf/mariadb.conf --user=$REP_USER --password=$REP_PWD  --no-timestamp --stream=xbstream --tmpdir=$INNO_TMP $INNO_TMP 2>> /usr/local/pf/logs/innobackup.log | gzip - > $BACKUP_DIRECTORY/$BACKUP_DB_FILENAME-innobackup-`date +%F_%Hh%M`.xbstream.gz
            elif [ "$MARIADB_REMOTE_CLUSTER" -eq 1 ]; then
                innobackupex --defaults-file=/usr/local/pf/var/conf/mariadb.conf --user=$REP_USER --password=$REP_PWD --host=$DB_HOST --no-timestamp --stream=xbstream --tmpdir=$INNO_TMP $INNO_TMP 2>> /usr/local/pf/logs/innobackup.log | gzip - > $BACKUP_DIRECTORY/$BACKUP_DB_FILENAME-innobackup-`date +%F_%Hh%M`.xbstream.gz
            else
                innobackupex --defaults-file=/usr/local/pf/var/conf/mariadb.conf --user=$DB_USER --password=$DB_PWD --no-timestamp --stream=xbstream --tmpdir=$INNO_TMP $INNO_TMP 2>> /usr/local/pf/logs/innobackup.log | gzip - > $BACKUP_DIRECTORY/$BACKUP_DB_FILENAME-innobackup-`date +%F_%Hh%M`.xbstream.gz
            fi
            tail -1 /usr/local/pf/logs/innobackup.log | grep 'completed OK!'
            BACKUPRC=$?
            if (( $BACKUPRC > 0 )); then 
                echo "innobackupex was not successful." >&2
                echo "innobackupex was not successful." > /usr/local/pf/var/backup_db.status
            else
                touch /usr/local/pf/var/run/last_backup
                echo "OK" > /usr/local/pf/var/backup_db.status
            fi
        else
            find $BACKUP_DIRECTORY -name "$BACKUP_DB_FILENAME-*.sql.gz" -mtime +$NB_DAYS_TO_KEEP_DB -delete
            current_filename=$BACKUP_DIRECTORY/$BACKUP_DB_FILENAME-`date +%F_%Hh%M`.sql.gz
            mysqldump --opt --routines -h $DB_HOST -u $DB_USER -p$DB_PWD $DB_NAME --ignore-table=$DB_NAME.locationlog_archive --ignore-table=$DB_NAME.iplog_archive | gzip > ${current_filename}
            BACKUPRC=$?
            if (( $BACKUPRC > 0 )); then 
                echo "mysqldump returned  error code: $?" >&2
                echo "mysqldump returned  error code: $?" > /usr/local/pf/var/backup_db.status
            else 
                touch /usr/local/pf/var/run/last_backup
                echo "OK" > /usr/local/pf/var/backup_db.status
            fi
        fi

        if [ $MARIADB_LOCAL_CLUSTER -eq 1 ]; then
             echo "Reenabling Galera cluster sync"
             mysql -u$REP_USER -p$REP_PWD -e 'set global wsrep_desync=OFF;'
        elif [ $MARIADB_REMOTE_CLUSTER -eq 1 ]; then
             echo "Reenabling Galera cluster sync"
             mysql -u$REP_USER -p$REP_PWD -h $DB_HOST -e 'set global wsrep_desync=OFF;'
        else
            echo "Not a Galera cluster, nothing to reenable"
        fi

    else 
        echo "There is not enough space in $BACKUP_DIRECTORY to safely backup the database. Skipping backup." >&2
        echo "There is not enough space in $BACKUP_DIRECTORY to safely backup the database. Skipping backup." > /usr/local/pf/var/backup_db.status
    fi
}

should_backup
# Is the database running on the current server and should we be running a backup ?
if [ $SHOULD_BACKUP -eq 1 ] && { [ -f /var/run/mysqld/mysqld.pid ] || [ -f /var/run/mariadb/mariadb.pid ] || [ -f /var/lib/mysql/`hostname`.pid ]; }; then
    backup_db
elif [ $SHOULD_BACKUP -eq 1 ] && [ $MARIADB_REMOTE_CLUSTER -eq 1 ]; then
    backup_db
else
    echo "Nothing to do"
fi

# Replicate the db backups between both servers
if [ $ACTIVATE_REPLICATION == 1 ]; then
  if [ $HOSTNAME == $NODE1_HOSTNAME ]; then
    replicate_to=$NODE2_IP
  elif [ $HOSTNAME == $NODE2_HOSTNAME ]; then
    replicate_to=$NODE1_IP 
  else
    echo "Cannot recognize hostname. This script is made for $NODE1_HOSTNAME and $NODE2_HOSTNAME. Exiting" >&2
    exit 1
    fi;
  eval "rsync -auv -e ssh --delete --include '$BACKUP_DB_FILENAME*' --exclude='*' $BACKUP_DIRECTORY $REPLICATION_USER@$replicate_to:$BACKUP_DIRECTORY"
fi

exit $BACKUPRC

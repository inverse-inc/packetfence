#!/bin/bash
#
# Backup of $PF_DIRECTORY and $DB_NAME that can be used in export/import procedure
#
# - compressed $PF_DIRECTORY to $BACKUP_DIRECTORY
# - compressed mysqldump to $BACKUP_DIRECTORY
# - prepare files for backup and exportation, rotate and clean
#
# Copyright (C) 2005-2024 Inverse inc.
#
# Author: Inverse inc. <info@inverse.ca>
#
# Licensed under the GPL
#

source /usr/local/pf/addons/functions/helpers.functions

BACKUP_DIRECTORY=${BACKUP_DIRECTORY:-/root/backup/}
BACKUP_DB_FILENAME='packetfence-db-dump'
BACKUP_CONF_FILENAME='packetfence-conf-dump'
BACKUP_OLD_CONF_FILENAME='packetfence-files-dump'
BACKUP_PF_FILENAME='packetfence-exportable-backup'
NB_DAYS_TO_KEEP_BACKUP=${NB_DAYS_TO_KEEP_BACKUP:-7}
BACKUPRC=1

#############################################################################
### Replicate
#############################################################################
replicate_backup(){
    REPLICATION_USER=${REPLICATION_USER:-root}
    NODE1_HOSTNAME=${NODE1_HOSTNAME:-node1_hostname}
    NODE2_HOSTNAME=${NODE2_HOSTNAME:-node2_hostname}
    NODE1_IP=${NODE1_IP:-node1_ip_address}
    NODE2_IP=${NODE2_IP:-node2_ip_address}

    if [ $HOSTNAME == $NODE1_HOSTNAME ]; then
        replicate_to=$NODE2_IP
    elif [ $HOSTNAME == $NODE2_HOSTNAME ]; then
        replicate_to=$NODE1_IP
    else
        echo "Cannot recognize hostname. This script is made for $NODE1_HOSTNAME and $NODE2_HOSTNAME. Exiting" >&2
        exit 1
    fi;
    eval "rsync -auv -e ssh --delete --include '$BACKUP_DB_FILENAME*' --exclude='*' $BACKUP_DIRECTORY $REPLICATION_USER@$replicate_to:$BACKUP_DIRECTORY"
    exit $BACKUPRC
}

#############################################################################
### Help
#############################################################################
help(){
    cat <<-EOF
$0 Backup a PacketFence instance

Usage: $0 -f /path/to/backup_file.tgz [OPTION]...

Options:
 -f,--file                  Backup in a specific PacketFence (by default it will be under /root/backup/)
 -h,--help                  Display this help
 --db                       Backup only database from PacketFence database
 --conf                     Backup only configuration from PacketFence configuration
 --replication           Replicate the backup accross two nodes.

EOF
}

#############################################################################
### Clean old exportable backup archive
#############################################################################
clean_old_backup_archive(){
    find $BACKUP_DIRECTORY -name "$BACKUP_PF_FILENAME-*.tgz" -mtime +$NB_DAYS_TO_KEEP_BACKUP -delete
}

#############################################################################
### Disk space 
#############################################################################
check_disk_space(){
    BACKUPS_AVAILABLE_SPACE=`df --output=avail $BACKUP_DIRECTORY | awk 'NR == 2 { print $1  }'`
    MYSQL_USED_SPACE=`du -s /var/lib/mysql | awk '{ print $1 }'`
    CONF_USED_SPACE=`du -s $PF_DIRECTORY --exclude=logs --exclude=var | awk '{ print $1 }'`
    if (( $BACKUPS_AVAILABLE_SPACE < (( (( $MYSQL_USED_SPACE + $CONF_USED_SPACE )) /2 )) )); then
        echo "There is not enough space in $BACKUP_DIRECTORY to safely backup exportable. Skipping backup." >&2
        echo "There is not enough space in $BACKUP_DIRECTORY to safely backup exportable. Skipping backup." > /usr/local/pf/var/backup_pf.status
        exit $BACKUPRC
    fi
}


create_backup_directory(){
    # Create the backup directory
    if [ ! -d "$BACKUP_DIRECTORY" ]; then
        mkdir -p $BACKUP_DIRECTORY
        echo -e "$BACKUP_DIRECTORY , created. \n"
    else
        echo -e "$BACKUP_DIRECTORY , folder already created. \n"
    fi
}


#############################################################################
### Cleaning
#############################################################################
clean_backup(){
    echo "Start backup cleaning"
    find $BACKUP_DIRECTORY -name "$BACKUP_PF_FILENAME-*.tgz" -mtime +$NB_DAYS_TO_KEEP_BACKUP -delete
    echo "Old backup cleaned"
    find $BACKUP_DIRECTORY -name "$BACKUP_DB_FILENAME-*.sql.gz" -delete
    echo "Temp db backup cleaned"
    find $BACKUP_DIRECTORY -name "$BACKUP_CONF_FILENAME-*.tgz"  -delete
    echo "Temp config backup cleaned"
    find $BACKUP_DIRECTORY -name "$BACKUP_OLD_CONF_FILENAME-*.tgz" -mtime +$NB_DAYS_TO_KEEP_BACKUP -delete
    echo "Old config backup cleaned"
    echo "Backup cleaning is done"
}

#############################################################################
### Handle args
#############################################################################
do_full_backup=1
do_db_backup=0
do_config_backup=0
do_replication=0
BACKUP_FILE=${BACKUP_FILE:-}

# Parse option
TEMP=$(getopt -o f:h --long file:,help,db,conf,replication \
     -n "$0" -- "$@") || (echo "getopt failed." && exit 1)

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -f|--file)
            # first shift is mandatory to get file path
            shift
            BACKUP_FILE="$1" ; shift
            ;;
        -h|--help)
            help ; exit 0 ; shift
            ;;
        --db)
            do_db_backup=1 ; do_full_backup=0 ; shift
            ;;
        --conf)
            do_config_backup=1 ; do_full_backup=0 ; shift
            ;;
        --replication)
            do_replication=1 ; shift
            ;;
        --)
            shift ; break
            ;;
        *)
            echo "Wrong usage !" ; help ; exit 1
            ;;
    esac
done

if [ -z "$BACKUP_FILE" ]; then
    echo "Default directory $BACKUP_DIRECTORY will be used."
    BACKUP_FILE=$BACKUP_DIRECTORY/$BACKUP_PF_FILENAME-`date +%F_%Hh%M`.tgz
    echo "The backup file will be $BACKUP_FILE"
fi

#############################################################################
### Main
#############################################################################
create_backup_directory
if check_disk_space; then
    /bin/bash /usr/local/pf/addons/backup-and-maintenance.sh
    if [ ! -f $BACKUP_FILE ]; then
        /bin/bash /usr/local/pf/addons/full-import/export.sh $BACKUP_FILE
    else
        echo -e $BACKUP_FILE ", file already created. \n"
    fi
    clean_backup
    if [ $do_replication == 1 ]; then
        replicate_backup
    fi
    echo "Exportable backup is done"
fi

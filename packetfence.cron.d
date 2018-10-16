# /etc/cron.d/packetfence: crontab entries for the packetfence package

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Database backup and maintenance script
30 00 * * * root /usr/local/pf/addons/backup-and-maintenance.sh

# Active / Passive synchronization
#SYNC_SERVER_IP=X.X.X.X
# Synchronization for /usr/local/pf
#*/15 * * * *  pf [ ! -d /var/lib/mysql/pf ] && rsync -e 'ssh -i /usr/local/pf/.ssh/packetfence-sync' --delete -logDprtuv --exclude=logs/* --exclude=var/* --exclude=.ssh/* $SYNC_SERVER_IP:/usr/local/pf /usr/local
# Synchronization for /usr/local/fingerbank
#*/15 * * * *  pf [ ! -d /var/lib/mysql/pf ] && rsync -e 'ssh -i /usr/local/pf/.ssh/packetfence-sync' --delete -logDprtuv --exclude=logs/* $SYNC_SERVER_IP:/usr/local/fingerbank /usr/local


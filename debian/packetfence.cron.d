# /etc/cron.d/packetfence: crontab entries for the packetfence package

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

30 0 * * * root /usr/local/pf/addons/backup-and-maintenance.sh

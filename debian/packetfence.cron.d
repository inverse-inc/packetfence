# /etc/cron.d/packetfence: crontab entries for the packetfence package

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

30 0 * * * root /usr/local/pf/addons/exportable-backup.sh

# Renew any Let's Encrypt certificates the first of the month
1 0 1 * * root /usr/local/pf/bin/pfcmd renew_lets_encrypt

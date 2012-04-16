#
# Regular cron jobs for the packetfence package
#
0 4	* * *	root	[ -x /usr/bin/packetfence_maintenance ] && /usr/bin/packetfence_maintenance

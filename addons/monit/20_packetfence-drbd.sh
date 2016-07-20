#!/bin/bash

# OS specific binaries declarations
if [ -e "/etc/debian_version" ]; then
    FREERADIUS_BIN=freeradius
else
    FREERADIUS_BIN=radiusd
fi


cat >> /etc/monit.d/packetfence.monit << EOF


# DRBD checks

check file syslog with path /var/log/messages
    group drbd
    if match "lost: " then alert
    if match "Process pause detected for" then alert
    if match "Split-Brain detected" then alert
    if match "cannot run anywhere" then alert

check file drbd with path /proc/drbd
    group drbd
    if match "Inconsistent" then alert  

check filesystem drbdfs with path /dev/drbd0
    group drbd
    if space usage > 80 % then alert

EOF

#!/bin/bash
# Generate the unit files and enable the services once a valid configuration exists.

cd /usr/local/pf/conf/systemd
SERVICES=`ls *.service.tt | sed 's/packetfence-//; s/.service.tt//' | grep -v radiusd `
SERVICES="$SERVICES radiusd"
for s in  $SERVICES ; do 
    echo "Generateting  $s unit file "
    /usr/local/pf/bin/pfcmd service $s generateunitfile
done 

SERVICES_TO_ENABLE=$( ls /usr/lib/systemd/system/packetfence-*.service )
systemctl daemon-reload

for s in $SERVICES_TO_ENABLE; do 
    s=$( basename $s )
    echo "Enabling $s service"
    systemctl enable $s
done

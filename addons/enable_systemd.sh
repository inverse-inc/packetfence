#!/bin/bash
# create the required target directories and enables the packetfence systemd services.

mkdir /etc/systemd/system/packetfence-base.target.wants
mkdir /etc/systemd/system/packetfence.target.wants
mkdir /etc/systemd/system/packetfence-cluster.target.wants

for f in /usr/local/pf/conf/systemd/packetfence-*.target /usr/local/pf/conf/systemd/*.slice ; do 
    cp $f /etc/systemd/system/
done


SERVICES_TO_GENERATE=' 
packetfence-carbon-cache 
packetfence-carbon-relay 
packetfence-collectd 
packetfence-dhcpd 
packetfence-httpd.aaa 
packetfence-httpd.admin 
packetfence-httpd.graphite 
packetfence-httpd.parking 
packetfence-httpd.portal 
packetfence-httpd.webservices 
packetfence-p0f 
packetfence-pfdetect 
packetfence-pfdhcplistener 
packetfence-pfdns 
packetfence-pfmon 
packetfence-pfqueue 
packetfence-radiusd
packetfence-radsniff 
packetfence-redis_queue 
packetfence-statsd 
'

SERVICES_TO_ENABLE=$( ls /usr/lib/systemd/system/packetfence-*.service )

for s in $SERVICES_TO_GENERATE; do 
    echo "Generateting  $s unit file "
    /usr/local/pf/bin/pfcmd service $( echo $s | sed 's/packetfence-//' ) generateunitfile
done

systemctl daemon-reload

for s in $SERVICES_TO_ENABLE; do 
    s=$( basename $s )
    echo "Enabling $s service"
    systemctl enable $s
done

#!/bin/bash

ALERT_EMAIL=$1
SUBJECT_NAME=$2

if [ -z "$ALERT_EMAIL" ] || [ -z "$SUBJECT_NAME" ]; then
    echo 'Missing parameter(s)\n'
    echo 'Syntax should be: ./00_packetfence.sh "alerting@email.address" "subject identifier"'
    exit 1;
fi


# OS specific binaries declarations
if [ -e "/etc/debian_version" ]; then
    FREERADIUS_BIN=freeradius
else
    FREERADIUS_BIN=radiusd
fi

# We delete the monit logging configuration if any since the config below replaces it with syslog
rm -f /etc/monit.d/logging

cat > /etc/monit.d/packetfence.monit << EOF
set logfile syslog facility log_daemon

set mailserver localhost
set alert $ALERT_EMAIL
# next line make sure we get notified every cycle for specific types of alerts (ie.: resource limit (drive space))
set alert $ALERT_EMAIL { resource } with reminder on 1 cycle

set mail-format {
    from: monit@\$HOST
    subject: $SUBJECT_NAME | Monit Alert -- \$EVENT on resource '\$SERVICE'
    message:
    Date:        \$DATE
    Host:        \$HOST
    Event:       \$EVENT
    Resource:    \$SERVICE
    Action:      \$ACTION
    Description: \$DESCRIPTION

    A copy of this alert have been sent to the PacketFence support team.
}


# OS checks

check filesystem rootfs with path /
    group server
    if space usage > 90% then alert
    if inode usage > 75% then alert


# PacketFence system checks

check program patch with path /usr/local/pf/addons/pf-maint.pl -t
    every 10080 cycles
    noalert $ALERT_EMAIL
    if status != 0 then exec "/bin/mail -s '$SUBJECT_NAME - PacketFence maintenance patch available' $ALERT_EMAIL"


# PacketFence services checks

check process packetfence-config with pidfile /usr/local/pf/var/run/pfconfig.pid
    group PacketFence
    start program = "/sbin/service packetfence-config start" with timeout 60 seconds
    stop program  = "/sbin/service packetfence-config stop"

check process packetfence-redis-cache with pidfile /usr/local/pf/var/run/redis_cache.pid
    group PacketFence
    start program = "/sbin/service packetfence-redis-cache start" with timeout 60 seconds
    stop program  = "/sbin/service packetfence-redis-cache stop"
    if failed host 127.0.0.1 port 6379 protocol redis then alert

check process packetfence-dhcpd with pidfile /usr/local/pf/var/run/dhcpd.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service dhcpd start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service dhcpd stop"

check process packetfence-httpd.aaa with pidfile /usr/local/pf/var/run/httpd.aaa.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service httpd.aaa start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service httpd.aaa stop"

check process packetfence-httpd.admin with pidfile /usr/local/pf/var/run/httpd.admin.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service httpd.admin start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service httpd.admin stop"

check process packetfence-httpd.graphite with pidfile /usr/local/pf/var/run/httpd.graphite.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service httpd.graphite start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service httpd.graphite stop"

check process packetfence-httpd.parking with pidfile /usr/local/pf/var/run/httpd.parking.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service httpd.parking start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service httpd.parking stop"

check process packetfence-httpd.portal with pidfile /usr/local/pf/var/run/httpd.portal.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service httpd.portal start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service httpd.portal stop"

check process packetfence-httpd.webservices with pidfile /usr/local/pf/var/run/httpd.webservices.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service httpd.webservices start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service httpd.webservices stop"

check process packetfence-pfdns with pidfile /usr/local/pf/var/run/pfdns.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service pfdns start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service pfdns stop"

check process packetfence-pfmon with pidfile /usr/local/pf/var/run/pfmon.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service pfmon start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service pfmon stop"

check process packetfence-pfqueue with pidfile /usr/local/pf/var/run/pfqueue.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service pfqueue start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service pfqueue stop"

check process packetfence-radiusd-acct with pidfile /usr/local/pf/var/run/radiusd-acct.pid
    group PacketFence
    start program = "/usr/sbin/$FREERADIUS_BIN -d /usr/local/pf/raddb -n acct" with timeout 60 seconds
    stop program  = "/usr/bin/pkill -F /usr/local/pf/var/run/radiusd-acct.pid"

check process packetfence-radiusd with pidfile /usr/local/pf/var/run/radiusd.pid
    group PacketFence
    start program = "/usr/sbin/$FREERADIUS_BIN -d /usr/local/pf/raddb -n auth" with timeout 60 seconds
    stop program  = "/usr/bin/pkill -F /usr/local/pf/var/run/radiusd.pid"
    if failed host 127.0.0.1 port 18120 type udp protocol radius
        secret testing123
    then alert

check process packetfence-redis_queue with pidfile /usr/local/pf/var/run/redis_queue.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service redis_queue start" with timeout 60 seconds
    stop program = "/usr/local/pf/bin/pfcmd service redis_queue stop"
    if failed host 127.0.0.1 port 6380 protocol redis then alert

EOF

for i in /usr/local/pf/var/run/pfdhcp*.pid;do

cat >> /etc/monit.d/packetfence.monit << EOF
check process packetfence-`basename $i .pid` with pidfile /usr/local/pf/var/run/`basename $i`
    group PacketFence
    start program = "/usr/local/pf/sbin/pfdhcplistener -i $(echo `basename $i` | sed 's/pfdhcplistener_\(.*\).pid/\1/') -d" with timeout 60 seconds
    stop program  = "/bin/kill -9 \$(cat $i)"

EOF

done

for domain in `perl -I/usr/local/pf/lib  -Mpf::config -e 'print join("\n", keys(%pf::config::ConfigDomain))'`;do

PID_FILE=`perl -I/usr/local/pf/lib -Mpf::services::manager::winbindd_child -e "print pf::services::manager::winbindd_child->new(name => 'dummy', domain => '$domain')->pidFile"`
cat >> /etc/monit.d/packetfence.monit << EOF
check process packetfence-winbind-$domain with pidfile $PID_FILE
    group PacketFence
    start program = "/usr/sbin/winbindd -D -s /etc/samba/$domain.conf -l /var/log/samba$domain" with timeout 60 seconds
    stop program  = "/bin/kill $PID_FILE"

EOF

done

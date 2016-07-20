#!/bin/bash

# OS specific binaries declarations
if [ -e "/etc/debian_version" ]; then
    FREERADIUS_BIN=freeradius
else
    FREERADIUS_BIN=radiusd
fi


cat >> /etc/monit.d/packetfence.monit << EOF


# PacketFence active-active clustering checks

check process packetfence-haproxy with pidfile /usr/local/pf/var/run/haproxy.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service haproxy start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service haproxy stop"

check process packetfence-keepalived with pidfile /usr/local/pf/var/run/keepalived.pid
    group PacketFence
    start program = "/usr/local/pf/bin/pfcmd service keepalived start" with timeout 60 seconds
    stop program  = "/usr/local/pf/bin/pfcmd service keepalived stop"

check process packetfence-radiusd-load_balancer with pidfile /usr/local/pf/var/run/radiusd-load_balancer.pid
    group PacketFence
    start program = "/usr/sbin/$FREERADIUS_BIN -d /usr/local/pf/raddb -n load_balancer" with timeout 60 seconds
    stop program  = "/bin/kill /usr/local/pf/var/run/radiusd-load_balancer.pid"

EOF

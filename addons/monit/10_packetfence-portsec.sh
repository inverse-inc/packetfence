#!/bin/bash

cat >> /etc/monit.d/packetfence.monit << EOF


# PacketFence SNMP checks

check process packetfence-pfsetvlan with pidfile /usr/local/pf/var/run/pfsetvlan.pid
       group PacketFence
       start program = "/usr/local/pf/bin/pfcmd service pfsetvlan start" with timeout 60 seconds
       stop program = "/usr/local/pf/bin/pfcmd service pfsetvlan stop"

check process packetfence-snmptrapd with pidfile /usr/local/pf/var/run/snmptrapd.pid
       group PacketFence
       start program = "/usr/local/pf/bin/pfcmd service snmptrapd start" with timeout 60 seconds
       stop program = "/usr/local/pf/bin/pfcmd service snmptrapd stop"

EOF

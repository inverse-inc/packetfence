
cat >> /etc/monit.d/packetfence.monit << EOF

check process packetfence-winbindd with pidfile /var/run/winbindd.pid
    group PacketFence
    start program = "service winbind start" with timeout 60 seconds
    stop program  = "service winbind stop"

EOF
